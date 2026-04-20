# PROJECT_MEMORY.md

## Project name
Rental OS

## Project purpose
Rental OS is the first serious internal system for managing rental operations.

It is meant to reduce dependence on scattered files, scattered people, and temporary memory.

## Current business goals
The system must help quickly answer:
- who is the tenant
- which unit or lease package they are in
- what contract is active
- what is overdue
- which units or packages are vacant
- which leases are expiring soon

## Project phase
Current phase: MVP restart

This project is being treated as **Rental OS first**, not as the full business control tower.

## Founder / current owner
- Sole current owner: Matthew Wong

## Current known official assets

### GitHub
- Repo starting point: `matthew1380/openclaw`

### Supabase
- Official project name: 利兴强租赁系统
- Current state: usable schema exists and staging/import work is underway

### Hosting
- Preferred hosting direction: Tencent Cloud
- Current server starting point exists on Tencent Cloud
- Current state: infrastructure exists, but full app deployment is not yet working cleanly

### File storage
- Current state: many files still originate from local computer
- Desired state: structured storage on Tencent Cloud and/or related cloud storage
- Rule: raw source files must remain recoverable

## Current confirmed progress
- operating entities created for 沙溪 use
- 沙溪 property row inserted
- 沙溪 staff staging imported
- 沙溪 tenant staging imported
- staff contacts inserted
- tenant contacts inserted
- asset master workbook imported into `stg_asset_master_20260415`
- certificate and asset-modeling rules clarified

## Current blockers
1. App-to-database connection and usable frontend are still incomplete
2. Asset / certificate layer, rentable inventory layer, and contract layer are not fully separated yet
3. Physical-unit vacancy model is not finalized
4. Financial records / overdue import is not yet completed

## MVP scope

### Core MVP entities
- Properties
- Units / lease packages
- Contacts / Tenants / Staff
- Contracts
- Financial records
- Overdue visibility
- Vacancy visibility
- Lease expiry visibility

### Requested additional version-1 items
- Invoices
- Utilities
- Maintenance
- Tasks / reminders
- Approvals

## MVP delivery target
- Target: usable internal MVP within one month

## Most important business priorities
1. Find tenant / lease information fast
2. Know overdue payments clearly
3. Know vacancy clearly

## Locked modeling rules

### Rule 1 — Do not expand into the broader control tower until Rental OS MVP works
Rental OS comes first.

### Rule 2 — Do not rely on chat history as project memory
Anything important must be written into repo docs.

### Rule 3 — Any code or schema change must update the relevant repo files
At minimum:
- `PROJECT_MEMORY.md`
- `DATABASE_SCHEMA.md`
- `DECISIONS.md`
- `TODO.md`
- `CHANGELOG.md`

### Rule 4 — The first working layer must be reliable before adding more features
Do not pile new features onto unstable basics.

### Rule 5 — A certificate is not a rentable unit
A 房产证 / certificate record is not the same thing as a rentable unit.
One certificate may correspond to:
- one building
- multiple buildings
- several floors
- a dorm block
- a factory block
- many future rentable rooms/cards/spaces

### Rule 6 — Do not use 房产证号 as the unique operational key
Confirmed duplicates exist in source data, including:
- 0230864 appearing 3 times
- 0230865 appearing 3 times
- 0231464 appearing 3 times

There is also source noise where a header-like 房产证号 value appeared in duplicates.
Therefore 房产证号 is a raw legal/certificate field, not a guaranteed unique property key.

### Rule 7 — Do not use 名称 as the unique key
名称 is descriptive only and may repeat.

### Rule 8 — Keep owner text raw first, derive current owner later
Examples:
- 黄继雄变更为：中山市中铭房地产置业发展有限公司
- 黄继铭变更为：中山市中铭房地产置业发展有限公司
- 黄广流、容玉娟变更为：中山市中铭房地产置业发展有限公司

These must be preserved as raw source truth.
A cleaned current owner field should be derived later.

### Rule 9 — Keep changed-address text raw first, derive current address later
Examples:
- 中山市大涌镇青岗村"企岭上" 变更为 :中山市大涌镇兴华路8号
- 中山市大涌镇兴华路 变更为 :中山市大涌镇兴华路8号之一

These must be preserved as raw source truth.
A cleaned current address field should be derived later.

### Rule 10 — 无房产证 is valid operational information
Rows with no certificate number must not be discarded automatically.

### Rule 11 — Asset master is a raw staging layer, not the final live property table
The imported workbook is raw source truth.
It must not be copied row-for-row into final live tables without classification and cleaning.

### Rule 12 — Separate these three layers in future design
The project must distinguish between:
1. asset / certificate layer
2. physical rentable inventory layer
3. lease / contract layer

### Rule 13 — Duplicate certificate numbers usually mean shared or multi-part asset coverage
Do not delete duplicates blindly.

### Rule 14 — Source truth and cleaned truth must be separate
For important source fields such as 房产证号, 权属人, 房产地址:
- preserve raw source text
- derive cleaned operational fields separately
- never overwrite raw source truth

## First working layer
1. asset-master raw layer
2. property grouping logic
3. tenant / contact layer
4. contract linkage
5. financial-record linkage
6. overdue visibility
7. vacancy visibility
8. lease expiry
9. fast search

## Current open questions
- What exact app stack will be used for MVP frontend/backend?
- What is the final strategy for physical rentable inventory?
- When should `contract_units` or equivalent many-to-many structure be introduced?
- What is the exact Tencent Cloud folder/storage structure?
- What is the best import path for financial records / overdue data?

## Update rule
Whenever the project changes, update:
- `PROJECT_MEMORY.md`
- `TODO.md`
- `CHANGELOG.md`
- `DECISIONS.md`
- `DATABASE_SCHEMA.md` if schema or modeling changes

 ### Locked Shaxi grouping rule
For operational purposes:
- 下泽村 and 港园村 belong to the same Shaxi industrial estate
- Shaxi has one industrial estate: 沙溪兴工路39号工业园
- Shaxi has one residential site: 沙溪宝翠园
- The industrial estate has three sections:
  - 建泰
  - 利生
  - 佳達洗水

Therefore Shaxi top-level property grouping must be:
1. 沙溪兴工路39号工业园
2. 沙溪宝翠园

### Contract section labeling rule
For Shaxi lease-package contracts, `section_group_name` is an operational helper label only.
If a contract spans multiple sections, the label may reflect the first or dominant matched section and must not be treated as perfect physical truth.
