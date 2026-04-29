# TODO.md

## Current State
Shaxi Rental OS v2.6 is complete. Confirmed exception decisions applied.
**8 issued bills outstanding (¥329,922 total).** 0 payments recorded. 0 draft bills remain.
2 unbilled holds remain (川田 keep_on_hold, 朱河芳 pending_decision).
3 business exception reviews: 1 pending_decision (朱河芳), 1 keep_on_hold (川田), 1 approved_to_issue (杨华禾).
0 mapping/billing/payment-allocation exceptions. 0 duplicate bills.
Streamlit app available for payment recording and exception viewing. HTML review page can be regenerated.

## v2.1 Delivered
- `bill_approval_reviews` table created with `review_status` constraint
- 8 `pending_review` records seeded for May 2026 draft bills
- `vw_shaxi_bill_approval_queue_v2_1` — draft bills with approval status + recommendation
- `vw_shaxi_bill_issue_candidates_v2_1` — bills cleared for issuance
- `vw_shaxi_bill_approval_summary_v2_1` — single-row workflow status
- `sql/25_issue_approved_shaxi_bills_v2_1.sql` — safe issuance script (idempotent, issues 0 if no approvals)
- HTML review page updated to show approval status per bill

## v2.2 Delivered
- `sql/27_approve_normal_shaxi_bills_v2_2.sql` — approved 7 normal bills (all `review_and_approve`)
- `sql/25_issue_approved_shaxi_bills_v2_1.sql` — issued 7 approved bills
- Hotfix: corrected `vw_shaxi_bill_issue_candidates_v2_1` to handle `duplicate_existing` candidate status after bills are generated
- 杨华禾 remains `pending_review` (not approved, not issued)
- 川田 and 朱河芳 remain unbilled holds

## v2.3 Delivered
- `sql/29_record_shaxi_payments_v2_3.sql` — created payment recording views:
  - `vw_shaxi_outstanding_bills_v2_3` — 7 issued bills with allocated/outstanding/payment status
  - `vw_shaxi_payment_recording_queue_v2_3` — bills eligible for payment recording (issued + outstanding > 0)
  - `vw_shaxi_payment_allocation_exceptions_v2_3` — 8 exception detectors for payment allocations
- No fake payments inserted. `payments` and `payment_allocations` remain empty.
- `sql/30_verify_shaxi_payment_allocations_v2_3.sql` — 25 checks, ALL PASSED
- HTML review page updated with Outstanding Bills table and total outstanding card

## v2.4 Delivered
- `scripts/shaxi_staff_app.py` — Streamlit staff operating interface
  - Dashboard: issued bills, total issued, outstanding, payment-eligible, draft/pending, holds, exceptions
  - Outstanding Bills table with payment status
  - Payment Recording Queue
  - Payment Entry form: select bill, enter amount, method, reference, notes
  - Safety: only issued bills selectable, allocation capped at outstanding, draft/holds blocked
  - Holds section and Exceptions section
- `scripts/requirements.txt` — `streamlit` dependency
- `docs/SHAXI_STAFF_INTERFACE_V2_4.md` — interface documentation
- `sql/31_verify_shaxi_staff_interface_support_v2_4.sql` — 25 checks, ALL PASSED

## v2.6 Delivered
- `sql/34_apply_shaxi_exception_decisions_v2_6.sql` — applied 3 captured decisions (4 UPDATEs)
  - 中山市川田制衣厂: `pending_decision` → `keep_on_hold` with full master/sublease note
    - No new `rent_bills` row created for 川田
    - No new master-lease bill for 靖大物业 (master rent + rule not yet confirmed)
  - 杨华禾: `pending_decision` → `approved_to_issue`; bill_approval_reviews → `approved`; rent_bills.bill_status `draft` → `issued` (¥2,500.00, bill `4adcf5d2…`)
  - 朱河芳: NO CHANGE. Stays `pending_decision` pending 阮绮杨 renewal follow-up.
  - All 4 UPDATEs state-guarded; rerun confirmed `UPDATE 0` × 4 (idempotent).
