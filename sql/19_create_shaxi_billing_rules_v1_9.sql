-- ============================================================
-- sql/19_create_shaxi_billing_rules_v1_9.sql
-- Create billing generation rule table and insert Shaxi rule
-- Batch: shaxi_promotion_v1
--
-- Purpose: Establish a controlled rule for rent bill generation
--          so that billing is explicit, reviewable, and repeatable.
--
-- Rules:
--   - Table is idempotent (CREATE TABLE IF NOT EXISTS).
--   - Rule insert is idempotent (ON CONFLICT DO NOTHING).
--   - Does NOT generate bills.
-- ============================================================

-- ============================================================
-- TABLE: billing_generation_rules
-- ============================================================

CREATE TABLE IF NOT EXISTS public.billing_generation_rules (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_code text NOT NULL,
  billing_month date NOT NULL,
  bill_type text NOT NULL,
  due_day integer NOT NULL,
  generation_status text NOT NULL,
  created_from text,
  notes text,
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now(),
  CONSTRAINT billing_generation_rules_due_day_check CHECK (due_day BETWEEN 1 AND 28),
  CONSTRAINT billing_generation_rules_bill_type_check CHECK (
    bill_type IN ('rent', 'management_fee', 'utility', 'deposit', 'adjustment', 'other')
  ),
  CONSTRAINT billing_generation_rules_status_check CHECK (
    generation_status IN ('draft', 'reviewed', 'approved', 'generated', 'cancelled')
  ),
  CONSTRAINT billing_generation_rules_unique_rule UNIQUE (property_code, billing_month, bill_type)
);

COMMENT ON TABLE public.billing_generation_rules IS 'Controls when and how rent bills are generated. Each rule is unique per property, billing month, and bill type.';

-- ============================================================
-- INSERT: First controlled Shaxi rent bill generation rule
-- Idempotent via ON CONFLICT.
-- ============================================================

INSERT INTO public.billing_generation_rules (
  property_code,
  billing_month,
  bill_type,
  due_day,
  generation_status,
  created_from,
  notes
)
VALUES (
  'SX-39',
  '2026-05-01',
  'rent',
  5,
  'draft',
  'sql/19_create_shaxi_billing_rules_v1_9.sql',
  'First controlled Shaxi rent bill generation rule | v1.9 | property: SX-39 | billing_month: 2026-05-01 | due_date: 2026-05-05'
)
ON CONFLICT (property_code, billing_month, bill_type) DO NOTHING;


-- ============================================================
-- VERIFICATION
-- ============================================================

-- Rule exists exactly once
SELECT
  'RULE: billing rule count' AS check_name,
  COUNT(*) AS rule_count
FROM public.billing_generation_rules
WHERE property_code = 'SX-39'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';

-- Rule details
SELECT
  'RULE: rule details' AS check_name,
  property_code,
  billing_month,
  bill_type,
  due_day,
  generation_status,
  created_from
FROM public.billing_generation_rules
WHERE property_code = 'SX-39'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';
