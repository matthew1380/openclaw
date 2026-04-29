# PROJECT_MEMORY.md

## Current Working State (2026-04-29)

### Shaxi pilot status — post v2.6
The Shaxi promotion pipeline is now **live through safe lease_package_components creation with staff approval workflow, issued bills (8 for May 2026), payment recording views, Streamlit staff operating interface, business exception resolution workflow, and applied exception decisions (v2.6)**.

Staging is complete. Promotion into final truth tables is in progress with strict review-first rules.

---

### Live psql connection pattern
```powershell
$line = Get-Content .env | Where-Object { $_ -match "^SUPABASE_DB_URL=" } | Select-Object -First 1
$dbUrl = $line.Split("=",2)[1].Trim().Trim('"')
psql $dbUrl -f sql/<file>.sql
```
- `.env` contains `SUPABASE_DB_URL` using Supabase Session Pooler.
- `.env` must remain uncommitted (already in `.gitignore`).

---

### Staging tables (source of truth for promotion)
| Table | Rows | Purpose |
|-------|------|---------|
| `public.stg_shaxi_areas_prepared` | 11 | Canonical staged areas ready for promotion |
| `public.stg_shaxi_contracts_prepared` | 10 | Canonical staged contracts ready for promotion |

### Promotion batch tag
All promoted data uses batch identifier: **`shaxi_promotion_v1`**

---

### Completed promotions

#### 1. Area promotion (`sql/02_promote_shaxi_v1.sql`)
- Promoted 11 staged areas into `rentable_areas` using UUID FKs.
- Result: **9 new rows inserted**, 2 pre-existing rows skipped.
- Idempotent via `WHERE NOT EXISTS (property_id, building_id, area_name)`.

#### 2. Contract promotion (`sql/04_promote_shaxi_contracts_v1_1.sql`)
- 10 staged contracts already existed in `contracts` table.
- Result: `INSERT 0 0` (all 10 already present).
- Idempotent via `WHERE NOT EXISTS (tenant_id, unit_id, start_date, end_date)`.

#### 3. Contract source traceability (`sql/05_add_contract_source_audit_fields.sql`)
- Added 14 audit/source columns to `contracts`.
- Backfilled all 10 Shaxi contracts from staging.
- `promotion_batch = 'shaxi_contracts_v1_1'`.

#### 4. Candidate review flow (`sql/06_prepare_candidate_review_v1_2.sql`)
- Added 13 review-resolution columns to `promotion_contract_area_candidates`.
- Added check constraint on `review_decision`.
- Created read-only view `vw_shaxi_contract_area_candidates_pending`.

#### 5. Human review decisions (`sql/09_apply_candidate_decisions_v1_2.sql`)
- 6 candidates approved with explicit staff decisions.
- 3 candidates remain pending.

#### 6. Approved candidate areas applied (`sql/10_apply_approved_candidate_areas_v1_3.sql`)
- 6 new rentable_areas created from approved candidates.
- Approved candidates updated: `review_status = 'area_created'`, `resolved_at = NOW()`.

#### 7. Safe lease_package_components (`sql/11_create_safe_lease_package_components_v1_4.sql`)
- **7 safe components created**:
  - 1 exact original match: 川田 U012 → `RA-SX39-Q4-B-GF`
  - 6 approved candidate links:
    - 素语 U013 → `RA-SX39-Q4-C-整栋`
    - 珍美 U003 → `RA-SX39-Q3-A-1层1卡`
    - 嘉睿 U004 → `RA-SX39-Q3-A-1层3卡`
    - 兼熙 U006 → `RA-SX39-Q3-A-2层`
    - 嘉睿 U005 → `RA-SX39-Q3-A-3层`
    - 陈盼 U010 → `RA-SX39-Q3-C-整栋`
- Added 4 audit columns to `lease_package_components`.
- Idempotent via `WHERE NOT EXISTS (package_unit_id, rentable_area_id)`.

