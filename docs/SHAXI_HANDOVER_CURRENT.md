# Shaxi Rental OS Handover — Current State After v2.7

_Last updated: 2026-04-30 after Excel↔DB drift corrections + 华佑/刘英 master-lease May 2026 bills_

## 1. Current Milestone

The Shaxi Rental OS pilot has reached the **v2.7 Excel↔DB drift corrections + master-lease billing checkpoint**.

All 9 promotion candidates have been resolved:
- 6 approved in v1.3/v1.4
- 3 approved in v1.5

Staff-facing reporting views, operating-data views, billing foundation, controlled draft bill generation, bill review layer, staff approval workflow, issued bills, payment recording views, Streamlit staff operating interface, and **business exception resolution workflow** are now live:
- Component review, mapping exceptions, summary counts (v1.6)
- Contract expiry watch, area occupancy, payment data readiness (v1.7)
- Billing tables (rent_bills, payments, payment_allocations) and billing views (v1.8)
- Billing generation rules, draft bill candidates, and 8 generated draft rent bills (v1.9)
- Bill review queue, hold review with recommended actions, issue readiness (v2.0)
- Approval workflow table, approval queue, issue candidates, approval summary (v2.1)
- 7 normal bills approved and issued. 1 bill (杨华禾) remains draft/pending. (v2.2)
- Outstanding bills view, payment recording queue, payment allocation exceptions (v2.3)
- Streamlit staff interface for payment recording and dashboard (v2.4)
- Business exception resolution workflow: 3 active reviews (川田, 朱河芳, 杨华禾) (v2.5)
- Confirmed exception decisions applied: 川田 keep_on_hold, 杨华禾 approved_to_issue (bill issued, ¥2,500), 朱河芳 unchanged (v2.6)
- **Excel↔DB drift corrections (5 contract date fields) + 华佑/刘英 master-lease May 2026 bills issued (¥355,000 total) (v2.7)**

The system has safely moved from raw/staged Shaxi data into verified structured rental components with staff visibility, controlled billing, human-review queue, explicit approval gate, **10 issued bills (¥684,922) with full traceability**, structured business exception tracking, applied human decisions on those exceptions, and **first-pass Excel reconciliation for SX-39**. Zero unresolved candidates remain. Zero remaining draft bills.

---

## 2. Current Verified Counts

| Item | Verified Count / Status |
|---|---:|
| Staged areas promoted/reused in `rentable_areas` | 11 |
| Approved candidate areas created | 9 |
| Contracts verified | 10 |
| Safe `lease_package_components` | 10 |
| Candidates still `pending_review` | 0 |
| Components for pending candidates | 0 |
| Duplicate components | 0 |
| SX-39 rentable_areas | 44 |
| Occupied areas | 34 |
| Areas with no component | 9 |
| Multiple-active areas | 1 |
| Draft rent bills (2026-05-01) | 0 |
| Issued rent bills (2026-05-01) | 10 |
| Bills in review queue | 0 |
| Approval records (approved) | 10 |
| Approval records (pending_review) | 0 |
| Approval records (rejected) | 0 |
| Approval records (needs_adjustment) | 0 |
| Issue-ready bills | 0 |
| Billing holds (true holds, unbilled) | 2 (川田, 朱河芳) + 1 master held (靖大 SX-C-008) |
| Business exception reviews | 3 |
| Exception reviews pending_decision | 1 (朱河芳) |
| Exception reviews keep_on_hold | 1 (川田) |
| Exception reviews approved_to_issue | 1 (杨华禾) |
| Exception reviews resolved | 0 |
| Payments recorded | 0 |
| Payment allocations recorded | 0 |
| Total issued amount | ¥684,922.00 |
| Total outstanding amount | ¥684,922.00 |

---

## 3. Resolved Candidates (All 9)

