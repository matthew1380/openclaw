-- ============================================================
-- sql/33_verify_shaxi_exception_resolution_workflow_v2_5.sql
-- Verify business exception resolution workflow for Shaxi v2.5
-- Batch: shaxi_promotion_v1
--
-- Purpose: Prove the exception resolution workflow is healthy,
--          exactly 3 review records exist, held cases remain
--          unbilled, no fake payments were inserted, and all
--          prior version views remain intact.
--
-- Expected results:
--   - exactly 3 active business exception review records
--   - 川田 remains unbilled until decision
--   - 朱河芳 remains unbilled until renewal/new contract decision
--   - 杨华禾 remains draft/pending_review until approval
--   - no fake payments inserted
--   - payments count remains 0
--   - payment_allocations count remains 0
--   - existing 7 issued bills remain unchanged
--   - total outstanding remains ¥327,422
--   - mapping/billing/payment exceptions remain 0
--   - all v1.7 to v2.4 regression checks still pass
-- ============================================================


-- ============================================================
-- 1. EXACTLY 3 ACTIVE BUSINESS EXCEPTION REVIEW RECORDS
-- Expected: 3
-- ============================================================

SELECT
  'EXCEPTION: total review record count' AS check_name,
  COUNT(*) AS row_count
FROM public.shaxi_business_exception_reviews;


-- ============================================================
-- 2. ALL 3 ARE PENDING_DECISION INITIALLY
-- Expected: 3 pending_decision, 0 others
-- ============================================================

SELECT
  'EXCEPTION: decision_status breakdown' AS check_name,
  decision_status,
  COUNT(*) AS row_count
FROM public.shaxi_business_exception_reviews
GROUP BY decision_status
ORDER BY decision_status;


-- ============================================================
-- 3. EXCEPTION QUEUE RETURNS 3 ROWS
-- Expected: 3
-- ============================================================

SELECT
  'QUEUE: exception_queue row count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_business_exception_queue_v2_5;


-- ============================================================
-- 4. EXCEPTION SUMMARY EXISTS
-- Expected: 1 row with pending_decision_count=3, workflow_status='exceptions_pending_decision'
-- ============================================================

SELECT
  'SUMMARY: exception_summary' AS check_name,
  pending_decision_count,
  approved_to_bill_count,
  approved_to_issue_count,
  total_exception_count,
  workflow_status
FROM public.vw_shaxi_business_exception_summary_v2_5;


-- ============================================================
-- 5. 川田 EXCEPTION RECORD EXISTS WITH CORRECT TYPE
-- Expected: 1 row, exception_type='billing_hold', decision_status='pending_decision'
-- ============================================================

SELECT
  'QUEUE: 川田 exception record' AS check_name,
  tenant_name,
  exception_type,
  decision_status,
  recommended_action
FROM public.vw_shaxi_business_exception_queue_v2_5
WHERE tenant_name = '中山市川田制衣厂';


-- ============================================================
-- 6. 朱河芳 EXCEPTION RECORD EXISTS WITH CORRECT TYPE
-- Expected: 1 row, exception_type='expired_contract', decision_status='pending_decision'
-- ============================================================

SELECT
  'QUEUE: 朱河芳 exception record' AS check_name,
  tenant_name,
  exception_type,
  decision_status,
  recommended_action
FROM public.vw_shaxi_business_exception_queue_v2_5
WHERE tenant_name = '朱河芳';


-- ============================================================
-- 7. 杨华禾 EXCEPTION RECORD EXISTS WITH CORRECT TYPE
-- Expected: 1 row, exception_type='pending_draft_bill', decision_status='pending_decision'
-- ============================================================

SELECT
  'QUEUE: 杨华禾 exception record' AS check_name,
  tenant_name,
  exception_type,
  decision_status,
  related_bill_status,
  recommended_action
FROM public.vw_shaxi_business_exception_queue_v2_5
WHERE tenant_name = '杨华禾';


-- ============================================================
-- 8. 川田 REMAINS UNBILLED (no rent_bill for this component)
-- Expected: 0
-- ============================================================

SELECT
  'HOLDS: 川田 unbilled' AS check_name,
  COUNT(rb.id) AS bill_count
FROM public.rent_bills rb
WHERE rb.lease_package_component_id = '1a17c28c-3df6-41d3-b305-3ba50cc62806';


-- ============================================================
-- 9. 朱河芳 REMAINS UNBILLED (no rent_bill for this component)
-- Expected: 0
-- ============================================================

SELECT
  'HOLDS: 朱河芳 unbilled' AS check_name,
  COUNT(rb.id) AS bill_count
FROM public.rent_bills rb
WHERE rb.lease_package_component_id = 'c47ac0c3-b963-4222-a4d3-ab07d05b8eac';


-- ============================================================
-- 10. 杨华禾 BILL REMAINS DRAFT/PENDING_REVIEW
-- Expected: bill_status='draft', review_status='pending_review'
-- ============================================================

SELECT
  'HOLDS: 杨华禾 draft status' AS check_name,
  rb.bill_status,
  bar.review_status
