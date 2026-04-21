# AGENTS.md — Rental OS
> This file is the first thing an AI coding agent should read before working on this project.
> The repo is documentation-only at this stage. All live data and schema live in Supabase.
---
## Project Overview
**Rental OS** is an internal rental management system for managing rental assets, land parcels, buildings, rentable areas, lease packages, tenants, contracts, finance records, overdue items, vacancy, and lease expiry.
- **Current phase**: MVP build with real pilot data (active as of April 2026).
- **Current pilot sites**:
  - `SX-39` = 沙溪兴工路39号工业园
  - `SX-BCY` = 沙溪宝翠园
- **Sole owner**: Matthew Wong
- **Official repo starting point**: `matthew1380/openclaw` on GitHub
- **Official database**: Supabase (project name: 利兴强租赁系统)
- **Preferred hosting direction**: Tencent Cloud
- **Preferred builder workflow**: Kimi Code / AI coding assistant
### What the MVP must do
1. Fast tenant / contract lookup
2. Overdue visibility
3. Vacancy / unclear-area visibility
4. Show active contracts and upcoming expiry
5. Show current physical rented area with reasonable truth
---
## Technology Stack and Runtime Architecture
### Important: this repo contains no application code yet
This repository is currently **documentation-only**. There is no `pyproject.toml`, `package.json`, `Cargo.toml`, or any other build configuration. The live schema, data, and any application layer reside in external systems.
### External systems
| Layer | System | Purpose |
|-------|--------|---------|
| Database | Supabase (PostgreSQL) | Live pilot schema and real tenant/contract/finance data |
| Hosting | Tencent Cloud (planned) | Target runtime environment |
| Source control | GitHub (`matthew1380/openclaw`) | Code home (application code not yet committed here) |
| Builder | Kimi Code / AI assistant | Primary development workflow |
### Planned architecture (from decisions)
- Database-first approach: schema lives in Supabase
- Application layer will be built to query the live Supabase schema
- Reporting/views layer should use "current-truth" views rather than raw tables
- Staging and review tables are used for data cleanup before promoting to operational truth
---
## Repo Structure
```
.
├── AGENTS.md              ← You are here
├── CHANGELOG.md           ← Date-stamped change history
├── DATABASE_SCHEMA.md     ← Live MVP schema documentation
├── DECISIONS.md           ← Architecture and direction decisions
├── PROJECT_MEMORY.md      ← Business context, pilot status, rules
├── README.md              ← Human-facing project overview
├── TODO.md                ← Task list by phase
├── scripts/               ← Reusable Python cleanup and mapping scripts
│   ├── rent_summary_cleaner.py
│   ├── vacancy_summary_cleaner.py
│   └── shaxi_parcel_building_mapper.py
├── Desktop.code-workspace ← VS Code workspace config (points to parent dir)
└── (starter docs)         ← Old starter files being phased out
```
### File purposes
| File | What it contains | When to update |
|------|------------------|----------------|
| `README.md` | Human-facing project description, current status, repo rules | When project status or scope changes |
| `PROJECT_MEMORY.md` | Business context, Shaxi parcel/building truth, contract mapping, owner info | When pilot reality changes |
| `DATABASE_SCHEMA.md` | Table definitions, field lists, schema rules, view guidance | When tables or fields change |
| `TODO.md` | Phased task list, definition of done | When tasks complete or priorities shift |
| `CHANGELOG.md` | Dated list of what was done | After every meaningful change |
| `DECISIONS.md` | Locked architecture and modeling decisions | When a new major decision is made |
---
## Mandatory Workflow for Agents
Before changing **anything** in this repo or in the connected Supabase schema:
1. **Read `PROJECT_MEMORY.md`** — understand current pilot reality.
2. **Read `DATABASE_SCHEMA.md`** — understand current table structure and rules.
3. **Read `TODO.md`** — understand current priorities.
4. **Make the smallest safe change** — do not over-engineer.
5. **Update `CHANGELOG.md`** — add a dated entry explaining what changed.
6. **Update docs** — if the change affects structure or workflow, update the relevant `.md` file.
### Critical rules
- **Chat is not the source of truth.** The repo docs must carry the latest operating rules, structure, and decisions.
- **Do not collapse truth layers.** Keep certificate truth, parcel truth, building truth, rentable-area truth, lease-package truth, contract truth, and finance truth in separate tables or layers.
- **Keep raw/source wording** for audit, even after creating resolved/current-truth views.
- **Do not skip staging/review layers** when source truth is messy.
- **Keep pilot sites stable** before broad rollout.
- **Never change live Supabase schema or data directly** without first showing the proposed SQL and getting approval.
- **For write/delete/rename actions affecting multiple files,** always ask for approval first.
---
## Data Model Conventions
### Hierarchy for Shaxi (and future sites)
```
site -> land parcel -> building -> rentable area -> lease package -> contract
```
### Table roles
| Table | Role | Notes |
|-------|------|-------|
| `properties` | Top-level operating site | e.g. `SX-39`, `SX-BCY` |
| `land_parcels` | Legal parcel/certificate layer | Separates legal land from building structure |
| `building_registry` | Physical building layer | Bridges parcel truth and rentable-area truth |
| `rentable_areas` | Physical occupancy/vacancy layer | True physical areas; some rows are still broad seeds |
| `units` | **Lease package layer** (current MVP) | Acts as contract bundle, not final physical unit |
| `lease_package_components` | Bridge table | Links `units` to `rentable_areas` for bundled leases |
| `contacts` | Tenants and other contacts | |
| `contracts` | Lease agreements | Linked to package-level `units`, not directly to physical rows |
| `operating_entities` | Legal income-collecting entities | |
| `financial_records` | Receivables, payments, overdue backlog | Includes seeded operational backlog rows |
### Contract roles
Current pilot uses:
- `direct_lease`
- `master_lease`
- `sublease`
### Key Shaxi truth
- `A/B/C` building labels are **only unique inside a parcel**.
- `三区A栋` and `四区A栋` are different buildings.
- Shaxi parcels:
  - `SX39-Q1` = 一区 = certificate `0233015`
  - `SX39-Q2` = 二区 = certificate `0230865`
  - `SX39-Q3` = 三区 = certificate `0231461`
  - `SX39-Q4` = 四区 = certificate `0230864`
