-- ============================================================
-- sql/10_apply_approved_candidate_areas_v1_3.sql
-- Apply approved candidate decisions into rentable_areas truth
-- Batch: shaxi_promotion_v1
--
-- Purpose: Create new rentable_areas rows for the 6 approved
--          candidates and link them back to the candidate table.
--
-- Rules:
--   1. Only processes candidates where:
--      - promotion_batch = 'shaxi_promotion_v1'
--      - review_status = 'pending_review'
--      - review_decision = 'approve_new_area'
--      - approved_area_name IS NOT NULL
--   2. Generates safe area_code.
--   3. Idempotent via WHERE NOT EXISTS (property_id, building_id, area_name).
--   4. Backfills target_rentable_area_id on candidate rows.
--   5. Marks successfully linked candidates as review_status = 'area_created'.
--   6. Does NOT touch still-pending candidates.
--   7. Does NOT create lease_package_components.
-- ============================================================


-- ============================================================
-- STEP 1: Preview rows to be inserted
-- Expected: 6
-- ============================================================

WITH inferred_types AS (
  SELECT DISTINCT ON (c.id)
    c.id AS candidate_id,
    ra.area_type AS inferred_area_type
  FROM public.promotion_contract_area_candidates c
  JOIN public.contacts con ON con.name = c.tenant_name
  JOIN public.contracts ct
    ON ct.tenant_id = con.id
    AND ct.monthly_rent = c.monthly_rent
    AND ct.start_date = c.contract_start_date
    AND ct.end_date = c.contract_end_date
  JOIN public.units u ON u.id = ct.unit_id
  JOIN public.lease_package_components lpc ON lpc.package_unit_id = u.id
  JOIN public.rentable_areas ra ON ra.id = lpc.rentable_area_id
  WHERE c.promotion_batch = 'shaxi_promotion_v1'
    AND c.review_status = 'pending_review'
    AND c.review_decision = 'approve_new_area'
    AND c.approved_area_name IS NOT NULL
  ORDER BY c.id, CASE WHEN lpc.component_role = 'primary' THEN 0 ELSE 1 END
)
SELECT
  c.id AS candidate_id,
  c.tenant_name,
  c.mapped_property_code,
  c.mapped_building_code,
  c.approved_area_name,
  c.approved_leaseable_scope,
  COALESCE(c.approved_area_type, it.inferred_area_type) AS area_type,
  CASE
    WHEN c.approved_area_name LIKE '%层%' OR c.approved_area_name LIKE '%卡%'
    THEN REPLACE(c.approved_area_name, c.mapped_building_name, '')
    ELSE NULL
  END AS derived_floor_label,
  'RA-' || c.mapped_building_code || '-' ||
    CASE
      WHEN NULLIF(REPLACE(c.approved_area_name, c.mapped_building_name, ''), '') IS NULL
      THEN COALESCE(c.approved_leaseable_scope, 'FULL')
      ELSE REPLACE(c.approved_area_name, c.mapped_building_name, '')
    END AS generated_area_code
FROM public.promotion_contract_area_candidates c
JOIN public.properties p ON p.property_code = c.mapped_property_code
JOIN public.building_registry b ON b.building_code = c.mapped_building_code
LEFT JOIN inferred_types it ON it.candidate_id = c.id
LEFT JOIN public.rentable_areas existing
  ON existing.property_id = p.id
  AND existing.building_id = b.id
  AND existing.area_name = c.approved_area_name
WHERE c.promotion_batch = 'shaxi_promotion_v1'
  AND c.review_status = 'pending_review'
  AND c.review_decision = 'approve_new_area'
  AND c.approved_area_name IS NOT NULL
  AND existing.id IS NULL
ORDER BY c.id;


-- ============================================================
-- STEP 2: Insert new rentable_areas for approved candidates
-- ============================================================

