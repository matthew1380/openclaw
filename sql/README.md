# sql/ — Rental OS Promotion SQL

This directory contains the ordered, idempotent SQL promotion scripts for the Rental OS Shaxi pilot.

All scripts are designed to be run via local `psql` against the live Supabase database.

## Connection Pattern

```powershell
$line = Get-Content .env | Where-Object { $_ -match "^SUPABASE_DB_URL=" } | Select-Object -First 1
$dbUrl = $line.Split("=",2)[1].Trim().Trim('"')
psql $dbUrl -f sql/<file>.sql
```

- `.env` must contain `SUPABASE_DB_URL` using Supabase Session Pooler.
- `.env` is gitignored and must never be committed.

---

## File Inventory

| # | File | Purpose | Status |
|---|------|---------|--------|
| 02 | `02_promote_shaxi_v1.sql` | Promote 11 staged areas → `rentable_areas` | ✅ Executed |
| 03 | `03_verify_shaxi_v1.sql` | Master verification script (8 sections) | ✅ Active — run after any step |
| 04 | `04_promote_shaxi_contracts_v1_1.sql` | Promote 10 staged contracts → `contracts` | ✅ Executed |
| 05 | `05_add_contract_source_audit_fields.sql` | Add audit columns + backfill 10 contracts | ✅ Executed |
| 06 | `06_prepare_candidate_review_v1_2.sql` | Add review columns + create pending view | ✅ Executed |
| 07 | `07_verify_candidate_review_v1_2.sql` | Verify review flow setup | ✅ Executed |
| 08 | `08_export_candidate_review_list_v1_2.sql` | Human-readable export of pending candidates | ✅ Executed |
| 09 | `09_apply_candidate_decisions_v1_2.sql` | Record human review decisions | ✅ Executed |
| 10 | `10_apply_approved_candidate_areas_v1_3.sql` | Create rentable_areas from approved candidates | ✅ Executed |
| 11 | `11_create_safe_lease_package_components_v1_4.sql` | Create safe unit→area components | ✅ Executed |

---

## Verification

Run the master verification script to check the entire promotion state:

```powershell
psql $dbUrl -f sql/03_verify_shaxi_v1.sql
```

Expected results (all sections):

| Section | Check | Expected |
|---------|-------|----------|
| 1 | FK integrity | 0 invalid |
| 2 | Staged area lookup | 11 matched, 0 missing |
| 3 | Candidate dedup | CLEAN, 9 pending |
| 4 | Post-promotion areas | 11 in rentable_areas, 0 duplicates |
| 5 | Post-promotion contracts | 10 in contracts, 0 duplicates |
| 6 | Contract source audit | 10 with batch tag |
| 7 | Approved candidate areas | 6 with rentable_area_id, 3 pending |
| 8 | Lease_package_components | 7 safe components, 3 pending untouched |

---

## Next Session

1. Run verification:
   ```powershell
   psql $dbUrl -f sql/03_verify_shaxi_v1.sql
   ```

2. Pending work — 3 unresolved candidates:
   - 鲸鸣服饰 — 三区A栋4层
   - 杨华禾 — 三区A栋首层1卡
   - 朱河芳 — 三区A栋首层2卡

   These need either:
   - Human review decision → `approve_new_area` or `map_existing_area`
   - Or staff confirmation that existing long-name area linkage is sufficient

3. Potential next steps (do not proceed without explicit instruction):
   - Resolve remaining 3 candidates and create their components
   - Consolidate duplicate long-name vs short-name rentable_areas
   - Build staff review UI for candidate queue
   - Extend pattern to next site (SX-BCY)
   - Create current-truth views for app/reporting layer

---

## Rules for New Scripts

1. **Idempotent by default** — use `WHERE NOT EXISTS` or `ON CONFLICT DO NOTHING`.
2. **Read-only preview first** — every script should show what it will do before modifying data.
3. **Post-execution verification** — every script should include verification queries.
4. **Batch tagging** — use `promotion_batch = 'shaxi_promotion_v1'` for traceability.
5. **Do not auto-resolve** — never guess area names or force decisions.
6. **Preserve audit** — keep source/raw data even after creating resolved views.
