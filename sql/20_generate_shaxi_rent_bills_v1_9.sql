-- ============================================================
-- sql/20_generate_shaxi_rent_bills_v1_9.sql
-- Controlled rent bill generation for Shaxi
-- Batch: shaxi_promotion_v1
--
-- Purpose: Generate draft rent bills only for safe, eligible
--          lease_package_components based on an explicit rule.
--
-- Steps:
--   1. Create/refresh candidate view.
--   2. Preview generate_ready candidates.
--   3. Insert draft rent_bills for generate_ready candidates only.
--   4. Update billing rule to 'generated'.
--   5. Create summary and holds views.
--   6. Preview results.
--
-- Rules:
--   - Draft bills only (bill_status = 'draft').
--   - No bills for pending/unsafe candidates.
--   - No bills for expired contracts.
--   - No bills for missing rent.
--   - No bills for multiple_active areas (master/sublease hold).
--   - Idempotent insert via WHERE NOT EXISTS.
--   - Safe to rerun.
-- ============================================================


-- ============================================================
-- STEP 1: Create/refresh candidate view
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_rent_bill_candidates_v1_9 AS
WITH safe_components AS (
  SELECT
    lpc.id AS component_id,
    lpc.package_unit_id,
    lpc.rentable_area_id,
    ra.area_code,
    ra.area_name,
    c.id AS contract_id,
    c.tenant_id,
    con.name AS tenant_name,
    c.contract_code,
    c.monthly_rent,
    c.start_date,
    c.end_date,
    c.contract_status::text AS contract_status,
    CASE
      WHEN lpc.source_candidate_id IS NULL THEN 'exact_original_match'
      ELSE 'approved_candidate'
    END AS source_type
  FROM public.lease_package_components lpc
  JOIN public.rentable_areas ra ON ra.id = lpc.rentable_area_id
  JOIN public.units u ON u.id = lpc.package_unit_id
  JOIN public.contracts c ON c.unit_id = u.id
  JOIN public.contacts con ON con.id = c.tenant_id
  WHERE lpc.promotion_batch = 'shaxi_promotion_v1'
),
area_active_contracts AS (
  SELECT
    ra.id AS rentable_area_id,
    COUNT(DISTINCT c.id) FILTER (WHERE c.contract_status::text = 'active') AS active_contract_count
  FROM public.rentable_areas ra
  LEFT JOIN public.lease_package_components lpc ON lpc.rentable_area_id = ra.id
  LEFT JOIN public.units u ON u.id = lpc.package_unit_id
  LEFT JOIN public.contracts c ON c.unit_id = u.id
  WHERE ra.property_id = (SELECT id FROM public.properties WHERE property_code = 'SX-39')
  GROUP BY ra.id
)
SELECT
  sc.component_id,
  sc.package_unit_id,
  sc.rentable_area_id,
  sc.area_code,
  sc.area_name,
  sc.contract_id,
  sc.tenant_id,
  sc.tenant_name,
  sc.contract_code,
  sc.monthly_rent,
  sc.start_date,
  sc.end_date,
  sc.contract_status,
  sc.source_type,
  COALESCE(aac.active_contract_count, 0) AS area_active_contract_count,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM public.rent_bills rb
      WHERE rb.lease_package_component_id = sc.component_id
        AND rb.billing_month = '2026-05-01'
        AND rb.bill_type = 'rent'
    ) THEN 'duplicate_existing'
    WHEN sc.contract_status != 'active'
      OR sc.start_date > '2026-05-01'
      OR (sc.end_date IS NOT NULL AND sc.end_date < '2026-05-01')
    THEN 'expired'
    WHEN sc.monthly_rent IS NULL OR sc.monthly_rent < 0
    THEN 'missing_rent'
    WHEN COALESCE(aac.active_contract_count, 0) > 1
    THEN 'billing_hold'
    ELSE 'generate_ready'
  END AS candidate_status,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM public.rent_bills rb
      WHERE rb.lease_package_component_id = sc.component_id
        AND rb.billing_month = '2026-05-01'
        AND rb.bill_type = 'rent'
    ) THEN 'Bill already exists for this component + billing_month + bill_type'
    WHEN sc.contract_status != 'active'
      OR sc.start_date > '2026-05-01'
      OR (sc.end_date IS NOT NULL AND sc.end_date < '2026-05-01')
    THEN 'Contract not valid for billing_month 2026-05-01 (status=' || sc.contract_status || ', end=' || COALESCE(sc.end_date::text, 'NULL') || ')'
    WHEN sc.monthly_rent IS NULL OR sc.monthly_rent < 0
    THEN 'Invalid monthly_rent: ' || COALESCE(sc.monthly_rent::text, 'NULL')
    WHEN COALESCE(aac.active_contract_count, 0) > 1
    THEN 'Area has multiple active contracts (' || COALESCE(aac.active_contract_count, 0) || ') — master/sublease case held'
    ELSE 'Ready for draft bill generation'
  END AS candidate_note
FROM safe_components sc
LEFT JOIN area_active_contracts aac ON aac.rentable_area_id = sc.rentable_area_id
ORDER BY sc.area_code;


-- ============================================================
-- STEP 2: Preview generate_ready candidates
-- Expected: 8
-- ============================================================

