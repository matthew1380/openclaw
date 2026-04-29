-- ============================================================
-- sql/23_verify_shaxi_bill_review_views_v2_0.sql
-- Verify bill review and approval layer for Shaxi v2.0
-- Batch: shaxi_promotion_v1
--
-- Purpose: Prove the review layer is healthy and the draft bills
--          are ready for human review.
--
-- Expected results:
--   - review queue returns 8 draft bills
--   - hold review returns 2 rows
--   - no issued bills exist
--   - billing exceptions remain 0
--   - duplicate bills remain 0
--   - all draft bills trace to safe lease components
--   - expired and multiple_active components remain unbilled
--   - v1.7, v1.8, v1.9 regression views still work
-- ============================================================


-- ============================================================
-- 1. REVIEW QUEUE ROW COUNT
-- Expected: 8
-- ============================================================

SELECT
  'QUEUE: review_queue row count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_review_queue_v2_0;


-- ============================================================
-- 2. REVIEW QUEUE ALL DRAFT
-- Expected: all bill_status = 'draft'
-- ============================================================

SELECT
  'QUEUE: all bills are draft' AS check_name,
  bill_status,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_review_queue_v2_0
GROUP BY bill_status
ORDER BY bill_status;


-- ============================================================
-- 3. REVIEW QUEUE BILLING MONTH
-- Expected: all billing_month = 2026-05-01
-- ============================================================

SELECT
  'QUEUE: billing_month check' AS check_name,
  billing_month,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_review_queue_v2_0
GROUP BY billing_month
ORDER BY billing_month;


-- ============================================================
-- 4. REVIEW QUEUE BILL TYPE
-- Expected: all bill_type = 'rent'
-- ============================================================

SELECT
  'QUEUE: bill_type check' AS check_name,
  bill_type,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_review_queue_v2_0
GROUP BY bill_type
ORDER BY bill_type;


-- ============================================================
-- 5. REVIEW QUEUE RECOMMENDATION BREAKDOWN
-- Expected: 1 review_before_approve + 7 review_and_approve
-- ============================================================

SELECT
  'QUEUE: recommendation breakdown' AS check_name,
  review_recommendation,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_review_queue_v2_0
GROUP BY review_recommendation
ORDER BY review_recommendation;


-- ============================================================
-- 6. REVIEW QUEUE DETAIL
-- Full list for audit
-- ============================================================

SELECT
  'QUEUE: bill detail' AS check_name,
  tenant_name,
  area_code,
  amount_due,
  due_date,
  review_recommendation
FROM public.vw_shaxi_bill_review_queue_v2_0
ORDER BY amount_due DESC;


-- ============================================================
-- 7. HOLD REVIEW ROW COUNT
-- Expected: 2
-- ============================================================

SELECT
  'HOLDS: hold_review row count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_hold_review_v2_0;


-- ============================================================
-- 8. HOLD REVIEW STATUS BREAKDOWN
-- Expected: 1 billing_hold + 1 expired
-- ============================================================

SELECT
  'HOLDS: status breakdown' AS check_name,
  candidate_status,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_hold_review_v2_0
GROUP BY candidate_status
ORDER BY candidate_status;


-- ============================================================
-- 9. HOLD REVIEW DETAIL
-- Expected: 川田 (billing_hold) + 朱河芳 (expired)
-- ============================================================

SELECT
  'HOLDS: hold detail' AS check_name,
  tenant_name,
  area_code,
  candidate_status,
  hold_reason,
  recommended_action
FROM public.vw_shaxi_billing_hold_review_v2_0
ORDER BY candidate_status, tenant_name;


-- ============================================================
-- 10. ISSUE READINESS STATUS
-- Expected: ready_for_human_review
-- ============================================================

SELECT
  'READINESS: status' AS check_name,
  draft_bill_count,
  hold_count,
  exception_count,
  duplicate_bill_count,
  non_draft_bill_count,
  readiness_status
FROM public.vw_shaxi_bill_issue_readiness_v2_0;


-- ============================================================
-- 11. NO ISSUED BILLS
-- Expected: 0 bills with status != 'draft'
-- ============================================================

SELECT
  'DATA: non-draft bill count' AS check_name,
  COUNT(*) AS non_draft_count
FROM public.rent_bills
WHERE bill_status != 'draft'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';


-- ============================================================
-- 12. NO DUPLICATE BILLS
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
-- 13. ALL DRAFT BILLS TRACE TO SAFE COMPONENTS
-- Expected: 0 bills linked to non-safe components
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
-- 14. EXPIRED COMPONENT REMAINS UNBILLED
-- Expected: 0 bills for 朱河芳 component
-- ============================================================

SELECT
  'HOLDS: expired component unbilled' AS check_name,
  COUNT(rb.id) AS bill_count
FROM public.rent_bills rb
WHERE rb.lease_package_component_id = 'c47ac0c3-b963-4222-a4d3-ab07d05b8eac';


-- ============================================================
-- 15. MULTIPLE_ACTIVE COMPONENT REMAINS UNBILLED
-- Expected: 0 bills for 川田 component
-- ============================================================

SELECT
  'HOLDS: multiple_active component unbilled' AS check_name,
  COUNT(rb.id) AS bill_count
FROM public.rent_bills rb
WHERE rb.lease_package_component_id = '1a17c28c-3df6-41d3-b305-3ba50cc62806';


-- ============================================================
-- 16. BILLING EXCEPTIONS REMAIN 0
-- Expected: 0
-- ============================================================

SELECT
  'EXCEPTIONS: billing_exceptions count' AS check_name,
  COUNT(*) AS exception_count
FROM public.vw_shaxi_billing_exceptions;


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
-- Expected: 9 (1 billing_hold + 1 expired + 8 duplicate_existing)
-- ============================================================

SELECT
  'REGRESSION: v1.9 billing_holds' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_holds_v1_9;
