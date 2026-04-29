-- ============================================================
-- sql/30_verify_shaxi_payment_allocations_v2_3.sql
-- Verify payment recording foundation for Shaxi v2.3
-- Batch: shaxi_promotion_v1
--
-- Purpose: Prove the payment recording views are healthy, all
--          issued bills are payment-eligible, draft/held bills
--          are excluded, and all prior version views remain intact.
--
-- Expected results:
--   - 7 issued bills in outstanding view
--   - 7 bills in payment recording queue (all with outstanding > 0)
--   - 1 draft bill is NOT in outstanding view
--   - 川田 and 朱河芳 are NOT in outstanding view
--   - total issued amount = ¥327,421
--   - total outstanding = ¥327,421 (if no payments recorded)
--   - payment allocation exceptions = 0
--   - billing exceptions = 0
--   - duplicate bills = 0
--   - v1.7, v1.8, v1.9, v2.0, v2.1, v2.2 regression views still pass
-- ============================================================


-- ============================================================
-- 1. OUTSTANDING BILLS ROW COUNT
-- Expected: 7 (only issued bills)
-- ============================================================

SELECT
  'OUTSTANDING: row count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_outstanding_bills_v2_3;


-- ============================================================
-- 2. ALL OUTSTANDING BILLS ARE ISSUED
-- Expected: all bill_status = 'issued'
-- ============================================================

SELECT
  'OUTSTANDING: bill_status breakdown' AS check_name,
  bill_status,
  COUNT(*) AS row_count
FROM public.vw_shaxi_outstanding_bills_v2_3
GROUP BY bill_status
ORDER BY bill_status;


-- ============================================================
-- 3. PAYMENT RECORDING QUEUE ROW COUNT
-- Expected: 7 (all issued bills have outstanding > 0)
-- ============================================================

SELECT
  'QUEUE: payment_recording_queue row count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_payment_recording_queue_v2_3;


-- ============================================================
-- 4. ALL QUEUE BILLS HAVE OUTSTANDING > 0
-- Expected: min outstanding_amount > 0
-- ============================================================

SELECT
  'QUEUE: min outstanding check' AS check_name,
  MIN(outstanding_amount) AS min_outstanding,
  MAX(outstanding_amount) AS max_outstanding
FROM public.vw_shaxi_payment_recording_queue_v2_3;


-- ============================================================
-- 5. TOTAL ISSUED AMOUNT
-- Expected: ¥327,421.00
-- ============================================================

SELECT
  'OUTSTANDING: total issued amount' AS check_name,
  SUM(amount_due) AS total_issued_amount
FROM public.vw_shaxi_outstanding_bills_v2_3;


-- ============================================================
-- 6. TOTAL OUTSTANDING AMOUNT
-- Expected: ¥327,421.00 (if no payments recorded yet)
-- ============================================================

SELECT
  'OUTSTANDING: total outstanding amount' AS check_name,
  SUM(outstanding_amount) AS total_outstanding_amount
FROM public.vw_shaxi_outstanding_bills_v2_3;


-- ============================================================
-- 7. DRAFT BILL IS NOT IN OUTSTANDING VIEW
-- Expected: 0 (杨华禾 should not appear)
-- ============================================================

SELECT
  'OUTSTANDING: draft bill excluded' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_outstanding_bills_v2_3
WHERE tenant_name = '杨华禾';


-- ============================================================
-- 8. DRAFT BILL IS NOT IN PAYMENT QUEUE
-- Expected: 0
-- ============================================================

SELECT
  'QUEUE: draft bill excluded' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_payment_recording_queue_v2_3
WHERE tenant_name = '杨华禾';


-- ============================================================
-- 9. 川田 IS NOT IN OUTSTANDING VIEW
-- Expected: 0
-- ============================================================

SELECT
  'OUTSTANDING: 川田 excluded' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_outstanding_bills_v2_3
WHERE tenant_name LIKE '%川田%';


-- ============================================================
-- 10. 朱河芳 IS NOT IN OUTSTANDING VIEW
-- Expected: 0
-- ============================================================

SELECT
  'OUTSTANDING: 朱河芳 excluded' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_outstanding_bills_v2_3
WHERE tenant_name LIKE '%朱河芳%';


