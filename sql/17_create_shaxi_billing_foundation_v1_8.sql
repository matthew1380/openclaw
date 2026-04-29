-- ============================================================
-- sql/17_create_shaxi_billing_foundation_v1_8.sql
-- Create billing/payment foundation tables and views for Shaxi
-- Batch: shaxi_promotion_v1
--
-- Purpose: Establish the minimum reliable schema for future
--          rent bills, payments, and overdue tracking.
--
-- Tables created:
--   A. rent_bills           — expected rental charges
--   B. payments             — actual money received
--   C. payment_allocations  — connect payments to bills
--
-- Views created:
--   A. vw_shaxi_billing_readiness     — readiness check (1 row)
--   B. vw_shaxi_bill_payment_status   — bill + payment + outstanding
--   C. vw_shaxi_billing_exceptions    — exception detector
--
-- Rules:
--   - Does NOT generate monthly bills yet.
--   - Does NOT create fake overdue data.
--   - All tables are idempotent (CREATE TABLE IF NOT EXISTS).
--   - All views are idempotent (CREATE OR REPLACE VIEW).
--   - Safe to rerun.
-- ============================================================


-- ============================================================
-- TABLE A: rent_bills
-- Expected rental charges.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.rent_bills (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  lease_contract_id uuid REFERENCES public.contracts(id) ON DELETE SET NULL,
  lease_package_component_id uuid REFERENCES public.lease_package_components(id) ON DELETE SET NULL,
  tenant_id uuid REFERENCES public.contacts(id) ON DELETE SET NULL,
  billing_month date,
  bill_type text,
  amount_due numeric NOT NULL DEFAULT 0,
  due_date date,
  bill_status text,
  source_type text,
  created_from text,
  notes text,
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now(),
  CONSTRAINT rent_bills_amount_due_nonneg CHECK (amount_due >= 0),
  CONSTRAINT rent_bills_bill_status_check CHECK (
    bill_status IS NULL OR
    bill_status IN ('draft', 'issued', 'partially_paid', 'paid', 'overdue', 'cancelled', 'waived', 'disputed')
  ),
  CONSTRAINT rent_bills_bill_type_check CHECK (
    bill_type IS NULL OR
    bill_type IN ('rent', 'management_fee', 'utility', 'deposit', 'adjustment', 'other')
  )
);

-- Index for duplicate-bill detection and common lookups
CREATE INDEX IF NOT EXISTS idx_rent_bills_contract ON public.rent_bills(lease_contract_id);
CREATE INDEX IF NOT EXISTS idx_rent_bills_component ON public.rent_bills(lease_package_component_id);
CREATE INDEX IF NOT EXISTS idx_rent_bills_tenant ON public.rent_bills(tenant_id);
CREATE INDEX IF NOT EXISTS idx_rent_bills_due_date ON public.rent_bills(due_date);
CREATE INDEX IF NOT EXISTS idx_rent_bills_billing_month ON public.rent_bills(billing_month);
CREATE UNIQUE INDEX IF NOT EXISTS idx_rent_bills_unique_component_month_type
  ON public.rent_bills(lease_package_component_id, billing_month, bill_type)
  WHERE lease_package_component_id IS NOT NULL AND billing_month IS NOT NULL AND bill_type IS NOT NULL;

COMMENT ON TABLE public.rent_bills IS 'Expected rental charges. Empty at v1.8 creation; bills will be generated after billing rules are confirmed.';


-- ============================================================
-- TABLE B: payments
-- Actual money received.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.payments (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id uuid REFERENCES public.contacts(id) ON DELETE SET NULL,
  payment_date date,
  amount_received numeric NOT NULL DEFAULT 0,
  payment_method text,
  bank_account text,
  reference_no text,
  payer_name text,
  source_type text,
  notes text,
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now(),
  CONSTRAINT payments_amount_received_positive CHECK (amount_received > 0)
);

-- Index for common lookups
CREATE INDEX IF NOT EXISTS idx_payments_tenant ON public.payments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_payments_date ON public.payments(payment_date);
CREATE INDEX IF NOT EXISTS idx_payments_reference ON public.payments(reference_no);

