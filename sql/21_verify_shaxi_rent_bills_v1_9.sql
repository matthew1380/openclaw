-- ============================================================
-- sql/21_verify_shaxi_rent_bills_v1_9.sql
-- Verify controlled rent bill generation for Shaxi v1.9
-- Batch: shaxi_promotion_v1
--
-- Purpose: Prove that draft bills were generated safely and
--          only for eligible candidates.
--
-- Expected results:
--   - billing rule exists exactly once
--   - candidate view exists
--   - 8 generate_ready candidates
--   - 2 held candidates (1 billing_hold + 1 expired)
--   - 8 draft bills generated
--   - 0 non-draft bills
--   - 0 duplicate bills
--   - 0 bills for pending/unsafe candidates
--   - 0 bills for missing rent
--   - 0 bills for expired contracts
--   - master/sublease overlap clearly documented as billing_hold
--   - billing exceptions remain 0 or clearly explained
--   - v1.7 and v1.8 regression views still work
-- ============================================================


-- ============================================================
-- 1. BILLING RULE EXISTS EXACTLY ONCE
-- Expected: 1
-- ============================================================

SELECT
  'RULE: billing rule count' AS check_name,
  COUNT(*) AS rule_count
FROM public.billing_generation_rules
WHERE property_code = 'SX-39'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';


-- ============================================================
-- 2. BILLING RULE STATUS IS GENERATED
-- Expected: 'generated'
-- ============================================================

SELECT
  'RULE: generation_status' AS check_name,
  generation_status
FROM public.billing_generation_rules
WHERE property_code = 'SX-39'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';


-- ============================================================
-- 3. CANDIDATE VIEW EXISTS
-- Expected: 1
-- ============================================================

SELECT
  'SCHEMA: candidate view exists' AS check_name,
  COUNT(*) AS view_count
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name = 'vw_shaxi_rent_bill_candidates_v1_9';


-- ============================================================
-- 4. SUMMARY VIEW EXISTS
-- Expected: 1
-- ============================================================

SELECT
  'SCHEMA: summary view exists' AS check_name,
  COUNT(*) AS view_count
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name = 'vw_shaxi_billing_generation_summary_v1_9';


-- ============================================================
-- 5. HOLDS VIEW EXISTS
-- Expected: 1
-- ============================================================

SELECT
  'SCHEMA: holds view exists' AS check_name,
  COUNT(*) AS view_count
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name = 'vw_shaxi_billing_holds_v1_9';


-- ============================================================
-- 6. CANDIDATE STATUS BREAKDOWN
-- Expected: 8 generate_ready, 1 billing_hold, 1 expired
-- ============================================================

SELECT
  'CANDIDATES: status breakdown' AS check_name,
  candidate_status,
  COUNT(*) AS row_count
FROM public.vw_shaxi_rent_bill_candidates_v1_9
GROUP BY candidate_status
ORDER BY candidate_status;


-- ============================================================
-- 7. GENERATED BILLS ARE DRAFT ONLY
-- Expected: all bill_status = 'draft'
-- ============================================================

SELECT
  'BILLS: all draft status' AS check_name,
  bill_status,
  COUNT(*) AS row_count
FROM public.rent_bills
WHERE billing_month = '2026-05-01'
  AND bill_type = 'rent'
GROUP BY bill_status
ORDER BY bill_status;


-- ============================================================
-- 8. NO NON-DRAFT BILLS
-- Expected: 0
-- ============================================================

SELECT
  'BILLS: non-draft count' AS check_name,
  COUNT(*) AS non_draft_count
FROM public.rent_bills
WHERE billing_month = '2026-05-01'
  AND bill_type = 'rent'
  AND bill_status != 'draft';


-- ============================================================
-- 9. NO DUPLICATE BILLS
-- Expected: 0
-- ============================================================

SELECT
  'BILLS: duplicate count' AS check_name,
  COUNT(*) AS duplicate_count
FROM (
  SELECT lease_package_component_id, billing_month, bill_type
  FROM public.rent_bills
  GROUP BY lease_package_component_id, billing_month, bill_type
  HAVING COUNT(*) > 1
) dups;


-- ============================================================
-- 10. BILL COUNT MATCHES GENERATE_READY CANDIDATE COUNT
-- Expected: both = 8
-- ============================================================

SELECT
  'BILLS: count matches generate_ready' AS check_name,
  (SELECT COUNT(*) FROM public.rent_bills WHERE billing_month = '2026-05-01' AND bill_type = 'rent' AND bill_status = 'draft') AS bill_count,
  (SELECT COUNT(*) FROM public.vw_shaxi_rent_bill_candidates_v1_9 WHERE candidate_status = 'generate_ready') AS generate_ready_count;


