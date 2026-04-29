-- ============================================================
-- sql/32_create_shaxi_exception_resolution_workflow_v2_5.sql
-- Business exception resolution workflow for Shaxi
-- Batch: shaxi_promotion_v1
--
-- Purpose:
--   1. Create shaxi_business_exception_reviews table.
--   2. Seed 3 current review records idempotently.
--   3. Create read-only queue and summary views.
--
-- Rules:
--   - No automatic resolution. All exceptions start as pending_decision.
--   - Held and expired items remain unbilled until explicit decision.
--   - 杨华禾 draft bill remains pending until rent amount is confirmed.
--   - All idempotent. Safe to rerun.
-- ============================================================


-- ============================================================
-- PART 1: Create shaxi_business_exception_reviews table
-- ============================================================

CREATE TABLE IF NOT EXISTS public.shaxi_business_exception_reviews (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  exception_type text NOT NULL,
  tenant_name text NOT NULL,
  area_code text,
  area_name text,
  related_contract_id uuid REFERENCES public.contracts(id) ON DELETE SET NULL,
  related_bill_id uuid REFERENCES public.rent_bills(id) ON DELETE SET NULL,
  current_status text NOT NULL,
  decision_status text NOT NULL DEFAULT 'pending_decision',
  decision_by text,
  decision_at timestamp without time zone,
  decision_note text,
  created_from text,
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now(),
  CONSTRAINT shaxi_business_exception_reviews_decision_status_check CHECK (
    decision_status IN (
      'pending_decision',
      'approved_to_bill',
      'approved_to_issue',
      'keep_on_hold',
      'mark_vacant',
      'renewed_contract_needed',
      'needs_adjustment',
      'resolved'
    )
  )
);

COMMENT ON TABLE public.shaxi_business_exception_reviews IS 'Staff review/decision workflow for Shaxi business exceptions (billing holds, expired contracts, pending draft bills). One row per exception. decision_status must be pending_decision, approved_to_bill, approved_to_issue, keep_on_hold, mark_vacant, renewed_contract_needed, needs_adjustment, or resolved.';

CREATE INDEX IF NOT EXISTS idx_shaxi_exception_reviews_decision_status
  ON public.shaxi_business_exception_reviews(decision_status);

CREATE INDEX IF NOT EXISTS idx_shaxi_exception_reviews_tenant_name
  ON public.shaxi_business_exception_reviews(tenant_name);


-- ============================================================
-- PART 2: Seed 3 current review records idempotently
-- Only inserts where no record exists for the same tenant_name + exception_type.
-- ============================================================

INSERT INTO public.shaxi_business_exception_reviews (
  exception_type,
  tenant_name,
  area_code,
  area_name,
  related_contract_id,
  related_bill_id,
  current_status,
  decision_status,
  created_from,
  created_at,
  updated_at
)
SELECT * FROM (VALUES
  (
    'billing_hold',
    '中山市川田制衣厂',
    'RA-SX39-Q4-B-GF',
    '四区B栋首层',
    '7feb1ce5-28f2-4cb3-949e-3a91ff89edcb'::uuid,
    NULL::uuid,
    'billing_hold',
    'pending_decision',
    'sql/32_create_shaxi_exception_resolution_workflow_v2_5.sql',
    NOW(),
    NOW()
  ),
  (
    'expired_contract',
    '朱河芳',
    'RA-SX39-Q3-A-首层2卡',
    '三区A栋首层2卡',
    '9e5a40aa-8fb3-45f1-a1be-37afadfcc1e5'::uuid,
    NULL::uuid,
    'expired',
    'pending_decision',
    'sql/32_create_shaxi_exception_resolution_workflow_v2_5.sql',
    NOW(),
    NOW()
  ),
  (
    'pending_draft_bill',
    '杨华禾',
    'RA-SX39-Q3-A-首层1卡',
    '三区A栋首层1卡',
    '8c992253-44e7-4dbc-8c86-e3b81a0ccdda'::uuid,
    '4adcf5d2-9b93-497b-b422-327a473e342a'::uuid,
    'draft_pending_review',
    'pending_decision',
    'sql/32_create_shaxi_exception_resolution_workflow_v2_5.sql',
    NOW(),
    NOW()
  )
) AS v(
  exception_type,
  tenant_name,
  area_code,
  area_name,
  related_contract_id,
  related_bill_id,
  current_status,
  decision_status,
  created_from,
  created_at,
  updated_at
)
WHERE NOT EXISTS (
  SELECT 1 FROM public.shaxi_business_exception_reviews e
  WHERE e.tenant_name = v.tenant_name
    AND e.exception_type = v.exception_type
);


