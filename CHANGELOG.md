# CHANGELOG.md

## 2026-04-29 (v2.6 — Apply Shaxi Exception Decisions)

**Goal:** Apply the 3 captured business exception decisions from v2.5: keep 川田 on hold (master/sublease chain), approve and issue 杨华禾 May 2026 draft bill, leave 朱河芳 pending pending renewal follow-up.

### v2.6: Decision Application
- `sql/34_apply_shaxi_exception_decisions_v2_6.sql`
  - 中山市川田制衣厂: `pending_decision` → `keep_on_hold`
    - decision_note: "川田 pays rent to 靖大物业; 靖大物业 pays 中铭. Do not issue direct rent bill from 中铭 to 川田 unless policy changes. Future billing should be handled at 靖大物业/master-lease level if confirmed."
    - No new `rent_bills` row created for 川田
    - No new master-lease bill created for 靖大物业 (master rent + rule not yet confirmed)
  - 杨华禾: `pending_decision` → `approved_to_issue`
    - `bill_approval_reviews.review_status`: `pending_review` → `approved` (Matthew/admin)
    - `rent_bills.bill_status`: `draft` → `issued` for bill `4adcf5d2-9b93-497b-b422-327a473e342a` (¥2,500.00)
  - 朱河芳: NO CHANGE. Stays `pending_decision`. 阮绮杨 follow-up still in flight.
  - All 4 UPDATEs are state-guarded (rerun produces `UPDATE 0` × 4). Idempotency confirmed against live DB.
  - No INSERTs into `rent_bills`, `payments`, or `payment_allocations`.
  - No expansion to SX-BCY.

### v2.6: Verification
- `sql/35_verify_shaxi_exception_decisions_v2_6.sql` — 31 checks
  - 川田 decision_status = `keep_on_hold`, decision_note contains "靖大物业" + "中铭" + "Do not issue direct rent bill"
  - 杨华禾 decision_status = `approved_to_issue`, bill_status = `issued`, review_status = `approved`, amount_due = ¥2,500.00
  - 朱河芳 decision_status = `pending_decision`, decision_by IS NULL (truly unchanged)
  - 川田 still unbilled (0 rent_bills rows for component `1a17c28c…`)
  - 朱河芳 still unbilled (0 rent_bills rows for component `c47ac0c3…`)
  - No 靖大物业 master-lease bill created for May 2026
  - payments=0, payment_allocations=0
  - issued bill count: 7 → **8**
  - total outstanding: ¥327,422.00 → **¥329,922.00** (+¥2,500 for 杨华禾)
  - remaining draft bills (May 2026 rent): 1 → **0**
  - mapping_exceptions=0, billing_exceptions=0, payment_allocation_exceptions=0
  - 0 duplicate bills, 0 unsafe-source bills
  - Regression: v1.7 expiry_watch (10), occupancy_status (44), v1.8 billing_readiness (1), v1.9 billing_generation_summary (1) + billing_holds (10), v2.0 bill_review_queue (now 0), v2.1 approval_queue (8), v2.3 outstanding_bills (now 8) + payment_recording_queue (now 8), v2.5 exception_queue (3) — ALL PASS
  - Result: **ALL 31 CHECKS PASSED**

### Documentation Updates
- `docs/SHAXI_HANDOVER_CURRENT.md` — updated to v2.6 with new decision rows, issued bill count 8, total outstanding ¥329,922, 0 remaining draft, exception breakdown 1 pending / 1 keep_on_hold / 1 approved_to_issue
- `PROJECT_MEMORY.md` — updated current state, counts, unresolved items, SQL inventory rows 34/35
- `TODO.md` — added v2.6 Delivered section, updated Current State summary, repointed Next Priority to 朱河芳 renewal follow-up + payment recording

### Post-Verification Counts
- `rentable_areas`: 44 (SX-39)
- `contracts`: 13 (staged + pre-existing)
- `lease_package_components`: 10 (safe, 0 pending)
- `rent_bills`: **8 issued, 0 draft** (2026-05-01, rent)
- `bill_approval_reviews`: **8 approved, 0 pending_review**
- `shaxi_business_exception_reviews`: 3 (1 pending_decision / 1 keep_on_hold / 1 approved_to_issue)
- `payments`: 0
- `payment_allocations`: 0
- Total issued amount: **¥329,922.00**
- Total outstanding: **¥329,922.00**
- Billing holds (true holds, unchanged): 2 (川田 master/sublease, 朱河芳 expired)
- Mapping/billing/payment exceptions: 0
- Duplicates: 0
- Workflow status: `exceptions_pending_decision` (because 朱河芳 still pending)

### Current Decision Required
- **Path A** — Record actual payments against the now 8 issued bills (via Streamlit app or manual SQL). Total receivable: ¥329,922.00.
- **Path B** — Resolve 朱河芳 (renewal vs vacancy) once 阮绮杨 confirms — then update `shaxi_business_exception_reviews` for 朱河芳.
- **Path C** — If/when business confirms master lease rent and rule, generate the 靖大物业 master-lease bill (川田 chain). Until then, 川田 stays on hold.
- **Path D** — Extend to `SX-BCY` (only after Shaxi is fully trusted).

**Blocked from expanding to SX-BCY until Shaxi has both reliable review loop AND trusted operating data.**


## 2026-04-27 — Staff Bill Review Page v2.0 (UI)

Created `scripts/generate_shaxi_bill_review_page.py` — Python 3 standard-library script that queries live Supabase views via psql and generates a static HTML review page.

**Generated output:**
- `reports/shaxi_bill_review_2026-05.html` — read-only staff-facing bill review screen

**Page sections:**
- Summary cards: draft bills (8), issued (0), holds (2), exceptions (0), duplicates (0), readiness (✓)
- Alerts:
  - 杨华禾 — review_before_approve warning
  - 朱河芳 — expiring soon / expired danger
  - 川田 — billing_hold master/sublease warning
- Draft bill review table: 8 rows with tenant, area, amount, due date, status, recommendation, source
- Billing holds table: 川田 + 朱河芳 with reasons and recommended actions
- Safety panel: mapping exceptions PASS, billing exceptions PASS, duplicates PASS, traceability PASS

**Rules followed:**
- No Supabase credentials exposed in committed code
- `.gitignore` updated to exclude `reports/` directory
- Script uses only Python standard library + psql CLI
- Script reads `SUPABASE_DB_URL` from `.env`

**Docs updated:**
- `docs/SHAXI_HANDOVER_CURRENT.md` — updated to v2.0
- `PROJECT_MEMORY.md` — script inventory updated
- `TODO.md` — review page complete; next is payment recording or approval workflow

## 2026-04-27 — Bill Review and Approval Layer v2.0

Created `sql/22_create_shaxi_bill_review_views_v2_0.sql` and `sql/23_verify_shaxi_bill_review_views_v2_0.sql`.

**Views created:**
- `vw_shaxi_bill_review_queue_v2_0` — 8 draft bills requiring human review
  - 7 `review_and_approve`, 1 `review_before_approve` (杨华禾, expires 2026-09-15)
  - All bill_status = 'draft', billing_month = 2026-05-01, bill_type = 'rent'
- `vw_shaxi_billing_hold_review_v2_0` — 2 true holds
  - 川田 (四区B栋首层) — `billing_hold` → recommended action: resolve master/sublease billing rule
  - 朱河芳 (三区A栋首层2卡) — `expired` → recommended action: confirm renewal or vacancy
- `vw_shaxi_bill_issue_readiness_v2_0` — readiness summary
  - Status: `ready_for_human_review`
  - 8 draft bills, 2 holds, 0 exceptions, 0 duplicates, 0 non-draft

**Verification passed:**
- All 21 checks pass
- 8 draft bills in review queue, all trace to safe components
- 2 holds clearly documented with recommended actions
- 0 issued bills, 0 duplicates, 0 exceptions
- Expired (朱河芳) and multiple_active (川田) components remain unbilled
- v1.7, v1.8, v1.9 regression views unchanged

**Docs updated:**
- `docs/SHAXI_HANDOVER_CURRENT.md` — updated to v2.0
- `PROJECT_MEMORY.md` — SQL inventory to file 23, review views documented
- `TODO.md` — review layer complete; next is staff approval workflow or payment recording

