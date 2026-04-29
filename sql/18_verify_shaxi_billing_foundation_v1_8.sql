-- ============================================================
-- sql/18_verify_shaxi_billing_foundation_v1_8.sql
-- Verify billing foundation tables and views for Shaxi v1.8
-- Batch: shaxi_promotion_v1
--
-- Purpose: Prove the billing foundation is healthy and the data
--          underlying it is clean.
--
-- Expected results:
--   - rent_bills, payments, payment_allocations tables exist
--   - required columns and constraints exist
--   - vw_shaxi_billing_readiness returns 1 row with foundation_ready
--   - vw_shaxi_bill_payment_status exists and is safe (0 rows initially)
--   - vw_shaxi_billing_exceptions returns 0 rows
--   - no fake overdue data was generated
--   - existing Shaxi v1.7 views still work
--   - all SQL is idempotent and safe to rerun
-- ============================================================


-- ============================================================
-- 1. TABLES EXIST
-- Expected: 3
-- ============================================================

SELECT
  'SCHEMA: billing tables exist' AS check_name,
  COUNT(*) AS table_count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('rent_bills', 'payments', 'payment_allocations');


-- ============================================================
-- 2. REQUIRED COLUMNS EXIST IN rent_bills
-- Expected: all listed columns found
-- ============================================================

SELECT
  'SCHEMA: rent_bills columns' AS check_name,
  COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'rent_bills'
  AND column_name IN (
    'id', 'lease_contract_id', 'lease_package_component_id', 'tenant_id',
    'billing_month', 'bill_type', 'amount_due', 'due_date', 'bill_status',
    'source_type', 'created_from', 'notes', 'created_at', 'updated_at'
  );


-- ============================================================
-- 3. REQUIRED COLUMNS EXIST IN payments
-- Expected: all listed columns found
-- ============================================================

SELECT
  'SCHEMA: payments columns' AS check_name,
  COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'payments'
  AND column_name IN (
    'id', 'tenant_id', 'payment_date', 'amount_received', 'payment_method',
    'bank_account', 'reference_no', 'payer_name', 'source_type', 'notes',
    'created_at', 'updated_at'
  );


-- ============================================================
-- 4. REQUIRED COLUMNS EXIST IN payment_allocations
-- Expected: all listed columns found
-- ============================================================

SELECT
  'SCHEMA: payment_allocations columns' AS check_name,
  COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'payment_allocations'
  AND column_name IN (
    'id', 'payment_id', 'bill_id', 'allocated_amount', 'created_at'
  );


-- ============================================================
-- 5. CHECK CONSTRAINTS EXIST ON rent_bills
-- Expected: 3 (amount_due_nonneg, bill_status_check, bill_type_check)
-- ============================================================

SELECT
  'SCHEMA: rent_bills check constraints' AS check_name,
  COUNT(*) AS constraint_count
FROM information_schema.table_constraints
WHERE table_schema = 'public'
  AND table_name = 'rent_bills'
  AND constraint_type = 'CHECK'
  AND constraint_name IN (
    'rent_bills_amount_due_nonneg',
    'rent_bills_bill_status_check',
    'rent_bills_bill_type_check'
  );


-- ============================================================
-- 6. CHECK CONSTRAINTS EXIST ON payments
-- Expected: 1 (amount_received_positive)
-- ============================================================

SELECT
  'SCHEMA: payments check constraints' AS check_name,
  COUNT(*) AS constraint_count
FROM information_schema.table_constraints
WHERE table_schema = 'public'
  AND table_name = 'payments'
  AND constraint_type = 'CHECK'
  AND constraint_name = 'payments_amount_received_positive';


-- ============================================================
-- 7. CHECK CONSTRAINTS EXIST ON payment_allocations
-- Expected: 1 (positive)
-- ============================================================

SELECT
  'SCHEMA: payment_allocations check constraints' AS check_name,
  COUNT(*) AS constraint_count
FROM information_schema.table_constraints
WHERE table_schema = 'public'
  AND table_name = 'payment_allocations'
  AND constraint_type = 'CHECK'
  AND constraint_name = 'payment_allocations_positive';


-- ============================================================
-- 8. UNIQUE INDEX EXISTS FOR DUPLICATE-BILL PREVENTION
-- Expected: 1
-- ============================================================

SELECT
  'SCHEMA: duplicate-bill unique index' AS check_name,
  COUNT(*) AS index_count
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'rent_bills'
  AND indexname = 'idx_rent_bills_unique_component_month_type';


-- ============================================================
-- 9. VIEWS EXIST
-- Expected: 3
-- ============================================================

SELECT
  'SCHEMA: billing views exist' AS check_name,
  COUNT(*) AS view_count
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name IN (
    'vw_shaxi_billing_readiness',
    'vw_shaxi_bill_payment_status',
    'vw_shaxi_billing_exceptions'
  );


-- ============================================================
-- 10. BILLING READINESS STATUS
-- Expected: 1 row, readiness_status = 'foundation_ready', counts all 0
-- ============================================================

SELECT
  'VIEW: billing_readiness status' AS check_name,
  readiness_status,
  rent_bill_count,
  payment_count,
  allocation_count
FROM public.vw_shaxi_billing_readiness;


-- ============================================================
-- 11. BILL PAYMENT STATUS VIEW IS SAFE (0 rows initially)
-- Expected: 0
-- ============================================================

SELECT
  'VIEW: bill_payment_status row count' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_bill_payment_status;


-- ============================================================
-- 12. BILLING EXCEPTIONS VIEW RETURNS 0
-- Expected: 0
-- ============================================================

SELECT
  'VIEW: billing_exceptions row count' AS check_name,
  COUNT(*) AS exception_count
FROM public.vw_shaxi_billing_exceptions;


-- ============================================================
-- 13. NO FAKE OVERDUE DATA GENERATED
-- Verify rent_bills is empty (no bills were auto-generated)
-- Expected: 0
-- ============================================================

SELECT
  'DATA: rent_bills row count' AS check_name,
  COUNT(*) AS row_count
FROM public.rent_bills;


-- ============================================================
-- 14. NO FAKE PAYMENT DATA GENERATED
-- Expected: 0
-- ============================================================

SELECT
  'DATA: payments row count' AS check_name,
  COUNT(*) AS row_count
FROM public.payments;


-- ============================================================
-- 15. NO FAKE ALLOCATION DATA GENERATED
-- Expected: 0
-- ============================================================

SELECT
  'DATA: payment_allocations row count' AS check_name,
  COUNT(*) AS row_count
FROM public.payment_allocations;


-- ============================================================
-- 16. EXISTING V1.7 VIEWS STILL WORK
-- vw_shaxi_contract_expiry_watch should still return 10 rows
-- ============================================================

SELECT
  'REGRESSION: v1.7 expiry_watch still works' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_contract_expiry_watch;


-- ============================================================
-- 17. EXISTING V1.7 VIEWS STILL WORK
-- vw_shaxi_area_occupancy_status should still return 44 rows
-- ============================================================

SELECT
  'REGRESSION: v1.7 occupancy_status still works' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_area_occupancy_status;


-- ============================================================
-- 18. EXISTING V1.7 VIEWS STILL WORK
-- vw_shaxi_payment_data_readiness should still return 1 row
-- ============================================================

SELECT
  'REGRESSION: v1.7 payment_readiness still works' AS check_name,
  COUNT(*) AS row_count
FROM public.vw_shaxi_payment_data_readiness;