---

### Current Verified Counts After v1.5

| Item | Verified Count / Status |
|---|---:|
| Staged areas promoted/reused in `rentable_areas` | 11 |
| Approved candidate areas created | 9 |
| Contracts verified | 10 |
| Safe `lease_package_components` | 10 |
| Candidates still `pending_review` | 0 |
| Components for pending candidates | 0 |
| Duplicate components | 0 |

**rentable_areas for SX-39:**
- 11 originally staged areas (9 promoted + 2 pre-existing)
- 6 newly created from approved candidates
- Total canonical short-name areas: 17
- Plus legacy long-name areas still in system

**contracts for SX-39:**
- 13 total contracts in system
- 10 staged contracts with source audit fields populated
- 3 additional contracts (华佑物业, 靖大物业, 刘英) from pre-existing data

**promotion_contract_area_candidates:**
| Status | Count | IDs / Tenants |
|--------|-------|---------------|
| `area_created` | 9 | 1素语, 2珍美, 3杨华禾, 4朱河芳, 5嘉睿(第三卡), 6兼熙, 7嘉睿(3层), 8鲸鸣, 9陈盼 |
| `pending_review` | 0 | — |

**lease_package_components for safe links:**
- 10 components created linking units to canonical rentable_areas
- 0 pending candidates (all resolved)

**Staff-facing views available:**
| View | Purpose | Rows |
|------|---------|------|
| `vw_shaxi_lease_component_review` | Safe component detail with tenant/contract/area/audit | 10 |
| `vw_shaxi_mapping_exceptions` | Exception detector (0 = clean) | 0 |
| `vw_shaxi_reporting_summary` | Key counts summary | 1 |
| `vw_shaxi_contract_expiry_watch` | Expiry risk for 10 safe components | 10 |
| `vw_shaxi_area_occupancy_status` | All 44 SX-39 areas with occupancy | 44 |
| `vw_shaxi_payment_data_readiness` | Payment data readiness check | 1 |
| `vw_shaxi_billing_readiness` | Billing foundation status | 1 |
| `vw_shaxi_bill_payment_status` | Bill + allocated + outstanding + computed status | 0 (initially) |
| `vw_shaxi_billing_exceptions` | Billing exception detector | 0 |

**Billing foundation tables:**
| Table | Purpose | Status |
|-------|---------|--------|
| `rent_bills` | Expected rental charges | 8 issued + 0 draft for 2026-05-01 |
| `payments` | Actual money received | Empty, ready for entry |
| `payment_allocations` | Connect payments to bills | Empty, ready for entry |
| `billing_generation_rules` | Controls bill generation | 1 rule: SX-39, 2026-05-01, rent, due_day=5, status=generated |
| `bill_approval_reviews` | Staff approval workflow | 8 rows (8 approved, 0 pending_review) |
| `shaxi_business_exception_reviews` | Business exception resolution workflow | 3 rows (1 pending_decision / 1 keep_on_hold / 1 approved_to_issue) |

