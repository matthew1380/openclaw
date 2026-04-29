-- ============================================================
-- sql/12_resolve_pending_candidates_v1_5.sql
-- Resolve remaining 3 pending candidates for Shaxi
-- Batch: shaxi_promotion_v1
--
-- Purpose: Classify and resolve the 3 remaining pending
--          promotion_contract_area_candidates into approved
--          rentable_areas and safe lease_package_components.
--
-- Candidates:
--   8 中山市鲸鸣服饰有限公司 — 三区A栋4层
--   3 杨华禾                 — 三区A栋首层1卡
--   4 朱河芳                 — 三区A栋首层2卡
--
-- Classification: All 3 approved as new areas (precise physical
-- locations, consistent with previous 6 approvals).
--
-- Rules:
--   - Does NOT create components for pending_review candidates.
--   - Idempotent rentable_area insert via WHERE NOT EXISTS.
--   - Idempotent component insert via WHERE NOT EXISTS.
--   - All components trace back to approved or exact original source.
-- ============================================================


-- ============================================================
-- STEP 1: Preview decisions to be applied
-- ============================================================

SELECT
  id AS candidate_id,
  tenant_name,
  mapped_area_name AS current_area_name,
  CASE id
    WHEN 8 THEN 'approve_new_area — whole floor lease (整层)'
    WHEN 3 THEN 'approve_new_area — specific card lease'
    WHEN 4 THEN 'approve_new_area — specific card lease'
  END AS classification,
  CASE id
    WHEN 8 THEN '三区A栋4层'
    WHEN 3 THEN '三区A栋首层1卡'
    WHEN 4 THEN '三区A栋首层2卡'
  END AS proposed_approved_area_name,
  CASE id
    WHEN 8 THEN '整层'
    ELSE NULL
  END AS proposed_leaseable_scope
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review'
  AND id IN (3, 4, 8)
ORDER BY id;


-- ============================================================
-- STEP 2: Apply review decisions
-- Idempotent: only touches rows still in pending_review.
-- ============================================================

UPDATE public.promotion_contract_area_candidates
SET
  review_decision = 'approve_new_area',
  approved_area_name = CASE id
    WHEN 8 THEN '三区A栋4层'
    WHEN 3 THEN '三区A栋首层1卡'
    WHEN 4 THEN '三区A栋首层2卡'
  END,
  approved_leaseable_scope = CASE id
    WHEN 8 THEN '整层'
    ELSE NULL
  END,
  approved_area_type = 'factory',
  reviewed_by = 'human_review_2026-04-27',
  reviewed_at = NOW(),
  resolution_notes = CASE id
    WHEN 8 THEN 'Staff decision: approve whole floor (整层) for 三区A栋4层'
    WHEN 3 THEN 'Staff decision: approve specific card for 三区A栋首层1卡'
    WHEN 4 THEN 'Staff decision: approve specific card for 三区A栋首层2卡'
  END
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review'
  AND id IN (3, 4, 8);


-- ============================================================
-- STEP 3: Preview rentable_areas to be created
-- Expected: 3
-- ============================================================

SELECT
  c.id AS candidate_id,
  c.tenant_name,
  c.mapped_property_code,
  c.mapped_building_code,
  c.approved_area_name,
  c.approved_leaseable_scope,
  c.approved_area_type,
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
    END AS generated_area_code,
  CASE WHEN existing.id IS NOT NULL THEN 'EXISTS — will skip' ELSE 'NEW — will insert' END AS insert_action
FROM public.promotion_contract_area_candidates c
JOIN public.properties p ON p.property_code = c.mapped_property_code
JOIN public.building_registry b ON b.building_code = c.mapped_building_code
LEFT JOIN public.rentable_areas existing
  ON existing.property_id = p.id
  AND existing.building_id = b.id
  AND existing.area_name = c.approved_area_name
WHERE c.promotion_batch = 'shaxi_promotion_v1'
  AND c.review_status = 'pending_review'
  AND c.review_decision = 'approve_new_area'
  AND c.approved_area_name IS NOT NULL
  AND c.id IN (3, 4, 8)
ORDER BY c.id;


