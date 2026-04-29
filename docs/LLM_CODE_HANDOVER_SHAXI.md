# LLM Code Handover — Shaxi Rental OS
> **For:** The next code-writing LLM taking over from KimiCode
> **Project:** Rental OS — Shaxi Pilot (`SX-39`, `SX-BCY`)
> **Handover Date:** 2026-04-29
> **Current Version:** v2.5 complete
> **Next Task:** v2.6 — apply confirmed exception decisions

---

## 1. Current Project State

### What is built
- **v1.0–v1.9:** Landed data model, parcel/building/area hierarchy, safe lease-package components, billing foundation, rent bill generation.
- **v2.0–v2.2:** Bill review queue, bill approval workflow, normal bills approved and issued.
- **v2.3:** Payment recording and allocation framework (built but unused — see below).
- **v2.4:** Streamlit staff app (`scripts/shaxi_staff_app.py`) — operational for staff review.
- **v2.5:** Business exception resolution workflow (`shaxi_business_exception_reviews`) — built, decisions captured, but **not yet applied**.

### Critical business facts
| Fact | Detail |
|------|--------|
| **Fake payments** | **NONE inserted.** `payments` = 0, `payment_allocations` = 0. |
| **Outstanding May 2026 rent bills** | **7 bills**, total **¥327,422**. All are `bill_status = 'issued'`. |
| **杨华禾 (Yang Huahé)** | Approved by business decision to issue rent bill, but **v2.6 has not been applied** unless already done by you. |
| **川田 (Chuantián / 中山市川田制衣厂)** | **Correction:** 川田 pays rent to **靖大物业**, and **靖大物业** pays **中铭**. **Do NOT bill 川田 directly** from 中铭. Future billing for this chain should be handled at the 靖大物业 / master-lease level **only if** the master lease rent amount and billing rule are confirmed. |
| **朱河芳 (Zhu Hefāng)** | Renewal is **pending**. 阮绮杨 (Ruǎn Qǐyáng) is following up. **Do NOT issue a bill** until renewal is confirmed. |
| **SX-BCY expansion** | **Not yet.** Do not expand billing or exception workflows to `SX-BCY` until Shaxi (`SX-39`) is fully stable. |

---

## 2. Current Database State (Key Counts)

Run these queries to verify current state:

```sql
-- Safe lease-package components
SELECT COUNT(*) FROM lease_package_components;
-- Result: 40

-- Issued rent bills
SELECT COUNT(*), COALESCE(SUM(amount_due), 0)
FROM rent_bills
WHERE bill_status = 'issued';
-- Result: 7 bills, ¥327,422.00

-- Draft rent bills
SELECT COUNT(*) FROM rent_bills WHERE bill_status = 'draft';
-- Result: 1

-- Business exceptions
SELECT COUNT(*) FROM shaxi_business_exception_reviews;
-- Result: 3 (all decision_status = 'pending_decision')

-- Payments
SELECT COUNT(*) FROM payments;
-- Result: 0

-- Payment allocations
SELECT COUNT(*) FROM payment_allocations;
-- Result: 0

-- Exception details
SELECT exception_type, tenant_name, decision_status, decision_note
FROM shaxi_business_exception_reviews
ORDER BY id;
```

**Current exception queue:**
| exception_type | tenant_name | decision_status |
|----------------|-------------|-----------------|
| `expired_contract` | 朱河芳 | `pending_decision` |
| `pending_draft_bill` | 杨华禾 | `pending_decision` |
| `billing_hold` | 中山市川田制衣厂 | `pending_decision` |

**Note:** The `vw_shaxi_business_exception_queue_v2_5` and `vw_shaxi_business_exception_summary_v2_5` views provide staff-facing summaries.

---

## 3. File Inventory

### SQL migration files (`sql/`)
Files `02` through `33` are applied in sequence. Each build step has a matching `verify` file.

