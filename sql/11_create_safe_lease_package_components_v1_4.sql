-- ============================================================
-- sql/11_create_safe_lease_package_components_v1_4.sql
-- Create safe lease_package_components for Shaxi contract-area links
-- Batch: shaxi_promotion_v1
--
-- Purpose: Link contract units to their canonical rentable_areas
--          for safe, reviewed, or exact-match cases only.
--
-- Safe links:
--   1 exact original match (川田 四区B栋首层 -> RA-SX39-Q4-B-GF)
--   6 approved candidate areas
--   Total: 7
--
-- Rules:
--   - Insert only when contract_id is found exactly once.
--   - Insert only when rentable_area_id is found exactly once.
--   - Idempotent via WHERE NOT EXISTS (package_unit_id, rentable_area_id).
--   - Do NOT touch the 3 still-pending candidates.
--   - Do NOT guess unresolved area links.
-- ============================================================


-- ============================================================
-- STEP 0: Inspect and prepare schema
-- ============================================================

-- Add minimal audit columns if missing
ALTER TABLE public.lease_package_components
  ADD COLUMN IF NOT EXISTS promotion_batch text,
  ADD COLUMN IF NOT EXISTS source_candidate_id bigint,
  ADD COLUMN IF NOT EXISTS source_staging_table text,
  ADD COLUMN IF NOT EXISTS created_from text;


-- ============================================================
-- STEP 1: Preview safe links to be created
-- Expected: 7 rows
-- ============================================================

WITH exact_original_matches AS (
  -- Staged contracts whose mapped area exactly matches a rentable_area
  -- AND are NOT in the candidates table
  SELECT
    NULL::bigint AS candidate_id,
    s.tenant_name,
    s.mapped_area_name AS area_name,
    c.id AS contract_id,
    c.unit_id,
    ra.id AS rentable_area_id,
    'exact_original_match' AS link_type
  FROM public.stg_shaxi_contracts_prepared s
  JOIN public.contacts con ON con.name = s.tenant_name
  JOIN public.contracts c
    ON c.tenant_id = con.id
    AND c.monthly_rent = s.monthly_rent
    AND c.start_date = s.contract_start_date
    AND c.end_date = s.contract_end_date
  JOIN public.building_registry b ON b.building_code = s.mapped_building_code
  JOIN public.rentable_areas ra
    ON ra.building_id = b.id
    AND ra.area_name = s.mapped_area_name
  WHERE NOT EXISTS (
    SELECT 1 FROM public.promotion_contract_area_candidates pc
    WHERE pc.tenant_name = s.tenant_name
      AND pc.monthly_rent = s.monthly_rent
      AND pc.contract_start_date = s.contract_start_date
      AND pc.contract_end_date = s.contract_end_date
  )
),
approved_candidate_links AS (
  -- Approved candidates with their newly created target rentable_areas
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
),
safe_links AS (
  SELECT * FROM exact_original_matches
  UNION ALL
  SELECT * FROM approved_candidate_links
)
SELECT
  safe_links.link_type,
  safe_links.candidate_id,
  safe_links.tenant_name,
  safe_links.area_name,
  safe_links.unit_id,
  safe_links.rentable_area_id,
  CASE WHEN existing.id IS NOT NULL THEN 'EXISTS — will skip' ELSE 'NEW — will insert' END AS insert_action
FROM safe_links
LEFT JOIN public.lease_package_components existing
  ON existing.package_unit_id = safe_links.unit_id
  AND existing.rentable_area_id = safe_links.rentable_area_id
ORDER BY safe_links.link_type, safe_links.tenant_name;


-- ============================================================
-- STEP 2: Insert safe lease_package_components
-- ============================================================

WITH exact_original_matches AS (
  SELECT
    NULL::bigint AS candidate_id,
    s.tenant_name,
    s.mapped_area_name AS area_name,
    c.id AS contract_id,
    c.unit_id,
    ra.id AS rentable_area_id,
    'exact_original_match' AS link_type
  FROM public.stg_shaxi_contracts_prepared s
  JOIN public.contacts con ON con.name = s.tenant_name
  JOIN public.contracts c
    ON c.tenant_id = con.id
    AND c.monthly_rent = s.monthly_rent
    AND c.start_date = s.contract_start_date
    AND c.end_date = s.contract_end_date
  JOIN public.building_registry b ON b.building_code = s.mapped_building_code
  JOIN public.rentable_areas ra
    ON ra.building_id = b.id
    AND ra.area_name = s.mapped_area_name
  WHERE NOT EXISTS (
    SELECT 1 FROM public.promotion_contract_area_candidates pc
    WHERE pc.tenant_name = s.tenant_name
      AND pc.monthly_rent = s.monthly_rent
      AND pc.contract_start_date = s.contract_start_date
      AND pc.contract_end_date = s.contract_end_date
  )
),
approved_candidate_links AS (
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
),
safe_links AS (
  SELECT * FROM exact_original_matches
  UNION ALL
  SELECT * FROM approved_candidate_links
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
  s.unit_id,
  s.rentable_area_id,
  'component',
  'Safe link ' || s.link_type || ' | tenant: ' || s.tenant_name || ' | area: ' || s.area_name,
  'shaxi_promotion_v1',
  s.candidate_id,
  'stg_shaxi_contracts_prepared',
  'safe_link_v1_4',
  NOW()
FROM safe_links s
LEFT JOIN public.lease_package_components existing
  ON existing.package_unit_id = s.unit_id
  AND existing.rentable_area_id = s.rentable_area_id
WHERE existing.id IS NULL;


-- ============================================================
-- STEP 3: Verification
-- ============================================================

-- 3.1 Total safe components created or present for this flow
-- Expected: 7
SELECT
  'POST_INSERT: safe components for batch' AS check_name,
  COUNT(*) AS component_count
FROM public.lease_package_components
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND created_from = 'safe_link_v1_4';


-- 3.2 Still-pending candidates remain untouched
-- Expected: 3
SELECT
  'POST_INSERT: still-pending candidates' AS check_name,
  COUNT(*) AS pending_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review';


-- 3.3 No components created for pending candidates
-- Expected: 0
SELECT
  'POST_INSERT: components for pending candidates' AS check_name,
  COUNT(lpc.id) AS component_count
FROM public.lease_package_components lpc
JOIN public.promotion_contract_area_candidates pc
  ON pc.id = lpc.source_candidate_id
WHERE pc.promotion_batch = 'shaxi_promotion_v1'
  AND pc.review_status = 'pending_review';


-- 3.4 No duplicate components (same unit + rentable_area)
-- Expected: 0
SELECT
  'POST_INSERT: duplicate components' AS check_name,
  COUNT(*) AS duplicate_count
FROM (
  SELECT package_unit_id, rentable_area_id
  FROM public.lease_package_components
  GROUP BY package_unit_id, rentable_area_id
  HAVING COUNT(*) > 1
) dups;
