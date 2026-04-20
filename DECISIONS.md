# DECISIONS.md

## 2026-04-18 — Initial reset decision
- Defined Rental OS as the first project scope
- Excluded the broader control tower from the first MVP
- Confirmed one-month internal MVP goal
- Confirmed top priorities: tenant/lease lookup, overdue, vacancy

## 2026-04-20 — Core technical direction locked
- Official code home: GitHub
- Official database: Supabase
- Preferred hosting direction: Tencent Cloud
- Preferred main AI builder: Kimi Code

## 2026-04-20 — Current live schema direction locked
- Continue with the existing live Supabase schema
- Do not rebuild the whole database from zero
- Use the current core live tables as the MVP base:
  - `properties`
  - `units`
  - `contacts`
  - `contracts`
  - `financial_records`
  - `operating_entities`

## 2026-04-20 — Asset/certificate modeling decision locked
We confirmed from the imported asset-master workbook that:

- 房产证号 is not unique in source data
- some owner fields contain ownership-change text
- some address fields contain changed-address text
- some valid assets have 无房产证
- one certificate may correspond to multiple future rentable units

Decision:
- treat the imported workbook as raw staging, not final live properties
- preserve raw fields exactly as source truth
- derive cleaned fields later
- do not use 房产证号 or 名称 as the sole unique key
- do not assume one certificate equals one rentable unit
- keep asset/certificate layer separate from rentable inventory and from lease contracts

## 2026-04-20 — Current MVP modeling priority
For the current MVP, prioritize:
1. asset-master raw layer
2. property grouping logic
3. tenant / contract lookup
4. financial-record linkage
5. overdue / vacancy / expiry views

Detailed physical-unit splitting comes later.

## 2026-04-20 — Shaxi operational grouping locked

Business truth from founder review:

- 下泽村 and 港园村 are the same industrial estate land for Shaxi operations
- Shaxi should be modeled as:
  1. 沙溪兴工路39号工业园 (industrial estate)
  2. 沙溪宝翠园 (residential site)

- 沙溪兴工路39号工业园 contains three operational sections:
  - 建泰
  - 利生
  - 佳達洗水

Decision:
- Do not treat 下泽村 and 港园村 as separate top-level properties
- Do not treat each parking space or motorbike space as a property group
- For Shaxi, the `properties` layer should collapse to two top-level properties:
  - 沙溪兴工路39号工业园
  - 沙溪宝翠园
- 建泰 / 利生 / 佳達洗水 should be modeled as sub-sections or later building/inventory grouping, not top-level properties

## 2026-04-20 — Shaxi overdue seed decision
Decision:
- Keep the existing 13 Shaxi lease-package units and 13 contracts
- Do not rebuild them
- Use the 2026 rent summary to create a first-pass YTD overdue seed
- Insert only matched SX-39 high-confidence overdue rows into financial_records
- Keep unmatched SX-BCY shop rows in review until the BCY contract layer is built
