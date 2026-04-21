# Rental OS Repo Starter Files

Use the following as the current repo starter files for GitHub. These drafts reflect the **actual current state** of the Supabase pilot, especially the Shaxi (`SX-39`, `SX-BCY`) structure and the new middle-layer model.

---

# 1. README.md

```markdown
# Rental OS

Rental OS is an internal rental management system for managing rental assets, land parcels, buildings, rentable areas, lease packages, tenants, contracts, finance records, overdue items, vacancy, and lease expiry.

## Current project status
This project is in active MVP build phase.

The database skeleton is no longer just a draft. A working pilot structure now exists in Supabase, with Shaxi as the main model site.

## Current MVP goals
The first usable version must help the operator answer these questions quickly:
- Who is the tenant?
- What contract is currently active?
- What physical area is being rented?
- What is overdue?
- Which areas are vacant or still unclear?
- Which contracts are expiring soon?

## Current pilot scope
The current pilot focuses on:
- `SX-39` = 沙溪兴工路39号工业园
- `SX-BCY` = 沙溪宝翠园

The Shaxi pilot now includes:
- property grouping
- land parcel layer
- building layer
- rentable area layer
- lease package layer
- contract layer
- seeded overdue backlog

## Current official direction
- Official database: Supabase
- Official code home: GitHub
- Preferred hosting direction: Tencent Cloud
- Preferred builder direction: Kimi Code / code assistant workflow

## Important modeling rule
Rental OS must not force one table to represent all truths at once.

The system should separate:
1. legal/certificate truth
2. parcel/building truth
3. rentable-area truth
4. lease-package truth
5. contract truth
6. finance truth

## Current Shaxi hierarchy
For Shaxi, the correct structure is:

`site -> land parcel -> building -> rentable area -> lease package -> contract`

### Example
- Site: `SX-39`
- Land parcels: `一区 / 二区 / 三区 / 四区`
- Buildings inside parcels: `1栋 / A栋 / B栋 / C栋`
- Rentable areas: floors, cards, shopfronts, dorm areas
- Lease packages: current contract bundles

## Current reality of `units`
In the current MVP, the `units` table is acting mainly as the **lease package layer**, not as the final physical area layer.

That is intentional for now.

## What already works in the pilot
### Shaxi
- `properties`
- `contacts`
- `contracts`
- `financial_records`
- `land_parcels`
- `building_registry`
- `rentable_areas`
- `lease_package_components`
- Shaxi contract role mapping
- preferred physical-area logic
- seeded overdue backlog for matched rows

### Overdue pilot
Current overdue logic is still a seeded operational backlog, not final month-by-month accounting truth.

Seeded overdue rows currently exist for:
- `SX-39`
- `SX-BCY`

## Current known limitations
The system is not yet fully cleaned to perfect physical truth for all sites.

Remaining work includes:
- finer splitting of broad Shaxi component areas
- manual scope confirmation for a few Shaxi contracts
- broader site rollout beyond Shaxi
- later month-by-month receivable truth

## Repo rules
Before changing code or schema:
1. Read `PROJECT_MEMORY.md`
2. Read `DATABASE_SCHEMA.md`
3. Read `TODO.md`
4. Make the smallest safe change
5. Update `CHANGELOG.md`
6. Update docs if structure or workflow changed

## Current immediate milestone
Lock the working Shaxi pilot structure into repo memory, then extend the same pattern to the next site.

## Definition of MVP success
The MVP is successful only if it can:
- search tenant and contract info fast
- show current physical rented area with reasonable truth
- identify overdue clearly enough for operations
- show vacancy / unclear area gaps clearly
- show active contracts and upcoming expiry

## Important note
Chat is not the source of truth.
The repo must carry the latest operating rules, structure, and decisions.
```

---

# 2. PROJECT_MEMORY.md

