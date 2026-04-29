-- ============================================================
-- sql/27_approve_normal_shaxi_bills_v2_2.sql
-- Approve normal May 2026 Shaxi rent bills
-- Batch: shaxi_promotion_v1
--
-- Purpose: Approve the 7 clearly normal draft bills for May 2026.
--          Leave 杨华禾 as pending_review (review_before_approve).
--
-- Rules:
--   - Only bills with review_recommendation = 'review_and_approve' are approved.
--   - 杨华禾 (review_before_approve) stays pending_review.
--   - Does NOT issue bills — run sql/25_issue_approved_shaxi_bills_v2_1.sql after this.
--   - Does NOT record payments.
--   - Does NOT resolve holds.
--   - Idempotent: only updates rows currently pending_review.
--   - Safe to rerun.
-- ============================================================


-- ============================================================
-- HOTFIX: Refresh issue_candidates view
-- The v2.1 view required candidate_status = 'generate_ready', which
-- becomes 'duplicate_existing' after bills are generated. Change the
-- rule to only exclude held/expired/missing_rent candidates.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_bill_issue_candidates_v2_1 AS
SELECT
  rb.id AS bill_id,
  con.name AS tenant_name,
  ra.area_code,
  ra.area_name,
  b.building_name,
  rb.billing_month,
  rb.bill_type,
  rb.amount_due,
  rb.due_date,
  bar.review_status,
  bar.reviewed_by,
  bar.reviewed_at,
  rb.lease_contract_id,
  rb.lease_package_component_id,
  rb.source_type,
  rb.created_from
FROM public.rent_bills rb
JOIN public.contacts con ON con.id = rb.tenant_id
JOIN public.lease_package_components lpc ON lpc.id = rb.lease_package_component_id
JOIN public.rentable_areas ra ON ra.id = lpc.rentable_area_id
JOIN public.building_registry b ON b.id = ra.building_id
JOIN public.bill_approval_reviews bar ON bar.bill_id = rb.id
WHERE rb.bill_status = 'draft'
  AND rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND bar.review_status = 'approved'
  -- no duplicate bill for same component / month / type
  AND NOT EXISTS (
    SELECT 1 FROM public.rent_bills rb2
    WHERE rb2.lease_package_component_id = rb.lease_package_component_id
      AND rb2.billing_month = rb.billing_month
      AND rb2.bill_type = rb.bill_type
      AND rb2.id != rb.id
  )
  -- safe traceability
  AND rb.lease_package_component_id IN (
    SELECT id FROM public.lease_package_components
    WHERE promotion_batch = 'shaxi_promotion_v1'
  )
  -- not held / not expired: candidate_status must NOT be blocked
  AND NOT EXISTS (
    SELECT 1 FROM public.vw_shaxi_rent_bill_candidates_v1_9 c
    WHERE c.component_id = rb.lease_package_component_id
      AND c.candidate_status IN ('billing_hold', 'expired', 'missing_rent')
  )
  -- no billing exceptions referencing this bill
  AND NOT EXISTS (
    SELECT 1 FROM public.vw_shaxi_billing_exceptions be
    WHERE be.bill_id = rb.id
  )
ORDER BY rb.amount_due DESC;


-- ============================================================
-- STEP 1: Preview bills to approve
-- Expected: 7 rows (all except 杨华禾)
-- ============================================================

SELECT
  'PREVIEW: bills to approve' AS check_name,
  bill_id,
  tenant_name,
  area_name,
  amount_due,
  review_recommendation,
  review_status
FROM public.vw_shaxi_bill_approval_queue_v2_1
WHERE review_recommendation = 'review_and_approve'
ORDER BY amount_due DESC;


-- ============================================================
-- STEP 2: Preview bill to leave pending
-- Expected: 1 row (杨华禾)
-- ============================================================

SELECT
  'PREVIEW: bill to leave pending' AS check_name,
  bill_id,
  tenant_name,
  area_name,
  amount_due,
  review_recommendation,
  review_status
FROM public.vw_shaxi_bill_approval_queue_v2_1
WHERE review_recommendation = 'review_before_approve'
ORDER BY amount_due DESC;


-- ============================================================
-- STEP 3: Approve normal bills
-- Only updates rows where review_status = pending_review.
-- ============================================================

UPDATE public.bill_approval_reviews
SET
  review_status = 'approved',
  reviewed_by = 'Matthew/admin',
  reviewed_at = NOW(),
  approval_note = 'Approved in v2.2 normal May 2026 Shaxi rent bill review',
  updated_at = NOW()
WHERE bill_id IN (
  SELECT bill_id FROM public.vw_shaxi_bill_approval_queue_v2_1
  WHERE review_recommendation = 'review_and_approve'
)
  AND review_status = 'pending_review';


-- ============================================================
-- STEP 4: Preview approval state after update
-- ============================================================

SELECT
  'POST_APPROVE: approval status breakdown' AS check_name,
  review_status,
  COUNT(*) AS row_count
FROM public.bill_approval_reviews bar
JOIN public.rent_bills rb ON rb.id = bar.bill_id
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
GROUP BY review_status
ORDER BY review_status;


-- ============================================================
-- STEP 5: Preview issue candidates before running issue script
-- Expected: 7 rows (the newly approved bills)
-- ============================================================

SELECT
  'POST_APPROVE: issue candidates' AS check_name,
  bill_id,
  tenant_name,
  area_name,
  amount_due,
  review_status
FROM public.vw_shaxi_bill_issue_candidates_v2_1
ORDER BY amount_due DESC;


-- ============================================================
-- STEP 6: Show 杨华禾 remains pending
-- Expected: 1 row, review_status = pending_review
-- ============================================================

SELECT
  'POST_APPROVE: 杨华禾 status' AS check_name,
  tenant_name,
  review_status,
  review_recommendation
FROM public.vw_shaxi_bill_approval_queue_v2_1
WHERE tenant_name = '杨华禾';
