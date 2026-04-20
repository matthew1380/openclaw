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
