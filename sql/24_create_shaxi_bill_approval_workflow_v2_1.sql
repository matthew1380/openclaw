-- ============================================================
-- sql/24_create_shaxi_bill_approval_workflow_v2_1.sql
-- Create minimal staff approval workflow for Shaxi draft bills
-- Batch: shaxi_promotion_v1
--
-- Purpose:
--   1. Create bill_approval_reviews table (one active review per bill).
--   2. Seed pending_review records for current May 2026 draft bills only.
--   3. Create read-only approval queue, issue-candidate, and summary views.
--
-- Rules:
--   - No automatic approval. All bills start as pending_review.
--   - Only human-approved bills can become issue candidates.
--   - Held and expired items remain excluded.
--   - All idempotent. Safe to rerun.
-- ============================================================


-- ============================================================
-- PART 1: Create bill_approval_reviews table
-- One review record per bill. Unique on bill_id.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.bill_approval_reviews (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  bill_id uuid NOT NULL REFERENCES public.rent_bills(id) ON DELETE CASCADE,
  review_status text NOT NULL DEFAULT 'pending_review',
  reviewed_by text,
  reviewed_at timestamp without time zone,
  approval_note text,
  created_from text,
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now(),
  CONSTRAINT bill_approval_reviews_status_check CHECK (
    review_status IN ('pending_review', 'approved', 'rejected', 'needs_adjustment')
  )
);

-- Unique index ensures one active review per bill
CREATE UNIQUE INDEX IF NOT EXISTS idx_bill_approval_reviews_bill_id
  ON public.bill_approval_reviews(bill_id);

COMMENT ON TABLE public.bill_approval_reviews IS 'Staff approval workflow for rent_bills. One row per bill. review_status must be pending_review, approved, rejected, or needs_adjustment.';


-- ============================================================
-- PART 2: Seed pending_review records for 8 current draft bills
-- Idempotent: only inserts where no review record exists.
-- Targets: May 2026 rent draft bills only.
-- Does NOT seed held/unbilled items.
-- ============================================================

INSERT INTO public.bill_approval_reviews (
  bill_id,
  review_status,
  created_from,
  created_at,
  updated_at
)
SELECT
  rb.id,
  'pending_review',
  'sql/24_create_shaxi_bill_approval_workflow_v2_1.sql',
  NOW(),
  NOW()
FROM public.rent_bills rb
WHERE rb.bill_status = 'draft'
  AND rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND NOT EXISTS (
    SELECT 1 FROM public.bill_approval_reviews bar
    WHERE bar.bill_id = rb.id
  );


-- ============================================================
-- PART 3A: vw_shaxi_bill_approval_queue_v2_1
-- All draft bills with their current approval status and review recommendation.
-- LEFT JOIN ensures bills appear even if review record is missing.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_bill_approval_queue_v2_1 AS
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
  COALESCE(bar.review_status, 'pending_review') AS review_status,
  bar.reviewed_by,
  bar.reviewed_at,
  bar.approval_note,
  CASE
    WHEN c.end_date IS NOT NULL AND c.end_date <= CURRENT_DATE + INTERVAL '180 days'
    THEN 'review_before_approve'
    ELSE 'review_and_approve'
  END AS review_recommendation,
  rb.lease_contract_id,
  rb.lease_package_component_id,
  c.start_date AS contract_start_date,
  c.end_date AS contract_end_date,
  rb.source_type,
  rb.created_from
FROM public.rent_bills rb
JOIN public.contacts con ON con.id = rb.tenant_id
JOIN public.lease_package_components lpc ON lpc.id = rb.lease_package_component_id
JOIN public.rentable_areas ra ON ra.id = lpc.rentable_area_id
JOIN public.building_registry b ON b.id = ra.building_id
JOIN public.contracts c ON c.id = rb.lease_contract_id
LEFT JOIN public.bill_approval_reviews bar ON bar.bill_id = rb.id
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
ORDER BY rb.amount_due DESC;


-- ============================================================
-- PART 3B: vw_shaxi_bill_issue_candidates_v2_1
-- Bills that are cleared for issuance.
-- Issue candidate rule:
--   - bill_status = draft
--   - review_status = approved
--   - no billing exceptions referencing this bill
--   - no duplicate bill for same component/month/type
--   - safe traceability (component in shaxi_promotion_v1)
--   - not held (candidate_status = generate_ready)
--   - not expired
-- Returns 0 rows safely if no approvals exist yet.
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
  -- not held / not expired: candidate_status must be generate_ready
  AND EXISTS (
    SELECT 1 FROM public.vw_shaxi_rent_bill_candidates_v1_9 c
    WHERE c.component_id = rb.lease_package_component_id
      AND c.candidate_status = 'generate_ready'
  )
  -- no billing exceptions referencing this bill
  AND NOT EXISTS (
    SELECT 1 FROM public.vw_shaxi_billing_exceptions be
    WHERE be.bill_id = rb.id
  )
ORDER BY rb.amount_due DESC;


-- ============================================================
-- PART 3C: vw_shaxi_bill_approval_summary_v2_1
-- Single-row summary of the approval workflow state.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_bill_approval_summary_v2_1 AS
WITH draft_bills AS (
  SELECT COUNT(*) AS total_draft
  FROM public.rent_bills
  WHERE bill_status = 'draft'
    AND billing_month = '2026-05-01'
    AND bill_type = 'rent'
),
approval_counts AS (
  SELECT
    COUNT(*) FILTER (WHERE bar.review_status = 'pending_review') AS pending_count,
    COUNT(*) FILTER (WHERE bar.review_status = 'approved') AS approved_count,
    COUNT(*) FILTER (WHERE bar.review_status = 'rejected') AS rejected_count,
    COUNT(*) FILTER (WHERE bar.review_status = 'needs_adjustment') AS needs_adjustment_count
  FROM public.bill_approval_reviews bar
  JOIN public.rent_bills rb ON rb.id = bar.bill_id
  WHERE rb.billing_month = '2026-05-01'
    AND rb.bill_type = 'rent'
),
issue_ready AS (
  SELECT COUNT(*) AS issue_ready_count
  FROM public.vw_shaxi_bill_issue_candidates_v2_1
),
issued AS (
  SELECT COUNT(*) AS issued_count
  FROM public.rent_bills
  WHERE bill_status != 'draft'
    AND billing_month = '2026-05-01'
    AND bill_type = 'rent'
)
SELECT
  db.total_draft,
  ac.pending_count,
  ac.approved_count,
  ac.rejected_count,
  ac.needs_adjustment_count,
  ir.issue_ready_count,
  iss.issued_count,
  CASE
    WHEN ir.issue_ready_count > 0 THEN 'issue_ready_exists'
    WHEN ac.approved_count = 0 AND db.total_draft > 0 THEN 'awaiting_approvals'
    WHEN db.total_draft = 0 THEN 'no_draft_bills'
    ELSE 'review_in_progress'
  END AS workflow_status
FROM draft_bills db, approval_counts ac, issue_ready ir, issued iss;


-- ============================================================
-- PART 4: Preview results
-- ============================================================

SELECT 'APPROVAL QUEUE' AS section, * FROM public.vw_shaxi_bill_approval_queue_v2_1;

SELECT 'ISSUE CANDIDATES' AS section, * FROM public.vw_shaxi_bill_issue_candidates_v2_1;

SELECT 'APPROVAL SUMMARY' AS section, * FROM public.vw_shaxi_bill_approval_summary_v2_1;