COMMENT ON TABLE public.payments IS 'Actual money received. Empty at v1.8 creation.';


-- ============================================================
-- TABLE C: payment_allocations
-- Connect payments to rent bills.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.payment_allocations (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  payment_id uuid NOT NULL REFERENCES public.payments(id) ON DELETE RESTRICT,
  bill_id uuid NOT NULL REFERENCES public.rent_bills(id) ON DELETE RESTRICT,
  allocated_amount numeric NOT NULL DEFAULT 0,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT payment_allocations_positive CHECK (allocated_amount > 0)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_payment_allocations_payment ON public.payment_allocations(payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_allocations_bill ON public.payment_allocations(bill_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_allocations_unique
  ON public.payment_allocations(payment_id, bill_id);

COMMENT ON TABLE public.payment_allocations IS 'Links payments to rent bills. Empty at v1.8 creation.';


-- ============================================================
-- VIEW A: vw_shaxi_billing_readiness
-- Readiness check for billing foundation.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_billing_readiness AS
WITH table_check AS (
  SELECT
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'rent_bills') AS has_rent_bills,
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'payments') AS has_payments,
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'payment_allocations') AS has_payment_allocations
),
row_counts AS (
  SELECT
    (SELECT COUNT(*) FROM public.rent_bills) AS rent_bill_count,
    (SELECT COUNT(*) FROM public.payments) AS payment_count,
    (SELECT COUNT(*) FROM public.payment_allocations) AS allocation_count
)
SELECT
  tc.has_rent_bills,
  tc.has_payments,
  tc.has_payment_allocations,
  rc.rent_bill_count,
  rc.payment_count,
  rc.allocation_count,
  CASE
    WHEN tc.has_rent_bills AND tc.has_payments AND tc.has_payment_allocations
      THEN 'foundation_ready'
    ELSE 'foundation_incomplete'
  END AS readiness_status,
  CASE
    WHEN tc.has_rent_bills AND tc.has_payments AND tc.has_payment_allocations
      THEN 'Billing tables exist. Monthly bill generation can begin after billing rules are confirmed by staff. '
           || 'Current counts: rent_bills=' || rc.rent_bill_count || ', payments=' || rc.payment_count || ', allocations=' || rc.allocation_count || '. '
           || 'Master/sublease cases (e.g. 四区B栋首层 with 靖大物业+川田) require explicit billing-rule confirmation.'
    ELSE 'One or more billing tables are missing. Foundation is incomplete.'
  END AS readiness_note
FROM table_check tc, row_counts rc;


-- ============================================================
-- VIEW B: vw_shaxi_bill_payment_status
-- For each bill, show allocated paid amount, outstanding, status.
-- Returns 0 rows initially if no bills exist.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_bill_payment_status AS
WITH bill_allocations AS (
  SELECT
    rb.id AS bill_id,
    COALESCE(SUM(pa.allocated_amount), 0) AS allocated_amount
  FROM public.rent_bills rb
  LEFT JOIN public.payment_allocations pa ON pa.bill_id = rb.id
  GROUP BY rb.id
)
SELECT
  rb.id AS bill_id,
  rb.billing_month,
  rb.bill_type,
  rb.bill_status,
  rb.amount_due,
  ba.allocated_amount,
  GREATEST(rb.amount_due - ba.allocated_amount, 0) AS outstanding_amount,
  CASE
    WHEN rb.bill_status IN ('cancelled', 'waived') THEN rb.bill_status
    WHEN rb.amount_due = 0 THEN 'paid'
    WHEN ba.allocated_amount >= rb.amount_due THEN 'paid'
    WHEN ba.allocated_amount > 0 THEN 'partially_paid'
    WHEN rb.due_date IS NOT NULL AND rb.due_date < CURRENT_DATE THEN 'overdue'
    ELSE 'due'
  END AS computed_status,
  rb.due_date,
  CASE
    WHEN rb.due_date IS NOT NULL AND rb.due_date < CURRENT_DATE
    THEN CURRENT_DATE - rb.due_date
    ELSE NULL
  END AS days_overdue,
  con.name AS tenant_name,
  c.contract_code,
  rb.lease_package_component_id,
  rb.notes
