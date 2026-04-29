-- ============================================================
-- sql/25_issue_approved_shaxi_bills_v2_1.sql
-- Issue approved Shaxi rent bills for May 2026
-- Batch: shaxi_promotion_v1
--
-- Purpose: Move draft bills to 'issued' status ONLY for bills
--          that have been explicitly approved by staff.
--
-- Rules:
--   - Only bills in vw_shaxi_bill_issue_candidates_v2_1 are issued.
--   - If no approvals exist, 0 bills are issued (safe).
--   - Does NOT issue held or expired items.
--   - Does NOT issue 杨华禾 unless explicitly approved.
--   - Idempotent: a bill already issued will not be re-processed
--     because the view filters to bill_status = 'draft'.
--   - Safe to rerun.
-- ============================================================


-- ============================================================
-- STEP 1: Preview issue candidates before issuing
-- Expected: 0 rows initially (no approvals yet)
-- ============================================================

SELECT
  'PREVIEW: issue candidates' AS check_name,
  bill_id,
  tenant_name,
  area_code,
  amount_due,
  due_date,
  review_status,
  reviewed_by
FROM public.vw_shaxi_bill_issue_candidates_v2_1
ORDER BY amount_due DESC;


-- ============================================================
-- STEP 2: Issue approved bills
-- Update rent_bills from 'draft' to 'issued' only for approved candidates.
-- ============================================================

UPDATE public.rent_bills
SET
  bill_status = 'issued',
  updated_at = NOW()
WHERE id IN (
  SELECT bill_id FROM public.vw_shaxi_bill_issue_candidates_v2_1
)
  AND bill_status = 'draft';


-- ============================================================
-- STEP 3: Report how many bills were issued
-- ============================================================

SELECT
  'POST_ISSUE: issued bill count' AS check_name,
  COUNT(*) AS issued_count
FROM public.rent_bills
WHERE bill_status = 'issued'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';


-- ============================================================
-- STEP 4: Show remaining draft bills
-- ============================================================

SELECT
  'POST_ISSUE: remaining draft bills' AS check_name,
  rb.id AS bill_id,
  con.name AS tenant_name,
  rb.amount_due,
  COALESCE(bar.review_status, 'pending_review') AS review_status
FROM public.rent_bills rb
JOIN public.contacts con ON con.id = rb.tenant_id
LEFT JOIN public.bill_approval_reviews bar ON bar.bill_id = rb.id
WHERE rb.bill_status = 'draft'
  AND rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
ORDER BY rb.amount_due DESC;


-- ============================================================
-- STEP 5: Show current approval summary
-- ============================================================

SELECT * FROM public.vw_shaxi_bill_approval_summary_v2_1;
