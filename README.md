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