| ID | Tenant | Area Text | Resolved In |
|---|---|---|---|
| 1 | 素语服饰 | 四区C栋 | v1.4 |
| 2 | 珍美商贸 | 三区A栋1层1卡 | v1.4 |
| 5 | 嘉睿服饰 | 三区A栋1层3卡 | v1.4 |
| 6 | 兼熙服饰 | 三区A栋2层 | v1.4 |
| 7 | 嘉睿服饰 | 三区A栋3层 | v1.4 |
| 9 | 陈盼 | 三区C栋 | v1.4 |
| 3 | 杨华禾 | 三区A栋首层1卡 | v1.5 |
| 4 | 朱河芳 | 三区A栋首层2卡 | v1.5 |
| 8 | 鲸鸣服饰 | 三区A栋4层 | v1.5 |

---

## 4. Billing Holds (2)

| Tenant | Area | Status | Reason | Recommended Action |
|---|---|---|---|---|
| 川田 | 四区B栋首层 | billing_hold | multiple_active — 靖大物业 master lease + 川田 sublease | resolve_master_sublease_billing_rule |
| 朱河芳 | 三区A栋首层2卡 | expired | contract SX-C-011 ends 2026-04-30 | confirm_renewal_or_vacancy |

## 5. Business Exception Reviews (3) — post v2.6

| Tenant | Area | Exception Type | Current Status | Decision Status | Decided By | Recommended Action |
|---|---|---|---|---|---|---|
| 中山市川田制衣厂 | 四区B栋首层 | billing_hold | billing_hold | **keep_on_hold** | Matthew/admin (2026-04-29) | Confirm master lease rent + rule at 靖大物业 level. NO direct 中铭 → 川田 bill. |
| 朱河芳 | 三区A栋首层2卡 | expired_contract | expired | pending_decision | — | Confirm renewal or mark vacant for 三区A栋首层2卡 (阮绮杨 follow-up) |
| 杨华禾 | 三区A栋首层1卡 | pending_draft_bill | draft_pending_review | **approved_to_issue** | Matthew/admin (2026-04-29) | Bill issued ¥2,500.00 in v2.6 |

All 3 exceptions are tracked in `shaxi_business_exception_reviews`. Workflow status: `exceptions_pending_decision` (because 朱河芳 is still pending).
Allowed decisions: `pending_decision`, `approved_to_bill`, `approved_to_issue`, `keep_on_hold`, `mark_vacant`, `renewed_contract_needed`, `needs_adjustment`, `resolved`.

**v2.6 decision details:**
- 川田: `pending_decision` → `keep_on_hold`. decision_note: "川田 pays rent to 靖大物业; 靖大物业 pays 中铭. Do not issue direct rent bill from 中铭 to 川田 unless policy changes. Future billing should be handled at 靖大物业/master-lease level if confirmed."
- 杨华禾: `pending_decision` → `approved_to_issue`. Existing draft bill `4adcf5d2…` moved from `draft` → `issued`; bill_approval_reviews.review_status `pending_review` → `approved`.
- 朱河芳: NO CHANGE. Stays `pending_decision`.

---

## 6. Issued Bills (8) — post v2.6

| Tenant | Area | Amount | Status | Approved By |
|---|---|---:|---|---|
| 中山市素语服饰有限公司 | 四区C栋 | ¥79,000.00 | issued | Matthew/admin |
| 陈盼 | 三区C栋 | ¥61,800.00 | issued | Matthew/admin |
| 中山市兼熙服饰有限公司 | 三区A栋2层 | ¥45,130.15 | issued | Matthew/admin |
| 中山市嘉睿服饰有限公司 | 三区A栋3层 | ¥42,575.61 | issued | Matthew/admin |
| 中山市鲸鸣服饰有限公司 | 三区A栋4层 | ¥40,640.36 | issued | Matthew/admin |
| 中山市珍美商贸有限公司 | 三区A栋1层1卡 | ¥36,302.77 | issued | Matthew/admin |
| 中山市嘉睿服饰有限公司 | 三区A栋1层3卡 | ¥21,973.11 | issued | Matthew/admin |
| **杨华禾** | **三区A栋首层1卡** | **¥2,500.00** | **issued (v2.6)** | **Matthew/admin** |

**Total issued: ¥329,922.00. All 8 bills outstanding (0 payments recorded).**

---

## 7. Remaining Draft Bills (0)

No draft bills remain for 2026-05-01 rent. The single previous draft (杨华禾) was approved and issued in v2.6.

---