## 2026-04-27 — Controlled Rent Bill Generation v1.9

Created `sql/19_create_shaxi_billing_rules_v1_9.sql`, `sql/20_generate_shaxi_rent_bills_v1_9.sql`, and `sql/21_verify_shaxi_rent_bills_v1_9.sql`.

**Billing rule table created:**
- `billing_generation_rules` — controls when/how bills are generated
  - Unique per (property_code, billing_month, bill_type)
  - Inserted one rule: SX-39, 2026-05-01, rent, due_day=5, status=draft → updated to generated

**Candidate view created:**
- `vw_shaxi_rent_bill_candidates_v1_9` — classifies each safe component as:
  - `generate_ready` — eligible for draft bill
  - `billing_hold` — multiple_active area (master/sublease)
  - `expired` — contract not valid for billing month
  - `missing_rent` — invalid rent amount
  - `duplicate_existing` — bill already exists

**Draft bills generated:**
- 8 draft `rent_bills` inserted for 2026-05-01, due 2026-05-05
- All from `controlled_generation` source
- Held:
  - 川田 (四区B栋首层) — `billing_hold` due to multiple_active (靖大物业 master + 川田 sublease)
  - 朱河芳 (三区A栋首层2卡) — `expired` (contract ends 2026-04-30)

**Summary/hold views created:**
- `vw_shaxi_billing_generation_summary_v1_9` — candidate and bill counts
- `vw_shaxi_billing_holds_v1_9` — non-generate-ready candidates with reasons

**Verification passed:**
- All 21 checks pass
- 8 draft bills, 0 non-draft, 0 duplicates
- 0 bills for expired contracts, multiple_active areas, missing rent, or unsafe sources
- Master/sublease and expired cases clearly documented in holds view
- Billing exceptions view: 0 rows
- v1.7 and v1.8 regression views unchanged

**Docs updated:**
- `docs/SHAXI_HANDOVER_CURRENT.md` — updated to v1.9
- `PROJECT_MEMORY.md` — SQL inventory to file 21, billing views/rules documented
- `TODO.md` — bill generation complete; next is payment entry or next-month bills

## 2026-04-27 — Billing Foundation v1.8

Created `sql/17_create_shaxi_billing_foundation_v1_8.sql` and `sql/18_verify_shaxi_billing_foundation_v1_8.sql`.

**Tables created:**
- `rent_bills` — expected rental charges
  - 14 columns, CHECK constraints on amount_due >= 0, bill_status, bill_type
  - Unique index on (lease_package_component_id, billing_month, bill_type) to prevent duplicates
  - FKs to contracts, lease_package_components, contacts
  - Empty at creation (no fake data)
- `payments` — actual money received
  - 12 columns, CHECK constraint on amount_received > 0
  - FK to contacts
  - Empty at creation
- `payment_allocations` — connects payments to bills
  - 5 columns, CHECK constraint on allocated_amount > 0
  - FKs to payments and rent_bills with RESTRICT delete
  - Empty at creation

**Views created:**
- `vw_shaxi_billing_readiness` — foundation status (1 row, `foundation_ready`, all counts 0)
- `vw_shaxi_bill_payment_status` — bill + allocated + outstanding + computed status (0 rows initially)
- `vw_shaxi_billing_exceptions` — exception detector (0 rows)

**Verification passed:**
- All 18 checks pass (tables, columns, constraints, indexes, views, readiness, exceptions, empty-data confirmation, regression tests for v1.7 views)
- No fake overdue data generated
- Existing v1.7 views unchanged and working

**Docs updated:**
- `docs/SHAXI_HANDOVER_CURRENT.md` — updated to v1.8
- `PROJECT_MEMORY.md` — SQL inventory to file 18, table/view descriptions
- `TODO.md` — billing foundation complete; next is bill generation rules or site expansion

## 2026-04-27 — Operating Data Views v1.7

Created `sql/15_create_shaxi_operating_views_v1_7.sql` and `sql/16_verify_shaxi_operating_views_v1_7.sql`.

**Views created:**
- `vw_shaxi_contract_expiry_watch` — 10 rows, expiry risk for safe components
  - 1 contract expiring within 30 days: 朱河芳 (SX-C-011, ends 2026-04-30)
  - 9 contracts active over 90 days
- `vw_shaxi_area_occupancy_status` — 44 rows, all SX-39 rentable_areas
  - 34 occupied, 9 no_component, 1 multiple_active (RA-SX39-Q4-B-GF: 靖大物业 + 川田)
  - Area origin breakdown: 9 canonical_approved + 9 canonical_promoted + 13 legacy_existing + 2 legacy_corrected + 11 other
- `vw_shaxi_payment_data_readiness` — 1 row, readiness check
  - Status: `seeded_only` — financial_records has 6 seeded backlog rows, but no real billing/payment tables exist
  - Clearly explains that overdue reporting cannot be trusted until rent_bills, payments, invoices tables are introduced

**Verification passed:**
- All 15 verification checks pass (row counts, source breakdown, expiry classification, duplicate checks, tenant completeness, payment readiness, schema existence)
- 0 unsafe sources in expiry view
- 0 duplicate area rows in occupancy view
- 0 occupied areas with missing tenant

**Docs updated:**
- `docs/SHAXI_HANDOVER_CURRENT.md` — updated to v1.7, added operating views section
- `PROJECT_MEMORY.md` — SQL inventory updated to file 16, view descriptions added
- `TODO.md` — operating views complete; next priority is introduce real billing/payment tables or enhance reporting further

## 2026-04-27 — Staff Reporting Views v1.6

Created `sql/13_create_shaxi_staff_reporting_views_v1_6.sql` and `sql/14_verify_shaxi_staff_reporting_views_v1_6.sql`.

**Views created:**
- `vw_shaxi_lease_component_review` — 10 rows, one per safe component
  - Shows tenant, contract, area, building, source type, audit columns
  - 9 approved_candidate + 1 exact_original_match
- `vw_shaxi_mapping_exceptions` — 0 rows (data is clean)
  - Detects missing contract/area, duplicate components, pending candidate links, unexpected created_from, staged contracts without safe components
- `vw_shaxi_reporting_summary` — single-row summary
  - verified_contracts: 10, safe_components: 10, approved_candidates: 9, pending_candidates: 0, duplicate_components: 0, exception_rows: 0

**Verification passed:**
- All 13 verification checks pass (row counts, source breakdown, exception count, traceability, schema existence)

**Docs updated:**
- `docs/SHAXI_HANDOVER_CURRENT.md` — created with full v1.5 handover state and v1.6 view inventory.
- `PROJECT_MEMORY.md` — added SQL file inventory, view descriptions, next session instructions.
- `TODO.md` — reporting views complete; next is operational enhancements (overdue, vacancy, expiry).

## 2026-04-27 — Resolve 3 Pending Candidates v1.5

Created and executed `sql/12_resolve_pending_candidates_v1_5.sql`.

**Classification (all 3 approved as new areas):**
- 鲸鸣服饰 — 三区A栋4层 → approve_new_area, scope 整层
- 杨华禾 — 三区A栋首层1卡 → approve_new_area
- 朱河芳 — 三区A栋首层2卡 → approve_new_area

**Actions:**
- Updated 3 candidate rows with review_decision = 'approve_new_area'.
- Created 3 new canonical rentable_areas:
  - `RA-SX39-Q3-A-4层` = 三区A栋4层
  - `RA-SX39-Q3-A-首层1卡` = 三区A栋首层1卡
  - `RA-SX39-Q3-A-首层2卡` = 三区A栋首层2卡
- Created 3 safe lease_package_components linking units to canonical areas.

**Verification passed:**
- pending_review candidates: 0
- components for pending candidates: 0
- duplicate components: 0
- total safe components for batch: 10 (7 from v1_4 + 3 from v1_5)
- all components traceable to approved or exact original source
- 0 duplicate rentable_areas

**State after v1.5:**
- 11 staged areas promoted, 9 approved candidate areas created (was 6).
- 10 contracts verified.
- 10 safe lease_package_components (was 7).
- 0 candidates pending review (was 3).
- 0 duplicates, 0 leaks.