-- ============================================================
-- 11. NO BILLS FOR EXPIRED CONTRACTS
-- Expected: 0 bills linked to 朱河芳 (SX-C-011, end_date 2026-04-30)
-- ============================================================

SELECT
  'BILLS: bills for expired contracts' AS check_name,
  COUNT(rb.id) AS bill_count
FROM public.rent_bills rb
JOIN public.contracts c ON c.id = rb.lease_contract_id
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND (c.end_date IS NOT NULL AND c.end_date < '2026-05-01');


-- ============================================================
-- 12. NO BILLS FOR MULTIPLE_ACTIVE AREAS
-- Expected: 0 bills for area RA-SX39-Q4-B-GF
-- ============================================================

SELECT
  'BILLS: bills for multiple_active areas' AS check_name,
  COUNT(rb.id) AS bill_count
FROM public.rent_bills rb
JOIN public.lease_package_components lpc ON lpc.id = rb.lease_package_component_id
JOIN public.rentable_areas ra ON ra.id = lpc.rentable_area_id
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND ra.area_code = 'RA-SX39-Q4-B-GF';


-- ============================================================
-- 13. NO BILLS FOR MISSING RENT
-- Expected: 0
-- ============================================================

SELECT
  'BILLS: bills with missing/invalid rent' AS check_name,
  COUNT(rb.id) AS bill_count
FROM public.rent_bills rb
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND (rb.amount_due IS NULL OR rb.amount_due < 0);


-- ============================================================
-- 14. NO BILLS FOR PENDING/UNSAFE CANDIDATES
-- Expected: 0
-- ============================================================

SELECT
  'BILLS: bills from unsafe sources' AS check_name,
  COUNT(rb.id) AS bill_count
FROM public.rent_bills rb
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND rb.source_type != 'controlled_generation';


-- ============================================================
-- 15. MASTER/SUBLEASE HOLD DOCUMENTED
-- Verify the holds view shows the multiple_active case
-- Expected: 1 row for 川田 with billing_hold
-- ============================================================

SELECT
  'HOLDS: master/sublease documented' AS check_name,
  tenant_name,
  area_code,
  candidate_status,
  hold_reason
FROM public.vw_shaxi_billing_holds_v1_9
WHERE candidate_status = 'billing_hold';


-- ============================================================
-- 16. EXPIRED CONTRACT HOLD DOCUMENTED
-- Verify the holds view shows the expired case
-- Expected: 1 row for 朱河芳 with expired
-- ============================================================

SELECT
  'HOLDS: expired contract documented' AS check_name,
  tenant_name,
  area_code,
  candidate_status,
  hold_reason
FROM public.vw_shaxi_billing_holds_v1_9
WHERE candidate_status = 'expired';


-- ============================================================
-- 17. BILLING EXCEPTIONS VIEW CHECK
-- Expected: 0 (all generated bills pass exception checks)
-- ============================================================

SELECT
  'EXCEPTIONS: billing_exceptions count' AS check_name,
  COUNT(*) AS exception_count
FROM public.vw_shaxi_billing_exceptions;


-- ============================================================
-- 18. REGRESSION: v1.7 expiry_watch still works
-- Expected: 10
-- ============================================================

SELECT
  'REGRESSION: v1.7 expiry_watch' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_contract_expiry_watch;


-- ============================================================
-- 19. REGRESSION: v1.7 occupancy_status still works
-- Expected: 44
-- ============================================================

SELECT
  'REGRESSION: v1.7 occupancy_status' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_area_occupancy_status;


-- ============================================================
-- 20. REGRESSION: v1.8 billing_readiness still works
-- Expected: 1
-- ============================================================

SELECT
  'REGRESSION: v1.8 billing_readiness' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_readiness;


-- ============================================================
-- 21. GENERATED BILL DETAIL
-- Full list for audit
-- ============================================================

SELECT
  'AUDIT: generated bill list' AS check_name,
  rb.id AS bill_id,
  con.name AS tenant_name,
  rb.lease_package_component_id,
  rb.billing_month,
  rb.bill_type,
  rb.amount_due,
  rb.due_date,
  rb.bill_status,
  rb.source_type,
  rb.created_from
FROM public.rent_bills rb
JOIN public.contacts con ON con.id = rb.tenant_id
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
ORDER BY con.name;
