-- ============================================================
-- sql/07_verify_candidate_review_v1_2.sql
-- Verify candidate review flow v1.2 setup
-- Batch: shaxi_promotion_v1
--
-- Purpose: Read-only verification after running
--          sql/06_prepare_candidate_review_v1_2.sql.
-- ============================================================


-- ============================================================
-- 1. PENDING CANDIDATES COUNT
-- Expected: 9
-- ============================================================

SELECT
  'CANDIDATES: pending count' AS check_name,
  COUNT(*) AS pending_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review';


-- ============================================================
-- 2. NEW REVIEW COLUMNS EXIST
-- Expected: 13 (all listed columns found)
-- ============================================================

SELECT
  'SCHEMA: new review columns count' AS check_name,
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


-- ============================================================
-- 3. CHECK CONSTRAINT EXISTS
-- Expected: 1
-- ============================================================

SELECT
  'SCHEMA: check constraint exists' AS check_name,
  COUNT(*) AS constraint_count
FROM information_schema.table_constraints
WHERE table_schema = 'public'
  AND table_name = 'promotion_contract_area_candidates'
  AND constraint_name = 'chk_review_decision_values'
  AND constraint_type = 'CHECK';


-- ============================================================
-- 4. VIEW RETURNS EXPECTED ROWS
-- Expected: 9
-- ============================================================

SELECT
  'VIEW: pending candidates row count' AS check_name,
  COUNT(*) AS view_row_count
FROM public.vw_shaxi_contract_area_candidates_pending;


-- ============================================================
-- 5. VIEW COLUMN COVERAGE
-- Verify the view exposes the key candidate + review fields.
-- Expected: 20 columns (candidate fields + exact match fields + review fields)
-- ============================================================

SELECT
  'VIEW: column count' AS check_name,
  COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'vw_shaxi_contract_area_candidates_pending';


-- ============================================================
-- 6. NO LEASE_PACKAGE_COMPONENTS CREATED
-- Expected: 0 new components for this batch.
-- We verify by checking no rentable_areas with batch notes
-- (from area promotion) have unexpected components.
-- ============================================================

SELECT
  'COMPONENTS: accidental new components' AS check_name,
  COUNT(lpc.id) AS component_count
FROM public.lease_package_components lpc
JOIN public.rentable_areas ra ON ra.id = lpc.rentable_area_id
WHERE ra.notes LIKE '%batch: shaxi_promotion_v1%';


-- ============================================================
-- 7. NO AUTO-RESOLUTION OCCURRED
-- Verify no candidate has been auto-resolved (resolved_at or
-- target_rentable_area_id should be null for all pending rows).
-- Expected: 0
-- ============================================================

SELECT
  'CANDIDATES: auto-resolved count' AS check_name,
  COUNT(*) AS auto_resolved_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review'
  AND (resolved_at IS NOT NULL OR target_rentable_area_id IS NOT NULL);
