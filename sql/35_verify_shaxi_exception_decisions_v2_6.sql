-- ============================================================
-- sql/35_verify_shaxi_exception_decisions_v2_6.sql
-- Verify Shaxi business exception decisions for v2.6
-- Batch: shaxi_promotion_v1
--
-- Purpose: Prove the v2.6 exception decision script applied cleanly,
--          no fake payments were inserted, no unauthorised bills were
--          created, and all v1.7 -> v2.5 regression views still pass.
--
-- Expected results (post-v2.6):
--   - 川田: decision_status = keep_on_hold (decided by Matthew/admin)
--   - 杨华禾: decision_status = approved_to_issue (decided by Matthew/admin)
--   - 朱河芳: decision_status = pending_decision (unchanged)
--   - 杨华禾 bill: bill_status = issued, review_status = approved
--   - 川田 still unbilled (0 bills for its component_id)
--   - 朱河芳 still unbilled (0 bills for its component_id)
--   - No new master-lease (靖大物业) bill created
--   - issued bill count: 8 (was 7)
--   - total outstanding: 329922.00 (was 327422.00, +2500 for 杨华禾)
--   - payments = 0, payment_allocations = 0
--   - mapping/billing/payment_allocation exceptions = 0
--   - 0 duplicate bills, 0 unsafe issued bills
--   - vw_shaxi_bill_review_queue_v2_0 = 0 (no draft bills left)
--   - vw_shaxi_outstanding_bills_v2_3 = 8
--   - vw_shaxi_payment_recording_queue_v2_3 = 8
--   - vw_shaxi_bill_approval_queue_v2_1 = 8 (unchanged, view ignores bill_status)
--   - workflow_status = exceptions_pending_decision (because 朱河芳 still pending)
-- ============================================================


-- ============================================================
-- 1. EXCEPTION REVIEW TOTAL COUNT UNCHANGED
-- Expected: 3
-- ============================================================

SELECT
  'EXCEPTION: total review record count' AS check_name,
  COUNT(*) AS row_count
FROM public.shaxi_business_exception_reviews;


-- ============================================================
-- 2. DECISION_STATUS BREAKDOWN POST-v2.6
-- Expected: pending_decision=1 (朱河芳), keep_on_hold=1 (川田), approved_to_issue=1 (杨华禾)
-- ============================================================

SELECT
  'EXCEPTION: decision_status breakdown' AS check_name,
  decision_status,
  COUNT(*) AS row_count
FROM public.shaxi_business_exception_reviews
GROUP BY decision_status
ORDER BY decision_status;


-- ============================================================
-- 3. 川田 DECISION RECORDED CORRECTLY
-- Expected: 1 row, decision_status = keep_on_hold, decision_by = Matthew/admin
-- ============================================================

SELECT
  'DECISION: 川田 keep_on_hold' AS check_name,
  tenant_name,
  exception_type,
  decision_status,
  decision_by,
  CASE WHEN decision_at IS NOT NULL THEN 'decided' ELSE 'NOT decided' END AS decision_at_state,
  CASE
    WHEN decision_note LIKE '%靖大物业%'
     AND decision_note LIKE '%中铭%'
     AND decision_note LIKE '%Do not issue direct rent bill%'
    THEN 'note_present'
    ELSE 'note_missing_or_wrong'
  END AS note_check
FROM public.shaxi_business_exception_reviews
WHERE tenant_name = '中山市川田制衣厂'
  AND exception_type = 'billing_hold';


-- ============================================================
-- 4. 杨华禾 EXCEPTION DECISION RECORDED CORRECTLY
-- Expected: 1 row, decision_status = approved_to_issue, decision_by = Matthew/admin
-- ============================================================

SELECT
  'DECISION: 杨华禾 approved_to_issue' AS check_name,
  tenant_name,
  exception_type,
  decision_status,
  decision_by,
  CASE WHEN decision_at IS NOT NULL THEN 'decided' ELSE 'NOT decided' END AS decision_at_state
FROM public.shaxi_business_exception_reviews
WHERE tenant_name = '杨华禾'
  AND exception_type = 'pending_draft_bill';


