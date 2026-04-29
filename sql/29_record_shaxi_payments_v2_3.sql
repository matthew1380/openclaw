-- ============================================================
-- sql/29_record_shaxi_payments_v2_3.sql
-- Payment recording and allocation foundation for Shaxi
-- Batch: shaxi_promotion_v1
--
-- Purpose:
--   1. Create read-only views for outstanding bills and payment recording.
--   2. Create exception detector for payment allocations.
--   3. Prove views are ready even with 0 payments.
--
-- Rules:
--   - Does NOT insert fake/test payments.
--   - Only real payments should be inserted into `payments`.
--   - Payments should only be allocated to issued bills.
--   - All views are idempotent (CREATE OR REPLACE VIEW).
--   - Safe to rerun.
-- ============================================================


-- ============================================================
-- VIEW A: vw_shaxi_outstanding_bills_v2_3
-- All issued May 2026 rent bills with payment status.
-- Includes allocated amount, outstanding, and days overdue.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_outstanding_bills_v2_3 AS
WITH bill_allocations AS (
  SELECT
    pa.bill_id,
    COALESCE(SUM(pa.allocated_amount), 0) AS allocated_paid_amount
  FROM public.payment_allocations pa
  GROUP BY pa.bill_id
)
SELECT
  rb.id AS bill_id,
  con.name AS tenant_name,
  ra.area_code,
  ra.area_name,
  b.building_name,
  rb.billing_month,
  rb.bill_type,
  rb.amount_due,
  COALESCE(ba.allocated_paid_amount, 0) AS allocated_paid_amount,
  GREATEST(rb.amount_due - COALESCE(ba.allocated_paid_amount, 0), 0) AS outstanding_amount,
  rb.due_date,
  CASE
    WHEN rb.due_date IS NOT NULL AND rb.due_date < CURRENT_DATE
    THEN CURRENT_DATE - rb.due_date
    ELSE NULL
  END AS days_overdue,
  CASE
    WHEN rb.bill_status IN ('cancelled', 'waived') THEN rb.bill_status
    WHEN rb.amount_due = 0 THEN 'paid'
    WHEN COALESCE(ba.allocated_paid_amount, 0) >= rb.amount_due THEN 'paid'
    WHEN COALESCE(ba.allocated_paid_amount, 0) > 0 THEN 'partially_paid'
    WHEN rb.due_date IS NOT NULL AND rb.due_date < CURRENT_DATE THEN 'overdue'
    ELSE 'due'
  END AS payment_status,
  rb.bill_status,
  rb.lease_contract_id,
  rb.lease_package_component_id,
  rb.source_type
FROM public.rent_bills rb
JOIN public.contacts con ON con.id = rb.tenant_id
JOIN public.lease_package_components lpc ON lpc.id = rb.lease_package_component_id
JOIN public.rentable_areas ra ON ra.id = lpc.rentable_area_id
JOIN public.building_registry b ON b.id = ra.building_id
LEFT JOIN bill_allocations ba ON ba.bill_id = rb.id
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND rb.bill_status = 'issued'
ORDER BY rb.amount_due DESC;


-- ============================================================
-- VIEW B: vw_shaxi_payment_recording_queue_v2_3
-- Bills eligible for payment recording.
-- Only issued bills with outstanding amount > 0.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_payment_recording_queue_v2_3 AS
SELECT
  bill_id,
  tenant_name,
  area_code,
  area_name,
  billing_month,
  bill_type,
  amount_due,
  allocated_paid_amount,
  outstanding_amount,
  due_date,
  days_overdue,
  payment_status,
  bill_status
FROM public.vw_shaxi_outstanding_bills_v2_3
WHERE outstanding_amount > 0
ORDER BY days_overdue DESC NULLS LAST, amount_due DESC;


-- ============================================================
-- VIEW C: vw_shaxi_payment_allocation_exceptions_v2_3
-- Detects payment allocation problems.
-- Expected: 0 rows when data is clean.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_payment_allocation_exceptions_v2_3 AS

-- 1. Allocation to draft bill (payments should only go to issued bills)
SELECT
  'allocation_to_draft_bill' AS exception_type,
  pa.id AS allocation_id,
  pa.payment_id,
  pa.bill_id,
  pa.allocated_amount,
  'Allocation ' || pa.id || ' is linked to draft bill ' || pa.bill_id AS details
FROM public.payment_allocations pa
JOIN public.rent_bills rb ON rb.id = pa.bill_id
WHERE rb.bill_status = 'draft'

UNION ALL