## 8. Important Files

### SQL Files
Run and review these files in order when continuing the Shaxi workstream.

```text
sql/02_promote_shaxi_v1.sql
sql/03_verify_shaxi_v1.sql
sql/04_promote_shaxi_contracts_v1_1.sql
sql/05_add_contract_source_audit_fields.sql
sql/06_prepare_candidate_review_v1_2.sql
sql/07_verify_candidate_review_v1_2.sql
sql/09_apply_candidate_decisions_v1_2.sql
sql/10_apply_approved_candidate_areas_v1_3.sql
sql/11_create_safe_lease_package_components_v1_4.sql
sql/12_resolve_pending_candidates_v1_5.sql
sql/13_create_shaxi_staff_reporting_views_v1_6.sql
sql/14_verify_shaxi_staff_reporting_views_v1_6.sql
sql/15_create_shaxi_operating_views_v1_7.sql
sql/16_verify_shaxi_operating_views_v1_7.sql
sql/17_create_shaxi_billing_foundation_v1_8.sql
sql/18_verify_shaxi_billing_foundation_v1_8.sql
sql/19_create_shaxi_billing_rules_v1_9.sql
sql/20_generate_shaxi_rent_bills_v1_9.sql
sql/21_verify_shaxi_rent_bills_v1_9.sql
sql/22_create_shaxi_bill_review_views_v2_0.sql
sql/23_verify_shaxi_bill_review_views_v2_0.sql
sql/24_create_shaxi_bill_approval_workflow_v2_1.sql
sql/25_issue_approved_shaxi_bills_v2_1.sql
sql/26_verify_shaxi_bill_approval_workflow_v2_1.sql
sql/27_approve_normal_shaxi_bills_v2_2.sql
sql/28_verify_issued_shaxi_bills_v2_2.sql
sql/29_record_shaxi_payments_v2_3.sql
sql/30_verify_shaxi_payment_allocations_v2_3.sql
sql/31_verify_shaxi_staff_interface_support_v2_4.sql
sql/32_create_shaxi_exception_resolution_workflow_v2_5.sql
sql/33_verify_shaxi_exception_resolution_workflow_v2_5.sql
sql/34_apply_shaxi_exception_decisions_v2_6.sql
sql/35_verify_shaxi_exception_decisions_v2_6.sql
```

Recommended use:
- Use `sql/03_verify_shaxi_v1.sql` as the first health check at the start of any session.
- Use `sql/14_verify_shaxi_staff_reporting_views_v1_6.sql` to confirm the review layer is healthy.
- Use `sql/16_verify_shaxi_operating_views_v1_7.sql` to confirm the operating layer is healthy.
- Use `sql/18_verify_shaxi_billing_foundation_v1_8.sql` to confirm the billing foundation is healthy.
- Use `sql/21_verify_shaxi_rent_bills_v1_9.sql` to confirm the bill generation layer is healthy.
- Use `sql/23_verify_shaxi_bill_review_views_v2_0.sql` to confirm the bill review layer is healthy.
- Use `sql/26_verify_shaxi_bill_approval_workflow_v2_1.sql` to confirm the approval workflow is healthy.
- Use `sql/28_verify_issued_shaxi_bills_v2_2.sql` to confirm the issued-bill state is healthy.
- Use `sql/30_verify_shaxi_payment_allocations_v2_3.sql` to confirm the payment recording foundation is healthy.
- Use `sql/31_verify_shaxi_staff_interface_support_v2_4.sql` to confirm the staff interface support views are healthy.
- Use `sql/33_verify_shaxi_exception_resolution_workflow_v2_5.sql` to confirm the business exception resolution workflow is healthy.

### Scripts
```text
scripts/generate_shaxi_bill_review_page.py
scripts/shaxi_staff_app.py
scripts/requirements.txt
```

### Exception Resolution Workflow
Run the creation script to seed or refresh exception review records:
```powershell
psql $dbUrl -f sql/32_create_shaxi_exception_resolution_workflow_v2_5.sql
```

Run the verification script:
```powershell
psql $dbUrl -f sql/33_verify_shaxi_exception_resolution_workflow_v2_5.sql
```

