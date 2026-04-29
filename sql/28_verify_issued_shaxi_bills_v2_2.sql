-- ============================================================
-- sql/28_verify_issued_shaxi_bills_v2_2.sql
-- Verify approved and issued Shaxi bills for v2.2
-- Batch: shaxi_promotion_v1
--
-- Purpose: Prove that 7 normal bills were approved and issued,
--          杨华禾 remains draft/pending, holds untouched, and
--          all prior version views remain intact.
--
-- Expected results:
--   - approved approval records = 7
--   - pending_review approval records = 1
--   - issued bills = 7
--   - draft bills = 1
--   - 杨华禾 remains draft + pending_review
--   - issue candidates = 0 after issuing
--   - holds = 2
--   - billing exceptions = 0
--   - duplicate bills = 0
--   - v1.7, v1.8, v1.9, v2.0, v2.1 regression views still pass
-- ============================================================


-- ============================================================
-- 1. APPROVED RECORDS COUNT
-- Expected: 7
-- ============================================================

SELECT
  'APPROVAL: approved count' AS check_name,
  COUNT(*) AS row_count
FROM public.bill_approval_reviews bar
JOIN public.rent_bills rb ON rb.id = bar.bill_id
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND bar.review_status = 'approved';


-- ============================================================
-- 2. PENDING_REVIEW RECORDS COUNT
-- Expected: 1
-- ============================================================

SELECT
  'APPROVAL: pending_review count' AS check_name,
  COUNT(*) AS row_count
FROM public.bill_approval_reviews bar
JOIN public.rent_bills rb ON rb.id = bar.bill_id
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND bar.review_status = 'pending_review';


-- ============================================================
-- 3. NO REJECTED OR NEEDS_ADJUSTMENT RECORDS
-- Expected: 0
-- ============================================================

SELECT
  'APPROVAL: rejected+needs_adjustment count' AS check_name,
  COUNT(*) AS row_count
FROM public.bill_approval_reviews bar
JOIN public.rent_bills rb ON rb.id = bar.bill_id
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND bar.review_status IN ('rejected', 'needs_adjustment');


-- ============================================================
-- 4. ISSUED BILLS COUNT
-- Expected: 7
-- ============================================================

SELECT
  'ISSUE: issued bill count' AS check_name,
  COUNT(*) AS issued_count
FROM public.rent_bills
WHERE bill_status = 'issued'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';


-- ============================================================
-- 5. DRAFT BILLS COUNT
-- Expected: 1
-- ============================================================

SELECT
  'ISSUE: draft bill count' AS check_name,
  COUNT(*) AS draft_count
FROM public.rent_bills
WHERE bill_status = 'draft'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';


-- ============================================================
-- 6. 杨华禾 REMAINS DRAFT AND PENDING_REVIEW
-- Expected: 1 row, bill_status = draft, review_status = pending_review
-- ============================================================

SELECT
  'ISSUE: 杨华禾 remains draft+pending' AS check_name,
  rb.bill_status,
  bar.review_status,
  q.review_recommendation
FROM public.rent_bills rb
JOIN public.bill_approval_reviews bar ON bar.bill_id = rb.id
JOIN public.vw_shaxi_bill_approval_queue_v2_1 q ON q.bill_id = rb.id
WHERE q.tenant_name = '杨华禾';


-- ============================================================
-- 7. ISSUE CANDIDATES = 0 AFTER ISSUING
-- Expected: 0 (all approved bills are now issued, not draft)
-- ============================================================

SELECT
  'ISSUE: issue_candidate count post-issue' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_issue_candidates_v2_1;


-- ============================================================
-- 8. APPROVAL SUMMARY POST-ISSUE
-- Expected: total_draft=1, pending=1, approved=7, rejected=0,
--           needs_adjustment=0, issue_ready=0, issued=7
-- ============================================================

SELECT
  'SUMMARY: approval summary post-issue' AS check_name,
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
-- 9. ALL ISSUED BILLS TRACE TO SAFE COMPONENTS
-- Expected: 0 unsafe bills
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
-- 10. ISSUED BILLS HAVE APPROVAL RECORDS
-- Expected: 7 (every issued bill has an approved review record)
-- ============================================================

SELECT
  'TRACEABILITY: issued bills without approval' AS check_name,
  COUNT(*) AS unapproved_issued_count
FROM public.rent_bills rb
LEFT JOIN public.bill_approval_reviews bar ON bar.bill_id = rb.id
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND rb.bill_status = 'issued'
  AND (bar.id IS NULL OR bar.review_status != 'approved');


-- ============================================================
-- 11. HOLD REVIEW ROW COUNT
-- Expected: 2
-- ============================================================

SELECT
  'HOLDS: hold_review row count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_billing_hold_review_v2_0;


-- ============================================================
-- 12. HOLD REVIEW STATUS BREAKDOWN
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
-- 14. BILLING EXCEPTIONS REMAIN 0
-- Expected: 0
-- ============================================================

SELECT
  'EXCEPTIONS: billing_exceptions count' AS check_name,
  COUNT(*) AS exception_count
FROM public.vw_shaxi_billing_exceptions;


-- ============================================================
-- 15. 川田 COMPONENT REMAINS UNBILLED
-- Expected: 0
-- ============================================================

SELECT
  'HOLDS: 川田 component unbilled' AS check_name,
  COUNT(rb.id) AS bill_count
FROM public.rent_bills rb
WHERE rb.lease_package_component_id = '1a17c28c-3df6-41d3-b305-3ba50cc62806';


-- ============================================================
-- 16. 朱河芳 COMPONENT REMAINS UNBILLED
-- Expected: 0
-- ============================================================

SELECT
  'HOLDS: 朱河芳 component unbilled' AS check_name,
  COUNT(rb.id) AS bill_count
FROM public.rent_bills rb
WHERE rb.lease_package_component_id = 'c47ac0c3-b963-4222-a4d3-ab07d05b8eac';


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
-- Expected: 10 (1 billing_hold + 1 expired + 8 duplicate_existing)
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
-- 23. REGRESSION: v2.0 bill_issue_readiness
-- Expected: 1
-- ============================================================

SELECT
  'REGRESSION: v2.0 bill_issue_readiness' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_issue_readiness_v2_0;


-- ============================================================
-- 24. REGRESSION: v2.1 approval_queue
-- Expected: 8 (all bills still visible in approval queue)
-- ============================================================

SELECT
  'REGRESSION: v2.1 approval_queue' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_approval_queue_v2_1;


-- ============================================================
-- 25. REGRESSION: v2.1 approval_summary
-- Expected: 1
-- ============================================================

SELECT
  'REGRESSION: v2.1 approval_summary' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_approval_summary_v2_1;