| Range | Phase |
|-------|-------|
| 02–03 | Promote Shaxi v1.0 |
| 04–05 | Contracts v1.1 + audit fields |
| 06–10 | Candidate review v1.2–v1.3 |
| 11–12 | Safe components v1.4–v1.5 |
| 13–16 | Staff reporting & operating views v1.6–v1.7 |
| 17–21 | Billing foundation & rent bills v1.8–v1.9 |
| 22–28 | Bill review, approval, issuance v2.0–v2.2 |
| 29–30 | Payment recording v2.3 (unused) |
| 31 | Staff interface support v2.4 |
| 32–33 | Exception resolution workflow v2.5 |

**Key files:**
- `sql/32_create_shaxi_exception_resolution_workflow_v2_5.sql`
- `sql/33_verify_shaxi_exception_resolution_workflow_v2_5.sql`

### Application files
- `scripts/shaxi_staff_app.py` — Streamlit staff interface (v2.4)

### Documentation files
- `docs/SHAXI_HANDOVER_CURRENT.md` — Previous human-facing handover
- `docs/SHAXI_STAFF_INTERFACE_V2_4.md` — Staff interface documentation
- `PROJECT_MEMORY.md` — Business context, pilot status, parcel/building truth
- `CHANGELOG.md` — Dated change history
- `TODO.md` — Phased task list

---

## 4. How to Run the App

```powershell
.\.venv\Scripts\python.exe -m streamlit run scripts/shaxi_staff_app.py
```

- Requires the `.venv` virtual environment in the repo root.
- No external dependencies beyond what is already in `.venv` (Streamlit, psycopg2-binary, python-dotenv).
- The app reads `SUPABASE_DB_URL` from `.env`.

---

## 5. How to Run SQL Using `.env`

**One-liner to run any SQL file:**

```powershell
$line = Get-Content .env | Where-Object { $_ -match "^SUPABASE_DB_URL=" } | Select-Object -First 1
$dbUrl = $line.Split("=",2)[1].Trim().Trim('"')
psql $dbUrl -f sql/33_verify_shaxi_exception_resolution_workflow_v2_5.sql
```

**One-liner to run an inline query:**

```powershell
$line = Get-Content .env | Where-Object { $_ -match "^SUPABASE_DB_URL=" } | Select-Object -First 1
$dbUrl = $line.Split("=",2)[1].Trim().Trim('"')
psql $dbUrl -c "SELECT COUNT(*) FROM rent_bills WHERE bill_status = 'issued';"
```

---

## 6. Current Next Task: v2.6 — Apply Confirmed Exception Decisions

### What must be done
Implement `sql/34_apply_confirmed_exception_decisions_v2_6.sql` (and matching `sql/35_verify_...`) to apply the business decisions already captured in `shaxi_business_exception_reviews`.

### Exact requirements
| Decision | Action |
|----------|--------|
| **Do NOT bill 川田 directly** | Update the 川田 exception record to `decision_status = 'approved'` with note explaining the billing chain. **Do NOT create a `rent_bills` row for 川田.** |
| **Record 川田 decision** | Document: "川田 pays 靖大物业, 靖大物业 pays 中铭." This is a business rule, not a payment record. |
| **Approve and issue 杨华禾** | Update 杨华禾 exception to `decision_status = 'approved'`. If a draft bill exists, move it to `bill_status = 'issued'`. If no draft exists, generate and issue the May 2026 bill according to existing billing rules. |
| **Keep 朱河芳 pending** | Leave `decision_status = 'pending_decision'`. **Do NOT create or issue any bill.** |
| **No fake payments** | `payments` and `payment_allocations` must remain at 0. Do not insert synthetic rows. |
| **No SX-BCY expansion** | Do not create bills or exceptions for `SX-BCY`. |
| **No new 靖大物业 bill** | Do not create a new master-lease bill for 靖大物业 unless the master lease rent amount and billing rule are explicitly confirmed by the business. |

### Verification requirement
After applying, run a verification query that confirms:
- 杨华禾 has an issued bill.
- 川田 has NO issued bill.
- 朱河芳 has NO issued bill.
- `payments` = 0, `payment_allocations` = 0.