FROM public.rent_bills rb
LEFT JOIN bill_allocations ba ON ba.bill_id = rb.id
LEFT JOIN public.contacts con ON con.id = rb.tenant_id
LEFT JOIN public.contracts c ON c.id = rb.lease_contract_id
ORDER BY rb.due_date ASC NULLS LAST, rb.billing_month DESC;


-- ============================================================
-- VIEW C: vw_shaxi_billing_exceptions
-- Detects billing and allocation problems.
-- Expected: 0 rows when data is clean.
-- ============================================================

CREATE OR REPLACE VIEW public.vw_shaxi_billing_exceptions AS

-- 1. Bill without valid contract
SELECT
  'bill_without_contract' AS exception_type,
  rb.id AS bill_id,
  NULL::uuid AS allocation_id,
  'Bill ' || rb.id || ' references non-existent contract ' || rb.lease_contract_id AS details
FROM public.rent_bills rb
WHERE rb.lease_contract_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.contracts c WHERE c.id = rb.lease_contract_id)

UNION ALL

-- 2. Bill without valid tenant
SELECT
  'bill_without_tenant' AS exception_type,
  rb.id AS bill_id,
  NULL::uuid AS allocation_id,
  'Bill ' || rb.id || ' references non-existent tenant ' || rb.tenant_id AS details
FROM public.rent_bills rb
WHERE rb.tenant_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.contacts con WHERE con.id = rb.tenant_id)

UNION ALL

-- 3. Bill without valid lease component
SELECT
  'bill_without_component' AS exception_type,
  rb.id AS bill_id,
  NULL::uuid AS allocation_id,
  'Bill ' || rb.id || ' references non-existent lease_package_component ' || rb.lease_package_component_id AS details
FROM public.rent_bills rb
WHERE rb.lease_package_component_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.lease_package_components lpc WHERE lpc.id = rb.lease_package_component_id)

UNION ALL

-- 4. Allocation without valid payment
SELECT
  'allocation_without_payment' AS exception_type,
  NULL::uuid AS bill_id,
  pa.id AS allocation_id,
  'Allocation ' || pa.id || ' references non-existent payment ' || pa.payment_id AS details
FROM public.payment_allocations pa
WHERE NOT EXISTS (SELECT 1 FROM public.payments p WHERE p.id = pa.payment_id)

UNION ALL

-- 5. Allocation without valid bill
SELECT
  'allocation_without_bill' AS exception_type,
  NULL::uuid AS bill_id,
  pa.id AS allocation_id,
  'Allocation ' || pa.id || ' references non-existent bill ' || pa.bill_id AS details
FROM public.payment_allocations pa
WHERE NOT EXISTS (SELECT 1 FROM public.rent_bills rb WHERE rb.id = pa.bill_id)

UNION ALL

-- 6. Over-allocated amount
SELECT
  'over_allocated' AS exception_type,
  pa.bill_id AS bill_id,
  pa.id AS allocation_id,
  'Allocation ' || pa.id || ' amount (' || pa.allocated_amount || ') exceeds bill amount_due (' || rb.amount_due || ')' AS details
FROM public.payment_allocations pa
JOIN public.rent_bills rb ON rb.id = pa.bill_id
WHERE pa.allocated_amount > rb.amount_due

UNION ALL

-- 7. Duplicate bill for same component / month / type
SELECT
  'duplicate_bill' AS exception_type,
  rb.id AS bill_id,
  NULL::uuid AS allocation_id,
  'Duplicate bill: component=' || rb.lease_package_component_id || ', month=' || rb.billing_month || ', type=' || rb.bill_type AS details
FROM public.rent_bills rb
WHERE EXISTS (
  SELECT 1 FROM public.rent_bills rb2
  WHERE rb2.lease_package_component_id = rb.lease_package_component_id
    AND rb2.billing_month = rb.billing_month
    AND rb2.bill_type = rb.bill_type
    AND rb2.id != rb.id
);