-- ============================================================
-- 5. 朱河芳 STAYS PENDING_DECISION (UNCHANGED)
-- Expected: 1 row, decision_status = pending_decision, decision_by IS NULL
-- ============================================================

SELECT
  'DECISION: 朱河芳 still pending_decision' AS check_name,
  tenant_name,
  exception_type,
  decision_status,
  decision_by,
  CASE WHEN decision_at IS NULL THEN 'never_decided' ELSE 'UNEXPECTED_DECISION' END AS decision_at_state
FROM public.shaxi_business_exception_reviews
WHERE tenant_name = '朱河芳'
  AND exception_type = 'expired_contract';


-- ============================================================
-- 6. EXCEPTION SUMMARY VIEW POST-v2.6
-- Expected: pending=1, keep_on_hold=1, approved_to_issue=1, total=3,
--           draft_pending_count=0, workflow_status=exceptions_pending_decision
-- ============================================================

SELECT
  'SUMMARY: exception_summary' AS check_name,
  pending_decision_count,
  approved_to_issue_count,
  keep_on_hold_count,
  approved_to_bill_count,
  needs_adjustment_count,
  resolved_count,
  total_exception_count,
  unbilled_hold_count,
  draft_pending_count,
  workflow_status
FROM public.vw_shaxi_business_exception_summary_v2_5;


-- ============================================================
-- 7. 杨华禾 BILL IS NOW ISSUED + APPROVED
-- Expected: 1 row, bill_status = issued, review_status = approved
-- ============================================================

SELECT
  'BILL: 杨华禾 issued + approved' AS check_name,
  rb.bill_status,
  rb.amount_due,
  bar.review_status,
  bar.reviewed_by
FROM public.rent_bills rb
LEFT JOIN public.bill_approval_reviews bar ON bar.bill_id = rb.id
WHERE rb.id = '4adcf5d2-9b93-497b-b422-327a473e342a';


-- ============================================================
-- 8. 川田 STILL UNBILLED (no rent_bill for its component_id)
-- Expected: 0
-- ============================================================

SELECT
  'HOLDS: 川田 still unbilled' AS check_name,
  COUNT(*) AS bill_count
FROM public.rent_bills
WHERE lease_package_component_id = '1a17c28c-3df6-41d3-b305-3ba50cc62806';


-- ============================================================
-- 9. 朱河芳 STILL UNBILLED (no rent_bill for its component_id)
-- Expected: 0
-- ============================================================

SELECT
  'HOLDS: 朱河芳 still unbilled' AS check_name,
  COUNT(*) AS bill_count
FROM public.rent_bills
WHERE lease_package_component_id = 'c47ac0c3-b963-4222-a4d3-ab07d05b8eac';


-- ============================================================
-- 10. NO NEW 靖大物业 MASTER-LEASE BILL CREATED IN v2.6
-- Expected: 0 (no rent_bills row whose tenant is 靖大物业 for May 2026)
-- ============================================================

SELECT
  'HOLDS: no 靖大物业 master-lease bill in v2.6' AS check_name,
  COUNT(*) AS bill_count
FROM public.rent_bills rb
JOIN public.contacts con ON con.id = rb.tenant_id
WHERE con.name LIKE '%靖大物业%'
  AND rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent';


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
-- 13. ISSUED BILL COUNT IS NOW 8 (was 7 in v2.5)
-- Expected: 8
-- ============================================================

SELECT
  'BILLS: issued bill count' AS check_name,
  COUNT(*) AS issued_count
FROM public.rent_bills
WHERE bill_status = 'issued'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';


-- ============================================================
-- 14. TOTAL OUTSTANDING IS NOW ¥329,922.00 (was ¥327,422.00, +¥2,500 for 杨华禾)
-- Expected: 329922.00
-- ============================================================

SELECT
  'BILLS: total outstanding amount' AS check_name,
  COALESCE(SUM(outstanding_amount), 0) AS total_outstanding
FROM public.vw_shaxi_outstanding_bills_v2_3;


-- ============================================================
-- 15. NO REMAINING DRAFT BILLS FOR MAY 2026 RENT
-- Expected: 0
-- ============================================================