**Billing views:**
| View | Purpose | Rows |
|------|---------|------|
| `vw_shaxi_billing_readiness` | Billing foundation status | 1 |
| `vw_shaxi_bill_payment_status` | Bill + allocated + outstanding + computed status | 8 (draft bills) |
| `vw_shaxi_billing_exceptions` | Billing exception detector | 0 |
| `vw_shaxi_rent_bill_candidates_v1_9` | Candidate classification per safe component | 10 |
| `vw_shaxi_billing_generation_summary_v1_9` | Candidate and bill counts | 1 |
| `vw_shaxi_billing_holds_v1_9` | Non-generate-ready candidates with reasons | 10 (1 billing_hold + 1 expired + 8 duplicate_existing) |
| `vw_shaxi_bill_review_queue_v2_0` | Draft bills requiring human review | 8 |
| `vw_shaxi_billing_hold_review_v2_0` | True holds with recommended actions | 2 |
| `vw_shaxi_bill_issue_readiness_v2_0` | Readiness for human review | 1 |
| `vw_shaxi_bill_approval_queue_v2_1` | Draft bills with approval status + recommendation | 8 |
| `vw_shaxi_bill_issue_candidates_v2_1` | Bills cleared for issuance (approved + safe) | 0 (awaiting approvals) |
| `vw_shaxi_bill_approval_summary_v2_1` | Single-row workflow status | 1 |
| `vw_shaxi_outstanding_bills_v2_3` | Issued bills with payment status | 7 |
| `vw_shaxi_payment_recording_queue_v2_3` | Bills eligible for payment recording | 7 |
| `vw_shaxi_payment_allocation_exceptions_v2_3` | Payment allocation exception detector | 0 |
| `vw_shaxi_business_exception_queue_v2_5` | Active business exception reviews | 3 |
| `vw_shaxi_business_exception_summary_v2_5` | Exception workflow summary | 1 |

**Staff interface:**
- `scripts/shaxi_staff_app.py` — Streamlit app for payment recording and dashboard
- `scripts/requirements.txt` — `streamlit` dependency
- `docs/SHAXI_STAFF_INTERFACE_V2_4.md` — interface documentation

**Issued bills (after v2.6):**
- 8 May 2026 rent bills issued for: 素语服饰, 陈盼, 兼熙服饰, 嘉睿服饰(3层), 鲸鸣服饰, 珍美商贸, 嘉睿服饰(1层3卡), **杨华禾 (issued in v2.6, ¥2,500.00)**
- 0 draft bills remain
- Total issued amount: ¥329,922.00
- Total outstanding: ¥329,922.00 (0 payments recorded)

**Known billing holds (tracked in `shaxi_business_exception_reviews`):**
- 川田 (四区B栋首层) — `billing_hold`: multiple_active area (靖大物业 master lease + 川田 sublease)
- 朱河芳 (三区A栋首层2卡) — `expired`: contract SX-C-011 ends 2026-04-30, not valid for 2026-05-01 billing
- 杨华禾 (三区A栋首层1卡) — `pending_draft_bill`: draft bill ¥2,500.00 pending rent amount confirmation

**Exception resolution workflow:**
- Table: `shaxi_business_exception_reviews`
- Allowed decisions: `pending_decision`, `approved_to_bill`, `approved_to_issue`, `keep_on_hold`, `mark_vacant`, `renewed_contract_needed`, `needs_adjustment`, `resolved`
- Queue view: `vw_shaxi_business_exception_queue_v2_5`
- Summary view: `vw_shaxi_business_exception_summary_v2_5`

**Key constraints:**
- `rent_bills.amount_due >= 0`
- `payments.amount_received > 0`
- `payment_allocations.allocated_amount > 0`
- Unique index on `(lease_package_component_id, billing_month, bill_type)` prevents duplicate bills
- `bill_status` limited to: draft, issued, partially_paid, paid, overdue, cancelled, waived, disputed

---

### Next Session Start Here

1. **Run full verification:**
   ```powershell
   $line = Get-Content .env | Where-Object { $_ -match "^SUPABASE_DB_URL=" } | Select-Object -First 1
   $dbUrl = $line.Split("=",2)[1].Trim().Trim('"')
   psql $dbUrl -f sql/03_verify_shaxi_v1.sql
   psql $dbUrl -f sql/14_verify_shaxi_staff_reporting_views_v1_6.sql
   ```
   Expected: all sections pass, all 13 reporting checks pass.

2. **Current staff views available:**
   - `vw_shaxi_lease_component_review` — 10 safe components with tenant/contract/area detail
   - `vw_shaxi_mapping_exceptions` — exception detector (0 rows = clean)
   - `vw_shaxi_reporting_summary` — single-row key counts

3. **Do not move to other sites until Shaxi reporting is operationally usable.**