-- ============================================================
-- STEP 4: Insert new rentable_areas for approved candidates
-- Idempotent via WHERE NOT EXISTS (property_id, building_id, area_name).
-- ============================================================

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
  COALESCE(c.approved_area_type, 'factory'),
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
LEFT JOIN public.rentable_areas existing
  ON existing.property_id = p.id
  AND existing.building_id = b.id
  AND existing.area_name = c.approved_area_name
WHERE c.promotion_batch = 'shaxi_promotion_v1'
  AND c.review_status = 'pending_review'
  AND c.review_decision = 'approve_new_area'
  AND c.approved_area_name IS NOT NULL
  AND c.id IN (3, 4, 8)
  AND existing.id IS NULL;


-- ============================================================
-- STEP 5: Backfill target_rentable_area_id on candidate rows
-- Idempotent: only sets NULL values.
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
  AND c.id IN (3, 4, 8)
  AND c.target_rentable_area_id IS NULL;


-- ============================================================
-- STEP 6: Mark successfully linked approved candidates
-- Idempotent: only touches rows not yet marked area_created.
-- ============================================================

UPDATE public.promotion_contract_area_candidates
SET
  review_status = 'area_created',
  resolved_at = NOW()
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_decision = 'approve_new_area'
  AND target_rentable_area_id IS NOT NULL
  AND id IN (3, 4, 8)
  AND review_status != 'area_created';


-- ============================================================
-- STEP 7: Preview safe lease_package_components to be created
-- Expected: 3
-- ============================================================

WITH approved_candidate_links AS (
  SELECT
    pc.id AS candidate_id,
    pc.tenant_name,
    pc.approved_area_name AS area_name,
    c.id AS contract_id,
    c.unit_id,
    pc.target_rentable_area_id AS rentable_area_id,
    'approved_candidate' AS link_type
  FROM public.promotion_contract_area_candidates pc
  JOIN public.contacts con ON con.name = pc.tenant_name
  JOIN public.contracts c
    ON c.tenant_id = con.id
    AND c.monthly_rent = pc.monthly_rent
    AND c.start_date = pc.contract_start_date
    AND c.end_date = pc.contract_end_date
  WHERE pc.promotion_batch = 'shaxi_promotion_v1'
    AND pc.review_status = 'area_created'
    AND pc.review_decision = 'approve_new_area'
    AND pc.target_rentable_area_id IS NOT NULL
    AND pc.id IN (3, 4, 8)
)
SELECT
  l.link_type,
  l.candidate_id,
  l.tenant_name,
  l.area_name,
  l.unit_id,
  l.rentable_area_id,
  CASE WHEN existing.id IS NOT NULL THEN 'EXISTS — will skip' ELSE 'NEW — will insert' END AS insert_action
FROM approved_candidate_links l
LEFT JOIN public.lease_package_components existing
  ON existing.package_unit_id = l.unit_id
  AND existing.rentable_area_id = l.rentable_area_id
ORDER BY l.candidate_id;


-- ============================================================
-- STEP 8: Insert safe lease_package_components
-- Idempotent via WHERE NOT EXISTS (package_unit_id, rentable_area_id).
-- Audit columns: promotion_batch, source_candidate_id,
--                source_staging_table, created_from.
-- ============================================================

WITH approved_candidate_links AS (
  SELECT
    pc.id AS candidate_id,
    pc.tenant_name,
    pc.approved_area_name AS area_name,
    c.id AS contract_id,
    c.unit_id,
    pc.target_rentable_area_id AS rentable_area_id,
    'approved_candidate' AS link_type
  FROM public.promotion_contract_area_candidates pc
  JOIN public.contacts con ON con.name = pc.tenant_name
  JOIN public.contracts c
    ON c.tenant_id = con.id
    AND c.monthly_rent = pc.monthly_rent
    AND c.start_date = pc.contract_start_date
    AND c.end_date = pc.contract_end_date
  WHERE pc.promotion_batch = 'shaxi_promotion_v1'
    AND pc.review_status = 'area_created'
    AND pc.review_decision = 'approve_new_area'
    AND pc.target_rentable_area_id IS NOT NULL
    AND pc.id IN (3, 4, 8)
)
INSERT INTO public.lease_package_components (
  package_unit_id,
  rentable_area_id,
  component_role,
  notes,
  promotion_batch,
  source_candidate_id,
  source_staging_table,
  created_from,
  created_at
)
SELECT
  l.unit_id,
  l.rentable_area_id,
  'component',
  'Safe link ' || l.link_type || ' | tenant: ' || l.tenant_name || ' | area: ' || l.area_name,
  'shaxi_promotion_v1',
  l.candidate_id,
  'promotion_contract_area_candidates',
  'safe_link_v1_5',
  NOW()
