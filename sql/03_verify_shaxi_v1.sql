-- ============================================================
-- sql/03_verify_shaxi_v1.sql
-- Shaxi staging -> operational truth VERIFICATION ONLY
-- Batch: shaxi_promotion_v1
--
-- Purpose: Read-only verification before promotion.
--          Does NOT insert, update, delete, or promote.
--          Does NOT write to lease_package_components.
-- ============================================================


-- ============================================================
-- 1. SCHEMA AWARENESS CHECKS
--    Verify final schema FK relationships and required fields.
-- ============================================================

-- 1.1 rentable_areas.property_id -> properties.id
-- Expected: 0 invalid references
SELECT
  'FK_CHECK: rentable_areas.property_id -> properties.id' AS check_name,
  COUNT(*) AS invalid_references
FROM public.rentable_areas ra
LEFT JOIN public.properties p ON ra.property_id = p.id
WHERE ra.property_id IS NOT NULL AND p.id IS NULL;


-- 1.2 rentable_areas.building_id -> building_registry.id
-- Expected: 0 invalid references
SELECT
  'FK_CHECK: rentable_areas.building_id -> building_registry.id' AS check_name,
  COUNT(*) AS invalid_references
FROM public.rentable_areas ra
LEFT JOIN public.building_registry b ON ra.building_id = b.id
WHERE ra.building_id IS NOT NULL AND b.id IS NULL;


-- 1.3 properties.property_code exists and is not null/empty
-- Expected: 0 null/empty codes
SELECT
  'FIELD_CHECK: properties.property_code mandatory' AS check_name,
  COUNT(*) AS null_or_empty_codes
FROM public.properties
WHERE property_code IS NULL OR TRIM(property_code) = '';


-- 1.4 building_registry.building_code exists and is not null/empty
-- Expected: 0 null/empty codes
SELECT
  'FIELD_CHECK: building_registry.building_code mandatory' AS check_name,
  COUNT(*) AS null_or_empty_codes
FROM public.building_registry
WHERE building_code IS NULL OR TRIM(building_code) = '';


-- ============================================================
-- 2. STAGED SHAXI AREA LOOKUP VERIFICATION
--    Verify all 11 staged areas resolve to properties + buildings.
-- ============================================================

WITH staged_areas AS (
  SELECT
    s.property_code,
    s.building_code,
    s.prepared_area_name,
    p.id AS matched_property_id,
    b.id AS matched_building_id
  FROM public.stg_shaxi_areas_prepared s
  LEFT JOIN public.properties p ON p.property_code = s.property_code
  LEFT JOIN public.building_registry b ON b.building_code = s.building_code
)

SELECT
  'STAGED_AREA_LOOKUP' AS check_category,
  (SELECT COUNT(*) FROM public.stg_shaxi_areas_prepared) AS total_staged_areas,
  (SELECT COUNT(*) FROM staged_areas WHERE matched_property_id IS NOT NULL) AS matched_properties,
  (SELECT COUNT(*) FROM staged_areas WHERE matched_building_id IS NOT NULL) AS matched_buildings,
  (SELECT COUNT(*) FROM staged_areas WHERE matched_property_id IS NULL) AS missing_property_matches,
  (SELECT COUNT(*) FROM staged_areas WHERE matched_building_id IS NULL) AS missing_building_matches;


-- Detail: list any missing property matches (expected: 0 rows)
SELECT
  'MISSING_PROPERTY_MATCH' AS issue_type,
  s.property_code,
  s.building_code,
  s.prepared_area_name
FROM public.stg_shaxi_areas_prepared s
LEFT JOIN public.properties p ON p.property_code = s.property_code
WHERE p.id IS NULL;


-- Detail: list any missing building matches (expected: 0 rows)
SELECT
  'MISSING_BUILDING_MATCH' AS issue_type,
  s.property_code,
  s.building_code,
  s.prepared_area_name
FROM public.stg_shaxi_areas_prepared s
LEFT JOIN public.building_registry b ON b.building_code = s.building_code
WHERE b.id IS NULL;


-- ============================================================
-- 3. PROMOTION_CONTRACT_AREA_CANDIDATES VERIFICATION
--    Expected: 9 pending review rows after dedup.
-- ============================================================

-- 3.1 Dedup status for this batch
WITH dedup_check AS (
  SELECT
    source_company,
    tenant_name,
    mapped_property_code,
    mapped_parcel_code,
    mapped_building_code,
    mapped_area_name,
    COUNT(*) AS duplicate_count
  FROM public.promotion_contract_area_candidates
  WHERE promotion_batch = 'shaxi_promotion_v1'
  GROUP BY
    source_company,
    tenant_name,
    mapped_property_code,
    mapped_parcel_code,
    mapped_building_code,
    mapped_area_name
)
SELECT
  'CANDIDATES_DEDUP_STATUS' AS check_name,
  COUNT(*) AS distinct_candidate_groups,
  SUM(duplicate_count) AS total_raw_rows,
  MAX(duplicate_count) AS max_duplicate_per_group,
  CASE WHEN MAX(duplicate_count) > 1 THEN 'HAS_DUPLICATES' ELSE 'CLEAN' END AS dedup_status