-- ============================================================
-- PART 3A: vw_shaxi_business_exception_queue_v2_5
-- Detailed queue of all active business exception reviews.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_business_exception_queue_v2_5 AS
SELECT
  e.id AS exception_review_id,
  e.exception_type,
  e.tenant_name,
  e.area_code,
  e.area_name,
  e.related_contract_id,
  c.contract_code AS related_contract_code,
  c.end_date AS contract_end_date,
  e.related_bill_id,
  rb.amount_due AS related_bill_amount,
  rb.bill_status AS related_bill_status,
  e.current_status,
  e.decision_status,
  e.decision_by,
  e.decision_at,
  e.decision_note,
  e.created_from,
  e.created_at,
  e.updated_at,
  CASE e.exception_type
    WHEN 'billing_hold' THEN 'Decide master/sublease billing rule for 四区B栋首层 (靖大物业 + 川田)'
    WHEN 'expired_contract' THEN 'Confirm renewal or mark vacant for 三区A栋首层2卡'
    WHEN 'pending_draft_bill' THEN 'Confirm rent amount before approving 杨华禾 May 2026 bill'
    ELSE 'Review and decide'
  END AS recommended_action
FROM public.shaxi_business_exception_reviews e
LEFT JOIN public.contracts c ON c.id = e.related_contract_id
LEFT JOIN public.rent_bills rb ON rb.id = e.related_bill_id
ORDER BY
  CASE e.decision_status
    WHEN 'pending_decision' THEN 1
    WHEN 'needs_adjustment' THEN 2
    WHEN 'approved_to_bill' THEN 3
    WHEN 'approved_to_issue' THEN 4
    WHEN 'keep_on_hold' THEN 5
    WHEN 'mark_vacant' THEN 6
    WHEN 'renewed_contract_needed' THEN 7
    WHEN 'resolved' THEN 8
    ELSE 9
  END,
  e.created_at;


-- ============================================================
-- PART 3B: vw_shaxi_business_exception_summary_v2_5
-- Single-row summary of exception resolution workflow state.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_business_exception_summary_v2_5 AS
WITH exception_counts AS (
  SELECT
    COUNT(*) FILTER (WHERE decision_status = 'pending_decision') AS pending_decision_count,
    COUNT(*) FILTER (WHERE decision_status = 'approved_to_bill') AS approved_to_bill_count,
    COUNT(*) FILTER (WHERE decision_status = 'approved_to_issue') AS approved_to_issue_count,
    COUNT(*) FILTER (WHERE decision_status = 'keep_on_hold') AS keep_on_hold_count,
    COUNT(*) FILTER (WHERE decision_status = 'mark_vacant') AS mark_vacant_count,
    COUNT(*) FILTER (WHERE decision_status = 'renewed_contract_needed') AS renewed_contract_needed_count,
    COUNT(*) FILTER (WHERE decision_status = 'needs_adjustment') AS needs_adjustment_count,
    COUNT(*) FILTER (WHERE decision_status = 'resolved') AS resolved_count,
    COUNT(*) AS total_exception_count
  FROM public.shaxi_business_exception_reviews
),
unbilled_holds AS (
  SELECT COUNT(*) AS unbilled_hold_count
  FROM public.shaxi_business_exception_reviews
  WHERE exception_type IN ('billing_hold', 'expired_contract')
    AND decision_status != 'approved_to_bill'
),
draft_pending AS (
  SELECT COUNT(*) AS draft_pending_count
  FROM public.shaxi_business_exception_reviews
  WHERE exception_type = 'pending_draft_bill'
    AND decision_status != 'approved_to_issue'
)
SELECT
  ec.pending_decision_count,
  ec.approved_to_bill_count,
  ec.approved_to_issue_count,
  ec.keep_on_hold_count,
  ec.mark_vacant_count,
  ec.renewed_contract_needed_count,
  ec.needs_adjustment_count,
  ec.resolved_count,
  ec.total_exception_count,
  uh.unbilled_hold_count,
  dp.draft_pending_count,
  CASE
    WHEN ec.pending_decision_count > 0 THEN 'exceptions_pending_decision'
    WHEN ec.needs_adjustment_count > 0 THEN 'exceptions_need_adjustment'
    WHEN ec.total_exception_count = ec.resolved_count THEN 'all_exceptions_resolved'
    ELSE 'review_in_progress'
  END AS workflow_status
FROM exception_counts ec, unbilled_holds uh, draft_pending dp;


-- ============================================================
-- PART 4: Preview results
-- ============================================================

SELECT 'BUSINESS EXCEPTION QUEUE' AS section, * FROM public.vw_shaxi_business_exception_queue_v2_5;

SELECT 'BUSINESS EXCEPTION SUMMARY' AS section, * FROM public.vw_shaxi_business_exception_summary_v2_5;