Generate the staff-facing HTML review page:
```bash
python scripts/generate_shaxi_bill_review_page.py
```

Run the Streamlit staff operating interface:
```powershell
.\.venv\Scripts\python.exe -m streamlit run scripts/shaxi_staff_app.py
```

Output: `reports/shaxi_bill_review_2026-05.html` (excluded from Git — contains live data).

---

## 9. Current Local Execution Method

Current local execution uses a project `.env` file containing `SUPABASE_DB_URL`.

PowerShell command pattern:

```powershell
$line = Get-Content .env | Where-Object { $_ -match "^SUPABASE_DB_URL=" } | Select-Object -First 1
$dbUrl = $line.Split("=",2)[1].Trim().Trim('"')
psql $dbUrl -f sql/03_verify_shaxi_v1.sql
```

---

## 10. Next Session Start Here

At the beginning of the next session, do **not** expand to other sites yet.

Start with:

```powershell
psql $dbUrl -f sql/03_verify_shaxi_v1.sql
psql $dbUrl -f sql/31_verify_shaxi_staff_interface_support_v2_4.sql
psql $dbUrl -f sql/33_verify_shaxi_exception_resolution_workflow_v2_5.sql
psql $dbUrl -f sql/35_verify_shaxi_exception_decisions_v2_6.sql
```

### Current priority (post v2.6): Record Actual Payments, Resolve 朱河芳 Renewal, or Confirm 川田 Master-Lease Rule

2. **Current staff views available:**
   - `vw_shaxi_lease_component_review` — 10 safe components with tenant/contract/area detail
   - `vw_shaxi_mapping_exceptions` — exception detector (0 rows = clean)
   - `vw_shaxi_reporting_summary` — single-row key counts
   - `vw_shaxi_contract_expiry_watch` — expiry risk (1 contract expiring in 3 days: 朱河芳 SX-C-011)
   - `vw_shaxi_area_occupancy_status` — all 44 SX-39 areas with occupancy
   - `vw_shaxi_payment_data_readiness` — payment data readiness (`seeded_only`)
   - `vw_shaxi_billing_readiness` — billing foundation status (`foundation_ready`)
   - `vw_shaxi_bill_payment_status` — bill + allocated + outstanding + computed status (7 issued + 1 draft)
   - `vw_shaxi_billing_exceptions` — billing exception detector (0 rows)
   - `vw_shaxi_rent_bill_candidates_v1_9` — candidate classification per safe component (10)
   - `vw_shaxi_billing_generation_summary_v1_9` — candidate and bill counts
   - `vw_shaxi_billing_holds_v1_9` — non-generate-ready candidates with reasons
   - `vw_shaxi_bill_review_queue_v2_0` — 1 draft bill requiring human review (杨华禾)
   - `vw_shaxi_billing_hold_review_v2_0` — 2 true holds with recommended actions
   - `vw_shaxi_bill_issue_readiness_v2_0` — readiness for human review
   - `vw_shaxi_bill_approval_queue_v2_1` — 8 bills with approval status (7 approved, 1 pending)
   - `vw_shaxi_bill_issue_candidates_v2_1` — bills cleared for issuance (0 after issuing)
   - `vw_shaxi_bill_approval_summary_v2_1` — single-row workflow status (`review_in_progress`)
   - `vw_shaxi_outstanding_bills_v2_3` — 7 issued bills with allocated/outstanding/payment status
   - `vw_shaxi_payment_recording_queue_v2_3` — bills eligible for payment recording (issued + outstanding > 0)
   - `vw_shaxi_payment_allocation_exceptions_v2_3` — payment allocation exception detector
   - `vw_shaxi_business_exception_queue_v2_5` — 3 active business exceptions with recommended actions
   - `vw_shaxi_business_exception_summary_v2_5` — single-row exception workflow status

3. **Staff-facing interfaces:**
   - `reports/shaxi_bill_review_2026-05.html` — static read-only HTML review page
   - `scripts/shaxi_staff_app.py` — Streamlit interactive interface for payment recording
     - Dashboard with 7 metric cards
     - Outstanding Bills table
     - Payment Recording Queue
     - Payment Entry form (issued bills only, allocation capped at outstanding)
     - Holds and Exceptions sections
     - Runs at `http://localhost:8501` by default

