-- ============================================================
-- sql/08_export_candidate_review_list_v1_2.sql
-- Export human-readable candidate review list
-- Batch: shaxi_promotion_v1
--
-- Purpose: Produce a read-only review list from
--          vw_shaxi_contract_area_candidates_pending.
--
-- Rules:
--   - Read-only. Does NOT update any data.
--   - Does NOT auto-resolve.
--   - Does NOT create lease_package_components.
--   - suggested_decision is NULL or 'needs_human_review' only.
--   - suggested_approved_area_name is left NULL; human decides.
-- ============================================================

SELECT
  candidate_id,
  tenant_name,
  source_company,
  rented_unit_text,
  mapped_building_name,
  mapped_area_name,
  mapped_confidence,
  monthly_rent,
  contract_start_date,
  contract_end_date,

  -- Classification of the review question
  CASE
    WHEN mapped_area_name LIKE '%1层%' THEN '1层 vs 首层 wording issue'
    WHEN mapped_area_name = mapped_building_name THEN 'whole-building / broad-building candidate'
    WHEN mapped_area_name LIKE '%层%' OR mapped_area_name LIKE '%卡%' THEN 'floor-level area missing from area truth'
    ELSE 'other'
  END AS suggested_review_question,

  -- Decision left for human reviewer
  'needs_human_review' AS suggested_decision,

  -- Approved area name intentionally left blank
  NULL::text AS suggested_approved_area_name,

  -- Reviewer note template with context
  'Candidate #' || candidate_id || ': ' || tenant_name ||
  ' | ' || mapped_building_name || ' / ' || mapped_area_name ||
  ' | Rent ' || monthly_rent || '/month' ||
  ' | Source: ' || COALESCE(source_company, '-') ||
  ' | Dates: ' || contract_start_date || ' to ' || contract_end_date ||
  CASE
    WHEN exact_rentable_area_id IS NOT NULL
    THEN ' | NOTE: Exact rentable area exists (' || exact_rentable_area_name || ')'
    ELSE ' | NOTE: No exact rentable area match found'
  END ||
  ' | Question: ' ||
  CASE
    WHEN mapped_area_name LIKE '%1层%' THEN '1层 vs 首层 wording issue — verify correct floor label before approving.'
    WHEN mapped_area_name = mapped_building_name THEN 'Whole-building scope — confirm if this is a building-level lease or needs split into units.'
    WHEN mapped_area_name LIKE '%层%' OR mapped_area_name LIKE '%卡%' THEN 'Floor-level area missing from area truth — check if area exists under a different name or needs creation.'
    ELSE 'Unclassified — manual review required.'
  END AS reviewer_note_template

FROM public.vw_shaxi_contract_area_candidates_pending
ORDER BY
  CASE
    WHEN mapped_area_name LIKE '%1层%' THEN 1
    WHEN mapped_area_name = mapped_building_name THEN 2
    WHEN mapped_area_name LIKE '%层%' OR mapped_area_name LIKE '%卡%' THEN 3
    ELSE 4
  END,
  mapped_building_code,
  mapped_area_name;