```markdown
# PROJECT_MEMORY.md

## Project name
Rental OS

## Project purpose
Rental OS is the internal operating system for rental management.

Its job is to reduce dependence on scattered spreadsheets, scattered people, and temporary memory.

## Current business goals
The system must help quickly answer:
- who is the tenant
- what contract is active
- what physical area is rented
- what is overdue
- what is vacant or unclear
- what is expiring soon

## Current project phase
Current phase: MVP build with real pilot data.

This project is still being treated as **Rental OS first**, not as the full business control tower.

## Current owner
- Sole current owner: Matthew Wong

## Official systems
### GitHub
- Repo starting point: `matthew1380/openclaw`

### Supabase
- Official project name: 利兴强租赁系统
- Current state: active working pilot schema exists

### Hosting
- Preferred hosting direction: Tencent Cloud

## Current pilot site
### Shaxi
Two top-level Shaxi properties are now locked:
- `SX-39` = 沙溪兴工路39号工业园
- `SX-BCY` = 沙溪宝翠园

### Critical Shaxi modeling rule
For `SX-39`, the correct hierarchy is:

`site -> land parcel -> building -> rentable area -> lease package -> contract`

### Shaxi parcel truth
Shaxi used to be four separate pieces of land. After land merge, building labels could not be changed, so the registry logic still uses:
- 一区
- 二区
- 三区
- 四区

to separate the four original land parcels.

### Shaxi parcel/building mapping
- `SX39-Q1` = 一区 = certificate `0233015` = 港园村 = 一区1栋
- `SX39-Q2` = 二区 = certificate `0230865` = 下泽村 = 二区A/B/C栋
- `SX39-Q3` = 三区 = certificate `0231461` = 下泽村 = 三区A/B/C栋
- `SX39-Q4` = 四区 = certificate `0230864` = 下泽村 = 四区A/B/C栋

### Important Shaxi truth
`A/B/C` is only unique inside a parcel.
So `三区A栋` and `四区A栋` are different buildings.

## Current live schema reality
### Core live tables already in use
- `properties`
- `units`
- `contacts`
- `contracts`
- `financial_records`
- `operating_entities`

### New middle-layer tables now added
- `land_parcels`
- `building_registry`
- `rentable_areas`
- `lease_package_components`

### Important interpretation
Current `units` rows are mainly acting as **lease packages**, not final physical units.
This is acceptable for the current MVP.

## Current Shaxi contract truth
### `SX-39`
13 package contracts are already loaded and working.

### `SX-BCY`
4 BCY shop contracts are already loaded and working.

## Current Shaxi finance truth
### Overdue seed rule
For the current MVP, seeded overdue rows were derived from the current rent summary and inserted into `financial_records` as operational backlog records.

These are not final month-by-month accounting truth.

They may be stored as:
- `record_type = rent`
- `direction = income`
- `status = pending`

with notes marking them as seeded overdue backlog.

## Current Shaxi truth layers
### Raw/source truth
- original contract wording remains preserved
- original rent-summary wording remains preserved

### Resolved operational truth
The app/reporting layer should prefer the resolved/current truth views, not raw contract wording.

### Manual location corrections already confirmed
Two Shaxi small-shop contracts were corrected from old `三区A` interpretation to `四区A`:
- `SX-C-011` -> 四区A栋首层2卡
- `SX-C-012` -> 四区A栋首层1卡

## Current manual scope-review queue
Current known review items:
- `SX-C-006` 珍美: scope ambiguity between contract wording and current rent summary
- `SX-C-008` 靖大: broad area label `三区A栋主租区域`
- `SX-C-010` 刘英: broad area label `四区B栋首层及2至4楼`

## Important current rule
Do not rewrite raw contracts just because current operational truth uses normalized or corrected wording.

Keep:
- raw contract wording
- current rent summary wording
- manual overrides
- preferred physical-area truth

## Current best operational view
The preferred operational truth for Shaxi should come from:
- preferred physical-area layer
- contract role map
- manual overrides where confirmed

Not from raw package seed rows alone.

## Project rules
1. Do not rely on chat history as project memory.
2. Any structural change must be written into the repo.
3. Do not collapse certificate truth, parcel truth, building truth, and contract truth into one table.
4. Keep pilot sites stable before broad rollout.

## Next high-value tasks
1. Freeze current pilot logic into repo docs
2. Use current-truth views for the app/reporting layer
3. Resolve only the small manual review queue
4. Extend the same structure to the next site after Shaxi is stable
```

---

# 3. DATABASE_SCHEMA.md

