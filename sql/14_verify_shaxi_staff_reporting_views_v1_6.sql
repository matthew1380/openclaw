-- ============================================================
-- sql/14_verify_shaxi_staff_reporting_views_v1_6.sql
-- Verify staff-facing reporting views for Shaxi v1.6
-- Batch: shaxi_promotion_v1
--
-- Purpose: Prove the reporting layer is healthy and the data
--          underlying it is clean.
--
-- Expected results:
--   - vw_shaxi_lease_component_review returns 10 rows
--   - vw_shaxi_mapping_exceptions returns 0 rows
--   - pending_review candidates = 0
--   - components for pending candidates = 0
--   - duplicate components = 0
--   - all final components trace back to approved_candidate
--     or exact_original_match source
-- ============================================================


-- ============================================================
-- 1. VIEW A ROW COUNT
-- Expected: 10
-- ============================================================

SELECT
  'VIEW_A: lease_component_review row count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_lease_component_review;


-- ============================================================
-- 2. VIEW A SOURCE TYPE BREAKDOWN
-- Expected: 1 exact_original_match + 9 approved_candidate = 10
-- ============================================================

SELECT
  'VIEW_A: source_type breakdown' AS check_name,
  source_type,
  COUNT(*) AS row_count
FROM public.vw_shaxi_lease_component_review
GROUP BY source_type
ORDER BY source_type;


-- ============================================================
-- 3. VIEW A CONTRACT STATUS CHECK
-- Expected: all 10 have contract_status = 'active'
-- ============================================================

SELECT
  'VIEW_A: contract_status summary' AS check_name,
  contract_status,
  COUNT(*) AS row_count
FROM public.vw_shaxi_lease_component_review
GROUP BY contract_status
ORDER BY contract_status;


-- ============================================================
-- 4. VIEW A TENANT LIST (readability check)
-- Expected: 10 distinct tenants
-- ============================================================

SELECT
  'VIEW_A: tenant list' AS check_name,
  tenant_name,
  area_code,
  source_type,
  source_candidate_id
FROM public.vw_shaxi_lease_component_review
ORDER BY source_type, tenant_name;


-- ============================================================
-- 5. VIEW B EXCEPTION COUNT
-- Expected: 0
-- ============================================================

SELECT
  'VIEW_B: mapping_exceptions row count' AS check_name,
  COUNT(*) AS exception_count
FROM public.vw_shaxi_mapping_exceptions;


-- ============================================================
-- 6. VIEW B EXCEPTION TYPE BREAKDOWN (if any)
-- Expected: 0 rows, but shows structure if run with issues
-- ============================================================

SELECT
  'VIEW_B: exception_type breakdown' AS check_name,
  exception_type,
  COUNT(*) AS exception_count
FROM public.vw_shaxi_mapping_exceptions
GROUP BY exception_type
ORDER BY exception_type;


-- ============================================================
-- 7. VIEW C SUMMARY
-- Expected:
--   verified_contracts = 10
--   safe_components = 10
--   approved_candidates = 9
--   pending_candidates = 0
--   duplicate_components = 0
--   exception_rows = 0
-- ============================================================

SELECT
  'VIEW_C: reporting_summary' AS check_name,
  *
FROM public.vw_shaxi_reporting_summary;


-- ============================================================
-- 8. DIRECT PENDING CANDIDATES CHECK
-- Expected: 0
-- ============================================================

SELECT
  'DIRECT: pending_review candidates' AS check_name,
  COUNT(*) AS pending_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review';


-- ============================================================
-- 9. DIRECT COMPONENTS FOR PENDING CANDIDATES
-- Expected: 0
-- ============================================================

SELECT
  'DIRECT: components for pending candidates' AS check_name,
  COUNT(lpc.id) AS component_count
FROM public.lease_package_components lpc
JOIN public.promotion_contract_area_candidates pc
  ON pc.id = lpc.source_candidate_id
WHERE pc.promotion_batch = 'shaxi_promotion_v1'
  AND pc.review_status = 'pending_review';


-- ============================================================
-- 10. DIRECT DUPLICATE COMPONENTS CHECK
-- Expected: 0
-- ============================================================

SELECT
  'DIRECT: duplicate components' AS check_name,
  COUNT(*) AS duplicate_count
FROM (
  SELECT package_unit_id, rentable_area_id
  FROM public.lease_package_components
  GROUP BY package_unit_id, rentable_area_id
  HAVING COUNT(*) > 1
) dups;


-- ============================================================
-- 11. TRACEABILITY: ALL SAFE COMPONENTS TRACE TO APPROVED SOURCE
-- Expected: 10 total
--   - 1 exact_original_match (source_candidate_id IS NULL)
--   - 9 approved_candidate (source_candidate_id IS NOT NULL)
-- ============================================================

SELECT
  'TRACEABILITY: safe component source breakdown' AS check_name,
  COUNT(*) AS total_count,
  COUNT(source_candidate_id) AS approved_candidate_count,
  COUNT(*) - COUNT(source_candidate_id) AS exact_original_match_count
FROM public.lease_package_components
WHERE promotion_batch = 'shaxi_promotion_v1';


-- ============================================================
-- 12. TRACEABILITY: ALL APPROVED CANDIDATES HAVE COMPONENTS
-- Expected: 9 (all approved candidates linked to at least 1 component)
-- ============================================================

SELECT
  'TRACEABILITY: approved candidates with components' AS check_name,
  COUNT(DISTINCT pc.id) AS candidate_count
FROM public.promotion_contract_area_candidates pc
WHERE pc.promotion_batch = 'shaxi_promotion_v1'
  AND pc.review_status = 'area_created'
  AND EXISTS (
    SELECT 1 FROM public.lease_package_components lpc
    WHERE lpc.source_candidate_id = pc.id
  );


-- ============================================================
-- 13. SCHEMA: ALL THREE VIEWS EXIST
-- Expected: 3
-- ============================================================

SELECT
  'SCHEMA: reporting views exist' AS check_name,
  COUNT(*) AS view_count
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name IN (
    'vw_shaxi_lease_component_review',
    'vw_shaxi_mapping_exceptions',
    'vw_shaxi_reporting_summary'
  );