SELECT
  'PREVIEW: generate_ready candidates' AS check_name,
  tenant_name,
  area_code,
  contract_code,
  monthly_rent,
  candidate_status,
  candidate_note
FROM public.vw_shaxi_rent_bill_candidates_v1_9
WHERE candidate_status = 'generate_ready'
ORDER BY area_code;


-- ============================================================
-- STEP 3: Preview held candidates
-- Expected: 2 (1 billing_hold + 1 expired)
-- ============================================================

SELECT
  'PREVIEW: held candidates' AS check_name,
  tenant_name,
  area_code,
  contract_code,
  monthly_rent,
  candidate_status,
  candidate_note
FROM public.vw_shaxi_rent_bill_candidates_v1_9
WHERE candidate_status != 'generate_ready'
ORDER BY candidate_status, area_code;


-- ============================================================
-- STEP 4: Insert draft rent bills for generate_ready candidates
-- Idempotent via WHERE NOT EXISTS.
-- ============================================================

INSERT INTO public.rent_bills (
  lease_contract_id,
  lease_package_component_id,
  tenant_id,
  billing_month,
  bill_type,
  amount_due,
  due_date,
  bill_status,
  source_type,
  created_from,
  notes,
  created_at,
  updated_at
)
SELECT
  c.contract_id,
  c.component_id,
  c.tenant_id,
  '2026-05-01'::date,
  'rent',
  c.monthly_rent,
  '2026-05-05'::date,
  'draft',
  'controlled_generation',
  'sql/20_generate_shaxi_rent_bills_v1_9.sql',
  'v1.9 first controlled Shaxi rent bill generation | billing_month: 2026-05-01 | due: 2026-05-05 | tenant: ' || c.tenant_name || ' | area: ' || c.area_code,
  NOW(),
  NOW()
FROM public.vw_shaxi_rent_bill_candidates_v1_9 c
WHERE c.candidate_status = 'generate_ready'
  AND NOT EXISTS (
    SELECT 1 FROM public.rent_bills rb
    WHERE rb.lease_package_component_id = c.component_id
      AND rb.billing_month = '2026-05-01'
      AND rb.bill_type = 'rent'
  );


-- ============================================================
-- STEP 5: Update billing rule to 'generated'
-- Only if currently 'draft'.
-- ============================================================

UPDATE public.billing_generation_rules
SET
  generation_status = 'generated',
  updated_at = NOW()
WHERE property_code = 'SX-39'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent'
  AND generation_status = 'draft';


-- ============================================================
-- STEP 6: Create/refresh summary view
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_billing_generation_summary_v1_9 AS
SELECT
  (SELECT COUNT(*) FROM public.vw_shaxi_rent_bill_candidates_v1_9) AS total_candidates,
  (SELECT COUNT(*) FROM public.vw_shaxi_rent_bill_candidates_v1_9 WHERE candidate_status = 'generate_ready') AS generate_ready_count,
  (SELECT COUNT(*) FROM public.vw_shaxi_rent_bill_candidates_v1_9 WHERE candidate_status = 'billing_hold') AS billing_hold_count,
  (SELECT COUNT(*) FROM public.vw_shaxi_rent_bill_candidates_v1_9 WHERE candidate_status = 'expired') AS expired_count,
  (SELECT COUNT(*) FROM public.vw_shaxi_rent_bill_candidates_v1_9 WHERE candidate_status = 'missing_rent') AS missing_rent_count,
  (SELECT COUNT(*) FROM public.vw_shaxi_rent_bill_candidates_v1_9 WHERE candidate_status = 'duplicate_existing') AS duplicate_count,
  (SELECT COUNT(*) FROM public.rent_bills WHERE bill_status = 'draft' AND billing_month = '2026-05-01' AND bill_type = 'rent') AS generated_draft_count,
  (SELECT COUNT(*) FROM public.rent_bills WHERE bill_status != 'draft' AND billing_month = '2026-05-01' AND bill_type = 'rent') AS non_draft_count;


-- ============================================================
-- STEP 7: Create/refresh holds view
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_billing_holds_v1_9 AS
SELECT
  tenant_name,
  area_code,
  area_name,
  contract_code,
  monthly_rent,
  candidate_status,
  candidate_note AS hold_reason
FROM public.vw_shaxi_rent_bill_candidates_v1_9
WHERE candidate_status != 'generate_ready'
ORDER BY candidate_status, tenant_name;


-- ============================================================
-- STEP 8: Preview generated bills
-- ============================================================

SELECT
  'POST_INSERT: generated draft bills' AS check_name,
  rb.id AS bill_id,
  con.name AS tenant_name,
  rb.billing_month,
  rb.bill_type,
  rb.amount_due,
  rb.due_date,
  rb.bill_status,
  rb.source_type,
  rb.created_from
FROM public.rent_bills rb
JOIN public.contacts con ON con.id = rb.tenant_id
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
ORDER BY rb.amount_due DESC;


-- ============================================================
-- STEP 9: Preview summary
-- ============================================================

SELECT * FROM public.vw_shaxi_billing_generation_summary_v1_9;


-- ============================================================
-- STEP 10: Preview holds
-- ============================================================

SELECT * FROM public.vw_shaxi_billing_holds_v1_9;
