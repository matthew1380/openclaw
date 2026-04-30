-- ============================================================
-- sql/36_apply_shaxi_excel_drift_corrections_v2_7.sql
-- Apply Excel↔DB drift corrections + generate master-lease May 2026 bills (v2.7)
-- Batch: shaxi_promotion_v1
--
-- Purpose: Reconcile DB with rent summary Excel (租金汇总表20260420.xls)
--          for the unambiguous discrepancies surfaced on 2026-04-30, AND
--          generate the previously-missing May 2026 rent bills for the
--          two master-lease tenants that have direct Excel evidence.
--
-- Excel sources of truth:
--   * imports/raw/租金汇总表20260420.xls
--     sheet: 出租物业  租金汇总表2026
--     row 44 (#38) — 珍美商贸  end 2027-10-31
--     row 50 (#44) — 中铭→华佑物业  start 2023-11-01, monthly 300000
--     row 52 (#46) — 中铭→刘英      end 2027-10-31
--     rows 40/41 (#34/#35) — 靖大→兼熙/嘉睿  start 2023-10-01
--
-- Changes:
--   1. Contract end_date corrections (off-by-one-day):
--        - SX-C-006 珍美商贸  2027-10-30 -> 2027-10-31
--        - SX-C-010 刘英      2027-10-30 -> 2027-10-31
--   2. Contract start_date drift corrections (DB had 2025; Excel has 2023):
--        - SX-C-001 兼熙服饰  2025-10-01 -> 2023-10-01
--        - SX-C-002 华佑物业  2025-11-01 -> 2023-11-01
--        - SX-C-004 嘉睿服饰  2025-10-01 -> 2023-10-01
--   3. Generate, approve, and issue May 2026 rent bills for the two
--      master-lease tenants that DB previously skipped (no
--      promotion_batch tag → excluded from v1.9 candidate view):
--        - 华佑物业 (SX-C-002, U001) ¥300,000.00
--        - 刘英     (SX-C-010, U011) ¥55,000.00
--      Bills go through the standard draft -> approved -> issued
--      sequence in one script, with Matthew/admin authorization
--      captured per the 2026-04-30 v2.7 decision.
--
-- Out of scope (deliberately deferred):
--   - 珍美 monthly_rent ¥1.00 mismatch (Excel internally inconsistent;
--     waiting on staff to confirm 补充协议 figure).
--   - RA-SX39-Q4-A-GF area_sqm backfill (1352.3m² 口径 unconfirmed).
--   - 鲸鸣 2027 rent escalation to ¥44,704.40 (matters Dec 2026, not now).
--   - 靖大物业 master (SX-C-008) ¥109,337 May 2026 bill (v2.6 hold;
--     master rent + rule still unconfirmed by business).
--
-- Rules:
--   - All UPDATEs are state-guarded; rerun yields UPDATE 0 across the board.
--   - INSERT into rent_bills uses WHERE NOT EXISTS on the unique key
--     (lease_package_component_id, billing_month, bill_type).
--   - INSERT into bill_approval_reviews uses WHERE NOT EXISTS on bill_id.
--   - No fake payments. payments and payment_allocations stay at 0.
--   - No expansion to SX-BCY.
-- ============================================================


-- ============================================================
-- STEP 1: Preview pre-v2.7 state
-- Expected:
--   - 5 contract rows showing the drifted dates
--   - 0 rent_bills for 华佑 and 刘英 components
--   - 8 issued bills for 2026-05-01 (¥329,922.00 total)
-- ============================================================

SELECT
  'PRE_v2.7: contract dates' AS check_name,
  contract_code,
  start_date,
  end_date,
  monthly_rent
FROM public.contracts
WHERE contract_code IN ('SX-C-001','SX-C-002','SX-C-004','SX-C-006','SX-C-010')
ORDER BY contract_code;

SELECT
  'PRE_v2.7: 华佑+刘英 May 2026 bill count' AS check_name,
  COUNT(*) AS bill_count
FROM public.rent_bills
WHERE billing_month = '2026-05-01'
  AND bill_type = 'rent'
  AND lease_package_component_id IN (
    'df2897e5-b881-4ebe-b7b4-3afd8a637ab9',  -- 华佑 RA-ZS-SX-U001
    '0eaadf29-9b41-41d2-b59a-d89de81a2cbf'   -- 刘英 RA-ZS-SX-U011
  );

SELECT
  'PRE_v2.7: issued bill count + outstanding' AS check_name,
  COUNT(*) FILTER (WHERE bill_status = 'issued') AS issued_count,
  COALESCE(SUM(amount_due) FILTER (WHERE bill_status = 'issued'), 0) AS issued_total
FROM public.rent_bills
WHERE billing_month = '2026-05-01'
  AND bill_type = 'rent';


-- ============================================================
-- STEP 2: Correct end_date 2027-10-30 -> 2027-10-31
-- Idempotent: only updates if currently 2027-10-30.
-- ============================================================

UPDATE public.contracts
SET end_date = DATE '2027-10-31'
WHERE contract_code = 'SX-C-006'
  AND end_date = DATE '2027-10-30';

UPDATE public.contracts
SET end_date = DATE '2027-10-31'
WHERE contract_code = 'SX-C-010'
  AND end_date = DATE '2027-10-30';


-- ============================================================
-- STEP 3: Correct start_date drift (DB 2025 -> Excel 2023)
-- Idempotent: only updates if currently the drifted 2025 value.
-- These reflect Excel's recorded original contract start dates.
-- ============================================================

UPDATE public.contracts
SET start_date = DATE '2023-10-01'
WHERE contract_code = 'SX-C-001'
  AND start_date = DATE '2025-10-01';

UPDATE public.contracts
SET start_date = DATE '2023-11-01'
WHERE contract_code = 'SX-C-002'
  AND start_date = DATE '2025-11-01';

UPDATE public.contracts
SET start_date = DATE '2023-10-01'
WHERE contract_code = 'SX-C-004'
  AND start_date = DATE '2025-10-01';


-- ============================================================
-- STEP 4: Insert draft May 2026 rent bills for 华佑 + 刘英
-- Component selection rationale:
--   - 华佑 master lease covers 一区1栋 + 二区A/B/C + 三区B 整体厂房;
--     billing component is RA-ZS-SX-U001 (legacy long-name row that
--     holistically represents the master-lease scope).
--   - 刘英 master lease covers 四区A栋2-4楼 + B栋首层2-4楼;
--     billing component is RA-ZS-SX-U011 (same rationale).
-- Idempotent via WHERE NOT EXISTS on unique key.
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
  '705186dc-d854-4188-a22a-18967cd66ee6'::uuid,  -- SX-C-002 华佑
  'df2897e5-b881-4ebe-b7b4-3afd8a637ab9'::uuid,  -- RA-ZS-SX-U001
  '257382f2-7bd3-40ba-8d5a-6a756aed8fbf'::uuid,  -- 华佑物业 contact
  DATE '2026-05-01',
  'rent',
  300000.00,
  DATE '2026-05-05',
  'draft',
  'master_lease_v2_7',
  'sql/36_apply_shaxi_excel_drift_corrections_v2_7.sql',
  'v2.7 — master-lease bill for 中铭→华佑物业 (一区/二区) per Excel 租金汇总表20260420.xls R50 #44',
  NOW(),
  NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM public.rent_bills rb
  WHERE rb.lease_package_component_id = 'df2897e5-b881-4ebe-b7b4-3afd8a637ab9'
    AND rb.billing_month = '2026-05-01'
    AND rb.bill_type = 'rent'
);

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
  'bb005fbd-3cde-44e4-9443-2efc46ef657d'::uuid,  -- SX-C-010 刘英
  '0eaadf29-9b41-41d2-b59a-d89de81a2cbf'::uuid,  -- RA-ZS-SX-U011
  '48ccaac1-d916-4d5b-b654-7eef4db5371b'::uuid,  -- 刘英 contact
  DATE '2026-05-01',
  'rent',
  55000.00,
  DATE '2026-05-05',
  'draft',
  'master_lease_v2_7',
  'sql/36_apply_shaxi_excel_drift_corrections_v2_7.sql',
  'v2.7 — master-lease bill for 中铭→刘英 (四区A/B宿舍2-4楼) per Excel 租金汇总表20260420.xls R52 #46',
  NOW(),
  NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM public.rent_bills rb
  WHERE rb.lease_package_component_id = '0eaadf29-9b41-41d2-b59a-d89de81a2cbf'
    AND rb.billing_month = '2026-05-01'
    AND rb.bill_type = 'rent'
);


-- ============================================================
-- STEP 5: Insert pending bill_approval_reviews rows
-- Idempotent via WHERE NOT EXISTS on bill_id.
-- ============================================================

INSERT INTO public.bill_approval_reviews (
  bill_id,
  review_status,
  created_from,
  created_at,
  updated_at
)
SELECT
  rb.id,
  'pending_review',
  'sql/36_apply_shaxi_excel_drift_corrections_v2_7.sql',
  NOW(),
  NOW()
FROM public.rent_bills rb
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND rb.lease_package_component_id IN (
    'df2897e5-b881-4ebe-b7b4-3afd8a637ab9',
    '0eaadf29-9b41-41d2-b59a-d89de81a2cbf'
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.bill_approval_reviews bar WHERE bar.bill_id = rb.id
  );


-- ============================================================
-- STEP 6: Approve the two new reviews (Matthew/admin authorized)
-- Idempotent: only updates if currently pending_review.
-- ============================================================

UPDATE public.bill_approval_reviews bar
SET
  review_status = 'approved',
  reviewed_by = 'Matthew/admin',
  reviewed_at = NOW(),
  approval_note = 'v2.7 — master-lease May 2026 bill approved per 2026-04-30 v2.7 decision (bill 华佑+刘英; 靖大 master held).',
  updated_at = NOW()
FROM public.rent_bills rb
WHERE bar.bill_id = rb.id
  AND rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND rb.lease_package_component_id IN (
    'df2897e5-b881-4ebe-b7b4-3afd8a637ab9',
    '0eaadf29-9b41-41d2-b59a-d89de81a2cbf'
  )
  AND bar.review_status = 'pending_review';


-- ============================================================
-- STEP 7: Issue the two bills (draft -> issued)
-- Gated by EXISTS approved review row, so we never issue an
-- unapproved bill even on partially-applied reruns.
-- ============================================================

UPDATE public.rent_bills rb
SET
  bill_status = 'issued',
  updated_at = NOW()
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND rb.lease_package_component_id IN (
    'df2897e5-b881-4ebe-b7b4-3afd8a637ab9',
    '0eaadf29-9b41-41d2-b59a-d89de81a2cbf'
  )
  AND rb.bill_status = 'draft'
  AND EXISTS (
    SELECT 1 FROM public.bill_approval_reviews bar
    WHERE bar.bill_id = rb.id AND bar.review_status = 'approved'
  );


-- ============================================================
-- STEP 8: Preview post-v2.7 contract state
-- Expected: 5 rows with corrected dates.
-- ============================================================

SELECT
  'POST_v2.7: contract dates' AS check_name,
  contract_code,
  start_date,
  end_date,
  monthly_rent
FROM public.contracts
WHERE contract_code IN ('SX-C-001','SX-C-002','SX-C-004','SX-C-006','SX-C-010')
ORDER BY contract_code;


-- ============================================================
-- STEP 9: Preview post-v2.7 bill state
-- Expected: 10 issued bills for 2026-05-01 (¥684,922.00 total).
-- ============================================================

SELECT
  'POST_v2.7: 华佑+刘英 issued bills' AS check_name,
  rb.id AS bill_id,
  con.name AS tenant_name,
  rb.amount_due,
  rb.bill_status,
  bar.review_status,
  bar.reviewed_by
FROM public.rent_bills rb
JOIN public.contacts con ON con.id = rb.tenant_id
LEFT JOIN public.bill_approval_reviews bar ON bar.bill_id = rb.id
WHERE rb.billing_month = '2026-05-01'
  AND rb.bill_type = 'rent'
  AND rb.lease_package_component_id IN (
    'df2897e5-b881-4ebe-b7b4-3afd8a637ab9',
    '0eaadf29-9b41-41d2-b59a-d89de81a2cbf'
  )
ORDER BY rb.amount_due DESC;

SELECT
  'POST_v2.7: total issued + outstanding (May 2026)' AS check_name,
  COUNT(*) FILTER (WHERE bill_status = 'issued') AS issued_count,
  COALESCE(SUM(amount_due) FILTER (WHERE bill_status = 'issued'), 0) AS issued_total
FROM public.rent_bills
WHERE billing_month = '2026-05-01'
  AND bill_type = 'rent';


-- ============================================================
-- STEP 10: No fake payments
-- Expected: 0 / 0
-- ============================================================

SELECT 'POST_v2.7: payments count' AS check_name, COUNT(*) AS row_count FROM public.payments;
SELECT 'POST_v2.7: payment_allocations count' AS check_name, COUNT(*) AS row_count FROM public.payment_allocations;