WITH inferred_types AS (
  SELECT DISTINCT ON (c.id)
    c.id AS candidate_id,
    ra.area_type AS inferred_area_type
  FROM public.promotion_contract_area_candidates c
  JOIN public.contacts con ON con.name = c.tenant_name
  JOIN public.contracts ct
    ON ct.tenant_id = con.id
    AND ct.monthly_rent = c.monthly_rent
    AND ct.start_date = c.contract_start_date
    AND ct.end_date = c.contract_end_date
  JOIN public.units u ON u.id = ct.unit_id
  JOIN public.lease_package_components lpc ON lpc.package_unit_id = u.id
  JOIN public.rentable_areas ra ON ra.id = lpc.rentable_area_id
  WHERE c.promotion_batch = 'shaxi_promotion_v1'
    AND c.review_status = 'pending_review'
    AND c.review_decision = 'approve_new_area'
    AND c.approved_area_name IS NOT NULL
  ORDER BY c.id, CASE WHEN lpc.component_role = 'primary' THEN 0 ELSE 1 END
)
INSERT INTO public.rentable_areas (
  property_id,
  building_id,
  area_code,
  area_name,
  area_type,
  floor_label,
  leaseable_scope,
  current_status,
  section_group_name,
  source_text_raw,
  certificate_no_raw,
  notes,
  created_at
)
SELECT
  p.id,
  b.id,
  'RA-' || c.mapped_building_code || '-' ||
    CASE
      WHEN NULLIF(REPLACE(c.approved_area_name, c.mapped_building_name, ''), '') IS NULL
      THEN COALESCE(c.approved_leaseable_scope, 'FULL')
      ELSE REPLACE(c.approved_area_name, c.mapped_building_name, '')
    END,
  c.approved_area_name,
  COALESCE(c.approved_area_type, it.inferred_area_type),
  CASE
    WHEN c.approved_area_name LIKE '%层%' OR c.approved_area_name LIKE '%卡%'
    THEN REPLACE(c.approved_area_name, c.mapped_building_name, '')
    ELSE NULL
  END,
  c.approved_leaseable_scope,
  COALESCE(c.approved_current_status, 'occupied'),
  lp.parcel_name,
  c.source_company,
  lp.certificate_no_raw,
  'Created from approved candidate ' || c.id || ' | batch: shaxi_promotion_v1',
  NOW()
FROM public.promotion_contract_area_candidates c
JOIN public.properties p ON p.property_code = c.mapped_property_code
JOIN public.building_registry b ON b.building_code = c.mapped_building_code
LEFT JOIN public.land_parcels lp ON lp.parcel_code = c.mapped_parcel_code
LEFT JOIN inferred_types it ON it.candidate_id = c.id
LEFT JOIN public.rentable_areas existing
  ON existing.property_id = p.id
  AND existing.building_id = b.id
  AND existing.area_name = c.approved_area_name
WHERE c.promotion_batch = 'shaxi_promotion_v1'
  AND c.review_status = 'pending_review'
  AND c.review_decision = 'approve_new_area'
  AND c.approved_area_name IS NOT NULL
  AND existing.id IS NULL;


-- ============================================================
-- STEP 3: Backfill target_rentable_area_id on candidate rows
-- ============================================================

UPDATE public.promotion_contract_area_candidates c
SET target_rentable_area_id = ra.id
FROM public.rentable_areas ra
JOIN public.properties p ON p.id = ra.property_id
JOIN public.building_registry b ON b.id = ra.building_id
WHERE c.mapped_property_code = p.property_code
  AND c.mapped_building_code = b.building_code
  AND c.approved_area_name = ra.area_name
  AND c.promotion_batch = 'shaxi_promotion_v1'
  AND c.review_decision = 'approve_new_area'
  AND c.review_status = 'pending_review';


-- ============================================================
-- STEP 4: Mark successfully linked approved candidates
-- ============================================================

UPDATE public.promotion_contract_area_candidates
SET
  review_status = 'area_created',
  resolved_at = NOW()
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_decision = 'approve_new_area'
  AND target_rentable_area_id IS NOT NULL
  AND review_status = 'pending_review';


-- ============================================================
-- STEP 5: Verification
-- ============================================================

-- 5.1 Approved candidates now have target_rentable_area_id
-- Expected: 6
SELECT
  'POST_APPLY: approved candidates with rentable_area_id' AS check_name,
  COUNT(*) AS linked_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_decision = 'approve_new_area'
  AND target_rentable_area_id IS NOT NULL;


-- 5.2 Approved candidates marked as area_created
-- Expected: 6
SELECT
  'POST_APPLY: approved candidates marked area_created' AS check_name,
  COUNT(*) AS area_created_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'area_created';


-- 5.3 Still-pending candidates remain untouched
-- Expected: 3
SELECT
  'POST_APPLY: still-pending candidates' AS check_name,
  COUNT(*) AS pending_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review';


-- 5.4 No duplicate rentable_areas created
-- Expected: 0
SELECT
  'POST_APPLY: duplicate rentable_areas' AS check_name,
  COUNT(*) AS duplicate_count
FROM (
  SELECT property_id, building_id, area_name
  FROM public.rentable_areas
  GROUP BY property_id, building_id, area_name
  HAVING COUNT(*) > 1
) dups;


-- 5.5 No accidental lease_package_components created for new areas
-- Expected: 0
SELECT
  'POST_APPLY: accidental lease_package_components' AS check_name,
  COUNT(lpc.id) AS component_count
FROM public.lease_package_components lpc
JOIN public.rentable_areas ra ON ra.id = lpc.rentable_area_id
WHERE ra.notes LIKE '%batch: shaxi_promotion_v1%'
  AND ra.notes LIKE '%approved candidate%';