```markdown
# DATABASE_SCHEMA.md

This file describes the current practical MVP schema direction for Rental OS.

It reflects both:
- the original core business tables
- the newer middle-layer structure needed for real-world rental truth

## Schema status
This is no longer just a theoretical draft.
The current Shaxi pilot already uses part of this structure in Supabase.

---

## 1. properties
Represents a top-level operating site.

### Current examples
- `SX-39` = 沙溪兴工路39号工业园
- `SX-BCY` = 沙溪宝翠园

### Current fields in live use (simplified)
- `id`
- `property_code`
- `property_name`
- `city`
- `district`
- `address_vague`
- `property_type`
- `total_units`
- `status`
- `created_at`

### Notes
A property is an operating site, not necessarily one legal certificate.

---

## 2. land_parcels
Represents legal parcel-level truth under a property.

### Purpose
Separates legal land/certificate structure from building and rental structure.

### Suggested fields
- `id`
- `property_id`
- `parcel_code`
- `parcel_name`
- `certificate_no_raw`
- `village_name`
- `notes`
- `created_at`

### Current Shaxi examples
- `SX39-Q1` / 一区 / `0233015`
- `SX39-Q2` / 二区 / `0230865`
- `SX39-Q3` / 三区 / `0231461`
- `SX39-Q4` / 四区 / `0230864`

---

## 3. building_registry
Represents the physical building/block layer.

### Purpose
Bridges legal parcel truth and operational rentable-area truth.

### Suggested fields
- `id`
- `property_id`
- `land_parcel_id`
- `building_code`
- `building_name`
- `parcel_building_label`
- `site_building_no`
- `section_group_name`
- `building_type`
- `certificate_no_raw`
- `source_asset_name`
- `source_address_raw`
- `gross_area_sqm`
- `land_piece_code` *(legacy text support if present)*
- `land_piece_name` *(legacy text support if present)*
- `is_active`
- `notes`
- `created_at`

### Current Shaxi examples
- `SX39-Q3-A` = 三区A栋
- `SX39-Q4-A` = 四区A栋
- `SX39-Q1-1` = 一区1栋
- `SX39-MULTI` = temporary cross-building grouping row

### Notes
`A/B/C` is only unique inside a parcel.
Do not treat `三区A栋` and `四区A栋` as the same building.

---

## 4. rentable_areas
Represents the physical or operational area that can be rented, reviewed, or tracked.

### Purpose
This is the true physical occupancy/vacancy layer.

### Suggested fields
- `id`
- `property_id`
- `building_id`
- `area_code`
- `area_name`
- `area_type`
- `floor_label`
- `card_or_room_label`
- `area_sqm`
- `leaseable_scope`
- `current_status`
- `section_group_name`
- `source_text_raw`
- `certificate_no_raw`
- `notes`
- `created_at`

### Current notes
Some rows are still:
- broad component seeds
- corrected components
- old primary package seeds kept for source-truth audit

### Important rule
Do not assume every `rentable_area` row is final physical truth.
Some still exist as temporary or broad component seeds and should be refined later.

---

## 5. units
Represents the **lease package layer** in the current MVP.

### Important interpretation
Although the table is called `units`, in the live Shaxi pilot it is functioning mainly as:
- lease package
- contract bundle
- current contract-level rentable grouping

### Current fields in live use (simplified)
- `id`
- `unit_code`
- `property_id`
- `unit_type`
- `building_code`
- `unit_number`
- `area_sqm`
- `base_rent`
- `status`
- `current_contract_id`
- `created_at`

### Notes
Do not treat current `units` rows as perfect physical areas.
Physical truth should come from `rentable_areas` + `lease_package_components`.

---

## 6. lease_package_components
Represents the relationship between a lease package (`units`) and one or more physical/operational areas.

### Purpose
This is the key bridge for real-world bundles.
One contract package may cover multiple buildings or multiple rentable areas.

### Suggested fields
- `id`
- `package_unit_id`
- `rentable_area_id`
- `component_role`
- `component_ratio`
- `is_estimated`
- `notes`
- `created_at`

### Current component roles seen in pilot
- `primary`
- `component`
- `corrected_component`

### Notes
This table is critical for bundled leases such as Shaxi master/head leases.

---

## 7. contacts
Represents tenants and other relevant contacts.

### Current fields in live use (simplified)
- `id`
- `contact_code`
- `contact_type`
- `name`
- `phone`
- `email`
- `wechat_id`
- `company_name`
- `position`
- `is_active`
- `created_at`

### Notes
Current live usage includes tenants and staff-related roles.

---

## 8. contracts
Represents lease agreements linked to package-level units.

### Current fields in live use (simplified)
- `id`
- `contract_code`
- `unit_id`
- `tenant_id`
- `landlord_op_entity_id`
- `receiving_account_hint`
- `start_date`
- `end_date`
- `monthly_rent`
- `deposit`
- `payment_day`
- `contract_status`
- `created_at`

### Important rule
Current `contracts` remain linked to package-level `units`, not directly to final physical rows.
The physical truth is reached through `lease_package_components`.

---

## 9. operating_entities
Represents the operating/legal income-collecting entity side.

### Current fields in live use (simplified)
- `id`
- `op_entity_code`
- `op_entity_name`
- `legal_parent_id`
- `city`
- `tax_regime`
- `default_bank_hint`
- `is_active`
- `created_at`

### Notes
Examples include Shaxi and BCY operator entities.

---

## 10. financial_records
Represents receivables, payment-related finance records, and seeded overdue backlog rows.

### Current fields in live use (simplified)
- `id`
- `record_code`
- `contract_id`
- `unit_id`
- `record_type`
- `direction`
- `amount`
- `period_start`
- `period_end`
- `due_date`
- `paid_date`
- `payment_method`
- `payment_reference`
- `bank_account_hint`
- `invoice_number`
- `status`
- `notes`
- `created_at`

### Important enum notes
Current live constraints include:
- `direction`: `income`, `expense`
- `record_type`: includes `rent`, `deposit`, `deposit_return`, utility types, fees, penalties, other income/expense

### Current seeded overdue rule
Some current rows are seeded overdue backlog rows created from the 2026 rent summary.
These are operational backlog rows, not final accounting truth.

---

## 11. staging / override / review tables
The current pilot also depends on staging and review tables for controlled cleanup.

### Examples already used
- rent summary staging tables
- BCY / Shaxi unit maps
- Shaxi tenant alias map
- Shaxi contract location override table
- Shaxi contract role map
- Shaxi scope review queue
- overdue seed staging tables

### Rule
Do not skip staging/review layers when source truth is messy.

---

## Current practical truth views
The app/reporting layer should prefer resolved/current-truth views rather than raw tables alone.

### Current examples already used in pilot
- contract backbone views
- overdue backlog views
- preferred physical-area views
- current-truth views

---

## Core calculated outputs needed for MVP
- active contract per package
- preferred current physical area per contract
- overdue backlog visibility
- vacancy / unclear area visibility
- days to contract expiry
- direct lease vs master lease vs sublease visibility

---

## Important schema rules
1. Do not collapse parcel, building, area, package, and contract truth into one table.
2. Keep raw/source wording available for audit.
3. Use resolved views for operations.
4. Use staging/review queues for ambiguous areas.
5. Add fields only when they solve a real operating problem.
```