---

### SQL file inventory (ordered workflow)

| # | File | Purpose | Status |
|---|------|---------|--------|
| 02 | `sql/02_promote_shaxi_v1.sql` | Promote staged areas → rentable_areas | ✅ Executed |
| 03 | `sql/03_verify_shaxi_v1.sql` | Master verification script (sections 1–8) | ✅ Active |
| 04 | `sql/04_promote_shaxi_contracts_v1_1.sql` | Promote staged contracts → contracts | ✅ Executed |
| 05 | `sql/05_add_contract_source_audit_fields.sql` | Add audit columns + backfill contracts | ✅ Executed |
| 06 | `sql/06_prepare_candidate_review_v1_2.sql` | Add review columns + create pending view | ✅ Executed |
| 07 | `sql/07_verify_candidate_review_v1_2.sql` | Verify review flow setup | ✅ Executed |
| 08 | `sql/08_export_candidate_review_list_v1_2.sql` | Human-readable export of pending candidates | ✅ Executed |
| 09 | `sql/09_apply_candidate_decisions_v1_2.sql` | Record human review decisions | ✅ Executed |
| 10 | `sql/10_apply_approved_candidate_areas_v1_3.sql` | Create rentable_areas from approved candidates | ✅ Executed |
| 11 | `sql/11_create_safe_lease_package_components_v1_4.sql` | Create safe unit→area components | ✅ Executed |
| 12 | `sql/12_resolve_pending_candidates_v1_5.sql` | Resolve remaining 3 pending candidates | ✅ Executed |
| 13 | `sql/13_create_shaxi_staff_reporting_views_v1_6.sql` | Create staff reporting views | ✅ Executed |
| 14 | `sql/14_verify_shaxi_staff_reporting_views_v1_6.sql` | Verify reporting views | ✅ Active |
| 15 | `sql/15_create_shaxi_operating_views_v1_7.sql` | Create operating data views (expiry, occupancy, payment readiness) | ✅ Executed |
| 16 | `sql/16_verify_shaxi_operating_views_v1_7.sql` | Verify operating views | ✅ Active |
| 17 | `sql/17_create_shaxi_billing_foundation_v1_8.sql` | Create billing/payment tables and views | ✅ Executed |
| 18 | `sql/18_verify_shaxi_billing_foundation_v1_8.sql` | Verify billing foundation | ✅ Active |
| 19 | `sql/19_create_shaxi_billing_rules_v1_9.sql` | Create billing generation rule table + insert rule | ✅ Executed |
| 20 | `sql/20_generate_shaxi_rent_bills_v1_9.sql` | Generate draft rent bills + candidate/hold/summary views | ✅ Executed |
| 21 | `sql/21_verify_shaxi_rent_bills_v1_9.sql` | Verify controlled bill generation | ✅ Active |
| 22 | `sql/22_create_shaxi_bill_review_views_v2_0.sql` | Create bill review and approval views | ✅ Executed |
| 23 | `sql/23_verify_shaxi_bill_review_views_v2_0.sql` | Verify bill review layer | ✅ Active |
| 24 | `sql/24_create_shaxi_bill_approval_workflow_v2_1.sql` | Create approval workflow table + views | ✅ Executed |
| 25 | `sql/25_issue_approved_shaxi_bills_v2_1.sql` | Issue approved bills (idempotent) | ✅ Executed |
| 26 | `sql/26_verify_shaxi_bill_approval_workflow_v2_1.sql` | Verify approval workflow | ✅ Active |
| 27 | `sql/27_approve_normal_shaxi_bills_v2_2.sql` | Approve 7 normal May 2026 bills | ✅ Executed |
| 28 | `sql/28_verify_issued_shaxi_bills_v2_2.sql` | Verify approved + issued state | ✅ Active |
| 29 | `sql/29_record_shaxi_payments_v2_3.sql` | Create payment recording views | ✅ Executed |
| 30 | `sql/30_verify_shaxi_payment_allocations_v2_3.sql` | Verify payment recording foundation | ✅ Active |
| 31 | `sql/31_verify_shaxi_staff_interface_support_v2_4.sql` | Verify staff interface support views | ✅ Active |
| 32 | `sql/32_create_shaxi_exception_resolution_workflow_v2_5.sql` | Create exception resolution table + views | ✅ Executed |
| 33 | `sql/33_verify_shaxi_exception_resolution_workflow_v2_5.sql` | Verify exception resolution workflow | ✅ Active |
| 34 | `sql/34_apply_shaxi_exception_decisions_v2_6.sql` | Apply confirmed exception decisions (川田 keep_on_hold, 杨华禾 approved_to_issue + bill issued, 朱河芳 unchanged) | ✅ Executed |
| 35 | `sql/35_verify_shaxi_exception_decisions_v2_6.sql` | Verify v2.6 decisions (31 checks, ALL PASSED) | ✅ Active |
| — | `scripts/generate_shaxi_bill_review_page.py` | Generate static HTML bill review page | ✅ Active |
| — | `scripts/shaxi_staff_app.py` | Streamlit staff operating interface | ✅ Active |
| — | `scripts/requirements.txt` | Python dependencies | ✅ Active |

