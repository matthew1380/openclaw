-- ============================================================
-- sql/15_create_shaxi_operating_views_v1_7.sql
-- Create read-only operating-data views for Shaxi
-- Batch: shaxi_promotion_v1
--
-- Purpose: Provide staff-facing operating views for expiry risk,
--          area occupancy, and payment data readiness.
--
-- Views:
--   A. vw_shaxi_contract_expiry_watch    — 10 rows expected
--   B. vw_shaxi_area_occupancy_status    — all SX-39 areas
--   C. vw_shaxi_payment_data_readiness   — readiness check (1 row)
--
-- Rules:
--   - All views are read-only.
--   - CREATE OR REPLACE VIEW for idempotency.
--   - Safe to rerun.
--   - Does NOT modify data.
--   - Does NOT guess overdue amounts without billing data.
-- ============================================================


-- ============================================================
-- VIEW A: vw_shaxi_contract_expiry_watch
-- Contract expiry risk for the 10 safe Shaxi components.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_contract_expiry_watch AS
WITH safe_components AS (
  SELECT
    lpc.id AS component_id,
    lpc.package_unit_id,
    ra.area_code,
    ra.area_name,
    b.building_name,
    ra.section_group_name,
    CASE
      WHEN lpc.source_candidate_id IS NULL THEN 'exact_original_match'
      ELSE 'approved_candidate'
    END AS source_type,
    lpc.promotion_batch
  FROM public.lease_package_components lpc
  JOIN public.rentable_areas ra ON ra.id = lpc.rentable_area_id
  JOIN public.building_registry b ON b.id = ra.building_id
  WHERE lpc.promotion_batch = 'shaxi_promotion_v1'
)
SELECT
  con.name AS tenant_name,
  sc.area_code,
  sc.area_name,
  sc.building_name,
  sc.section_group_name,
  c.start_date AS contract_start_date,
  c.end_date AS contract_end_date,
  c.end_date - CURRENT_DATE AS days_to_expiry,
  CASE
    WHEN c.end_date IS NULL THEN 'missing_end_date'
    WHEN c.end_date < CURRENT_DATE THEN 'expired'
    WHEN c.end_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'expiring_30_days'
    WHEN c.end_date <= CURRENT_DATE + INTERVAL '60 days' THEN 'expiring_60_days'
    WHEN c.end_date <= CURRENT_DATE + INTERVAL '90 days' THEN 'expiring_90_days'
    ELSE 'active_over_90_days'
  END AS expiry_status,
  c.monthly_rent,
  sc.source_type,
  sc.promotion_batch
FROM safe_components sc
JOIN public.contracts c ON c.unit_id = sc.package_unit_id
JOIN public.contacts con ON con.id = c.tenant_id
ORDER BY
  CASE
    WHEN c.end_date IS NULL THEN 1
    WHEN c.end_date < CURRENT_DATE THEN 2
    WHEN c.end_date <= CURRENT_DATE + INTERVAL '30 days' THEN 3
    WHEN c.end_date <= CURRENT_DATE + INTERVAL '60 days' THEN 4
    WHEN c.end_date <= CURRENT_DATE + INTERVAL '90 days' THEN 5
    ELSE 6
  END,
  c.end_date ASC,
  sc.area_code;