---

# 4. TODO.md

```markdown
# TODO.md

## Current objective
Stabilize the Rental OS MVP skeleton and make the Shaxi pilot the reference model for rollout.

## Top business priorities
1. Fast tenant / contract lookup
2. Overdue visibility
3. Vacancy / unclear-area visibility
4. Better physical area truth

---

## Phase 1 — Repo and documentation
- [ ] Replace old starter docs with current repo docs
- [ ] Update README.md to reflect current Shaxi pilot
- [ ] Update PROJECT_MEMORY.md with current Shaxi parcel/building logic
- [ ] Update DATABASE_SCHEMA.md with middle-layer tables
- [ ] Update CHANGELOG.md with real April 2026 progress
- [ ] Keep TODO.md aligned with current reality

---

## Phase 2 — Stabilize current pilot structure
- [x] Lock Shaxi top-level properties `SX-39` and `SX-BCY`
- [x] Add `land_parcels`
- [x] Add `building_registry`
- [x] Add `rentable_areas`
- [x] Add `lease_package_components`
- [x] Add BCY shop units and BCY contracts
- [x] Add Shaxi overdue seed backlog for matched rows
- [x] Add preferred physical-area logic
- [x] Add contract role map (`direct_lease`, `master_lease`, `sublease`)
- [ ] Freeze current-truth views as official app/reporting source for Shaxi

---

## Phase 3 — Shaxi cleanup queue
- [ ] Confirm `SX-C-006` physical scope with staff
- [ ] Split `三区A栋主租区域` into more precise areas after staff confirmation
- [ ] Split `四区B栋首层及2至4楼` into more precise areas after staff confirmation
- [ ] Decide whether to keep or retire old `primary` seed rows in operational reports
- [ ] Review whether `三区C栋宿舍` and `四区A栋2至4楼` are already good enough for first production use

---

## Phase 4 — Finance refinement
- [x] Seed first overdue backlog from current rent summary
- [ ] Replace seeded YTD overdue rows later with more exact month-by-month receivable logic
- [ ] Separate real bank-account meaning from operator-entity code hints where needed
- [ ] Review whether BCY overdue rows need the same preferred-truth treatment as SX-39

---

## Phase 5 — App/reporting layer
- [ ] Use current-truth views in the app instead of raw contract text
- [ ] Show contract role in app (`direct`, `master`, `sublease`)
- [ ] Show parcel/building/area hierarchy in Shaxi views
- [ ] Build vacancy / unclear-area report from preferred physical-area layer
- [ ] Build Shaxi current occupancy summary page

---

## Phase 6 — Rollout logic
- [ ] Decide next site after Shaxi
- [ ] Reuse the same model: property -> parcel -> building -> area -> package -> contract
- [ ] Create import rules for next site using Shaxi as template

---

## Definition of done for current Shaxi pilot
- [ ] Current-truth view is accepted as operational source of truth
- [ ] Only a small manual review queue remains
- [ ] Staff can understand parcel/building/area hierarchy
- [ ] Overdue backlog is visible and usable
- [ ] Repo docs reflect actual database reality
```

---

# 5. CHANGELOG.md

```markdown
# CHANGELOG.md

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
```