FROM dedup_check;


-- 3.2 Review status breakdown for this batch
SELECT
  'CANDIDATES_REVIEW_STATUS' AS check_name,
  promotion_batch,
  review_status,
  candidate_reason,
  COUNT(*) AS row_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
GROUP BY promotion_batch, review_status, candidate_reason;


-- 3.3 Expected unmatched contract-area sources (transparency)
-- These 9 contracts reference areas not present in stg_shaxi_areas_prepared.
-- They remain in review; they are NOT promoted to lease_package_components.
SELECT
  'EXPECTED_UNMATCHED_CONTRACT_AREAS' AS check_category,
  c.tenant_name,
  c.mapped_property_code,
  c.mapped_parcel_code,
  c.mapped_building_code,
  c.mapped_area_name,
  c.rented_unit_text
FROM public.stg_shaxi_contracts_prepared c
LEFT JOIN public.stg_shaxi_areas_prepared a
  ON c.mapped_property_code = a.property_code
  AND c.mapped_parcel_code = a.parcel_code
  AND c.mapped_building_code = a.building_code
  AND c.mapped_area_name = a.prepared_area_name
WHERE a.property_code IS NULL
  AND c.mapped_property_code IS NOT NULL
  AND c.mapped_property_code <> ''
ORDER BY c.mapped_building_code, c.mapped_area_name;


-- ============================================================
-- 4. POST-PROMOTION VERIFICATION
--    Run these checks after executing sql/02_promote_shaxi_v1.sql.
-- ============================================================

-- 4.1 All 11 staged areas now exist in rentable_areas
-- Expected: 11
SELECT
  'POST_PROMOTION: staged areas in rentable_areas' AS check_name,
  COUNT(*) AS promoted_area_count
FROM public.stg_shaxi_areas_prepared s
JOIN public.properties p ON p.property_code = s.property_code
JOIN public.building_registry b ON b.building_code = s.building_code
JOIN public.rentable_areas ra
  ON ra.property_id = p.id
  AND ra.building_id = b.id
  AND ra.area_name = s.prepared_area_name;


-- 4.2 No duplicate area names per building for SX-39
-- Expected: 0
SELECT
  'POST_PROMOTION: duplicate area_name per building' AS check_name,
  COUNT(*) AS duplicate_count
FROM (
  SELECT ra.property_id, ra.building_id, ra.area_name
  FROM public.rentable_areas ra
  JOIN public.properties p ON p.id = ra.property_id
  WHERE p.property_code = 'SX-39'
  GROUP BY ra.property_id, ra.building_id, ra.area_name
  HAVING COUNT(*) > 1
) dups;


-- 4.3 Candidates still 9 pending review
-- Expected: 9
SELECT
  'POST_PROMOTION: candidates pending review' AS check_name,
  COUNT(*) AS pending_review_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review';


-- 4.4 No accidental lease_package_components created for newly promoted areas
-- Newly promoted areas are identified by batch note.
-- Expected: 0
SELECT
  'POST_PROMOTION: accidental components for new areas' AS check_name,
  COUNT(lpc.id) AS component_count
FROM public.lease_package_components lpc
JOIN public.rentable_areas ra ON ra.id = lpc.rentable_area_id
WHERE ra.notes LIKE '%batch: shaxi_promotion_v1%';


-- ============================================================
-- 5. CONTRACT PROMOTION VERIFICATION
--    Run these checks after executing sql/04_promote_shaxi_contracts_v1_1.sql.
-- ============================================================

-- 5.1 All 10 staged contracts now exist in contracts
-- Expected: 10
SELECT
  'POST_CONTRACT: staged contracts in contracts' AS check_name,
  COUNT(*) AS promoted_contract_count
FROM public.stg_shaxi_contracts_prepared s
JOIN public.contacts con ON con.name = s.tenant_name
JOIN public.contracts c
  ON c.tenant_id = con.id
  AND c.monthly_rent = s.monthly_rent
  AND c.start_date = s.contract_start_date
  AND c.end_date = s.contract_end_date;


-- 5.2 No duplicate contracts per tenant + unit + dates
-- Expected: 0
SELECT
  'POST_CONTRACT: duplicate contracts' AS check_name,
  COUNT(*) AS duplicate_count
FROM (
  SELECT tenant_id, unit_id, start_date, end_date
  FROM public.contracts
  GROUP BY tenant_id, unit_id, start_date, end_date
  HAVING COUNT(*) > 1
) dups;