**Docs updated:**
- `PROJECT_MEMORY.md` — updated verified counts, pending candidates, next steps.
- `TODO.md` — pending candidates resolved; next path is staff-facing reporting view.

## 2026-04-27 — Handover Docs Refresh

Refreshed project docs with clean v1.4 handover state (no schema or data changes).

**Docs updated:**
- `PROJECT_MEMORY.md` — added "Current Verified Counts" table, refreshed "Next Session Start Here" with Option A / Option B.
- `TODO.md` — rewritten with two clear next paths: resolve 3 pending candidates vs build staff-facing review view.

**Current state unchanged from 2026-04-26:**
- 11 staged areas promoted, 6 approved candidate areas created, 10 contracts verified.
- 7 safe `lease_package_components`, 3 candidates `pending_review`, 0 duplicates, 0 leaks.

## 2026-04-26 — Session Handover

**Status:** Shaxi promotion pipeline complete through v1.4 (safe lease_package_components). Pausing for next session.

**Verified state:**
- 11 staged areas promoted to `rentable_areas` (9 new + 2 pre-existing).
- 10 staged contracts present in `contracts` with source audit fields.
- 6 approved candidate areas created in `rentable_areas`.
- 7 safe `lease_package_components` created linking units to canonical areas.
- 3 candidates remain `pending_review` (鲸鸣4层, 杨华禾首层1卡, 朱河芳首层2卡).
- 0 duplicates, 0 accidental components, 0 schema violations.

**Docs updated:**
- `PROJECT_MEMORY.md` — rewritten with current state, SQL inventory, and "Next Session Start Here" section.
- `README.md` — updated current pilot scope and what already works.
- `WORKFLOW.md` — updated stage snapshot, added psql connection pattern and SQL promotion workflow.
- `sql/README.md` — created with file inventory, verification guide, and next session instructions.

**Next session commands:**
```powershell
$line = Get-Content .env | Where-Object { $_ -match "^SUPABASE_DB_URL=" } | Select-Object -First 1
$dbUrl = $line.Split("=",2)[1].Trim().Trim('"')
psql $dbUrl -f sql/03_verify_shaxi_v1.sql
```

## 2026-04-26

- Created `sql/03_verify_shaxi_v1.sql` — read-only verification script for Shaxi promotion batch `shaxi_promotion_v1`:
  - Schema awareness checks:
    - FK integrity: `rentable_areas.property_id -> properties.id` (0 invalid).
    - FK integrity: `rentable_areas.building_id -> building_registry.id` (0 invalid).
    - Mandatory field: `properties.property_code` (0 null/empty).
    - Mandatory field: `building_registry.building_code` (0 null/empty).
  - Staged area lookup verification:
    - `stg_shaxi_areas_prepared` = 11 rows.
    - Matched properties = 11, matched buildings = 11.
    - Missing property matches = 0, missing building matches = 0.
  - `promotion_contract_area_candidates` verification:
    - Dedup status: CLEAN (9 distinct groups, 9 raw rows, max duplicate per group = 1).
    - Pending review rows = 9 (`contract_area_not_found_in_staged_area_truth`).
  - Transparency query listing the 9 expected unmatched contract-area sources.
  - Does NOT insert, update, delete, or promote anything.
  - Does NOT write to `lease_package_components`.

- Created `sql/02_promote_shaxi_v1.sql` — promotion script for Shaxi staging -> operational truth:
  - Promotes 11 staged areas from `stg_shaxi_areas_prepared` into `rentable_areas` using UUID FKs:
    - `property_code -> properties.id`
    - `building_code -> building_registry.id`
  - Generates unique `area_code` per row (`RA-{building_code}-{area_suffix}`).
  - Maps `unit_type_raw` (`厂房/宿舍`) to English `area_type` (`factory/dormitory`).
  - Idempotent insert using `WHERE NOT EXISTS` on `(property_id, building_id, area_name)`.
  - 9 new rows inserted; 2 rows skipped because they already existed in `rentable_areas`.
  - Does NOT promote the 9 pending candidate rows.
  - Does NOT create `lease_package_components`.

- Updated `sql/03_verify_shaxi_v1.sql` with post-promotion verification section:
  - Confirms 11 staged areas now exist in `rentable_areas`.
  - Confirms 0 duplicate area names per building for SX-39.
  - Confirms 9 candidates still pending review.
  - Confirms 0 accidental `lease_package_components` created for newly promoted areas.

- Created `sql/04_promote_shaxi_contracts_v1_1.sql` — contract promotion script for Shaxi staging -> operational truth:
  - Promotes 10 staged contracts from `stg_shaxi_contracts_prepared` into `contracts`.
  - Idempotent insert using `WHERE NOT EXISTS` on `(tenant_id, unit_id, start_date, end_date)`.
  - Derives `unit_id` by matching to existing contracts on (tenant, rent, dates).
  - Maps `payee_raw` to `landlord_op_entity_id` (靖大 -> JD-SX, 中铭公司 -> ZM-SX).
  - Maps `current_status` `在租` -> `active` with explicit enum cast.
  - Generates sequential `contract_code` (SX-C-{next}) for genuinely new rows.
  - Inserted 0 new rows on current run (all 10 already existed in `contracts`).
  - Does NOT create `lease_package_components`.
  - Keeps 9 unmatched candidates in `promotion_contract_area_candidates`.
  - Documents schema limitation: `contracts` table lacks a notes/source column for preserving mapped fields (`mapped_property_code`, `mapped_building_code`, `mapped_area_name`, etc.).

- Updated `sql/03_verify_shaxi_v1.sql` with contract promotion verification section:
  - Confirms 10 staged contracts now exist in `contracts`.
  - Confirms 0 duplicate contracts per `(tenant_id, unit_id, start_date, end_date)`.
  - Confirms 9 candidates still pending review.

- Created `sql/05_add_contract_source_audit_fields.sql` — schema change + backfill for contract traceability:
  - Added 14 audit/source columns to `public.contracts` via `ADD COLUMN IF NOT EXISTS`:
    - `source_company`, `source_rented_unit_text`, `source_payee_raw`, `source_remarks_raw`
    - `mapped_property_code`, `mapped_parcel_code`, `mapped_building_code`
    - `mapped_building_name`, `mapped_area_name`, `mapped_confidence`
    - `source_staging_table`, `promotion_batch`, `staging_imported_at`
    - `source_metadata` (jsonb)
  - Idempotent backfill from `stg_shaxi_contracts_prepared` into existing contracts:
    - Matched on `(tenant_id, unit_id, start_date, end_date)` via contact name join.
    - Updated 10 Shaxi contracts.
    - Did NOT change `contract_status`.
    - Did NOT create `lease_package_components`.
    - Did NOT resolve 9 pending candidates.
  - `source_metadata` jsonb stores extra fields: `current_status`, `load_batch_note`.

- Updated `sql/03_verify_shaxi_v1.sql` with source audit verification section (Section 6):
  - Confirms 10 contracts have `promotion_batch = 'shaxi_contracts_v1_1'`.
  - Confirms 10 contracts have `source_rented_unit_text IS NOT NULL`.
  - Confirms 10 contracts have `mapped_area_name IS NOT NULL`.
  - Confirms 9 candidates remain `pending_review`.

- Created `sql/06_prepare_candidate_review_v1_2.sql` — candidate review flow preparation:
  - Added 13 review-resolution columns to `promotion_contract_area_candidates`:
    - Decision: `review_decision`
    - Approved area details: `approved_area_name`, `approved_area_type`, `approved_floor_label`, `approved_card_or_room_label`, `approved_area_sqm`, `approved_leaseable_scope`, `approved_current_status`
    - Resolution tracking: `target_rentable_area_id`, `reviewed_by`, `reviewed_at`, `resolved_at`, `resolution_notes`
  - Added `CHECK` constraint `chk_review_decision_values` allowing NULL or values in (`approve_new_area`, `map_existing_area`, `reject_or_defer`).
  - Created read-only view `vw_shaxi_contract_area_candidates_pending` exposing:
    - All candidate fields
    - Exact rentable area match (if any) via LEFT JOIN
    - All new review columns
  - Does NOT auto-resolve candidates.
  - Does NOT create lease_package_components.
  - Does NOT guess 1层 vs 首层 or whole-building cases.

