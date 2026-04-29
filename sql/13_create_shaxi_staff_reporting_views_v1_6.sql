-- ============================================================
-- sql/13_create_shaxi_staff_reporting_views_v1_6.sql
-- Create read-only staff-facing reporting/review views for Shaxi
-- Batch: shaxi_promotion_v1
--
-- Purpose: Provide the first staff-facing reporting layer for
--          reviewing safe lease components and detecting mapping
--          exceptions.
--
-- Views:
--   A. vw_shaxi_lease_component_review  — 10 rows expected
--   B. vw_shaxi_mapping_exceptions      — 0 rows expected if clean
--   C. vw_shaxi_reporting_summary       — key counts
--
-- Rules:
--   - All views are read-only.
--   - CREATE OR REPLACE VIEW for idempotency.
--   - Safe to rerun.
--   - Does NOT modify data.
-- ============================================================


-- ============================================================
-- VIEW A: vw_shaxi_lease_component_review
-- One row per safe final lease_package_component.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_lease_component_review AS
SELECT
  con.name AS tenant_name,
  c.contract_code,
  u.unit_code,
  ra.area_code,
  ra.area_name,
  b.building_code,
  b.building_name,
  ra.section_group_name,
  c.monthly_rent,
  c.start_date AS contract_start_date,
  c.end_date AS contract_end_date,
  c.contract_status::text AS contract_status,
  CASE
    WHEN lpc.source_candidate_id IS NULL THEN 'exact_original_match'
    ELSE 'approved_candidate'
  END AS source_type,
  lpc.promotion_batch,
  lpc.source_candidate_id,
  lpc.source_staging_table,
  lpc.created_from,
  lpc.notes AS component_notes
FROM public.lease_package_components lpc
JOIN public.rentable_areas ra ON ra.id = lpc.rentable_area_id
JOIN public.building_registry b ON b.id = ra.building_id
JOIN public.units u ON u.id = lpc.package_unit_id
JOIN public.contracts c ON c.unit_id = u.id
JOIN public.contacts con ON con.id = c.tenant_id
WHERE lpc.promotion_batch = 'shaxi_promotion_v1'
ORDER BY
  lpc.created_from,
  lpc.source_candidate_id NULLS FIRST,
  ra.area_code;


-- ============================================================
-- VIEW B: vw_shaxi_mapping_exceptions
-- Detects mapping and data-quality exceptions.
-- Expected: 0 rows when data is clean.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_mapping_exceptions AS

-- 1. Safe component missing rentable_area
SELECT
  'missing_area' AS exception_type,
  lpc.id AS component_id,
  lpc.package_unit_id,
  NULL::uuid AS contract_id,
  'Safe component ' || lpc.id || ' linked to non-existent rentable_area_id ' || lpc.rentable_area_id AS details
FROM public.lease_package_components lpc
WHERE lpc.promotion_batch = 'shaxi_promotion_v1'
  AND NOT EXISTS (
    SELECT 1 FROM public.rentable_areas ra WHERE ra.id = lpc.rentable_area_id
  )

UNION ALL

-- 2. Safe component linked to pending or rejected candidate
SELECT
  'linked_to_pending_candidate' AS exception_type,
  lpc.id AS component_id,
  lpc.package_unit_id,
  NULL::uuid AS contract_id,
  'Component linked to candidate ' || pc.id || ' with status ' || pc.review_status AS details
FROM public.lease_package_components lpc
JOIN public.promotion_contract_area_candidates pc ON pc.id = lpc.source_candidate_id
WHERE lpc.promotion_batch = 'shaxi_promotion_v1'
  AND pc.review_status != 'area_created'

UNION ALL

-- 3. Safe component with unexpected created_from
SELECT
  'unexpected_created_from' AS exception_type,
  lpc.id AS component_id,
  lpc.package_unit_id,
  NULL::uuid AS contract_id,
  'Component has unexpected created_from: ' || COALESCE(lpc.created_from, 'NULL') AS details
FROM public.lease_package_components lpc
WHERE lpc.promotion_batch = 'shaxi_promotion_v1'
  AND COALESCE(lpc.created_from, '') NOT IN ('safe_link_v1_4', 'safe_link_v1_5')

UNION ALL

-- 4. Duplicate components (same unit + area)
SELECT
  'duplicate_component' AS exception_type,
  lpc.id AS component_id,
  lpc.package_unit_id,
  NULL::uuid AS contract_id,
  'Duplicate pair (unit=' || lpc.package_unit_id || ', area=' || lpc.rentable_area_id || '), count=' || d.cnt AS details
FROM public.lease_package_components lpc
JOIN (
  SELECT package_unit_id, rentable_area_id, COUNT(*) AS cnt
  FROM public.lease_package_components
  GROUP BY package_unit_id, rentable_area_id
  HAVING COUNT(*) > 1
) d ON d.package_unit_id = lpc.package_unit_id AND d.rentable_area_id = lpc.rentable_area_id

UNION ALL

-- 5. Staged contract without safe component
SELECT
  'contract_without_safe_component' AS exception_type,
  NULL::uuid AS component_id,
  c.unit_id AS package_unit_id,
  c.id AS contract_id,
  'Staged contract ' || c.contract_code || ' (' || con.name || ') has no safe lease_package_component' AS details
FROM public.contracts c
JOIN public.contacts con ON con.id = c.tenant_id
WHERE c.promotion_batch = 'shaxi_contracts_v1_1'
  AND NOT EXISTS (
    SELECT 1 FROM public.lease_package_components lpc
    WHERE lpc.package_unit_id = c.unit_id
      AND lpc.promotion_batch = 'shaxi_promotion_v1'
  )

UNION ALL

-- 6. Safe component with no associated contract
SELECT
  'missing_contract' AS exception_type,
  lpc.id AS component_id,
  lpc.package_unit_id,
  NULL::uuid AS contract_id,
  'Safe component ' || lpc.id || ' has no associated contract for unit ' || lpc.package_unit_id AS details
FROM public.lease_package_components lpc
WHERE lpc.promotion_batch = 'shaxi_promotion_v1'
  AND NOT EXISTS (
    SELECT 1 FROM public.contracts c WHERE c.unit_id = lpc.package_unit_id
  );


-- ============================================================
-- VIEW C: vw_shaxi_reporting_summary
-- Single-row summary of key Shaxi rental counts.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_reporting_summary AS
SELECT
  (SELECT COUNT(*) FROM public.contracts WHERE promotion_batch = 'shaxi_contracts_v1_1') AS verified_contracts,
  (SELECT COUNT(*) FROM public.lease_package_components WHERE promotion_batch = 'shaxi_promotion_v1') AS safe_components,
  (SELECT COUNT(*) FROM public.promotion_contract_area_candidates WHERE promotion_batch = 'shaxi_promotion_v1' AND review_status = 'area_created') AS approved_candidates,
  (SELECT COUNT(*) FROM public.promotion_contract_area_candidates WHERE promotion_batch = 'shaxi_promotion_v1' AND review_status = 'pending_review') AS pending_candidates,
  (SELECT COUNT(*) FROM (
    SELECT package_unit_id, rentable_area_id
    FROM public.lease_package_components
    GROUP BY package_unit_id, rentable_area_id
    HAVING COUNT(*) > 1
  ) d) AS duplicate_components,
  (SELECT COUNT(*) FROM public.vw_shaxi_mapping_exceptions) AS exception_rows;
