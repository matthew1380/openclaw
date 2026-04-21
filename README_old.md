# Rental OS

Rental OS is an internal rental management system for managing rental assets, tenants, contracts, receivables, vacancy, and lease expiry.

## Current project status
This project is in MVP restart phase.

The first usable version should help answer these business questions quickly:
- Who is the tenant in this unit or lease package?
- What contract is currently active?
- What is overdue?
- Which units or packages are vacant?
- Which leases are expiring soon?

## Current project direction
- Project phase: Rental OS first
- Broader control tower: excluded for now
- Official database: Supabase
- Official hosting direction: Tencent Cloud
- Official code home: GitHub
- Preferred main AI builder: Kimi Code

## MVP priorities
1. Fast tenant / lease lookup
2. Overdue visibility
3. Vacancy visibility

## Current modeling stance
Rental OS must distinguish between:
1. asset / certificate layer
2. physical rentable inventory layer
3. lease / contract layer

These layers are not the same thing.

### Important rule
A 房产证 / certificate record is **not** the same as a rentable unit.
One certificate may correspond to:
- one building
- multiple buildings
- several floors
- a dorm block
- a factory block
- many future rentable rooms/cards/spaces

## Current live schema direction
The current core live tables include:
- `properties`
- `units`
- `contacts`
- `contracts`
- `financial_records`
- `operating_entities`

Current staging tables include:
- `stg_sx_staff`
- `stg_sx_tenants`
- `stg_sx_unit_map`
- `stg_asset_master_20260415`

## Current known progress
Completed or in progress:
- project documentation created
- Supabase project confirmed
- Tencent Cloud server confirmed
- operating entities inserted
- 沙溪 property row inserted
- 沙溪 staff contacts imported
- 沙溪 tenant contacts imported
- asset master workbook imported into staging
- core SQL views drafted/tested

## Current biggest lessons
- 房产证号 is not unique in source data
- 名称 is not unique enough to be a system key
- raw owner/address change text must be preserved
- raw asset master is staging, not final live properties
- one contract may describe a lease package, not one physical unit

## Immediate next milestone
Produce a usable internal MVP within one month.

## Definition of MVP success
The MVP is successful only if it can be used to:
- search tenant and lease info fast
- identify overdue payments clearly
- show vacancy clearly
- show active leases and upcoming expiry
- preserve raw source truth while allowing cleaned operational views

## Repo rules
Before changing code:
1. Read `PROJECT_MEMORY.md`
2. Read `DATABASE_SCHEMA.md`
3. Read `DECISIONS.md`
4. Read `TODO.md`
5. Make the smallest safe change
6. Update `CHANGELOG.md`
7. Update documentation if schema or workflow changes

## Notes
This repo is the project memory for Rental OS.
Important decisions must not live only in chat history.