- Created `sql/07_verify_candidate_review_v1_2.sql` — verification script for candidate review flow:
  - Confirms 9 pending candidates still exist.
  - Confirms all 13 new review columns exist.
  - Confirms check constraint exists.
  - Confirms view returns 9 rows with 20 columns.
  - Confirms 0 accidental lease_package_components created.
  - Confirms 0 auto-resolved candidates.

- Created `sql/08_export_candidate_review_list_v1_2.sql` — read-only export of human-readable review list:
  - Selects from `vw_shaxi_contract_area_candidates_pending`.
  - Classifies each candidate into `suggested_review_question`:
    - `1层 vs 首层 wording issue` (2 rows: 珍美 1层1卡, 嘉睿 1层第三卡)
    - `whole-building / broad-building candidate` (2 rows: 素语 四区C栋, 陈盼 三区C栋)
    - `floor-level area missing from area truth` (5 rows: 兼熙 2层, 嘉睿 3层, 鲸鸣 4层, 杨华禾 首层1卡, 朱河芳 首层2卡)
  - `suggested_decision` explicitly set to `needs_human_review` for all rows.
  - `suggested_approved_area_name` left NULL (no auto-resolution).
  - `reviewer_note_template` includes candidate context, rent, dates, source, and specific review guidance.
  - Read-only: does NOT update data, does NOT auto-resolve, does NOT create components.

- Created `sql/09_apply_candidate_decisions_v1_2.sql` — apply human review decisions to candidate table:
  - Records staff decisions for 6 candidates:
    - 素语 四区C栋 → `approve_new_area`, approved name `四区C栋`, scope `整栋`
    - 珍美 三区A栋1层1卡 → `approve_new_area`, approved name `三区A栋1层1卡`, keep as-is
    - 嘉睿 三区A栋1层第三卡 → `approve_new_area`, approved name `三区A栋1层3卡`, normalized 第三卡→3卡
    - 兼熙 三区A栋2层 → `approve_new_area`, approved name `三区A栋2层`, scope `整层`
    - 嘉睿 三区A栋3层 → `approve_new_area`, approved name `三区A栋3层`, scope `整层`
    - 陈盼 三区C栋 → `approve_new_area`, approved name `三区C栋`, scope `整栋`
  - 3 candidates remain pending (鲸鸣 4层, 杨华禾 首层1卡, 朱河芳 首层2卡) — no explicit decision.
  - Does NOT create rentable_areas or lease_package_components.
  - Sets `reviewed_by = 'human_review_2026-04-26'` and `reviewed_at = NOW()`.

- Created `sql/10_apply_approved_candidate_areas_v1_3.sql` — create rentable_areas from approved candidates:
  - Inserted 6 new rentable_areas rows for approved candidates:
    - `RA-SX39-Q4-C-整栋` = 四区C栋 (factory, 整栋)
    - `RA-SX39-Q3-A-1层1卡` = 三区A栋1层1卡 (factory)
    - `RA-SX39-Q3-A-1层3卡` = 三区A栋1层3卡 (factory)
    - `RA-SX39-Q3-A-2层` = 三区A栋2层 (factory, 整层)
    - `RA-SX39-Q3-A-3层` = 三区A栋3层 (factory, 整层)
    - `RA-SX39-Q3-C-整栋` = 三区C栋 (dormitory, 整栋)
  - Inferred `area_type` from existing unit's primary lease_package_component:
    - 5 factory, 1 dormitory
  - Derived `floor_label` from approved area name suffix for floor/card areas.
  - Idempotent via `WHERE NOT EXISTS` on `(property_id, building_id, area_name)`.
  - Backfilled `target_rentable_area_id` on all 6 candidate rows.
  - Marked 6 candidates `review_status = 'area_created'`, `resolved_at = NOW()`.
  - 3 candidates remain `pending_review` (鲸鸣 4层, 杨华禾 首层1卡, 朱河芳 首层2卡).
  - Does NOT create `lease_package_components`.

- Updated `sql/03_verify_shaxi_v1.sql` with approved candidate verification section (Section 7):
  - Confirms 6 approved candidates have `target_rentable_area_id`.
  - Confirms 6 approved candidates have `review_status = 'area_created'`.
  - Confirms 3 candidates remain `pending_review`.
  - Confirms 0 duplicate rentable_areas.
  - Confirms 0 accidental `lease_package_components`.

- Created `sql/11_create_safe_lease_package_components_v1_4.sql` — create safe contract-area links:
  - Added 4 audit columns to `lease_package_components`:
    - `promotion_batch`, `source_candidate_id`, `source_staging_table`, `created_from`
  - Created 7 safe components:
    - 1 exact original match: 川田 U012 → `RA-SX39-Q4-B-GF` (四区B栋首层)
    - 6 approved candidate links:
      - 素语 U013 → `RA-SX39-Q4-C-整栋`
      - 珍美 U003 → `RA-SX39-Q3-A-1层1卡`
      - 嘉睿 U004 → `RA-SX39-Q3-A-1层3卡`
      - 兼熙 U006 → `RA-SX39-Q3-A-2层`
      - 嘉睿 U005 → `RA-SX39-Q3-A-3层`
      - 陈盼 U010 → `RA-SX39-Q3-C-整栋`
  - Idempotent via `WHERE NOT EXISTS` on `(package_unit_id, rentable_area_id)`.
  - Component role set to `'component'`.
  - Does NOT touch 3 still-pending candidates.
  - Does NOT guess unresolved area links.

- Updated `sql/03_verify_shaxi_v1.sql` with lease_package_components verification section (Section 8):
  - Confirms 7 safe components created for batch.
  - Confirms 3 candidates remain `pending_review`.
  - Confirms 0 components created for pending candidates.
  - Confirms 0 duplicate components.

## 2026-04-24

- Corrected `public.stg_shaxi_areas_prepared` column names in repo docs:
  - Actual columns do **not** use `mapped_*` prefixes.
  - Real columns: `property_code`, `parcel_name`, `parcel_code`, `building_code`, `building_name_current`, `prepared_area_name`, `normalized_scope_text`, `unit_type_raw`, `avg_area_sqm_raw`, `avg_monthly_rent_raw`, `rent_range_raw`, `remarks_raw`, `source_companies`, `source_count`, `load_batch_note`, `imported_at`.
- Added promotion SQL to `WORKFLOW.md` for `stg_shaxi_areas_prepared` -> `rentable_areas`:
  - Area preview query (11 rows expected).
  - Duplicate check query (0 rows expected).
  - Final `insert into public.rentable_areas(...)` with explicit column mapping.
- Created `promote_shaxi_v1.sql` — full promotion script for Shaxi staging -> operational truth:
  - Area promotion section (`stg_shaxi_areas_prepared` -> `rentable_areas`).
  - Contract-area candidate section: finds contracts whose mapped area is missing from staged area truth.
  - Deduplication logic for `promotion_contract_area_candidates` (keeps earliest row per logical candidate).
  - Unique index on `(promotion_batch, source_company, tenant_name, mapped_property_code, mapped_parcel_code, mapped_building_code, mapped_area_name)`.
  - Idempotent insert with `ON CONFLICT DO NOTHING`.
  - Expected unmatched candidates: 9 (`pending_review` / `contract_area_not_found_in_staged_area_truth`).
- Restructured `promote_shaxi_v1.sql` to clearly separate human mapping notes from executable SQL:
  - Removed `->` from mapping notes (valid PostgreSQL JSON operator) to prevent accidental execution.
  - Human notes now prefixed with `-- HUMAN NOTE:`.
  - Added schema inspection queries for `properties` and `buildings` as commented templates.

## 2026-04-23

- Tooling and workflow baseline complete:
  - Kimi Code confirmed working in VS Code
  - GitHub workflow confirmed working
  - Local workflow folders established: `imports/raw/`, `imports/cleaned/`, `imports/review/`
  - `.gitignore` excludes local batch/import files
