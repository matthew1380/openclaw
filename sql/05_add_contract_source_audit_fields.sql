-- ============================================================
-- sql/05_add_contract_source_audit_fields.sql
-- Add source/audit columns to contracts and backfill from staging
-- Batch: shaxi_contracts_v1_1
--
-- Purpose:
--   1. Add missing source-traceability columns to public.contracts.
--   2. Idempotent backfill from stg_shaxi_contracts_prepared
--      by matching (tenant_id + unit_id + start_date + end_date).
--
-- Rules:
--   - Does NOT change contract_status.
--   - Does NOT create lease_package_components.
--   - Does NOT resolve the 9 pending candidates.
-- ============================================================


-- ============================================================
-- STEP 1: Add columns if missing
-- ============================================================

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS source_company text,
  ADD COLUMN IF NOT EXISTS source_rented_unit_text text,
  ADD COLUMN IF NOT EXISTS source_payee_raw text,
  ADD COLUMN IF NOT EXISTS source_remarks_raw text,
  ADD COLUMN IF NOT EXISTS mapped_property_code text,
  ADD COLUMN IF NOT EXISTS mapped_parcel_code text,
  ADD COLUMN IF NOT EXISTS mapped_building_code text,
  ADD COLUMN IF NOT EXISTS mapped_building_name text,
  ADD COLUMN IF NOT EXISTS mapped_area_name text,
  ADD COLUMN IF NOT EXISTS mapped_confidence text,
  ADD COLUMN IF NOT EXISTS source_staging_table text,
  ADD COLUMN IF NOT EXISTS promotion_batch text,
  ADD COLUMN IF NOT EXISTS staging_imported_at timestamptz,
  ADD COLUMN IF NOT EXISTS source_metadata jsonb;


-- ============================================================
-- STEP 2: Preview rows that will be updated
-- Expected: 10 rows
-- ============================================================

SELECT
  c.contract_code,
  con.name AS tenant_name,
  c.monthly_rent,
  c.start_date,
  c.end_date,
  s.source_company,
  s.rented_unit_text,
  s.mapped_area_name,
  s.payee_raw
FROM public.contracts c
JOIN public.contacts con ON con.id = c.tenant_id
JOIN public.stg_shaxi_contracts_prepared s
  ON con.name = s.tenant_name
  AND c.monthly_rent = s.monthly_rent
  AND c.start_date = s.contract_start_date
  AND c.end_date = s.contract_end_date
ORDER BY c.contract_code;


-- ============================================================
-- STEP 3: Backfill staged source fields into contracts
-- This UPDATE is idempotent — same values every run.
-- ============================================================

UPDATE public.contracts c
SET
  source_company = s.source_company,
  source_rented_unit_text = s.rented_unit_text,
  source_payee_raw = s.payee_raw,
  source_remarks_raw = s.remarks_raw,
  mapped_property_code = s.mapped_property_code,
  mapped_parcel_code = s.mapped_parcel_code,
  mapped_building_code = s.mapped_building_code,
  mapped_building_name = s.mapped_building_name,
  mapped_area_name = s.mapped_area_name,
  mapped_confidence = s.mapped_confidence,
  source_staging_table = 'stg_shaxi_contracts_prepared',
  promotion_batch = 'shaxi_contracts_v1_1',
  staging_imported_at = s.imported_at,
  source_metadata = jsonb_build_object(
    'current_status', s.current_status,
    'load_batch_note', s.load_batch_note
  )
FROM public.stg_shaxi_contracts_prepared s
JOIN public.contacts con ON con.name = s.tenant_name
WHERE c.tenant_id = con.id
  AND c.monthly_rent = s.monthly_rent
  AND c.start_date = s.contract_start_date
  AND c.end_date = s.contract_end_date;


-- ============================================================
-- STEP 4: Post-backfill verification
-- ============================================================

-- 4.1 Contracts updated with this batch
-- Expected: 10
SELECT
  'BACKFILL: contracts with batch tag' AS check_name,
  COUNT(*) AS updated_count
FROM public.contracts
WHERE promotion_batch = 'shaxi_contracts_v1_1';


-- 4.2 Source fields populated
-- Expected: 10
SELECT
  'BACKFILL: contracts with source_rented_unit_text' AS check_name,
  COUNT(*) AS populated_count
FROM public.contracts
WHERE promotion_batch = 'shaxi_contracts_v1_1'
  AND source_rented_unit_text IS NOT NULL;


-- 4.3 Mapped fields populated
-- Expected: 10
SELECT
  'BACKFILL: contracts with mapped_area_name' AS check_name,
  COUNT(*) AS populated_count
FROM public.contracts
WHERE promotion_batch = 'shaxi_contracts_v1_1'
  AND mapped_area_name IS NOT NULL;