---

### Schema conventions confirmed
- `rentable_areas.property_id -> properties.id`
- `rentable_areas.building_id -> building_registry.id`
- `contracts.unit_id -> units.id`
- `lease_package_components.package_unit_id -> units.id`
- `lease_package_components.rentable_area_id -> rentable_areas.id`
- `properties.property_code` and `building_registry.building_code` are mandatory text fields.

### Payee mappings
| Raw | Operating Entity Code |
|-----|----------------------|
| 靖大 | JD-SX |
| 中铭公司 | ZM-SX |

### Contract status mapping
| Source | Target |
|--------|--------|
| 在租 | active |

---

### Current script status
Stable enough for current stage:
- `rent_summary_cleaner.py`
- `shaxi_parcel_building_mapper.py`
- `vacancy_summary_cleaner.py`
- `generate_shaxi_bill_review_page.py` — generates read-only HTML bill review page from live views

---

### Known unresolved items (after v2.6)
1. **1 business exception** still `pending_decision` in `shaxi_business_exception_reviews`:
   - 朱河芳 (三区A栋首层2卡) — `expired_contract`: contract SX-C-011 ended 2026-04-30. Renewal pending with 阮绮杨 follow-up. **Do not bill until confirmed.**
2. **1 business exception** on hold pending external confirmation:
   - 中山市川田制衣厂 (四区B栋首层) — `keep_on_hold` (decided in v2.6): 川田 pays 靖大物业 → 靖大物业 pays 中铭. Future billing must happen at 靖大物业/master-lease level once master rent + rule are confirmed. **No direct 中铭 → 川田 bill.**
3. **0 unresolved draft bills.** 杨华禾 was approved + issued in v2.6 (¥2,500.00).

2. **Legacy long-name rentable_areas** exist alongside new canonical short-name areas:
   - e.g., `RA-ZS-SX-U012` (long) vs `RA-SX39-Q4-B-GF` (short) for 四区B栋首层
   - Future consolidation may be needed.

3. **`一区 原建泰第1座`** remains `review_required` because legacy naming inference is not yet handled.
   - Next rule to add: `原建泰第1座` -> `一区1栋`.

---

### Immediate next deliverable
Record actual payments against the 8 issued May 2026 bills (¥329,922.00 receivable) using the Streamlit interface or manual SQL. In parallel, resolve 朱河芳 once 阮绮杨 confirms renewal/vacancy. Confirm 川田 master-lease rent + rule at the 靖大物业 level (no direct 中铭 → 川田 bill). Do not expand to SX-BCY until Shaxi has a reliable staff-facing review loop AND trusted operating data.