- Script status: `rent_summary_cleaner.py`, `shaxi_parcel_building_mapper.py`, `vacancy_summary_cleaner.py` are stable for current stage.
- Script refinements:
  - `rent_summary_cleaner.py`: supports real Shaxi confidence labels; `high_confidence_candidate` treated as clean/high; `needs_manual_review` remains review-triggering
  - `shaxi_parcel_building_mapper.py`: normalizes full-address Shaxi strings before matching (removes common site prefix, converts parcel brackets like `（三区）` -> `三区`, removes `【原...】` legacy suffixes, normalizes floor wording such as `二层` -> `2层`); broad bundled descriptions still sent to review
  - `vacancy_summary_cleaner.py`: broad area names marked unclear even with only one active contract
- Raw source preparation completed:
  - `imports/raw/shaxi_contracts_raw.csv` — combined from `shaxi_tenants_zhongming.csv` + `shaxi_tenants_jingda.csv`; blank rows and instruction rows removed
  - `imports/raw/shaxi_area_skeleton_raw.csv` — combined from `shaxi_buildings_zhongming.csv` + `shaxi_buildings_jingda.csv`; correct source columns used
  - `imports/raw/locations.csv` — extracted from `shaxi_contracts_raw.csv`
- Cleaned / review outputs created and verified:
  - `imports/cleaned/shaxi_mapped_locations.csv`
  - `imports/review/shaxi_mapping_review_queue.csv`
  - `imports/cleaned/shaxi_contracts_prepared.csv`
  - `imports/review/shaxi_contracts_mapping_review.csv`
  - `imports/cleaned/shaxi_area_skeleton_prepared.csv`
  - `imports/review/shaxi_area_skeleton_review.csv`
- Prepared contract logic completed:
  - Excel serial dates converted to ISO dates
  - Mapped fields attached from `shaxi_mapped_locations.csv`
  - Low-confidence/broad bundle rows preserved but marked `review_required`
  - Precise mapped rows marked `mapped`
- Prepared area logic completed:
  - Current parcel/building inferred from `property_internal_name` where possible
  - Building scope normalized from `building_name_raw`
  - Broad floor-range rows remain `review_required`
  - Precise rows such as `首层` / `首层1卡` / `夹层` are prepared
  - Known unresolved row remains: `一区 原建泰第1座` still `review_required` because current parcel/building inference for that legacy naming is not yet handled
- Stage-ready exports completed:
  - `imports/cleaned/shaxi_contracts_stage_ready.csv` (10 rows)
  - `imports/cleaned/shaxi_area_stage_ready.csv` (14 rows)
  - `imports/cleaned/shaxi_area_stage_canonical.csv` (11 rows)
- Supabase staging completed:
  - Created and loaded `public.stg_shaxi_contracts_prepared` (10 rows)
  - Created and loaded `public.stg_shaxi_areas_prepared` (11 rows)
- Current interpretation / business rules recorded:
  - Broad bundle rows stay out of stage-ready contract import
  - Broad floor-range area rows stay out of stage-ready area import
  - Shaxi remains the active pilot site
  - Current work is still a preparation/staging pipeline, not final promotion into all final truth tables

## 2026-04-22

- Set up Kimi Code in VS Code and confirmed repo-based workflow is working.
- Added and refined 3 local cleanup / preparation scripts:
  - `scripts/rent_summary_cleaner.py`
  - `scripts/shaxi_parcel_building_mapper.py`
  - `scripts/vacancy_summary_cleaner.py`
- Completed real mini-batch tests for all 3 scripts.
- Refined `rent_summary_cleaner.py` to support real Shaxi confidence labels:
  - `high_confidence_candidate` now maps to clean/high
  - `needs_manual_review` remains review-triggering
- Refined `shaxi_parcel_building_mapper.py` to normalize full-address Shaxi strings before matching:
  - removes common site prefix
  - converts parcel brackets like `（三区）` to `三区`
  - removes `【原...】` legacy suffixes
  - normalizes floor wording such as `二层 -> 2层`
  - keeps broad bundled descriptions in review
- Refined `vacancy_summary_cleaner.py` so broad area names are marked `unclear` even when only one active contract exists.
- Real mini-batch results:
  - rent summary cleaner: `3 cleaned / 1 review`
  - Shaxi mapper: precise rows mapped, broad bundled rows stayed in review
  - vacancy cleaner: `20 occupied / 0 vacant / 6 unclear`
- Created local workflow folders:
  - `imports/raw/`
  - `imports/cleaned/`
  - `imports/review/`
- Added `.gitignore` rules so local import/test data is not committed.
- Converted uploaded Excel workbooks to CSV and copied selected raw inputs into `imports/raw/`.
- Built `imports/raw/shaxi_contracts_raw.csv` from Shaxi tenant CSVs.
- Built `imports/raw/shaxi_area_skeleton_raw.csv` from Shaxi building CSVs using corrected source-column mapping.
- Built `imports/raw/locations.csv` from `shaxi_contracts_raw.csv` and ran mapping successfully.
- Confirmed GitHub is up to date after script/doc commits.

## 2026-04-18
- Created initial project restart documentation
- Defined Rental OS as the first project scope
- Confirmed Supabase as official database starting point
- Confirmed Tencent Cloud as preferred hosting direction
- Confirmed one-month internal MVP goal
- Confirmed top priorities: tenant/contract lookup, overdue, vacancy

## 2026-04-20
- Cleaned and loaded current rent summary staging data
- Built first-pass 2026 YTD overdue review logic
- Confirmed Shaxi package contracts and Shaxi contract backbone are working
- Seeded matched `SX-39` overdue backlog rows into `financial_records`
- Built BCY shop contract layer and linked BCY overdue candidates
- Created combined Shaxi overdue backlog covering `SX-39` and `SX-BCY`

## 2026-04-21
- Confirmed Shaxi should be modeled as `site -> land parcel -> building -> rentable area -> lease package -> contract`
- Added `land_parcels` table for Shaxi parcel truth
- Added parcel-aware building mapping for `一区 / 二区 / 三区 / 四区`
- Added `building_registry`, `rentable_areas`, and `lease_package_components` as the middle-layer skeleton
- Decomposed complex Shaxi package leases into component rentable areas
- Added Shaxi contract role mapping (`direct_lease`, `master_lease`, `sublease`)
- Added contract location reconciliation and manual override support
- Corrected `SX-C-011` and `SX-C-012` from old `三区A` interpretation to `四区A` current physical truth
- Created preferred physical-area logic for Shaxi current operational truth
- Reduced Shaxi unresolved cleanup queue to a small set of review items (`SX-C-006`, `SX-C-008`, `SX-C-010`)
- Added `scripts/rent_summary_cleaner.py` for staging rent summary CSV cleanup with review queue routing
- Added `scripts/vacancy_summary_cleaner.py` for vacancy/occupancy reporting from area and contract CSVs
- Added `scripts/shaxi_parcel_building_mapper.py` for mapping raw Chinese location strings to normalized parcel/building/area codes
- Updated `AGENTS.md` repo structure to reflect new `scripts/` directory

## 2026-04-21 (revised scripts)
- Revised `scripts/rent_summary_cleaner.py` to match real pilot fields:
  `property_code_hint`, `rent_collector`, `property_group`, `tenant_name`,
  `paying_unit_text`, `monthly_rent_due`, `received_ytd`, `expected_rent_ytd_simple`,
  `ytd_gap_simple`, `overdue_confidence`, `remarks`.
  - Never guesses `unit_code` or `contract_code`.
  - Normalizes `overdue_confidence` flexibly to high/medium/low/unknown;
    unmapped values route to review queue.
  - Cross-checks `ytd_gap_simple` against `expected - received`.
- Revised `scripts/shaxi_parcel_building_mapper.py` to treat broad vague remainders
  (e.g. `主租区域`, `整栋`, `首层及2至4楼` without card specificity) as
  low-confidence review items. Consolidated duplicate regex logic.
- Revised `scripts/vacancy_summary_cleaner.py`:
  - Understands contract hierarchy (`direct_lease`, `master_lease`, `sublease`).
  - Master/sub overlap marked `occupied` only when component roles confirm
    structural expectation (`primary` master + `component`/`corrected_component` subleases).
  - Outputs readable `unit_code`; requires `--units` CSV if `contracts.csv` lacks `unit_code`.
  - Documents expected input CSV schemas in script docstring.