SELECT
  'BILLS: remaining draft count' AS check_name,
  COUNT(*) AS draft_count
FROM public.rent_bills
WHERE bill_status = 'draft'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';


-- ============================================================
-- 16. MAPPING EXCEPTIONS = 0
-- Expected: 0
-- ============================================================

SELECT
  'EXCEPTIONS: mapping_exceptions count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_mapping_exceptions;


-- ============================================================
-- 17. BILLING EXCEPTIONS = 0
-- Expected: 0
-- ============================================================

SELECT
  'EXCEPTIONS: billing_exceptions count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_exceptions;


-- ============================================================
-- 18. PAYMENT ALLOCATION EXCEPTIONS = 0
-- Expected: 0
-- ============================================================

SELECT
  'EXCEPTIONS: payment_allocation_exceptions count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_payment_allocation_exceptions_v2_3;


-- ============================================================
-- 19. NO DUPLICATE BILLS
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
-- 20. ALL ISSUED BILLS TRACE TO SAFE COMPONENTS
-- Expected: 0 unsafe
-- ============================================================

SELECT
  'TRACEABILITY: issued bills from unsafe components' AS check_name,
  COUNT(*) AS unsafe_bill_count
FROM public.rent_bills rb
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND rb.bill_status = 'issued'
  AND rb.lease_package_component_id NOT IN (
    SELECT id FROM public.lease_package_components WHERE promotion_batch = 'shaxi_promotion_v1'
  );


-- ============================================================
-- 21. REGRESSION: v1.7 expiry_watch (10)
-- ============================================================

SELECT
  'REGRESSION: v1.7 expiry_watch' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_contract_expiry_watch;


-- ============================================================
-- 22. REGRESSION: v1.7 occupancy_status (44)
-- ============================================================

SELECT
  'REGRESSION: v1.7 occupancy_status' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_area_occupancy_status;


-- ============================================================
-- 23. REGRESSION: v1.8 billing_readiness (1)
-- ============================================================

SELECT
  'REGRESSION: v1.8 billing_readiness' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_readiness;


-- ============================================================
-- 24. REGRESSION: v1.9 billing_generation_summary (1)
-- ============================================================

SELECT
  'REGRESSION: v1.9 billing_generation_summary' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_generation_summary_v1_9;


-- ============================================================
-- 25. REGRESSION: v1.9 billing_holds (10)
-- ============================================================

SELECT
  'REGRESSION: v1.9 billing_holds' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_holds_v1_9;


-- ============================================================
-- 26. REGRESSION: v2.0 bill_review_queue (now 0, was 1)
-- Expected: 0 — 杨华禾 was the only draft and is now issued
-- ============================================================

SELECT
  'REGRESSION: v2.0 bill_review_queue (now 0)' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_review_queue_v2_0;


-- ============================================================
-- 27. REGRESSION: v2.1 approval_queue (8 — view does not filter on bill_status)
-- ============================================================

SELECT
  'REGRESSION: v2.1 approval_queue' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_approval_queue_v2_1;


-- ============================================================
-- 28. REGRESSION: v2.3 outstanding_bills (now 8, was 7)
-- ============================================================

SELECT
  'REGRESSION: v2.3 outstanding_bills (now 8)' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_outstanding_bills_v2_3;


-- ============================================================
-- 29. REGRESSION: v2.3 payment_recording_queue (now 8, was 7)
-- ============================================================

SELECT
  'REGRESSION: v2.3 payment_recording_queue (now 8)' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_payment_recording_queue_v2_3;


-- ============================================================
-- 30. REGRESSION: v2.5 exception_queue still returns 3 rows
-- ============================================================

SELECT
  'REGRESSION: v2.5 exception_queue' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_business_exception_queue_v2_5;


-- ============================================================
-- 31. FINAL FULL EXCEPTION QUEUE SNAPSHOT
-- Human-readable end-state confirmation.
-- ============================================================

SELECT
  'FINAL: exception queue snapshot' AS check_name,
  tenant_name,
  exception_type,
  decision_status,
  decision_by,
  recommended_action
FROM public.vw_shaxi_business_exception_queue_v2_5
ORDER BY tenant_name;