FROM approved_candidate_links l
LEFT JOIN public.lease_package_components existing
  ON existing.package_unit_id = l.unit_id
  AND existing.rentable_area_id = l.rentable_area_id
WHERE existing.id IS NULL;


-- ============================================================
-- STEP 9: Verification
-- ============================================================

-- 9.1 Pending review candidates count
-- Expected: 0 (all 3 resolved)
SELECT
  'VERIFICATION: pending_review candidates count' AS check_name,
  COUNT(*) AS pending_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review';


-- 9.2 Components for pending candidates = 0
-- Expected: 0
SELECT
  'VERIFICATION: components for pending candidates' AS check_name,
  COUNT(lpc.id) AS component_count
FROM public.lease_package_components lpc
JOIN public.promotion_contract_area_candidates pc
  ON pc.id = lpc.source_candidate_id
WHERE pc.promotion_batch = 'shaxi_promotion_v1'
  AND pc.review_status = 'pending_review';


-- 9.3 Duplicate components = 0
-- Expected: 0
SELECT
  'VERIFICATION: duplicate components' AS check_name,
  COUNT(*) AS duplicate_count
FROM (
  SELECT package_unit_id, rentable_area_id
  FROM public.lease_package_components
  GROUP BY package_unit_id, rentable_area_id
  HAVING COUNT(*) > 1
) dups;


-- 9.4 Final lease_package_components count for this batch
-- Expected: 10 (7 previous + 3 new)
SELECT
  'VERIFICATION: total safe components for batch' AS check_name,
  COUNT(*) AS component_count
FROM public.lease_package_components
WHERE promotion_batch = 'shaxi_promotion_v1';


-- 9.5 Final lease_package_components count by created_from
-- Expected: 7 from v1_4, 3 from v1_5
SELECT
  'VERIFICATION: components by created_from' AS check_name,
  created_from,
  COUNT(*) AS component_count
FROM public.lease_package_components
WHERE promotion_batch = 'shaxi_promotion_v1'
GROUP BY created_from
ORDER BY created_from;


-- 9.6 All created components trace back to approved or exact original source
-- Expected: 10 rows, all with non-null source_candidate_id OR created_from = 'safe_link_v1_4'
SELECT
  'VERIFICATION: component traceability' AS check_name,
  COUNT(*) AS total_count,
  COUNT(source_candidate_id) AS with_candidate_id,
  COUNT(*) FILTER (WHERE created_from = 'safe_link_v1_4') AS from_v1_4,
  COUNT(*) FILTER (WHERE created_from = 'safe_link_v1_5') AS from_v1_5
FROM public.lease_package_components
WHERE promotion_batch = 'shaxi_promotion_v1';


-- 9.7 Newly approved candidates have target_rentable_area_id
-- Expected: 3
SELECT
  'VERIFICATION: new approved candidates linked' AS check_name,
  COUNT(*) AS linked_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_decision = 'approve_new_area'
  AND target_rentable_area_id IS NOT NULL
  AND id IN (3, 4, 8);


-- 9.8 No duplicate rentable_areas
-- Expected: 0
SELECT
  'VERIFICATION: duplicate rentable_areas' AS check_name,
  COUNT(*) AS duplicate_count
FROM (
  SELECT property_id, building_id, area_name
  FROM public.rentable_areas
  GROUP BY property_id, building_id, area_name
  HAVING COUNT(*) > 1
) dups;


-- 9.9 Summary of resolved candidates
SELECT
  id,
  tenant_name,
  approved_area_name,
  review_decision,
  review_status,
  target_rentable_area_id,
  resolved_at
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND id IN (3, 4, 8)
ORDER BY id;