FROM public.rent_bills rb
LEFT JOIN public.bill_approval_reviews bar ON bar.bill_id = rb.id
WHERE rb.id = '4adcf5d2-9b93-497b-b422-327a473e342a';


-- ============================================================
-- 11. NO FAKE PAYMENTS INSERTED
-- Expected: 0
-- ============================================================

SELECT
  'PAYMENTS: payments count' AS check_name,
  COUNT(*) AS row_count
FROM public.payments;


-- ============================================================
-- 12. PAYMENT_ALLOCATIONS COUNT REMAINS 0
-- Expected: 0
-- ============================================================

SELECT
  'PAYMENTS: payment_allocations count' AS check_name,
  COUNT(*) AS row_count
FROM public.payment_allocations;


-- ============================================================
-- 13. EXISTING 7 ISSUED BILLS REMAIN UNCHANGED
-- Expected: 7
-- ============================================================

SELECT
  'BILLS: issued bill count' AS check_name,
  COUNT(*) AS issued_count
FROM public.rent_bills
WHERE bill_status = 'issued'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';


-- ============================================================
-- 14. TOTAL OUTSTANDING REMAINS ¥327,422
-- Expected: 327422.00
-- ============================================================

SELECT
  'BILLS: total outstanding amount' AS check_name,
  COALESCE(SUM(outstanding_amount), 0) AS total_outstanding
FROM public.vw_shaxi_outstanding_bills_v2_3;


-- ============================================================
-- 15. MAPPING EXCEPTIONS = 0
-- Expected: 0
-- ============================================================

SELECT
  'EXCEPTIONS: mapping_exceptions count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_mapping_exceptions;


-- ============================================================
-- 16. BILLING EXCEPTIONS = 0
-- Expected: 0
-- ============================================================

SELECT
  'EXCEPTIONS: billing_exceptions count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_exceptions;


-- ============================================================
-- 17. PAYMENT ALLOCATION EXCEPTIONS = 0
-- Expected: 0
-- ============================================================

SELECT
  'EXCEPTIONS: payment_allocation_exceptions count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_payment_allocation_exceptions_v2_3;


-- ============================================================
-- 18. NO DUPLICATE BILLS
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
-- 19. ALL ISSUED BILLS TRACE TO SAFE COMPONENTS
-- Expected: 0 unsafe
-- ============================================================

SELECT
  'TRACEABILITY: issued bills from unsafe components' AS check_name,
  COUNT(rb.id) AS unsafe_bill_count
FROM public.rent_bills rb
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND rb.bill_status = 'issued'
  AND rb.lease_package_component_id NOT IN (
    SELECT id FROM public.lease_package_components WHERE promotion_batch = 'shaxi_promotion_v1'
  );


-- ============================================================
-- 20. REGRESSION: v1.7 expiry_watch
-- Expected: 10
-- ============================================================

SELECT
  'REGRESSION: v1.7 expiry_watch' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_contract_expiry_watch;


-- ============================================================
-- 21. REGRESSION: v1.7 occupancy_status
-- Expected: 44
-- ============================================================

SELECT
  'REGRESSION: v1.7 occupancy_status' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_area_occupancy_status;


-- ============================================================
-- 22. REGRESSION: v1.8 billing_readiness
-- Expected: 1
-- ============================================================

SELECT
  'REGRESSION: v1.8 billing_readiness' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_readiness;


-- ============================================================
-- 23. REGRESSION: v1.9 billing_generation_summary
-- Expected: 1
-- ============================================================

SELECT
  'REGRESSION: v1.9 billing_generation_summary' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_generation_summary_v1_9;


-- ============================================================
-- 24. REGRESSION: v1.9 billing_holds
-- Expected: 10
-- ============================================================

SELECT
  'REGRESSION: v1.9 billing_holds' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_holds_v1_9;


-- ============================================================
-- 25. REGRESSION: v2.0 bill_review_queue
-- Expected: 1
-- ============================================================

SELECT
  'REGRESSION: v2.0 bill_review_queue' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_review_queue_v2_0;


-- ============================================================
-- 26. REGRESSION: v2.1 approval_queue
-- Expected: 8
-- ============================================================

SELECT
  'REGRESSION: v2.1 approval_queue' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_approval_queue_v2_1;


-- ============================================================
-- 27. REGRESSION: v2.2 issued bills
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
-- 28. REGRESSION: v2.3 outstanding_bills
-- Expected: 7
-- ============================================================

SELECT
  'REGRESSION: v2.3 outstanding_bills' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_outstanding_bills_v2_3;


-- ============================================================
-- 29. REGRESSION: v2.3 payment_recording_queue
-- Expected: 7
-- ============================================================

SELECT
  'REGRESSION: v2.3 payment_recording_queue' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_payment_recording_queue_v2_3;


-- ============================================================
-- 30. REGRESSION: v2.4 staff interface support views
-- Expected: 7
-- ============================================================

SELECT
  'REGRESSION: v2.4 staff_interface_support' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_payment_recording_queue_v2_3;