-- ============================================================
-- VIEW B: vw_shaxi_area_occupancy_status
-- All SX-39 rentable areas with occupancy status.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_area_occupancy_status AS
WITH area_contract_links AS (
  SELECT
    ra.id AS rentable_area_id,
    COUNT(DISTINCT lpc.id) AS linked_component_count,
    COUNT(DISTINCT lpc.id) FILTER (WHERE lpc.promotion_batch = 'shaxi_promotion_v1') AS safe_component_count,
    COUNT(DISTINCT c.id) FILTER (WHERE c.contract_status::text = 'active') AS active_contract_count,
    STRING_AGG(DISTINCT con.name, ', ' ORDER BY con.name)
      FILTER (WHERE c.contract_status::text = 'active') AS tenant_names,
    MIN(c.end_date) FILTER (WHERE c.contract_status::text = 'active') AS earliest_contract_end_date,
    MAX(c.end_date) FILTER (WHERE c.contract_status::text = 'active') AS latest_contract_end_date
  FROM public.rentable_areas ra
  LEFT JOIN public.lease_package_components lpc ON lpc.rentable_area_id = ra.id
  LEFT JOIN public.units u ON u.id = lpc.package_unit_id
  LEFT JOIN public.contracts c ON c.unit_id = u.id
  LEFT JOIN public.contacts con ON con.id = c.tenant_id
  WHERE ra.property_id = (SELECT id FROM public.properties WHERE property_code = 'SX-39')
  GROUP BY ra.id
)
SELECT
  ra.area_code,
  ra.area_name,
  b.building_name,
  b.building_code,
  ra.section_group_name,
  ra.current_status,
  ra.area_type,
  CASE
    WHEN ra.notes LIKE '%approved candidate%' THEN 'canonical_approved'
    WHEN ra.notes LIKE '%batch: shaxi_promotion_v1%' THEN 'canonical_promoted'
    WHEN ra.notes LIKE '%package_seed%' THEN 'legacy_package'
    WHEN ra.notes LIKE '%component_seed%' THEN 'legacy_component'
    WHEN ra.notes LIKE '%Corrected component%' THEN 'legacy_corrected'
    WHEN ra.notes LIKE '%Seeded from existing%' THEN 'legacy_existing'
    ELSE 'other'
  END AS area_origin,
  COALESCE(acl.linked_component_count, 0) AS linked_component_count,
  COALESCE(acl.safe_component_count, 0) AS safe_component_count,
  COALESCE(acl.active_contract_count, 0) AS active_contract_count,
  CASE
    WHEN COALESCE(acl.linked_component_count, 0) = 0 THEN 'no_component'
    WHEN COALESCE(acl.active_contract_count, 0) = 0 THEN 'vacant'
    WHEN COALESCE(acl.active_contract_count, 0) = 1 THEN 'occupied'
    ELSE 'multiple_active'
  END AS occupancy_status,
  acl.tenant_names AS tenant_name,
  acl.earliest_contract_end_date AS contract_end_date
FROM public.rentable_areas ra
JOIN public.properties p ON p.id = ra.property_id
JOIN public.building_registry b ON b.id = ra.building_id
LEFT JOIN area_contract_links acl ON acl.rentable_area_id = ra.id
WHERE p.property_code = 'SX-39'
ORDER BY b.building_code, ra.area_code;


-- ============================================================
-- VIEW C: vw_shaxi_payment_data_readiness
-- Readiness check for payment/ledger/collection reporting.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_payment_data_readiness AS
WITH table_check AS (
  SELECT
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'payments') AS has_payments,
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'rent_bills') AS has_rent_bills,
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'invoices') AS has_invoices,
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'receivables') AS has_receivables,
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'ledger') AS has_ledger,
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'utility_bills') AS has_utility_bills
),
financial_summary AS (
  SELECT
    COUNT(*) AS total_financial_records,
    COUNT(*) FILTER (WHERE fr.status::text = 'pending') AS pending_records,
    COUNT(*) FILTER (WHERE fr.status::text = 'paid') AS paid_records,
    COUNT(*) FILTER (WHERE fr.status::text = 'overdue') AS overdue_records,
    COUNT(*) FILTER (WHERE fr.status::text = 'cancelled') AS cancelled_records
  FROM public.financial_records fr
  JOIN public.units u ON u.id = fr.unit_id
  JOIN public.properties p ON p.id = u.property_id
  WHERE p.property_code = 'SX-39'
),
seed_summary AS (
  SELECT COUNT(*) AS seed_rows
  FROM public.stg_shaxi_overdue_seed_20260420
)
SELECT
  tc.has_payments,
  tc.has_rent_bills,
  tc.has_invoices,
  tc.has_receivables,
  tc.has_ledger,
  tc.has_utility_bills,
  fs.total_financial_records,
  fs.pending_records,
  fs.paid_records,
  fs.overdue_records,
  fs.cancelled_records,
  ss.seed_rows,
  CASE
    WHEN tc.has_payments AND tc.has_rent_bills AND tc.has_invoices THEN 'ready'
    WHEN fs.total_financial_records > 0 THEN 'seeded_only'
    ELSE 'missing'
  END AS readiness_status,
  CASE
    WHEN tc.has_payments AND tc.has_rent_bills AND tc.has_invoices
      THEN 'Payment/billing tables exist. Collection status reporting is ready.'
    WHEN fs.total_financial_records > 0
      THEN 'financial_records contains ' || fs.total_financial_records || ' seeded backlog rows for SX-39. '
           || 'These are operational seeds from rent summary (see stg_shaxi_overdue_seed), '
           || 'NOT month-by-month billing truth. Overdue reporting cannot be trusted until '
           || 'real billing/payment tables (rent_bills, payments, invoices) are introduced.'
    ELSE 'No payment, billing, or receivable tables exist. Collection status reporting is not possible.'
  END AS readiness_note
FROM table_check tc, financial_summary fs, seed_summary ss;