## 2026-04-27 (v2.0 — Bill Review Layer + Staff-Facing HTML Page)

**Goal:** Close the loop: provide Shaxi staff with a human-readable review page generated from live v2.0 views.

### v2.0: Bill Review Views
- `sql/22_create_shaxi_bill_review_views_v2_0.sql`
  - `vw_shaxi_bill_review_queue_v2_0` — 8 draft bills with `review_recommendation`
    (`review_and_approve` / `review_before_approve`) based on contract expiry risk.
  - `vw_shaxi_billing_hold_review_v2_0` — 2 non-billed safe components with `hold_reason`
    and `recommended_action`.
  - `vw_shaxi_bill_issue_readiness_v2_0` — single-row readiness summary.
    Status: `ready_for_human_review` when draft=8, exceptions=0, duplicates=0, non-draft=0.

### v2.0: Bill Review Verification
- `sql/23_verify_shaxi_bill_review_views_v2_0.sql` — 21 checks
  - Row counts: queue=8, holds=2, readiness=1
  - Data quality: all draft, all 2026-05-01, all rent, 0 non-draft, 0 duplicates, 0 exceptions
  - Traceability: 0 unsafe bills, expired component unbilled=0, multiple_active unbilled=0
  - Regression: v1.7 expiry_watch=10, occupancy=44; v1.8 billing_readiness=1; v1.9 summary=1, holds=10
  - Result: ALL PASSED

### v2.0: Staff-Facing HTML Review Page
- `reports/shaxi_bill_review_2026-05.html` — self-contained static HTML page (excluded from Git)
  - Summary cards: 8 Draft, 0 Issued, 2 Holds, 0 Exceptions, 0 Duplicates, Ready For Human Review
  - Alerts: 杨华禾 flagged `review_before_approve`; 朱河芳 expiry danger; 川田 master/sublease hold
  - Draft bill table: tenant, area, billing_month, amount_due, due_date, status, recommendation
  - Billing hold table: tenant, area, status, reason, recommended action
  - Safety panel: Mapping PASS, Billing PASS, Duplicates PASS, Traceability PASS
- `scripts/generate_shaxi_bill_review_page.py` — standalone Python generator
  - Queries live views via psycopg2
  - Outputs self-contained HTML with embedded CSS
  - Regenerates from fresh DB state on each run

### Documentation Updates
- `TODO.md` — updated with four clear paths (A/B/C/D) for next session
- `docs/SHAXI_HANDOVER_CURRENT.md` — added script section, HTML page description, and regeneration instructions

### Post-Verification Counts
- `rentable_areas`: 44 (SX-39)
- `contracts`: 13 (staged)
- `lease_package_components`: 10 (safe, 0 pending)
- Draft `rent_bills`: 8
- Billing holds: 2 (川田 master/sublease, 朱河芳 expired)
- Exceptions: 0
- Duplicates: 0
- Leaked pending candidates: 0
- HTML review page: 1 generated

### Current Decision Required
Choose between:
- **Path A** — Record actual payments against draft bills
- **Path B** — Build staff approval workflow (approve before issuance)
- **Path C** — Resolve held cases (master/sublease rule, expired renewal)
- **Path D** — Extend to `SX-BCY` (only after Shaxi fully trusted)

**Blocked from expanding to SX-BCY until Shaxi has both reliable review loop AND trusted operating data.**


## 2026-04-27 (v2.1 — Staff Approval Workflow)

**Goal:** Build a minimal approval gate so draft bills cannot be issued without explicit human approval.

### v2.1: Approval Workflow Table and Seed
- `sql/24_create_shaxi_bill_approval_workflow_v2_1.sql`
  - `bill_approval_reviews` table created with:
    - `id`, `bill_id` (unique), `review_status`, `reviewed_by`, `reviewed_at`, `approval_note`, `created_from`, `created_at`, `updated_at`
    - Check constraint: `review_status IN ('pending_review', 'approved', 'rejected', 'needs_adjustment')`
    - Unique index on `bill_id` ensures one active review per bill
  - Seeded 8 `pending_review` records for all May 2026 draft rent bills (idempotent, no auto-approval)
  - Does NOT seed held/unbilled items

### v2.1: Approval Views
- `vw_shaxi_bill_approval_queue_v2_1` — 8 draft bills with:
  - `review_status` (pending_review / approved / rejected / needs_adjustment)
  - `review_recommendation` (`review_and_approve` vs `review_before_approve`)
  - Contract dates, area detail, source traceability
- `vw_shaxi_bill_issue_candidates_v2_1` — bills cleared for issuance:
  - Rules: `bill_status = draft` + `review_status = approved` + no duplicates + no exceptions + safe traceability + not held + not expired
  - Returns 0 rows safely until staff manually approve bills
- `vw_shaxi_bill_approval_summary_v2_1` — single-row workflow summary:
  - total_draft, pending_count, approved_count, rejected_count, needs_adjustment_count, issue_ready_count, issued_count, workflow_status

### v2.1: Safe Issuance Script
- `sql/25_issue_approved_shaxi_bills_v2_1.sql`
  - Updates `rent_bills.bill_status` from `draft` to `issued` only for rows in `vw_shaxi_bill_issue_candidates_v2_1`
  - Idempotent: bills already issued are skipped
  - Safe: issues 0 bills if no approvals exist
  - Does NOT issue 杨华禾 unless explicitly approved
  - Does NOT issue held or expired items

### v2.1: Verification
- `sql/26_verify_shaxi_bill_approval_workflow_v2_1.sql` — 21 checks
  - 8 approval records exist, all `pending_review`
  - 杨华禾 flagged `review_before_approve` + `pending_review`
  - Issue candidates = 0, issued bills = 0
  - 川田 and 朱河芳 remain unbilled
  - 0 duplicates, 0 exceptions, 0 unsafe bills
  - Regression: v1.7 expiry_watch=10, occupancy=44; v1.8 billing_readiness=1; v1.9 summary=1, holds=10; v2.0 queue=8, readiness=1
  - Result: ALL PASSED

### v2.1: Staff Review Page Updated
- `scripts/generate_shaxi_bill_review_page.py` updated:
  - Queries `vw_shaxi_bill_approval_summary_v2_1` and `vw_shaxi_bill_approval_queue_v2_1`
  - New summary cards: Pending Review, Approved, Rejected, Needs Adjustment
  - Draft bill table now shows `Approval` column with color-coded status
  - Alerts for `review_before_approve` items include current approval status
  - New green alert when bills are ready to issue (`issue_ready_exists`)
  - Workflow status card shows `awaiting_approvals`

### Documentation Updates
- `TODO.md` — updated to v2.1 state, Path B completed, Path A (payments) recommended next
- `docs/SHAXI_HANDOVER_CURRENT.md` — updated to v2.1 with new file inventory, view list, counts, and next session instructions
- `PROJECT_MEMORY.md` — updated current working state to v2.1, added approval workflow views, fixed outdated unresolved items list

### Post-Verification Counts
- `rentable_areas`: 44 (SX-39)
- `contracts`: 13 (staged)
- `lease_package_components`: 10 (safe, 0 pending)
- `rent_bills`: 8 draft (2026-05-01, rent)
- `bill_approval_reviews`: 8 (all pending_review)
- `payments`: 0
- Billing holds: 2 (川田 master/sublease, 朱河芳 expired)
- Exceptions: 0
- Duplicates: 0
- Issued bills: 0
- Leaked pending candidates: 0

### Current Decision Required
Choose between:
- **Path A** — Record actual payments against approved/issued bills (recommended next)
- **Path B** — Resolve held cases (master/sublease rule, expired renewal)
- **Path C** — Extend to `SX-BCY` (only after Shaxi fully trusted)

**Blocked from expanding to SX-BCY until Shaxi has both reliable review loop AND trusted operating data.**


## 2026-04-27 (v2.2 — Approve and Issue Normal Bills)

**Goal:** Close the first real billing cycle by approving and issuing the 7 clearly normal May 2026 rent bills, while protecting the flagged bill (杨华禾) and held cases.