-- 5.3 Candidates still 9 pending review
-- Expected: 9
SELECT
  'POST_CONTRACT: candidates pending review' AS check_name,
  COUNT(*) AS pending_review_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review';


-- ============================================================
-- 6. CONTRACT SOURCE AUDIT VERIFICATION
--    Run these checks after executing sql/05_add_contract_source_audit_fields.sql.
-- ============================================================

-- 6.1 10 Shaxi contracts have promotion_batch = 'shaxi_contracts_v1_1'
-- Expected: 10
SELECT
  'AUDIT: contracts with batch tag' AS check_name,
  COUNT(*) AS batch_tagged_count
FROM public.contracts
WHERE promotion_batch = 'shaxi_contracts_v1_1';


-- 6.2 10 Shaxi contracts have source_rented_unit_text not null
-- Expected: 10
SELECT
  'AUDIT: contracts with source_rented_unit_text' AS check_name,
  COUNT(*) AS populated_count
FROM public.contracts
WHERE promotion_batch = 'shaxi_contracts_v1_1'
  AND source_rented_unit_text IS NOT NULL;


-- 6.3 10 Shaxi contracts have mapped_area_name not null
-- Expected: 10
SELECT
  'AUDIT: contracts with mapped_area_name' AS check_name,
  COUNT(*) AS populated_count
FROM public.contracts
WHERE promotion_batch = 'shaxi_contracts_v1_1'
  AND mapped_area_name IS NOT NULL;


-- 6.4 9 candidates remain pending_review
-- Expected: 9
SELECT
  'AUDIT: candidates still pending review' AS check_name,
  COUNT(*) AS pending_review_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review';


-- ============================================================
-- 7. APPROVED CANDIDATE AREA PROMOTION VERIFICATION
--    Run these checks after executing sql/10_apply_approved_candidate_areas_v1_3.sql.
-- ============================================================

-- 7.1 Approved candidates now have target_rentable_area_id
-- Expected: 6
SELECT
  'APPROVED: candidates with rentable_area_id' AS check_name,
  COUNT(*) AS linked_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_decision = 'approve_new_area'
  AND target_rentable_area_id IS NOT NULL;


-- 7.2 Approved candidates marked as area_created
-- Expected: 6
SELECT
  'APPROVED: candidates marked area_created' AS check_name,
  COUNT(*) AS area_created_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'area_created';


-- 7.3 Still-pending candidates remain untouched
-- Expected: 3
SELECT
  'APPROVED: still-pending candidates' AS check_name,
  COUNT(*) AS pending_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review';


-- 7.4 No duplicate rentable_areas created
-- Expected: 0
SELECT
  'APPROVED: duplicate rentable_areas' AS check_name,
  COUNT(*) AS duplicate_count
FROM (
  SELECT property_id, building_id, area_name
  FROM public.rentable_areas
  GROUP BY property_id, building_id, area_name
  HAVING COUNT(*) > 1
) dups;


-- 7.5 No accidental lease_package_components created
-- Expected: 0
SELECT
  'APPROVED: accidental lease_package_components' AS check_name,
  COUNT(lpc.id) AS component_count
FROM public.lease_package_components lpc
JOIN public.rentable_areas ra ON ra.id = lpc.rentable_area_id
WHERE ra.notes LIKE '%approved candidate%'
  AND ra.notes LIKE '%batch: shaxi_promotion_v1%';


-- ============================================================
-- 8. LEASE_PACKAGE_COMPONENTS VERIFICATION
--    Run these checks after executing sql/11_create_safe_lease_package_components_v1_4.sql.
-- ============================================================

-- 8.1 Safe components created or present for this flow
-- Expected: 7
SELECT
  'COMPONENTS: safe components for batch' AS check_name,
  COUNT(*) AS component_count
FROM public.lease_package_components
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND created_from = 'safe_link_v1_4';


-- 8.2 Still-pending candidates remain untouched
-- Expected: 3
SELECT
  'COMPONENTS: still-pending candidates' AS check_name,
  COUNT(*) AS pending_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review';


-- 8.3 No components created for pending candidates
-- Expected: 0
SELECT
  'COMPONENTS: components for pending candidates' AS check_name,
  COUNT(lpc.id) AS component_count
FROM public.lease_package_components lpc
JOIN public.promotion_contract_area_candidates pc
  ON pc.id = lpc.source_candidate_id
WHERE pc.promotion_batch = 'shaxi_promotion_v1'
  AND pc.review_status = 'pending_review';


-- 8.4 No duplicate components (same unit + rentable_area)
-- Expected: 0
SELECT
  'COMPONENTS: duplicate components' AS check_name,
  COUNT(*) AS duplicate_count
FROM (
  SELECT package_unit_id, rentable_area_id
  FROM public.lease_package_components
  GROUP BY package_unit_id, rentable_area_id
  HAVING COUNT(*) > 1
) dups;