-- 2. Allocation to non-issued bill (cancelled, waived, etc.)
SELECT
  'allocation_to_non_issued_bill' AS exception_type,
  pa.id AS allocation_id,
  pa.payment_id,
  pa.bill_id,
  pa.allocated_amount,
  'Allocation ' || pa.id || ' is linked to bill ' || pa.bill_id || ' with status ' || rb.bill_status AS details
FROM public.payment_allocations pa
JOIN public.rent_bills rb ON rb.id = pa.bill_id
WHERE rb.bill_status NOT IN ('issued', 'partially_paid', 'paid', 'overdue')
  AND rb.bill_status != 'draft'

UNION ALL

-- 3. Allocation to missing bill
SELECT
  'allocation_to_missing_bill' AS exception_type,
  pa.id AS allocation_id,
  pa.payment_id,
  pa.bill_id,
  pa.allocated_amount,
  'Allocation ' || pa.id || ' references missing bill ' || pa.bill_id AS details
FROM public.payment_allocations pa
WHERE NOT EXISTS (SELECT 1 FROM public.rent_bills rb WHERE rb.id = pa.bill_id)

UNION ALL

-- 4. Allocation to missing payment
SELECT
  'allocation_to_missing_payment' AS exception_type,
  pa.id AS allocation_id,
  pa.payment_id,
  pa.bill_id,
  pa.allocated_amount,
  'Allocation ' || pa.id || ' references missing payment ' || pa.payment_id AS details
FROM public.payment_allocations pa
WHERE NOT EXISTS (SELECT 1 FROM public.payments p WHERE p.id = pa.payment_id)

UNION ALL

-- 5. Allocated amount exceeds bill amount_due
SELECT
  'allocation_exceeds_bill' AS exception_type,
  pa.id AS allocation_id,
  pa.payment_id,
  pa.bill_id,
  pa.allocated_amount,
  'Allocation ' || pa.id || ' amount (' || pa.allocated_amount || ') exceeds bill amount_due (' || rb.amount_due || ')' AS details
FROM public.payment_allocations pa
JOIN public.rent_bills rb ON rb.id = pa.bill_id
WHERE pa.allocated_amount > rb.amount_due

UNION ALL

-- 6. Total allocated per bill exceeds bill amount_due
SELECT
  'total_allocation_exceeds_bill' AS exception_type,
  NULL::uuid AS allocation_id,
  NULL::uuid AS payment_id,
  pa.bill_id,
  SUM(pa.allocated_amount) AS allocated_amount,
  'Total allocations (' || SUM(pa.allocated_amount) || ') exceed bill ' || pa.bill_id || ' amount_due (' || rb.amount_due || ')' AS details
FROM public.payment_allocations pa
JOIN public.rent_bills rb ON rb.id = pa.bill_id
GROUP BY pa.bill_id, rb.amount_due
HAVING SUM(pa.allocated_amount) > rb.amount_due

UNION ALL

-- 7. Total allocated per payment exceeds payment amount_received
SELECT
  'total_allocation_exceeds_payment' AS exception_type,
  NULL::uuid AS allocation_id,
  pa.payment_id,
  NULL::uuid AS bill_id,
  SUM(pa.allocated_amount) AS allocated_amount,
  'Total allocations (' || SUM(pa.allocated_amount) || ') exceed payment ' || pa.payment_id || ' amount_received (' || p.amount_received || ')' AS details
FROM public.payment_allocations pa
JOIN public.payments p ON p.id = pa.payment_id
GROUP BY pa.payment_id, p.amount_received
HAVING SUM(pa.allocated_amount) > p.amount_received

UNION ALL

-- 8. Duplicate allocation (same payment + bill pair)
SELECT
  'duplicate_allocation' AS exception_type,
  pa.id AS allocation_id,
  pa.payment_id,
  pa.bill_id,
  pa.allocated_amount,
  'Duplicate allocation: payment=' || pa.payment_id || ', bill=' || pa.bill_id AS details
FROM public.payment_allocations pa
WHERE EXISTS (
  SELECT 1 FROM public.payment_allocations pa2
  WHERE pa2.payment_id = pa.payment_id
    AND pa2.bill_id = pa.bill_id
    AND pa2.id != pa.id
);


-- ============================================================
-- PART 4: Preview results
-- ============================================================

SELECT 'OUTSTANDING BILLS' AS section, * FROM public.vw_shaxi_outstanding_bills_v2_3;

SELECT 'PAYMENT RECORDING QUEUE' AS section, * FROM public.vw_shaxi_payment_recording_queue_v2_3;

SELECT 'PAYMENT ALLOCATION EXCEPTIONS' AS section, * FROM public.vw_shaxi_payment_allocation_exceptions_v2_3;
