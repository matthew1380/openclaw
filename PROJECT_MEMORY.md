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