---

## 7. Non-Negotiable Rules

These are hard constraints. Violating them will corrupt operational truth.

1. **No guessing** — If a business rule, rent amount, or contract status is unclear, stop and ask. Do not infer.
2. **No fake payments** — Never insert rows into `payments` or `payment_allocations` for demonstration or "balance" purposes.
3. **No direct bill to 川田** — 川田's rent flows through 靖大物业. Billing 川田 directly breaks the contract chain.
4. **No bill to 朱河芳 until renewal confirmed** — The contract is expired. Issuing a bill now is invalid.
5. **No SX-BCY expansion yet** — Keep scope locked to `SX-39` until Shaxi is fully stable.
6. **All SQL must be idempotent and safe to rerun** — Use `INSERT ... ON CONFLICT`, `WHERE NOT EXISTS`, or upsert patterns. A file re-run must never create duplicates.
7. **Always create verification SQL** — Every build file (e.g., `34_...`) must have a matching `35_verify_...` file that `SELECT`s counts and asserts expected state.
8. **Update docs after successful verification** — After `35_verify_...` passes, update `CHANGELOG.md`, `TODO.md`, and this file if the state changes.

---

## 8. New LLM — Start Here

### Step 0: Read the docs (5 minutes)
Read these in order:
1. `PROJECT_MEMORY.md` — understand Shaxi parcel/building truth and current pilot reality.
2. `DATABASE_SCHEMA.md` — understand table structure and field meanings.
3. `TODO.md` — see what is marked done vs. pending.
4. `CHANGELOG.md` — see the last dated entry to confirm where you are.
5. `docs/SHAXI_HANDOVER_CURRENT.md` — human-facing context.

### Step 1: Verify current database state (2 minutes)
Run the verification query for v2.5:

```powershell
$line = Get-Content .env | Where-Object { $_ -match "^SUPABASE_DB_URL=" } | Select-Object -First 1
$dbUrl = $line.Split("=",2)[1].Trim().Trim('"')
psql $dbUrl -f sql/33_verify_shaxi_exception_resolution_workflow_v2_5.sql
```

Also run the inline counts from **Section 2** above to confirm the numbers match.

### Step 2: Confirm the exception queue (1 minute)
```powershell
psql $dbUrl -c "SELECT id, exception_type, tenant_name, decision_status FROM shaxi_business_exception_reviews ORDER BY id;"
```

Expected: 3 rows, all `pending_decision` (朱河芳, 杨华禾, 中山市川田制衣厂).

### Step 3: Check for any existing v2.6 work
Look for `sql/34_*` or `sql/35_*` files. If they exist, read them before doing anything.

```powershell
Get-ChildItem sql/3[45]_*.sql
```

### Step 4: Implement v2.6
- Create `sql/34_apply_confirmed_exception_decisions_v2_6.sql`
- Create `sql/35_verify_shaxi_exception_decisions_v2_6.sql`
- Follow the exact requirements in **Section 6**.
- Follow the non-negotiable rules in **Section 7**.

### Step 5: Run verification
```powershell
psql $dbUrl -f sql/35_verify_shaxi_exception_decisions_v2_6.sql
```

### Step 6: Update documentation
- Append dated entry to `CHANGELOG.md`.
- Update `TODO.md` to mark v2.6 done.
- Update this file (`docs/LLM_CODE_HANDOVER_SHAXI.md`) with any new state changes.

---

## Quick Reference

| Question | Where to look |
|----------|---------------|
| What is the current pilot status? | `PROJECT_MEMORY.md` |
| What tables exist and what do they mean? | `DATABASE_SCHEMA.md` |
| What needs to be done next? | `TODO.md` and **Section 6** of this file |
| What changed recently? | `CHANGELOG.md` |
| How do I run SQL safely? | **Section 5** of this file |
| How do I run the staff app? | **Section 4** of this file |
| What are the hard rules? | **Section 7** of this file |

---

*End of handover. Good luck, next LLM. Do not break Shaxi.*