4. **Do not move to other sites until Shaxi has both reliable review loop AND trusted operating data.**
   - `reports/shaxi_bill_review_2026-05.html` — generated from live views
   - Shows summary cards with issued count, remaining pending count, total outstanding, workflow status
   - Draft bill table shows 杨华禾 as pending_review with review_before_approve warning
   - Outstanding Bills table shows 7 issued bills with payment status (all `due` until payments recorded)
   - Billing hold table unchanged
   - Safety panel shows all PASS
   - Regenerate with: `python scripts/generate_shaxi_bill_review_page.py`

4. **Do not move to other sites until Shaxi has both reliable review loop AND trusted operating data.**

---

## 10. Core Rules

The Shaxi workflow must follow these rules strictly:

1. **No guessing.**
2. **Unresolved candidates stay out of final lease components.**
3. **All final promotion must be verified and idempotent.**
4. **Pre-existing contracts stay in pre-existing state until explicitly promoted.**
5. **Draft bills only — no issuance without human approval.**
6. **Approved bills only — `sql/25_issue_approved_shaxi_bills_v2_1.sql` will issue 0 bills if no approvals exist.**

---

## 11. Current State Summary for New Session — post v2.6

Shaxi Rental OS v2.6 has safely resolved all 9 candidates, created 10 clean lease_package_components, built staff operating views, established a billing foundation, generated and issued **8** May 2026 rent bills (¥329,922.00 receivable), created a human-review queue, produced the staff-facing HTML review page, established an approval workflow gate, created payment recording views, built a Streamlit staff operating interface for payment recording, **structured business exception tracking, and applied the 3 confirmed exception decisions**.

Current clean state:
- 10 contracts verified (staged).
- 11 staged areas promoted/reused.
- 9 approved candidate areas created.
- 10 safe lease package components created.
- 0 candidates remain pending review.
- 0 pending candidates leaked into components.
- 0 duplicate components.
- 44 SX-39 rentable_areas tracked (9 canonical approved + 9 canonical promoted + 26 legacy/other).
- 34 areas occupied, 9 have no component, 1 has multiple active contracts (四区B栋首层).
- **8 issued rent bills for 2026-05-01 (due 2026-05-05), total ¥329,922.00.**
- **0 draft rent bills remaining.**
- **8 approval records: all 8 approved by Matthew/admin, 0 pending_review.**
- 0 issue-ready bills (all approved bills have been issued).
- 2 unbilled holds remain: 川田 (`keep_on_hold` per v2.6 — master/sublease, awaiting 靖大物业 master-lease rule), 朱河芳 (`pending_decision` — expired contract, awaiting 阮绮杨 renewal follow-up).
- 0 payments recorded. 0 payment allocations recorded.
- **Total outstanding: ¥329,922.00.**
- 1 static HTML review page can be regenerated from live views.
- 1 Streamlit staff interface ready for payment recording.

Next work should stay focused on Shaxi only.

Recommended next action:
1. Run `sql/35_verify_shaxi_exception_decisions_v2_6.sql` to confirm v2.6 state still holds.
2. Run earlier verifies (`03`, `14`, `16`, `18`, `21`, `23`, `26`, `28`, `30`, `31`, `33`) as needed.
3. Regenerate review page: `python scripts/generate_shaxi_bill_review_page.py`.
4. Confirm all safe counts still hold.
5. Choose next path:
    - **Path A** — Record actual payments against the 8 issued bills (via Streamlit app or manual SQL). ¥329,922.00 receivable.
    - **Path B** — Resolve 朱河芳 renewal (阮绮杨 follow-up). Update `shaxi_business_exception_reviews` once decision is in.
    - **Path C** — Confirm 川田 master-lease rent + rule at the 靖大物业 level. Generate the 靖大物业 master-lease bill if/when business confirms. NO direct 中铭 → 川田 bill.
    - **Path D** — Extend to `SX-BCY` (only after Shaxi is fully trusted).
6. Do not move to other sites until Shaxi has both reliable review loop AND trusted operating data.