### v2.2: Approval of Normal Bills
- `sql/27_approve_normal_shaxi_bills_v2_2.sql`
  - Approved 7 bills with `review_recommendation = 'review_and_approve'`:
    - 素语服饰 ¥79,000
    - 陈盼 ¥61,800
    - 兼熙服饰 ¥45,130
    - 嘉睿服饰(3层) ¥42,576
    - 鲸鸣服饰 ¥40,640
    - 珍美商贸 ¥36,303
    - 嘉睿服饰(1层3卡) ¥21,973
  - Set `reviewed_by = 'Matthew/admin'`, `reviewed_at = NOW()`, `approval_note = 'Approved in v2.2 normal May 2026 Shaxi rent bill review'`
  - Left 杨华禾 (`review_before_approve`) as `pending_review`
  - Idempotent: only updates rows where `review_status = 'pending_review'`

### v2.2: Hotfix to Issue Candidates View
- Corrected `vw_shaxi_bill_issue_candidates_v2_1` in `sql/27_approve_normal_shaxi_bills_v2_2.sql`
  - Original v2.1 view required `candidate_status = 'generate_ready'`, which becomes `'duplicate_existing'` after bills are generated
  - Fixed rule: exclude only `billing_hold`, `expired`, `missing_rent` statuses
  - This allows previously-generated bills to become issue candidates after approval

### v2.2: Issuance
- `sql/25_issue_approved_shaxi_bills_v2_1.sql` issued 7 approved bills
  - `rent_bills.bill_status` updated from `draft` → `issued`
  - 0 bills issued for 杨华禾 (still pending)
  - 0 bills issued for held cases (川田, 朱河芳)
  - Idempotent: already-issued bills are skipped

### v2.2: Verification
- `sql/28_verify_issued_shaxi_bills_v2_2.sql` — 25 checks
  - approved = 7, pending_review = 1, rejected/needs_adjustment = 0
  - issued = 7, draft = 1
  - 杨华禾 remains draft + pending_review
  - issue candidates = 0 after issuing
  - All issued bills trace to safe components with approved reviews
  - Holds = 2, exceptions = 0, duplicates = 0
  - Regression: v1.7 expiry_watch=10, occupancy=44; v1.8 billing_readiness=1; v1.9 summary=1, holds=10; v2.0 queue=1, readiness=1; v2.1 approval_queue=8, summary=1
  - Result: ALL PASSED

### v2.2: Staff Review Page Updated
- `scripts/generate_shaxi_bill_review_page.py` regenerated
  - Shows 7 Issued, 1 Pending Review, 0 Issue Ready
  - Workflow status card shows `review_in_progress`
  - 杨华禾 remains highlighted with `review_before_approve` warning

### Documentation Updates
- `TODO.md` — updated to v2.2 state, added Path C (approve 杨华禾 when ready)
- `docs/SHAXI_HANDOVER_CURRENT.md` — updated to v2.2 with issued bills table, remaining draft bill, new file inventory, updated counts
- `PROJECT_MEMORY.md` — updated current state, issued bills list, total amount, file inventory

### Post-Verification Counts
- `rentable_areas`: 44 (SX-39)
- `contracts`: 13 (staged)
- `lease_package_components`: 10 (safe, 0 pending)
- `rent_bills`: 7 issued + 1 draft (2026-05-01, rent)
- `bill_approval_reviews`: 8 (7 approved, 1 pending_review)
- `payments`: 0
- Billing holds: 2 (川田 master/sublease, 朱河芳 expired)
- Exceptions: 0
- Duplicates: 0
- Total issued amount: ¥327,421.00

### Current Decision Required
Choose between:
- **Path A** — Record actual payments against issued bills (recommended next)
- **Path B** — Resolve held cases (master/sublease rule, expired renewal)
- **Path C** — Approve 杨华禾 (when contract review is complete)
- **Path D** — Extend to `SX-BCY` (only after Shaxi fully trusted)

**Blocked from expanding to SX-BCY until Shaxi has both reliable review loop AND trusted operating data.**


## 2026-04-27 (v2.3 — Payment Recording Foundation)

**Goal:** Prepare and test payment recording views against issued bills, without inserting fake payment data.

### v2.3: Payment Recording Views
- `sql/29_record_shaxi_payments_v2_3.sql`
  - `vw_shaxi_outstanding_bills_v2_3` — 7 issued bills with:
    - `allocated_paid_amount` (from `payment_allocations`)
    - `outstanding_amount` (`amount_due - allocated`)
    - `days_overdue`, `payment_status` (`due` / `paid` / `partially_paid` / `overdue`)
    - Full tenant/area/building detail
  - `vw_shaxi_payment_recording_queue_v2_3` — 7 bills eligible for payment recording:
    - Filters to `bill_status = 'issued'` AND `outstanding_amount > 0`
    - Sorted by days overdue descending, then amount due descending
  - `vw_shaxi_payment_allocation_exceptions_v2_3` — 8 exception detectors:
    - `allocation_to_draft_bill`
    - `allocation_to_non_issued_bill`
    - `allocation_to_missing_bill`
    - `allocation_to_missing_payment`
    - `allocation_exceeds_bill`
    - `total_allocation_exceeds_bill`
    - `total_allocation_exceeds_payment`
    - `duplicate_allocation`
    - Expected: 0 rows when data is clean

### v2.3: No Fake Payments Inserted
- `payments` table remains empty (0 rows)
- `payment_allocations` table remains empty (0 rows)
- Views are proven ready for real payment data when it becomes available

### v2.3: Verification
- `sql/30_verify_shaxi_payment_allocations_v2_3.sql` — 25 checks
  - 7 issued bills in outstanding view, all with `bill_status = 'issued'`
  - 7 bills in payment recording queue, all with `outstanding_amount > 0`
  - Total issued amount = ¥327,422.00
  - Total outstanding = ¥327,422.00 (no payments yet)
  - 杨华禾 (draft) is excluded from outstanding view and payment queue
  - 川田 and 朱河芳 are excluded from outstanding view
  - Payment allocation exceptions = 0
  - Billing exceptions = 0, duplicate bills = 0
  - Outstanding bills trace to safe components
  - Regression: v1.7 expiry_watch=10, occupancy=44; v1.8 billing_readiness=1; v1.9 summary=1, holds=10; v2.0 queue=1; v2.1 approval_queue=8, summary=1; v2.2 issued_bills=7
  - Result: ALL PASSED

### v2.3: Staff Review Page Updated
- `scripts/generate_shaxi_bill_review_page.py` updated:
  - New summary card: Total Outstanding (¥327,422.00)
  - New "Outstanding Bills (Issued)" table showing:
    - Tenant, Area, Amount Due, Allocated, Outstanding, Due Date, Payment Status
  - All 7 bills currently show status `due` (no payments recorded)

### Documentation Updates
- `TODO.md` — updated to v2.3 state, Path A refined with specific views to use
- `docs/SHAXI_HANDOVER_CURRENT.md` — updated to v2.3 with payment recording views, updated counts, new file inventory
- `PROJECT_MEMORY.md` — updated current state, added new views, corrected total issued amount to ¥327,422.00

### Post-Verification Counts
- `rentable_areas`: 44 (SX-39)
- `contracts`: 13 (staged)
- `lease_package_components`: 10 (safe, 0 pending)
- `rent_bills`: 7 issued + 1 draft (2026-05-01, rent)
- `bill_approval_reviews`: 8 (7 approved, 1 pending_review)
- `payments`: 0
- `payment_allocations`: 0
- Total issued amount: ¥327,422.00
- Total outstanding: ¥327,422.00
- Billing holds: 2 (川田 master/sublease, 朱河芳 expired)
- Exceptions: 0
- Duplicates: 0

### Current Decision Required
Choose between:
- **Path A** — Record actual payments against issued bills (recommended next)
- **Path B** — Resolve held cases (master/sublease rule, expired renewal)
- **Path C** — Approve 杨华禾 (when contract review is complete)
- **Path D** — Extend to `SX-BCY` (only after Shaxi fully trusted)

**Blocked from expanding to SX-BCY until Shaxi has both reliable review loop AND trusted operating data.**


