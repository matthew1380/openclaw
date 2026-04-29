-- ============================================================
-- sql/16_verify_shaxi_operating_views_v1_7.sql
-- Verify operating-data views for Shaxi v1.7
-- Batch: shaxi_promotion_v1
--
-- Purpose: Prove the operating views are healthy and the data
--          underlying them is clean.
--
-- Expected results:
--   - vw_shaxi_contract_expiry_watch returns 10 rows
--   - vw_shaxi_area_occupancy_status returns expected SX-39 areas
--   - no duplicate active occupancy rows for same area
--   - no unsafe/pending candidates included
--   - payment readiness shows 'seeded_only' with clear note
--   - all views are read-only and safe to rerun
-- ============================================================


-- ============================================================
-- 1. VIEW A ROW COUNT
-- Expected: 10
-- ============================================================

SELECT
  'VIEW_A: expiry_watch row count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_contract_expiry_watch;


-- ============================================================
-- 2. VIEW A SOURCE TYPE BREAKDOWN
-- Expected: 1 exact_original_match + 9 approved_candidate
-- ============================================================

SELECT
  'VIEW_A: source_type breakdown' AS check_name,
  source_type,
  COUNT(*) AS row_count
FROM public.vw_shaxi_contract_expiry_watch
GROUP BY source_type
ORDER BY source_type;


-- ============================================================
-- 3. VIEW A EXPIRY STATUS BREAKDOWN
-- Expected: varies by date; verifies classification logic works
-- ============================================================

SELECT
  'VIEW_A: expiry_status breakdown' AS check_name,
  expiry_status,
  COUNT(*) AS row_count
FROM public.vw_shaxi_contract_expiry_watch
GROUP BY expiry_status
ORDER BY expiry_status;


-- ============================================================
-- 4. VIEW A TENANT LIST (readability check)
-- ============================================================

SELECT
  'VIEW_A: tenant list' AS check_name,
  tenant_name,
  area_code,
  contract_end_date,
  days_to_expiry,
  expiry_status
FROM public.vw_shaxi_contract_expiry_watch
ORDER BY contract_end_date ASC NULLS LAST;


-- ============================================================
-- 5. VIEW A: NO PENDING/UNSAFE CANDIDATES
-- Expected: 0 rows with source_type outside expected values
-- ============================================================

SELECT
  'VIEW_A: no unsafe sources' AS check_name,
  COUNT(*) AS unsafe_count
FROM public.vw_shaxi_contract_expiry_watch
WHERE source_type NOT IN ('exact_original_match', 'approved_candidate');


-- ============================================================
-- 6. VIEW B ROW COUNT
-- Expected: 44 (all SX-39 rentable_areas)
-- ============================================================

SELECT
  'VIEW_B: occupancy_status row count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_area_occupancy_status;


-- ============================================================
-- 7. VIEW B: NO DUPLICATE AREA ROWS
-- Expected: 0
-- ============================================================

SELECT
  'VIEW_B: duplicate area rows' AS check_name,
  COUNT(*) AS duplicate_count
FROM (
  SELECT area_code
  FROM public.vw_shaxi_area_occupancy_status
  GROUP BY area_code
  HAVING COUNT(*) > 1
) dups;


-- ============================================================
-- 8. VIEW B: AREA ORIGIN BREAKDOWN
-- ============================================================

SELECT
  'VIEW_B: area_origin breakdown' AS check_name,
  area_origin,
  COUNT(*) AS row_count
FROM public.vw_shaxi_area_occupancy_status
GROUP BY area_origin
ORDER BY area_origin;


-- ============================================================
-- 9. VIEW B: OCCUPANCY STATUS BREAKDOWN
-- ============================================================

SELECT
  'VIEW_B: occupancy_status breakdown' AS check_name,
  occupancy_status,
  COUNT(*) AS row_count
FROM public.vw_shaxi_area_occupancy_status
GROUP BY occupancy_status
ORDER BY occupancy_status;


-- ============================================================
-- 10. VIEW B: SAFE COMPONENT COUNT MATCHES EXPECTED
-- Expected: sum of safe_component_count = 10
-- ============================================================

SELECT
  'VIEW_B: total safe components in occupancy view' AS check_name,
  SUM(safe_component_count) AS total_safe_components
FROM public.vw_shaxi_area_occupancy_status;


-- ============================================================
-- 11. VIEW B: OCCUPIED AREAS HAVE TENANTS
-- Expected: all rows with occupancy_status = 'occupied' have tenant_name IS NOT NULL
-- ============================================================

SELECT
  'VIEW_B: occupied areas with missing tenant' AS check_name,
  COUNT(*) AS missing_tenant_count
FROM public.vw_shaxi_area_occupancy_status
WHERE occupancy_status = 'occupied'
  AND tenant_name IS NULL;


-- ============================================================
-- 12. VIEW C ROW COUNT
-- Expected: 1
-- ============================================================

SELECT
  'VIEW_C: payment_readiness row count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_payment_data_readiness;


-- ============================================================
-- 13. VIEW C: READINESS STATUS
-- Expected: 'seeded_only' (financial_records exists but no billing tables)
-- ============================================================

SELECT
  'VIEW_C: readiness_status' AS check_name,
  readiness_status,
  total_financial_records,
  seed_rows,
  readiness_note
FROM public.vw_shaxi_payment_data_readiness;


-- ============================================================
-- 14. VIEW C: NO REAL BILLING TABLES
-- Expected: all has_* flags = false
-- ============================================================

SELECT
  'VIEW_C: billing table existence' AS check_name,
  has_payments,
  has_rent_bills,
  has_invoices,
  has_receivables,
  has_ledger,
  has_utility_bills
FROM public.vw_shaxi_payment_data_readiness;


-- ============================================================
-- 15. SCHEMA: ALL THREE VIEWS EXIST
-- Expected: 3
-- ============================================================

SELECT
  'SCHEMA: operating views exist' AS check_name,
  COUNT(*) AS view_count
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name IN (
    'vw_shaxi_contract_expiry_watch',
    'vw_shaxi_area_occupancy_status',
    'vw_shaxi_payment_data_readiness'
  );