---
## Build and Test Commands
### Python cleanup scripts
The `scripts/` directory contains standalone Python 3 scripts using only the standard library.
Run any script with `--help` for usage:
```bash
python scripts/rent_summary_cleaner.py raw_rent_summary.csv --output-cleaned cleaned.csv --output-review review.csv
python scripts/vacancy_summary_cleaner.py --rentable-areas rentable_areas.csv --components lease_package_components.csv --contracts contracts.csv
python scripts/shaxi_parcel_building_mapper.py raw_locations.csv --location-column location --output-mapped mapped.csv --output-review review.csv
```
No external dependencies are required.

When application code is added, this section must also be updated with:
- Dependency management commands
- Build/compile commands
- Lint/format commands
- Test runner commands
---
## Testing and Quality Assurance
### Current testing strategy
There are no automated tests yet. Quality is ensured through:
1. **Manual review queues** — ambiguous contracts or areas are tracked in review tables (e.g. `SX-C-006`, `SX-C-008`, `SX-C-010`).
2. **Staging tables** — source data is imported into staging tables first, then cleaned before promotion.
3. **Current-truth views** — the app/reporting layer should prefer resolved views over raw tables.
4. **Physical-area reconciliation** — contract locations are reconciled against the `building_registry` + `rentable_areas` layer with manual overrides where needed.
### Seeded data rules
- Overdue backlog rows in `financial_records` are **operational seeds**, not final month-by-month accounting truth.
- They are marked with notes indicating they are seeded from the rent summary.
- Future work will replace these with exact receivable logic.
---
## Code Style Guidelines
### Markdown documentation
- Use consistent H1/H2/H3 hierarchy.
- Keep tables aligned for readability.
- Use Chinese names in backticks when referring to physical sites (e.g. `沙溪兴工路39号`).
- Use `code` formatting for table names, field names, and record codes.
- Date format in `CHANGELOG.md` and `DECISIONS.md`: `YYYY-MM-DD`.
### Future application code
When code is added, follow these conventions derived from current decisions:
- Prefer small, focused changes.
- Do not over-abstract; solve the real operating problem first.
- Separate raw/source truth from resolved operational truth.
- Use staging layers for messy imports.
---
## Security Considerations
- **Sensitive data lives in Supabase, not in this repo.** Do not commit tenant personal data, contract scans, or financial details to Git.
- **Bank account hints** in `financial_records` and `operating_entities` are currently stored as text hints, not full account numbers. Keep it that way.
- **Do not expose Supabase credentials** in any committed code.
- **Prefer environment variables** for all external service configuration when application code is introduced.
- `.env` files should be ignored by Git.
---
## Current Immediate Milestone
Lock the working Shaxi pilot structure into repo memory, then extend the same pattern to the next site.
### Definition of MVP success
- [ ] Current-truth view is accepted as operational source of truth
- [ ] Only a small manual review queue remains
- [ ] Staff can understand parcel/building/area hierarchy
- [ ] Overdue backlog is visible and usable
- [ ] Repo docs reflect actual database reality
---
## Quick Reference
| Question | Where to look |
|----------|---------------|
| What is the current pilot status? | `PROJECT_MEMORY.md` |
| What tables exist and what do they mean? | `DATABASE_SCHEMA.md` |
| What needs to be done next? | `TODO.md` |
| What was decided and why? | `DECISIONS.md` |
| What changed recently? | `CHANGELOG.md` |
| How do I make a change safely? | **This file, section "Mandatory Workflow for Agents"** |
