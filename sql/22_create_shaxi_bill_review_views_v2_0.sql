-- ============================================================
-- sql/22_create_shaxi_bill_review_views_v2_0.sql
-- Create read-only bill review and approval layer for Shaxi
-- Batch: shaxi_promotion_v1
--
-- Purpose: Provide staff-facing review views for draft bills
--          and held components before any bills are issued.
--
-- Views created:
--   A. vw_shaxi_bill_review_queue_v2_0        — 8 draft bills
--   B. vw_shaxi_billing_hold_review_v2_0      — 2 true holds
--   C. vw_shaxi_bill_issue_readiness_v2_0     — readiness summary
--
-- Rules:
--   - All views are read-only.
--   - CREATE OR REPLACE VIEW for idempotency.
--   - Does NOT issue bills.
--   - Does NOT record payments.
--   - Does NOT modify data.
-- ============================================================


-- ============================================================
-- VIEW A: vw_shaxi_bill_review_queue_v2_0
-- Draft bills requiring human review.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_bill_review_queue_v2_0 AS
SELECT
  rb.id AS bill_id,
  con.name AS tenant_name,
  ra.area_code,
  ra.area_name,
  b.building_name,
  ra.section_group_name,
  rb.billing_month,
  rb.bill_type,
  rb.amount_due,
  rb.due_date,
  rb.bill_status,
  rb.source_type,
  rb.created_from,
  rb.lease_contract_id,
  rb.lease_package_component_id,
  c.start_date AS contract_start_date,
  c.end_date AS contract_end_date,
  CASE
    WHEN c.end_date IS NOT NULL AND c.end_date <= CURRENT_DATE + INTERVAL '180 days'
    THEN 'review_before_approve'
    ELSE 'review_and_approve'
  END AS review_recommendation
FROM public.rent_bills rb
JOIN public.contacts con ON con.id = rb.tenant_id
JOIN public.lease_package_components lpc ON lpc.id = rb.lease_package_component_id
JOIN public.rentable_areas ra ON ra.id = lpc.rentable_area_id
JOIN public.building_registry b ON b.id = ra.building_id
JOIN public.contracts c ON c.id = rb.lease_contract_id
WHERE rb.bill_status = 'draft'
  AND rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
ORDER BY rb.amount_due DESC;


-- ============================================================
-- VIEW B: vw_shaxi_billing_hold_review_v2_0
-- Non-billed safe components and why they are held.
-- Filters to true holds only (billing_hold, expired, missing_rent).
-- Excludes duplicate_existing because those bills were already generated.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_billing_hold_review_v2_0 AS
SELECT
  c.tenant_name,
  c.area_code,
  c.area_name,
  c.candidate_status,
  c.candidate_note AS hold_reason,
  c.start_date AS contract_start_date,
  c.end_date AS contract_end_date,
  c.monthly_rent,
  CASE c.candidate_status
    WHEN 'billing_hold' THEN 'resolve_master_sublease_billing_rule'
    WHEN 'expired' THEN 'confirm_renewal_or_vacancy'
    WHEN 'missing_rent' THEN 'fix_rent_amount_then_regenerate'
    ELSE 'review_and_decide'
  END AS recommended_action
FROM public.vw_shaxi_rent_bill_candidates_v1_9 c
WHERE c.candidate_status IN ('billing_hold', 'expired', 'missing_rent')
ORDER BY c.candidate_status, c.tenant_name;


-- ============================================================
-- VIEW C: vw_shaxi_bill_issue_readiness_v2_0
-- Summarize whether bills are ready for human review.
-- Does NOT mark as ready_to_issue — only ready_for_human_review.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_bill_issue_readiness_v2_0 AS
WITH draft_counts AS (
  SELECT COUNT(*) AS draft_bill_count
  FROM public.rent_bills
  WHERE bill_status = 'draft' AND billing_month = '2026-05-01' AND bill_type = 'rent'
),
hold_counts AS (
  SELECT COUNT(*) AS hold_count
  FROM public.vw_shaxi_rent_bill_candidates_v1_9
  WHERE candidate_status IN ('billing_hold', 'expired', 'missing_rent')
),
exception_counts AS (
  SELECT COUNT(*) AS exception_count
  FROM public.vw_shaxi_billing_exceptions
),
dup_counts AS (
  SELECT COUNT(*) AS duplicate_bill_count
  FROM (
    SELECT lease_package_component_id, billing_month, bill_type
    FROM public.rent_bills
    GROUP BY lease_package_component_id, billing_month, bill_type
    HAVING COUNT(*) > 1
  ) dups
),
non_draft_counts AS (
  SELECT COUNT(*) AS non_draft_bill_count
  FROM public.rent_bills
  WHERE bill_status != 'draft' AND billing_month = '2026-05-01' AND bill_type = 'rent'
)
SELECT
  dc.draft_bill_count,
  hc.hold_count,
  ec.exception_count,
  dupc.duplicate_bill_count,
  ndc.non_draft_bill_count,
  CASE
    WHEN ec.exception_count = 0
      AND dupc.duplicate_bill_count = 0
      AND ndc.non_draft_bill_count = 0
      AND dc.draft_bill_count > 0
    THEN 'ready_for_human_review'
    ELSE 'not_ready'
  END AS readiness_status
FROM draft_counts dc, hold_counts hc, exception_counts ec, dup_counts dupc, non_draft_counts ndc;
