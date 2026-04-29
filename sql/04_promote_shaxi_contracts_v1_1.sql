-- ============================================================
-- sql/04_promote_shaxi_contracts_v1_1.sql
-- Shaxi contract staging -> operational truth PROMOTION
-- Batch: shaxi_promotion_v1
--
-- Purpose: Promote 10 staged contracts from
--          stg_shaxi_contracts_prepared into the contracts table.
--
-- Rules:
--   1. Idempotent insert (skips rows already present by
--      tenant_id + unit_id + start_date + end_date).
--   2. Generates sequential contract_code for genuinely new rows.
--   3. Maps payee_raw to landlord_op_entity_id.
--   4. Maps current_status '在租' -> contract_status 'active'.
--   5. Does NOT promote unmatched area candidates.
--   6. Does NOT create lease_package_components (existing ones
--      for these units are already in place).
--   7. Keeps 9 unmatched candidates in
--      promotion_contract_area_candidates.
--
-- HUMAN NOTE: The contracts table currently lacks a notes/source
-- column. The following staged fields have no direct target column
-- and are NOT preserved in this promotion:
--   - source_company
--   - rented_unit_text
--   - mapped_property_code
--   - mapped_parcel_code
--   - mapped_building_code
--   - mapped_building_name
--   - mapped_area_name
--   - mapped_confidence
--   - remarks_raw
-- Consider adding a notes/source_metadata column in a future schema
-- change to preserve staging provenance.
--
-- HUMAN NOTE: unit_id is derived by matching staged contracts to
-- existing contracts on (tenant_name, monthly_rent, start_date,
-- end_date). In a fresh database without existing contracts, an
-- explicit unit mapping would be required.
-- ============================================================


-- ============================================================
-- STEP 1: Preview mapped contracts ready for insert
-- Expected: 10 rows, all with unit_id resolved.
-- In current state, existing contracts will cause all 10 to be
-- skipped by the idempotency check (0 new inserts).
-- ============================================================

WITH oe_jd AS (SELECT id FROM public.operating_entities WHERE op_entity_code = 'JD-SX'),
     oe_zm AS (SELECT id FROM public.operating_entities WHERE op_entity_code = 'ZM-SX')
SELECT
  s.tenant_name,
  s.monthly_rent,
  s.contract_start_date,
  s.contract_end_date,
  con.id AS tenant_id,
  ec.unit_id,
  CASE s.payee_raw
    WHEN '靖大' THEN oe_jd.id
    WHEN '中铭公司' THEN oe_zm.id
  END AS landlord_op_entity_id,
  s.payee_raw AS receiving_account_hint,
  CASE s.current_status
    WHEN '在租' THEN 'active'::contract_status
    ELSE s.current_status::contract_status
  END AS contract_status,
  CASE WHEN ec.id IS NOT NULL THEN 'EXISTS — will be skipped' ELSE 'NEW — will be inserted' END AS insert_action
FROM public.stg_shaxi_contracts_prepared s
JOIN public.contacts con ON con.name = s.tenant_name
LEFT JOIN public.contracts ec
  ON ec.tenant_id = con.id
  AND ec.monthly_rent = s.monthly_rent
  AND ec.start_date = s.contract_start_date
  AND ec.end_date = s.contract_end_date
CROSS JOIN oe_jd
CROSS JOIN oe_zm
ORDER BY s.tenant_name, s.contract_start_date;


-- ============================================================
-- STEP 2: Idempotent insert into contracts
-- ============================================================

WITH oe_jd AS (SELECT id FROM public.operating_entities WHERE op_entity_code = 'JD-SX'),
     oe_zm AS (SELECT id FROM public.operating_entities WHERE op_entity_code = 'ZM-SX'),
     max_code AS (
       SELECT COALESCE(MAX(CAST(SUBSTRING(contract_code FROM 7) AS INTEGER)), 0) AS max_num
       FROM public.contracts
       WHERE contract_code ~ '^SX-C-[0-9]+$'
     ),
     numbered AS (
       SELECT
         s.*,
         con.id AS tenant_id,
         ec.unit_id,
         CASE s.payee_raw
           WHEN '靖大' THEN oe_jd.id
           WHEN '中铭公司' THEN oe_zm.id
         END AS landlord_op_entity_id,
         ROW_NUMBER() OVER (ORDER BY s.tenant_name, s.contract_start_date) AS rn
       FROM public.stg_shaxi_contracts_prepared s
       JOIN public.contacts con ON con.name = s.tenant_name
       LEFT JOIN public.contracts ec
         ON ec.tenant_id = con.id
         AND ec.monthly_rent = s.monthly_rent
         AND ec.start_date = s.contract_start_date
         AND ec.end_date = s.contract_end_date
       CROSS JOIN oe_jd
       CROSS JOIN oe_zm
     )
INSERT INTO public.contracts (
  contract_code,
  unit_id,
  tenant_id,
  landlord_op_entity_id,
  receiving_account_hint,
  start_date,
  end_date,
  monthly_rent,
  contract_status,
  created_at
)
SELECT
  'SX-C-' || LPAD((m.max_num + n.rn)::text, 3, '0'),
  n.unit_id,
  n.tenant_id,
  n.landlord_op_entity_id,
  n.payee_raw,
  n.contract_start_date,
  n.contract_end_date,
  n.monthly_rent,
  CASE n.current_status
    WHEN '在租' THEN 'active'::contract_status
    ELSE n.current_status::contract_status
  END,
  NOW()
FROM numbered n
CROSS JOIN max_code m
WHERE n.unit_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.contracts c2
    WHERE c2.tenant_id = n.tenant_id
      AND c2.unit_id = n.unit_id
      AND c2.start_date = n.contract_start_date
      AND c2.end_date = n.contract_end_date
  );


-- ============================================================
-- STEP 3: Post-insert verification
-- ============================================================

-- 3.1 Total staged contracts now represented in contracts
-- Expected: 10
SELECT
  'POST_INSERT: staged contracts in contracts' AS check_name,
  COUNT(*) AS matched_count
FROM public.stg_shaxi_contracts_prepared s
JOIN public.contacts con ON con.name = s.tenant_name
JOIN public.contracts c
  ON c.tenant_id = con.id
  AND c.monthly_rent = s.monthly_rent
  AND c.start_date = s.contract_start_date
  AND c.end_date = s.contract_end_date;


-- 3.2 No duplicate contracts per tenant + unit + dates
-- Expected: 0
SELECT
  'POST_INSERT: duplicate contracts' AS check_name,
  COUNT(*) AS duplicate_count
FROM (
  SELECT tenant_id, unit_id, start_date, end_date
  FROM public.contracts
  GROUP BY tenant_id, unit_id, start_date, end_date
  HAVING COUNT(*) > 1
) dups;


-- 3.3 Candidates unchanged
-- Expected: 9 pending review
SELECT
  'POST_INSERT: candidates pending review' AS check_name,
  COUNT(*) AS pending_review_count
FROM public.promotion_contract_area_candidates
WHERE promotion_batch = 'shaxi_promotion_v1'
  AND review_status = 'pending_review';