- `sql/35_verify_shaxi_exception_decisions_v2_6.sql` — 31 checks, ALL PASSED
  - Issued bills: 7 → 8. Outstanding: ¥327,422 → ¥329,922. Drafts: 1 → 0.
  - 川田 still 0 bills. 朱河芳 still 0 bills. No 靖大物业 May 2026 bill.
  - payments=0, payment_allocations=0. Mapping/billing/payment_allocation exceptions=0.
  - Regression: v1.7–v2.5 views all match expected counts.
- Documentation updated: `CHANGELOG.md`, `docs/SHAXI_HANDOVER_CURRENT.md`, `PROJECT_MEMORY.md`, `TODO.md`

## v2.5 Delivered
- `sql/32_create_shaxi_exception_resolution_workflow_v2_5.sql` — exception resolution workflow
  - `shaxi_business_exception_reviews` table with 8 allowed decision statuses
  - 3 review records seeded idempotently (川田, 朱河芳, 杨华禾)
  - `vw_shaxi_business_exception_queue_v2_5` — active exception queue with recommended actions
  - `vw_shaxi_business_exception_summary_v2_5` — single-row workflow summary
- `sql/33_verify_shaxi_exception_resolution_workflow_v2_5.sql` — 30 checks, ALL PASSED
  - Exactly 3 active reviews, all pending_decision
  - Held cases remain unbilled, 杨华禾 remains draft
  - No fake payments, 0 payments, 0 allocations
  - 7 issued bills unchanged, total outstanding ¥327,422
  - All v1.7 to v2.4 regression views pass
- `scripts/shaxi_staff_app.py` updated with Business Exceptions tab
- Documentation updated: `docs/SHAXI_HANDOVER_CURRENT.md`, `CHANGELOG.md`, `PROJECT_MEMORY.md`

## Next Priority

### Path A — Record Actual Payments (Recommended next)
- 8 issued bills now eligible for payment recording (¥329,922.00 total)
- Use `scripts/shaxi_staff_app.py` to record payments via Streamlit interface
- Or insert real payment receipts manually into `payments` + `payment_allocations`
- Use `vw_shaxi_payment_recording_queue_v2_3` to target which bills to pay (8 rows)
- Monitor `vw_shaxi_payment_allocation_exceptions_v2_3` for data quality
- Regenerate the HTML review page to show updated payment status

### Path B — Resolve 朱河芳 Renewal
- 朱河芳 (三区A栋首层2卡, contract SX-C-011) remains `pending_decision`
- 阮绮杨 follow-up in flight — confirm renewal or mark vacant
- When confirmed: update `shaxi_business_exception_reviews` for 朱河芳 (decision_status, decision_by, decision_at, decision_note)
- If renewed: generate fresh draft bill for the new contract period
- If vacant: set decision_status to `mark_vacant`

### Path C — Confirm 川田 Master-Lease Billing Rule
- 川田 is `keep_on_hold` per v2.6 — billing chain documented (川田 → 靖大物业 → 中铭)
- Outstanding business work: confirm master lease rent amount and billing rule for 靖大物业
- Once confirmed: generate the 靖大物业 master-lease bill at the correct level (NOT a 中铭 → 川田 direct bill)
- Until then, do NOT bill 川田 directly

### Path D — Extend to Next Site
- Only after Shaxi has both reliable review loop AND trusted billing data
- Apply the same promotion pattern to `SX-BCY`

## Deferred / Later
- Consolidate duplicate long-name vs short-name rentable_areas (legacy vs canonical).
- Add legacy mapping rule for `原建泰第1座` -> `一区1栋`.
- Create full current-truth views for app/reporting layer.
- Build Streamlit or other interactive approval UI (only if manual SQL approval becomes painful).

## Core Rule
Do not expand to other sites until Shaxi has a reliable staff-facing review loop AND trusted operating data.
