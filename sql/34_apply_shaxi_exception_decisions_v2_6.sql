-- ============================================================
-- sql/34_apply_shaxi_exception_decisions_v2_6.sql
-- Apply confirmed Shaxi business exception decisions (v2.6)
-- Batch: shaxi_promotion_v1
--
-- Purpose: Apply the human decisions already captured for the 3
--          active business exception reviews from v2.5.
--
-- Decisions:
--   1. 中山市川田制衣厂 (billing_hold, 四区B栋首层)
--      decision_status: pending_decision -> keep_on_hold
--      Reason: 川田 pays rent to 靖大物业, and 靖大物业 pays 中铭.
--      Do NOT issue direct rent bill from 中铭 to 川田 unless policy changes.
--      Future billing should be handled at 靖大物业 / master-lease level
--      ONLY IF master lease rent amount and billing rule are confirmed.
--      No new rent_bill is created for 川田. No new master-lease bill is
--      created for 靖大物业 in this version.
--
--   2. 杨华禾 (pending_draft_bill, 三区A栋首层1卡)
--      decision_status: pending_decision -> approved_to_issue
--      Approve and issue the existing May 2026 draft rent bill (¥2,500.00,
--      bill id 4adcf5d2-9b93-497b-b422-327a473e342a):
--        - bill_approval_reviews.review_status: pending_review -> approved
--        - rent_bills.bill_status: draft -> issued
--
--   3. 朱河芳 (expired_contract, 三区A栋首层2卡)
--      decision_status: stays pending_decision (NO CHANGE).
--      Renewal is pending with 阮绮杨 follow-up. Do NOT issue any bill,
--      do NOT update the exception record, do NOT create or modify any
--      rent_bills row for this tenant.
--
-- Rules:
--   - All UPDATEs are state-guarded in WHERE clauses, so the script is
--     idempotent and safe to rerun.
--   - No INSERTs into rent_bills, payments, or payment_allocations.
--   - No fake payments. payments and payment_allocations remain at 0.
--   - No expansion to SX-BCY.
--   - No new master-lease (靖大物业) bill until master rent and rule
--     are confirmed by the business.
-- ============================================================


-- ============================================================
-- STEP 1: Preview current exception state (pre-v2.6)
-- Expected: 3 rows, all decision_status = pending_decision
-- ============================================================

SELECT
  'PRE_v2.6: exception state' AS check_name,
  tenant_name,
  exception_type,
  decision_status,
  decision_by,
  decision_at
FROM public.shaxi_business_exception_reviews
ORDER BY tenant_name;


-- ============================================================
-- STEP 2: Record 川田 decision -> keep_on_hold
-- Idempotent: only updates if currently pending_decision.
-- ============================================================

UPDATE public.shaxi_business_exception_reviews
SET
  decision_status = 'keep_on_hold',
  decision_by = 'Matthew/admin',
  decision_at = NOW(),
  decision_note = '川田 pays rent to 靖大物业; 靖大物业 pays 中铭. Do not issue direct rent bill from 中铭 to 川田 unless policy changes. Future billing should be handled at 靖大物业/master-lease level if confirmed.',
  updated_at = NOW()
WHERE tenant_name = '中山市川田制衣厂'
  AND exception_type = 'billing_hold'
  AND decision_status = 'pending_decision';


-- ============================================================
-- STEP 3: Record 杨华禾 exception decision -> approved_to_issue
-- Idempotent: only updates if currently pending_decision.
-- ============================================================

UPDATE public.shaxi_business_exception_reviews
SET
  decision_status = 'approved_to_issue',
  decision_by = 'Matthew/admin',
  decision_at = NOW(),
  decision_note = 'May 2026 rent amount confirmed at ¥2,500.00. Approve existing draft bill and issue.',
  updated_at = NOW()
WHERE tenant_name = '杨华禾'
  AND exception_type = 'pending_draft_bill'
  AND decision_status = 'pending_decision';


