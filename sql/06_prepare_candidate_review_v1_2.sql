-- ============================================================
-- sql/06_prepare_candidate_review_v1_2.sql
-- Shaxi candidate review flow preparation
-- Batch: shaxi_promotion_v1
--
-- Purpose:
--   1. Add review-resolution columns to promotion_contract_area_candidates.
--   2. Add check constraint on review_decision (allows NULL for pending rows).
--   3. Create read-only review view for staff review queue.
--
-- Rules:
--   - Do NOT build staff UI.
--   - Do NOT auto-resolve candidates.
--   - Do NOT guess 1层 vs 首层 or whole-building cases.
--   - Do NOT create lease_package_components.
-- ============================================================


-- ============================================================
-- STEP 1: Add review columns if missing
-- ============================================================

ALTER TABLE public.promotion_contract_area_candidates
  ADD COLUMN IF NOT EXISTS review_decision text,
  ADD COLUMN IF NOT EXISTS approved_area_name text,
  ADD COLUMN IF NOT EXISTS approved_area_type text,
  ADD COLUMN IF NOT EXISTS approved_floor_label text,
  ADD COLUMN IF NOT EXISTS approved_card_or_room_label text,
  ADD COLUMN IF NOT EXISTS approved_area_sqm numeric,
  ADD COLUMN IF NOT EXISTS approved_leaseable_scope text,
  ADD COLUMN IF NOT EXISTS approved_current_status text,
  ADD COLUMN IF NOT EXISTS target_rentable_area_id uuid,
  ADD COLUMN IF NOT EXISTS reviewed_by text,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS resolved_at timestamptz,
  ADD COLUMN IF NOT EXISTS resolution_notes text;


-- ============================================================
-- STEP 2: Add check constraint on review_decision
-- Allows NULL (existing pending rows) but restricts values once set.
-- ============================================================

ALTER TABLE public.promotion_contract_area_candidates
  ADD CONSTRAINT chk_review_decision_values
  CHECK (review_decision IS NULL OR review_decision IN (
    'approve_new_area',
    'map_existing_area',
    'reject_or_defer'
  ));


-- ============================================================
-- STEP 3: Create read-only review view
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_contract_area_candidates_pending AS
SELECT
  c.id AS candidate_id,
  c.source_company,
  c.tenant_name,
  c.rented_unit_text,
  c.monthly_rent,
  c.contract_start_date,
  c.contract_end_date,
  c.mapped_property_code,
  c.mapped_parcel_code,
  c.mapped_building_code,
  c.mapped_building_name,
  c.mapped_area_name,
  c.mapped_confidence,
  c.review_status,
  c.review_decision,
  c.approved_area_name,
  c.target_rentable_area_id,
  ra.id AS exact_rentable_area_id,
  ra.area_name AS exact_rentable_area_name,
  c.created_at
FROM public.promotion_contract_area_candidates c
LEFT JOIN public.building_registry b
  ON b.building_code = c.mapped_building_code
LEFT JOIN public.rentable_areas ra
  ON ra.building_id = b.id
  AND ra.area_name = c.mapped_area_name
WHERE c.promotion_batch = 'shaxi_promotion_v1'
  AND c.review_status = 'pending_review';


-- ============================================================
-- STEP 4: Post-setup verification
-- ============================================================

-- 4.1 Pending candidates count
-- Expected: 9
SELECT
  'SETUP: pending candidates count' AS check_name,
  COUNT(*) AS pending_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review';


-- 4.2 New review columns exist
-- Expected: 14
SELECT
  'SETUP: new review columns count' AS check_name,
  COUNT(*) AS new_column_count
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'promotion_contract_area_candidates'
  AND column_name IN (
    'review_decision',
    'approved_area_name',
    'approved_area_type',
    'approved_floor_label',
    'approved_card_or_room_label',
    'approved_area_sqm',
    'approved_leaseable_scope',
    'approved_current_status',
    'target_rentable_area_id',
    'reviewed_by',
    'reviewed_at',
    'resolved_at',
    'resolution_notes'
  );


-- 4.3 View row count
-- Expected: 9
SELECT
  'SETUP: view row count' AS check_name,
  COUNT(*) AS view_row_count
FROM public.vw_shaxi_contract_area_candidates_pending;
