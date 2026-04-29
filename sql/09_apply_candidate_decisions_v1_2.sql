-- ============================================================
-- sql/09_apply_candidate_decisions_v1_2.sql
-- Apply human review decisions to promotion_contract_area_candidates
-- Batch: shaxi_promotion_v1
--
-- Purpose: Record manual review decisions for candidates that
--          have been classified by staff. Does NOT create areas
--          or lease_package_components.
--
-- Rules:
--   - Only updates candidates with explicit human decisions.
--   - Does NOT auto-resolve.
--   - Does NOT create rentable_areas.
--   - Does NOT create lease_package_components.
-- ============================================================

-- ============================================================
-- STEP 1: Preview decisions to be applied
-- ============================================================

SELECT
  id AS candidate_id,
  tenant_name,
  mapped_area_name AS current_area_name,
  CASE id
    WHEN 2 THEN 'keep'
    WHEN 5 THEN 'change 第三卡to3卡'
    WHEN 1 THEN 'yes, whole building'
    WHEN 9 THEN 'yes, whole building'
    WHEN 6 THEN 'should be whole floor'
    WHEN 7 THEN 'should be whole floor'
    ELSE 'no explicit decision — will NOT be updated'
  END AS human_decision,
  CASE id
    WHEN 2 THEN '三区A栋1层1卡'
    WHEN 5 THEN '三区A栋1层3卡'
    WHEN 1 THEN '四区C栋'
    WHEN 9 THEN '三区C栋'
    WHEN 6 THEN '三区A栋2层'
    WHEN 7 THEN '三区A栋3层'
    ELSE NULL
  END AS proposed_approved_area_name,
  CASE id
    WHEN 2 THEN 'approve_new_area'
    WHEN 5 THEN 'approve_new_area'
    WHEN 1 THEN 'approve_new_area'
    WHEN 9 THEN 'approve_new_area'
    WHEN 6 THEN 'approve_new_area'
    WHEN 7 THEN 'approve_new_area'
    ELSE NULL
  END AS proposed_review_decision
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review'
ORDER BY id;


-- ============================================================
-- STEP 2: Apply human review decisions
-- Only candidates 1, 2, 5, 6, 7, 9 have explicit decisions.
-- Candidates 3, 4, 8 remain unchanged (still pending).
-- ============================================================

UPDATE public.promotion_contract_area_candidates
SET
  review_decision = 'approve_new_area',
  approved_area_name = CASE id
    WHEN 2 THEN '三区A栋1层1卡'
    WHEN 5 THEN '三区A栋1层3卡'
    WHEN 1 THEN '四区C栋'
    WHEN 9 THEN '三区C栋'
    WHEN 6 THEN '三区A栋2层'
    WHEN 7 THEN '三区A栋3层'
  END,
  approved_leaseable_scope = CASE id
    WHEN 1 THEN '整栋'
    WHEN 9 THEN '整栋'
    WHEN 6 THEN '整层'
    WHEN 7 THEN '整层'
    ELSE NULL
  END,
  reviewed_by = 'human_review_2026-04-26',
  reviewed_at = NOW(),
  resolution_notes = CASE id
    WHEN 2 THEN 'Staff decision: keep as 三区A栋1层1卡'
    WHEN 5 THEN 'Staff decision: normalize 第三卡 to 3卡 → 三区A栋1层3卡'
    WHEN 1 THEN 'Staff decision: yes, whole building lease for 四区C栋'
    WHEN 9 THEN 'Staff decision: yes, whole building lease for 三区C栋'
    WHEN 6 THEN 'Staff decision: should be whole floor (整层) for 三区A栋2层'
    WHEN 7 THEN 'Staff decision: should be whole floor (整层) for 三区A栋3层'
  END
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review'
  AND id IN (1, 2, 5, 6, 7, 9);


-- ============================================================
-- STEP 3: Post-update verification
-- ============================================================

-- 3.1 Updated candidates
-- Expected: 6
SELECT
  'POST_UPDATE: candidates with decisions' AS check_name,
  COUNT(*) AS decided_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review'
  AND review_decision IS NOT NULL;


-- 3.2 Still-pending candidates (no explicit decision yet)
-- Expected: 3
SELECT
  'POST_UPDATE: candidates still pending' AS check_name,
  COUNT(*) AS pending_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review'
  AND review_decision IS NULL;


-- 3.3 Summary of all 9 candidates
SELECT
  id,
  tenant_name,
  mapped_area_name,
  review_decision,
  approved_area_name,
  approved_leaseable_scope,
  reviewed_by
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review'
ORDER BY id;
