# TODO.md

## Current State
Shaxi Rental OS v2.5 is complete. Business exception resolution workflow created.
7 issued bills outstanding (¥327,422 total). 0 payments recorded. 1 draft remains.
2 holds remain. 3 business exception reviews tracked. 0 exceptions. 0 duplicates.
Streamlit app available for payment recording and exception viewing. HTML review page updated.

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
- Use `scripts/shaxi_staff_app.py` to record payments via Streamlit interface
- Or insert real payment receipts manually into `payments` + `payment_allocations`
- Use `vw_shaxi_payment_recording_queue_v2_3` to target which bills to pay
- Monitor `vw_shaxi_payment_allocation_exceptions_v2_3` for data quality
- Regenerate the HTML review page to show updated payment status

### Path B — Resolve Held Cases
- Decide billing rule for master/sublease at 四区B栋首层 (靖大物业 + 川田)
- Confirm 朱河芳 renewal or vacancy
- Update `shaxi_business_exception_reviews` with decision_status and decision_note
- Regenerate held bills after decisions

### Path C — Approve 杨华禾 (when ready)
- Review contract ending 2026-09-15 and confirm rent amount before approving May 2026 bill
- Update `shaxi_business_exception_reviews` decision_status to `approved_to_issue`
- Then run `sql/25_issue_approved_shaxi_bills_v2_1.sql` to issue

### Path D — Make Exception Decisions
- Use `shaxi_business_exception_reviews` table to record decisions
- Update decision_status, decision_by, decision_at, decision_note
- Monitor `vw_shaxi_business_exception_summary_v2_5` for workflow status

### Path E — Extend to Next Site
- Only after Shaxi has both reliable review loop AND trusted billing data
- Apply the same promotion pattern to `SX-BCY`

## Deferred / Later
- Consolidate duplicate long-name vs short-name rentable_areas (legacy vs canonical).
- Add legacy mapping rule for `原建泰第1座` -> `一区1栋`.
- Create full current-truth views for app/reporting layer.
- Build Streamlit or other interactive approval UI (only if manual SQL approval becomes painful).

## Core Rule
Do not expand to other sites until Shaxi has a reliable staff-facing review loop AND trusted operating data.
