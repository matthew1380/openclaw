-- ============================================================
-- sql/37_verify_shaxi_excel_drift_corrections_v2_7.sql
-- Verify v2.7 changes — Excel↔DB drift corrections + 华佑/刘英 master-lease bills
-- Batch: shaxi_promotion_v1
--
-- Each check returns one row with status = PASS | FAIL.
-- Re-runnable read-only.
-- ============================================================


-- ============================================================
-- A. Contract date corrections (5 contracts)
-- ============================================================

SELECT
  'A1. SX-C-006 珍美 end_date = 2027-10-31' AS check_name,
  CASE WHEN end_date = DATE '2027-10-31' THEN 'PASS' ELSE 'FAIL' END AS status,
  end_date::text AS observed
FROM public.contracts WHERE contract_code = 'SX-C-006';

SELECT
  'A2. SX-C-010 刘英 end_date = 2027-10-31' AS check_name,
  CASE WHEN end_date = DATE '2027-10-31' THEN 'PASS' ELSE 'FAIL' END AS status,
  end_date::text AS observed
FROM public.contracts WHERE contract_code = 'SX-C-010';

SELECT
  'A3. SX-C-001 兼熙 start_date = 2023-10-01' AS check_name,
  CASE WHEN start_date = DATE '2023-10-01' THEN 'PASS' ELSE 'FAIL' END AS status,
  start_date::text AS observed
FROM public.contracts WHERE contract_code = 'SX-C-001';

SELECT
  'A4. SX-C-002 华佑 start_date = 2023-11-01' AS check_name,
  CASE WHEN start_date = DATE '2023-11-01' THEN 'PASS' ELSE 'FAIL' END AS status,
  start_date::text AS observed
FROM public.contracts WHERE contract_code = 'SX-C-002';

SELECT
  'A5. SX-C-004 嘉睿(三层) start_date = 2023-10-01' AS check_name,
  CASE WHEN start_date = DATE '2023-10-01' THEN 'PASS' ELSE 'FAIL' END AS status,
  start_date::text AS observed
FROM public.contracts WHERE contract_code = 'SX-C-004';


-- ============================================================
-- B. New rent_bills exist (华佑 + 刘英)
-- ============================================================

SELECT
  'B1. 华佑 May 2026 rent bill exists' AS check_name,
  CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS status,
  COUNT(*)::text AS observed
FROM public.rent_bills
WHERE lease_package_component_id = 'df2897e5-b881-4ebe-b7b4-3afd8a637ab9'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';

SELECT
  'B2. 华佑 bill amount = 300000.00' AS check_name,
  CASE WHEN amount_due = 300000.00 THEN 'PASS' ELSE 'FAIL' END AS status,
  amount_due::text AS observed
FROM public.rent_bills
WHERE lease_package_component_id = 'df2897e5-b881-4ebe-b7b4-3afd8a637ab9'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';

SELECT
  'B3. 华佑 bill_status = issued' AS check_name,
  CASE WHEN bill_status = 'issued' THEN 'PASS' ELSE 'FAIL' END AS status,
  bill_status AS observed
FROM public.rent_bills
WHERE lease_package_component_id = 'df2897e5-b881-4ebe-b7b4-3afd8a637ab9'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';

SELECT
  'B4. 刘英 May 2026 rent bill exists' AS check_name,
  CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS status,
  COUNT(*)::text AS observed
FROM public.rent_bills
WHERE lease_package_component_id = '0eaadf29-9b41-41d2-b59a-d89de81a2cbf'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';

SELECT
  'B5. 刘英 bill amount = 55000.00' AS check_name,
  CASE WHEN amount_due = 55000.00 THEN 'PASS' ELSE 'FAIL' END AS status,
  amount_due::text AS observed
FROM public.rent_bills
WHERE lease_package_component_id = '0eaadf29-9b41-41d2-b59a-d89de81a2cbf'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';

SELECT
  'B6. 刘英 bill_status = issued' AS check_name,
  CASE WHEN bill_status = 'issued' THEN 'PASS' ELSE 'FAIL' END AS status,
  bill_status AS observed
FROM public.rent_bills
WHERE lease_package_component_id = '0eaadf29-9b41-41d2-b59a-d89de81a2cbf'
  AND billing_month = '2026-05-01'
  AND bill_type = 'rent';


-- ============================================================
-- C. Approval rows exist + approved by Matthew/admin
-- ============================================================

SELECT
  'C1. 华佑 review_status = approved' AS check_name,
  CASE WHEN bar.review_status = 'approved' THEN 'PASS' ELSE 'FAIL' END AS status,
  COALESCE(bar.review_status,'<missing>') AS observed
FROM public.rent_bills rb
LEFT JOIN public.bill_approval_reviews bar ON bar.bill_id = rb.id
WHERE rb.lease_package_component_id = 'df2897e5-b881-4ebe-b7b4-3afd8a637ab9'
  AND rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent';

SELECT
  'C2. 华佑 reviewed_by = Matthew/admin' AS check_name,
  CASE WHEN bar.reviewed_by = 'Matthew/admin' THEN 'PASS' ELSE 'FAIL' END AS status,
  COALESCE(bar.reviewed_by,'<null>') AS observed