## 2026-04-28 (v2.5 — Business Exception Resolution Workflow)

**Goal:** Create a safe review/decision workflow for the 3 remaining Shaxi business exceptions: 川田 billing hold, 朱河芳 expired contract, and 杨华禾 pending draft bill.

### v2.5: Exception Resolution Table and Seeds
- `sql/32_create_shaxi_exception_resolution_workflow_v2_5.sql`
  - `shaxi_business_exception_reviews` table created with:
    - `id`, `exception_type`, `tenant_name`, `area_code`, `area_name`
    - `related_contract_id`, `related_bill_id`
    - `current_status`, `decision_status` (CHECK: 8 allowed values)
    - `decision_by`, `decision_at`, `decision_note`
    - `created_from`, `created_at`, `updated_at`
  - Seeded 3 review records idempotently:
    - 中山市川田制衣厂 — `billing_hold` → pending_decision
    - 朱河芳 — `expired_contract` → pending_decision
    - 杨华禾 — `pending_draft_bill` → pending_decision
  - Indexes on `decision_status` and `tenant_name`

### v2.5: Exception Resolution Views
- `vw_shaxi_business_exception_queue_v2_5` — 3 active exceptions with:
  - Tenant, area, contract code, contract end date
  - Related bill amount and status
  - Recommended action per exception type
- `vw_shaxi_business_exception_summary_v2_5` — single-row summary:
  - Counts per decision_status
  - `unbilled_hold_count`, `draft_pending_count`
  - `workflow_status` (exceptions_pending_decision / all_exceptions_resolved / etc.)

### v2.5: Verification
- `sql/33_verify_shaxi_exception_resolution_workflow_v2_5.sql` — 30 checks
  - Exactly 3 active exception review records
  - All 3 pending_decision initially
  - 川田 remains unbilled until decision
  - 朱河芳 remains unbilled until renewal/new contract decision
  - 杨华禾 remains draft/pending_review until approval
  - No fake payments inserted (payments=0, allocations=0)
  - 7 issued bills unchanged, total outstanding ¥327,422
  - Mapping/billing/payment exceptions remain 0
  - Regression: v1.7 through v2.4 views still pass
  - Result: ALL PASSED

### v2.5: Streamlit App Updated
- `scripts/shaxi_staff_app.py` updated with **Business Exceptions** tab
  - Exception queue table showing all 3 active reviews
  - Exception summary cards (pending, resolved, total)
  - Color-coded decision_status badges
  - Recommended actions displayed per exception

### Documentation Updates
- `docs/SHAXI_HANDOVER_CURRENT.md` — updated to v2.5 with exception reviews section, new file inventory, updated counts, next session instructions
- `PROJECT_MEMORY.md` — updated current state, added exception workflow table and views, updated SQL inventory
- `TODO.md` — updated to v2.5 state, Path D added (make exception decisions)

### Post-Verification Counts
- `rentable_areas`: 44 (SX-39)
- `contracts`: 13 (staged)
- `lease_package_components`: 10 (safe, 0 pending)
- `rent_bills`: 7 issued + 1 draft (2026-05-01, rent)
- `bill_approval_reviews`: 8 (7 approved, 1 pending_review)
- `shaxi_business_exception_reviews`: 3 (all pending_decision)
- `payments`: 0
- `payment_allocations`: 0
- Total issued amount: ¥327,422.00
- Total outstanding: ¥327,422.00
- Billing holds: 2 (川田 master/sublease, 朱河芳 expired)
- Exceptions: 0
- Duplicates: 0

### Current Decision Required
Choose between:
- **Path A** — Record actual payments against issued bills (via Streamlit app or manual SQL)
- **Path B** — Resolve held cases (川田 master/sublease, 朱河芳 renewal)
- **Path C** — Approve 杨华禾 (when contract review is complete)
- **Path D** — Make exception decisions via `shaxi_business_exception_reviews` table
- **Path E** — Extend to `SX-BCY` (only after Shaxi is fully trusted)

**Blocked from expanding to SX-BCY until Shaxi has both reliable review loop AND trusted operating data.**


## 2026-04-27 (v2.4 — Staff Operating Interface)

**Goal:** Build the first simple staff-facing operating interface for Shaxi, focused on issued bills, outstanding amounts, and payment recording.

### v2.4: Streamlit Staff Interface
- `scripts/shaxi_staff_app.py` — Streamlit application with:
  - **Dashboard** — 7 metric cards: Issued Bills (7), Total Issued (¥327,422), Outstanding (¥327,422), Payment-Eligible (7), Draft/Pending (1), Holds (2), Exceptions (0)
  - **Outstanding Bills tab** — Table of all issued bills with amount_due, allocated_paid_amount, outstanding_amount, due_date, days_overdue, payment_status
  - **Payment Recording tab** — Queue of bills eligible for payment + payment entry form:
    - Bill selection dropdown (only from `vw_shaxi_payment_recording_queue_v2_3`)
    - Payment date, amount received, allocation amount
    - Payment method dropdown, bank account hint, reference no, payer name, notes
    - Validation: allocation cannot exceed outstanding amount; cannot exceed amount received
    - Draft bills and held cases are not selectable
    - On submit: inserts one row into `payments` with `source_type = 'staff_entry'`, then one row into `payment_allocations`
  - **Holds tab** — Current billing holds with reasons + draft bills awaiting review
  - **Exceptions tab** — Mapping, billing, and payment allocation exception counts with drill-down
- `scripts/requirements.txt` — `streamlit>=1.50`
- `docs/SHAXI_STAFF_INTERFACE_V2_4.md` — Installation, usage, safety rules, troubleshooting

### v2.4: Installation
- Created local Python venv (`.venv/`)
- Installed `streamlit` and dependencies
- Interface runs with: `.venv\Scripts\python.exe -m streamlit run scripts/shaxi_staff_app.py`

### v2.4: Verification
- `sql/31_verify_shaxi_staff_interface_support_v2_4.sql` — 25 checks
  - 7 issued bills visible in outstanding view
  - 7 payment-eligible bills in queue
  - 杨华禾 (draft) excluded from outstanding and queue
  - 川田 and 朱河芳 excluded from outstanding and queue
  - All exception views return 0
  - Interface source views exist and return expected counts
  - Regression: v1.7 expiry_watch=10, occupancy=44; v1.8 billing_readiness=1; v1.9 summary=1, holds=10; v2.0 queue=1; v2.1 approval_queue=8; v2.2 issued=7; v2.3 outstanding=7, queue=7
  - Result: ALL PASSED

### v2.4: Safety Design
- No contract/area/rent editing is exposed
- Payments only against issued bills
- Allocation capped at outstanding amount
- Draft bills and held cases blocked from payment entry
- All inserts use `NOW()` timestamps and `source_type = 'staff_entry'`
- DB access via `psql` subprocess (no new DB driver dependency)

### Documentation Updates
- `TODO.md` — updated to v2.4 state, Path A refined with Streamlit app option
- `docs/SHAXI_HANDOVER_CURRENT.md` — updated to v2.4 with interface documentation, new file inventory, updated next session instructions
- `PROJECT_MEMORY.md` — updated current state, added staff interface section, updated file inventory

### Post-Verification Counts
- `rentable_areas`: 44 (SX-39)
- `contracts`: 13 (staged)
- `lease_package_components`: 10 (safe, 0 pending)
- `rent_bills`: 7 issued + 1 draft (2026-05-01, rent)
- `bill_approval_reviews`: 8 (7 approved, 1 pending_review)
- `payments`: 0
- `payment_allocations`: 0
- Total issued amount: ¥327,422.00
- Total outstanding: ¥327,422.00
- Billing holds: 2 (川田 master/sublease, 朱河芳 expired)
- Exceptions: 0
- Duplicates: 0

### Current Decision Required
Choose between:
- **Path A** — Record actual payments against issued bills (via Streamlit app or manual SQL)
- **Path B** — Resolve held cases (master/sublease rule, expired renewal)
- **Path C** — Approve 杨华禾 (when contract review is complete)
- **Path D** — Extend to `SX-BCY` (only after Shaxi fully trusted)

**Blocked from expanding to SX-BCY until Shaxi has both reliable review loop AND trusted operating data.**