-- ============================================================
-- STEP 4: Approve 杨华禾 bill in bill_approval_reviews
-- Bill id: 4adcf5d2-9b93-497b-b422-327a473e342a
-- Idempotent: only updates if currently pending_review.
-- ============================================================

UPDATE public.bill_approval_reviews
SET
  review_status = 'approved',
  reviewed_by = 'Matthew/admin',
  reviewed_at = NOW(),
  approval_note = 'Approved in v2.6 after confirming May 2026 rent amount (¥2,500.00).',
  updated_at = NOW()
WHERE bill_id = '4adcf5d2-9b93-497b-b422-327a473e342a'
  AND review_status = 'pending_review';


-- ============================================================
-- STEP 5: Issue 杨华禾 bill (draft -> issued)
-- Idempotent: only updates if currently draft AND approved.
-- The EXISTS gate ensures we never issue an unapproved bill, even if
-- this script is rerun in a partially-applied state.
-- ============================================================

UPDATE public.rent_bills
SET
  bill_status = 'issued',
  updated_at = NOW()
WHERE id = '4adcf5d2-9b93-497b-b422-327a473e342a'
  AND bill_status = 'draft'
  AND EXISTS (
    SELECT 1 FROM public.bill_approval_reviews bar
    WHERE bar.bill_id = '4adcf5d2-9b93-497b-b422-327a473e342a'
      AND bar.review_status = 'approved'
  );


-- ============================================================
-- STEP 6: 朱河芳 — NO CHANGES
-- Renewal pending with 阮绮杨 follow-up. Exception stays pending_decision.
-- This step intentionally performs no UPDATE/INSERT.
-- ============================================================


-- ============================================================
-- STEP 7: Preview post-v2.6 state
-- Expected:
--   - 川田: keep_on_hold (decision_by = Matthew/admin)
--   - 杨华禾: approved_to_issue (decision_by = Matthew/admin)
--   - 朱河芳: pending_decision (decision_by NULL)
-- ============================================================

SELECT
  'POST_v2.6: exception decisions' AS check_name,
  tenant_name,
  exception_type,
  decision_status,
  decision_by,
  decision_at,
  LEFT(decision_note, 80) AS decision_note_preview
FROM public.shaxi_business_exception_reviews
ORDER BY tenant_name;


-- ============================================================
-- STEP 8: Preview 杨华禾 bill state (issued + approved)
-- Expected: 1 row, bill_status = issued, review_status = approved
-- ============================================================

SELECT
  'POST_v2.6: 杨华禾 bill status' AS check_name,
  rb.id AS bill_id,
  rb.bill_status,
  rb.amount_due,
  bar.review_status,
  bar.reviewed_by,
  bar.reviewed_at
FROM public.rent_bills rb
LEFT JOIN public.bill_approval_reviews bar ON bar.bill_id = rb.id
WHERE rb.id = '4adcf5d2-9b93-497b-b422-327a473e342a';


-- ============================================================
-- STEP 9: Preview no-bill confirmation for 川田 and 朱河芳
-- Expected: 0 rows for each component_id
-- ============================================================

SELECT
  'POST_v2.6: 川田 still unbilled' AS check_name,
  COUNT(*) AS bill_count
FROM public.rent_bills
WHERE lease_package_component_id = '1a17c28c-3df6-41d3-b305-3ba50cc62806';

SELECT
  'POST_v2.6: 朱河芳 still unbilled' AS check_name,
  COUNT(*) AS bill_count
FROM public.rent_bills
WHERE lease_package_component_id = 'c47ac0c3-b963-4222-a4d3-ab07d05b8eac';


-- ============================================================
-- STEP 10: Preview no fake payments inserted
-- Expected: 0 / 0
-- ============================================================

SELECT
  'POST_v2.6: payments count' AS check_name,
  COUNT(*) AS row_count
FROM public.payments;

SELECT
  'POST_v2.6: payment_allocations count' AS check_name,
  COUNT(*) AS row_count
FROM public.payment_allocations;