-- ============================================================
-- 11. PAYMENT ALLOCATION EXCEPTIONS = 0
-- Expected: 0
-- ============================================================

SELECT
  'EXCEPTIONS: payment_allocation_exceptions count' AS check_name,
  COUNT(*) AS exception_count
FROM public.vw_shaxi_payment_allocation_exceptions_v2_3;


-- ============================================================
-- 12. BILLING EXCEPTIONS REMAIN 0
-- Expected: 0
-- ============================================================

SELECT
  'EXCEPTIONS: billing_exceptions count' AS check_name,
  COUNT(*) AS exception_count
FROM public.vw_shaxi_billing_exceptions;


-- ============================================================
-- 13. NO DUPLICATE BILLS
-- Expected: 0
-- ============================================================

SELECT
  'DATA: duplicate bill count' AS check_name,
  COUNT(*) AS duplicate_count
FROM (
  SELECT lease_package_component_id, billing_month, bill_type
  FROM public.rent_bills
  GROUP BY lease_package_component_id, billing_month, bill_type
  HAVING COUNT(*) > 1
) dups;


-- ============================================================
-- 14. OUTSTANDING BILLS TRACE TO SAFE COMPONENTS
-- Expected: 0 unsafe bills
-- ============================================================

SELECT
  'TRACEABILITY: outstanding bills from unsafe components' AS check_name,
  COUNT(*) AS unsafe_bill_count
FROM public.vw_shaxi_outstanding_bills_v2_3 ob
WHERE ob.lease_package_component_id NOT IN (
  SELECT id FROM public.lease_package_components WHERE promotion_batch = 'shaxi_promotion_v1'
);


-- ============================================================
-- 15. PAYMENTS TABLE IS EMPTY (no fake data inserted)
-- Expected: 0
-- ============================================================

SELECT
  'DATA: payments row count' AS check_name,
  COUNT(*) AS row_count
FROM public.payments;


-- ============================================================
-- 16. PAYMENT ALLOCATIONS TABLE IS EMPTY
-- Expected: 0
-- ============================================================

SELECT
  'DATA: payment_allocations row count' AS check_name,
  COUNT(*) AS row_count
FROM public.payment_allocations;


-- ============================================================
-- 17. REGRESSION: v1.7 expiry_watch
-- Expected: 10
-- ============================================================

SELECT
  'REGRESSION: v1.7 expiry_watch' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_contract_expiry_watch;


-- ============================================================
-- 18. REGRESSION: v1.7 occupancy_status
-- Expected: 44
-- ============================================================

SELECT
  'REGRESSION: v1.7 occupancy_status' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_area_occupancy_status;


-- ============================================================
-- 19. REGRESSION: v1.8 billing_readiness
-- Expected: 1
-- ============================================================

SELECT
  'REGRESSION: v1.8 billing_readiness' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_readiness;


-- ============================================================
-- 20. REGRESSION: v1.9 billing_generation_summary
-- Expected: 1
-- ============================================================

SELECT
  'REGRESSION: v1.9 billing_generation_summary' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_generation_summary_v1_9;


-- ============================================================
-- 21. REGRESSION: v1.9 billing_holds
-- Expected: 10
-- ============================================================

SELECT
  'REGRESSION: v1.9 billing_holds' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_holds_v1_9;


-- ============================================================
-- 22. REGRESSION: v2.0 bill_review_queue
-- Expected: 1 (only 杨华禾 remains draft)
-- ============================================================

SELECT
  'REGRESSION: v2.0 bill_review_queue' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_review_queue_v2_0;


-- ============================================================
-- 23. REGRESSION: v2.1 approval_queue
-- Expected: 8
-- ============================================================

SELECT
  'REGRESSION: v2.1 approval_queue' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_approval_queue_v2_1;


-- ============================================================
-- 24. REGRESSION: v2.1 approval_summary
-- Expected: 1
-- ============================================================

SELECT
  'REGRESSION: v2.1 approval_summary' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_approval_summary_v2_1;


-- ============================================================
-- 25. REGRESSION: v2.2 issued bills
-- Expected: 7
-- ============================================================

SELECT
  'REGRESSION: v2.2 issued_bills' AS check_name,
  COUNT(*) AS row_count
FROM public.rent_bills
WHERE bill_status = 'issued'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';
