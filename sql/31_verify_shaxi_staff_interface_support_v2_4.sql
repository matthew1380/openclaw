-- ============================================================
-- sql/31_verify_shaxi_staff_interface_support_v2_4.sql
-- Verify staff interface support views for Shaxi v2.4
-- Batch: shaxi_promotion_v1
--
-- Purpose: Prove the views used by the staff interface are
--          healthy, hold the expected data, and enforce the
--          safety rules (draft/held bills excluded).
--
-- Expected results:
--   - 7 issued bills visible in outstanding view
--   - 7 payment-eligible bills before payments
--   - draft 杨华禾 excluded from outstanding and queue views
--   - 川田 and 朱河芳 excluded from outstanding and queue views
--   - exception views return 0
--   - interface source views exist and return expected counts
--   - v1.7 through v2.3 regression views still pass
-- ============================================================


-- ============================================================
-- 1. OUTSTANDING VIEW EXISTS AND RETURNS ISSUED BILLS
-- Expected: 7
-- ============================================================

SELECT
  'INTERFACE: outstanding_bills row count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_outstanding_bills_v2_3;


-- ============================================================
-- 2. PAYMENT RECORDING QUEUE EXISTS AND RETURNS ELIGIBLE BILLS
-- Expected: 7
-- ============================================================

SELECT
  'INTERFACE: payment_recording_queue row count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_payment_recording_queue_v2_3;


-- ============================================================
-- 3. DRAFT BILL IS EXCLUDED FROM OUTSTANDING VIEW
-- Expected: 0
-- ============================================================

SELECT
  'INTERFACE: draft bill excluded from outstanding' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_outstanding_bills_v2_3
WHERE tenant_name = '杨华禾';


-- ============================================================
-- 4. DRAFT BILL IS EXCLUDED FROM PAYMENT QUEUE
-- Expected: 0
-- ============================================================

SELECT
  'INTERFACE: draft bill excluded from queue' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_payment_recording_queue_v2_3
WHERE tenant_name = '杨华禾';


-- ============================================================
-- 5. 川田 IS EXCLUDED FROM OUTSTANDING VIEW
-- Expected: 0
-- ============================================================

SELECT
  'INTERFACE: 川田 excluded from outstanding' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_outstanding_bills_v2_3
WHERE tenant_name LIKE '%川田%';


-- ============================================================
-- 6. 川田 IS EXCLUDED FROM PAYMENT QUEUE
-- Expected: 0
-- ============================================================

SELECT
  'INTERFACE: 川田 excluded from queue' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_payment_recording_queue_v2_3
WHERE tenant_name LIKE '%川田%';


-- ============================================================
-- 7. 朱河芳 IS EXCLUDED FROM OUTSTANDING VIEW
-- Expected: 0
-- ============================================================

SELECT
  'INTERFACE: 朱河芳 excluded from outstanding' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_outstanding_bills_v2_3
WHERE tenant_name LIKE '%朱河芳%';


-- ============================================================
-- 8. 朱河芳 IS EXCLUDED FROM PAYMENT QUEUE
-- Expected: 0
-- ============================================================

SELECT
  'INTERFACE: 朱河芳 excluded from queue' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_payment_recording_queue_v2_3
WHERE tenant_name LIKE '%朱河芳%';


-- ============================================================
-- 9. MAPPING EXCEPTIONS = 0
-- Expected: 0
-- ============================================================

SELECT
  'EXCEPTIONS: mapping_exceptions count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_mapping_exceptions;


-- ============================================================
-- 10. BILLING EXCEPTIONS = 0
-- Expected: 0
-- ============================================================

SELECT
  'EXCEPTIONS: billing_exceptions count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_exceptions;


-- ============================================================
-- 11. PAYMENT ALLOCATION EXCEPTIONS = 0
-- Expected: 0
-- ============================================================

SELECT
  'EXCEPTIONS: payment_allocation_exceptions count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_payment_allocation_exceptions_v2_3;


-- ============================================================
-- 12. APPROVAL SUMMARY EXISTS
-- Expected: 1
-- ============================================================

SELECT
  'INTERFACE: approval_summary exists' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_approval_summary_v2_1;


-- ============================================================
-- 13. HOLD REVIEW EXISTS
-- Expected: 2
-- ============================================================

SELECT
  'INTERFACE: hold_review exists' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_hold_review_v2_0;


-- ============================================================
-- 14. DRAFT QUEUE EXISTS
-- Expected: 1
-- ============================================================

SELECT
  'INTERFACE: draft_queue exists' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_review_queue_v2_0;


-- ============================================================
-- 15. ALL OUTSTANDING BILLS ARE ISSUED
-- Expected: all bill_status = 'issued'
-- ============================================================

SELECT
  'INTERFACE: outstanding bills status check' AS check_name,
  bill_status,
  COUNT(*) AS row_count
FROM public.vw_shaxi_outstanding_bills_v2_3
GROUP BY bill_status;


-- ============================================================
-- 16. ALL QUEUE BILLS HAVE OUTSTANDING > 0
-- Expected: min outstanding > 0
-- ============================================================

SELECT
  'INTERFACE: queue bills outstanding check' AS check_name,
  MIN(outstanding_amount) AS min_outstanding,
  MAX(outstanding_amount) AS max_outstanding
FROM public.vw_shaxi_payment_recording_queue_v2_3;


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
-- 21. REGRESSION: v2.0 bill_review_queue
-- Expected: 1
-- ============================================================

SELECT
  'REGRESSION: v2.0 bill_review_queue' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_review_queue_v2_0;


-- ============================================================
-- 22. REGRESSION: v2.1 approval_queue
-- Expected: 8
-- ============================================================

SELECT
  'REGRESSION: v2.1 approval_queue' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_approval_queue_v2_1;


-- ============================================================
-- 23. REGRESSION: v2.2 issued bills
-- Expected: 7
-- ============================================================

SELECT
  'REGRESSION: v2.2 issued_bills' AS check_name,
  COUNT(*) AS row_count
FROM public.rent_bills
WHERE bill_status = 'issued'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';


-- ============================================================
-- 24. REGRESSION: v2.3 outstanding_bills
-- Expected: 7
-- ============================================================

SELECT
  'REGRESSION: v2.3 outstanding_bills' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_outstanding_bills_v2_3;


-- ============================================================
-- 25. REGRESSION: v2.3 payment_recording_queue
-- Expected: 7
-- ============================================================

SELECT
  'REGRESSION: v2.3 payment_recording_queue' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_payment_recording_queue_v2_3;
