-- ============================================================
-- sql/26_verify_shaxi_bill_approval_workflow_v2_1.sql
-- Verify bill approval workflow for Shaxi v2.1
-- Batch: shaxi_promotion_v1
--
-- Purpose: Prove the approval workflow is healthy, all draft bills
--          have review records, no bills are auto-approved, and
--          prior version views remain intact.
--
-- Expected results:
--   - 8 approval records exist for the 8 draft bills
--   - all initial review_status = pending_review
--   - 杨华禾 remains pending_review with review_before_approve
--   - issue candidates = 0 (no manual approvals yet)
--   - issued bills = 0
--   - 川田 and 朱河芳 remain unbilled holds
--   - no duplicate bills
--   - no billing exceptions
--   - v1.7, v1.8, v1.9, v2.0 regression views still pass
-- ============================================================


-- ============================================================
-- 1. APPROVAL RECORD COUNT
-- Expected: 8
-- ============================================================

SELECT
  'APPROVAL: approval record count' AS check_name,
  COUNT(*) AS row_count
FROM public.bill_approval_reviews bar
JOIN public.rent_bills rb ON rb.id = bar.bill_id
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent';


-- ============================================================
-- 2. ALL APPROVAL RECORDS ARE PENDING_REVIEW INITIALLY
-- Expected: 8 pending_review, 0 others
-- ============================================================

SELECT
  'APPROVAL: review_status breakdown' AS check_name,
  review_status,
  COUNT(*) AS row_count
FROM public.bill_approval_reviews bar
JOIN public.rent_bills rb ON rb.id = bar.bill_id
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
GROUP BY review_status
ORDER BY review_status;


-- ============================================================
-- 3. APPROVAL QUEUE ROW COUNT
-- Expected: 8
-- ============================================================

SELECT
  'QUEUE: approval_queue row count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_approval_queue_v2_1;


-- ============================================================
-- 4. APPROVAL QUEUE STATUS BREAKDOWN
-- Expected: 8 pending_review
-- ============================================================

SELECT
  'QUEUE: queue review_status breakdown' AS check_name,
  review_status,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_approval_queue_v2_1
GROUP BY review_status
ORDER BY review_status;


-- ============================================================
-- 5. RECOMMENDATION BREAKDOWN IN QUEUE
-- Expected: 7 review_and_approve + 1 review_before_approve
-- ============================================================

SELECT
  'QUEUE: recommendation breakdown' AS check_name,
  review_recommendation,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_approval_queue_v2_1
GROUP BY review_recommendation
ORDER BY review_recommendation;


-- ============================================================
-- 6. 杨华禾 IS PENDING_REVIEW AND REVIEW_BEFORE_APPROVE
-- Expected: 1 row
-- ============================================================

SELECT
  'QUEUE: 杨华禾 status' AS check_name,
  tenant_name,
  review_status,
  review_recommendation
FROM public.vw_shaxi_bill_approval_queue_v2_1
WHERE tenant_name = '杨华禾';


-- ============================================================
-- 7. ISSUE CANDIDATES = 0 INITIALLY
-- Expected: 0 (no approvals yet)
-- ============================================================

SELECT
  'ISSUE: issue_candidate count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_issue_candidates_v2_1;


-- ============================================================
-- 8. ISSUED BILLS = 0
-- Expected: 0
-- ============================================================

SELECT
  'ISSUE: issued bill count' AS check_name,
  COUNT(*) AS issued_count
FROM public.rent_bills
WHERE bill_status = 'issued'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';


-- ============================================================
-- 9. APPROVAL SUMMARY
-- Expected: total_draft=8, pending=8, approved=0, rejected=0,
--           needs_adjustment=0, issue_ready=0, issued=0,
--           workflow_status='awaiting_approvals'
-- ============================================================

SELECT
  'SUMMARY: approval summary' AS check_name,
  total_draft,
  pending_count,
  approved_count,
  rejected_count,
  needs_adjustment_count,
  issue_ready_count,
  issued_count,
  workflow_status
FROM public.vw_shaxi_bill_approval_summary_v2_1;


-- ============================================================
-- 10. NO DUPLICATE BILLS
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
-- 11. BILLING EXCEPTIONS REMAIN 0
-- Expected: 0
-- ============================================================

SELECT
  'EXCEPTIONS: billing_exceptions count' AS check_name,
  COUNT(*) AS exception_count
FROM public.vw_shaxi_billing_exceptions;


-- ============================================================
-- 12. 川田 COMPONENT REMAINS UNBILLED (multiple_active hold)
-- Expected: 0
-- ============================================================

SELECT
  'HOLDS: 川田 component unbilled' AS check_name,
  COUNT(rb.id) AS bill_count
FROM public.rent_bills rb
WHERE rb.lease_package_component_id = '1a17c28c-3df6-41d3-b305-3ba50cc62806';


-- ============================================================
-- 13. 朱河芳 COMPONENT REMAINS UNBILLED (expired hold)
-- Expected: 0
-- ============================================================

SELECT
  'HOLDS: 朱河芳 component unbilled' AS check_name,
  COUNT(rb.id) AS bill_count
FROM public.rent_bills rb
WHERE rb.lease_package_component_id = 'c47ac0c3-b963-4222-a4d3-ab07d05b8eac';


-- ============================================================
-- 14. ALL DRAFT BILLS TRACE TO SAFE COMPONENTS
-- Expected: 0 unsafe bills
-- ============================================================

SELECT
  'TRACEABILITY: bills from unsafe components' AS check_name,
  COUNT(rb.id) AS unsafe_bill_count
FROM public.rent_bills rb
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND rb.lease_package_component_id NOT IN (
    SELECT id FROM public.lease_package_components WHERE promotion_batch = 'shaxi_promotion_v1'
  );


-- ============================================================
-- 15. REGRESSION: v1.7 expiry_watch
-- Expected: 10
-- ============================================================

SELECT
  'REGRESSION: v1.7 expiry_watch' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_contract_expiry_watch;


-- ============================================================
-- 16. REGRESSION: v1.7 occupancy_status
-- Expected: 44
-- ============================================================

SELECT
  'REGRESSION: v1.7 occupancy_status' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_area_occupancy_status;


-- ============================================================
-- 17. REGRESSION: v1.8 billing_readiness
-- Expected: 1
-- ============================================================

SELECT
  'REGRESSION: v1.8 billing_readiness' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_readiness;


-- ============================================================
-- 18. REGRESSION: v1.9 billing_generation_summary
-- Expected: 1
-- ============================================================

SELECT
  'REGRESSION: v1.9 billing_generation_summary' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_generation_summary_v1_9;


-- ============================================================
-- 19. REGRESSION: v1.9 billing_holds
-- Expected: 10 (8 duplicate_existing + 1 billing_hold + 1 expired)
-- ============================================================

SELECT
  'REGRESSION: v1.9 billing_holds' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_holds_v1_9;


-- ============================================================
-- 20. REGRESSION: v2.0 bill_review_queue
-- Expected: 8
-- ============================================================

SELECT
  'REGRESSION: v2.0 bill_review_queue' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_review_queue_v2_0;


-- ============================================================
-- 21. REGRESSION: v2.0 bill_issue_readiness
-- Expected: 1
-- ============================================================

SELECT
  'REGRESSION: v2.0 bill_issue_readiness' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_issue_readiness_v2_0;