FROM public.rent_bills rb
LEFT JOIN public.bill_approval_reviews bar ON bar.bill_id = rb.id
WHERE rb.lease_package_component_id = 'df2897e5-b881-4ebe-b7b4-3afd8a637ab9'
  AND rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent';

SELECT
  'C3. 刘英 review_status = approved' AS check_name,
  CASE WHEN bar.review_status = 'approved' THEN 'PASS' ELSE 'FAIL' END AS status,
  COALESCE(bar.review_status,'<missing>') AS observed
FROM public.rent_bills rb
LEFT JOIN public.bill_approval_reviews bar ON bar.bill_id = rb.id
WHERE rb.lease_package_component_id = '0eaadf29-9b41-41d2-b59a-d89de81a2cbf'
  AND rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent';

SELECT
  'C4. 刘英 reviewed_by = Matthew/admin' AS check_name,
  CASE WHEN bar.reviewed_by = 'Matthew/admin' THEN 'PASS' ELSE 'FAIL' END AS status,
  COALESCE(bar.reviewed_by,'<null>') AS observed
FROM public.rent_bills rb
LEFT JOIN public.bill_approval_reviews bar ON bar.bill_id = rb.id
WHERE rb.lease_package_component_id = '0eaadf29-9b41-41d2-b59a-d89de81a2cbf'
  AND rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent';


-- ============================================================
-- D. Aggregate post-v2.7 totals (May 2026 rent)
-- Expected: 10 issued / 0 draft / total ¥684,922.00
-- ============================================================

SELECT
  'D1. issued bill count = 10' AS check_name,
  CASE WHEN COUNT(*) = 10 THEN 'PASS' ELSE 'FAIL' END AS status,
  COUNT(*)::text AS observed
FROM public.rent_bills
WHERE billing_month = '2026-05-01' AND bill_type = 'rent' AND bill_status = 'issued';

SELECT
  'D2. draft bill count = 0' AS check_name,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
  COUNT(*)::text AS observed
FROM public.rent_bills
WHERE billing_month = '2026-05-01' AND bill_type = 'rent' AND bill_status = 'draft';

SELECT
  'D3. total issued amount = 684922.00' AS check_name,
  CASE WHEN COALESCE(SUM(amount_due),0) = 684922.00 THEN 'PASS' ELSE 'FAIL' END AS status,
  COALESCE(SUM(amount_due),0)::text AS observed
FROM public.rent_bills
WHERE billing_month = '2026-05-01' AND bill_type = 'rent' AND bill_status = 'issued';


-- ============================================================
-- E. Negative-state guarantees (no regressions from v2.6)
-- ============================================================

SELECT
  'E1. 川田 still unbilled (component 1a17c28c…)' AS check_name,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
  COUNT(*)::text AS observed
FROM public.rent_bills
WHERE lease_package_component_id = '1a17c28c-3df6-41d3-b305-3ba50cc62806';

SELECT
  'E2. 朱河芳 still unbilled (component c47ac0c3…)' AS check_name,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
  COUNT(*)::text AS observed
FROM public.rent_bills
WHERE lease_package_component_id = 'c47ac0c3-b963-4222-a4d3-ab07d05b8eac';

SELECT
  'E3. 靖大 master (SX-C-008) still unbilled in May 2026' AS check_name,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
  COUNT(*)::text AS observed
FROM public.rent_bills
WHERE lease_contract_id = (SELECT id FROM public.contracts WHERE contract_code = 'SX-C-008')
  AND billing_month = '2026-05-01';

SELECT
  'E4. payments table empty' AS check_name,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
  COUNT(*)::text AS observed
FROM public.payments;

SELECT
  'E5. payment_allocations table empty' AS check_name,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
  COUNT(*)::text AS observed
FROM public.payment_allocations;

SELECT
  'E6. exception reviews unchanged (3 rows; 1 pending / 1 keep_on_hold / 1 approved)' AS check_name,
  CASE WHEN
    COUNT(*) = 3
    AND COUNT(*) FILTER (WHERE decision_status = 'pending_decision') = 1
    AND COUNT(*) FILTER (WHERE decision_status = 'keep_on_hold') = 1
    AND COUNT(*) FILTER (WHERE decision_status = 'approved_to_issue') = 1
  THEN 'PASS' ELSE 'FAIL' END AS status,
  COUNT(*)::text AS observed
FROM public.shaxi_business_exception_reviews;


-- ============================================================
-- F. Idempotency probe — re-running build is a no-op
-- ============================================================

SELECT
  'F1. no duplicate (component, month, type) bills' AS check_name,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
  COUNT(*)::text AS observed
FROM (
  SELECT lease_package_component_id, billing_month, bill_type, COUNT(*) AS n
  FROM public.rent_bills
  WHERE billing_month = '2026-05-01' AND bill_type = 'rent'
  GROUP BY 1,2,3
  HAVING COUNT(*) > 1
) dup;

SELECT
  'F2. each May 2026 bill has exactly one approval row' AS check_name,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
  COUNT(*)::text AS observed
FROM (
  SELECT rb.id, COUNT(bar.id) AS n
  FROM public.rent_bills rb
  LEFT JOIN public.bill_approval_reviews bar ON bar.bill_id = rb.id
  WHERE rb.billing_month = '2026-05-01' AND rb.bill_type = 'rent'
  GROUP BY rb.id
  HAVING COUNT(bar.id) <> 1
) bad;
