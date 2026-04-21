# CHANGELOG.md

## 2026-04-18
- Created initial project restart documentation
- Defined Rental OS as the first project scope
- Confirmed Supabase as official database starting point
- Confirmed Tencent Cloud as preferred hosting direction
- Confirmed one-month internal MVP goal
- Confirmed top priorities: tenant/lease lookup, overdue, vacancy

## 2026-04-20
- Confirmed current live Supabase schema is usable enough to continue
- Confirmed current core live tables: properties, units, contacts, contracts, financial_records, operating_entities
- Created 沙溪 staging tables for staff and tenants
- Imported 沙溪 staff staging and tenant staging
- Inserted 沙溪 staff contacts and tenant contacts
- Imported consolidated asset master workbook into staging
- Locked modeling rule that a certificate is not the same as a rentable unit
- Locked modeling rule that 房产证号 is not a unique operational key
- Locked modeling rule that raw source truth must remain separate from cleaned operational truth
- Locked modeling rule that owner/address change text must be preserved raw first
- Locked modeling rule that 无房产证 assets remain valid operational records

## 2026-04-20
- Imported and cleaned asset master workbook into staging
- Locked rule that one 房产证 is not the same as one rentable unit
- Built Shaxi property grouping:
  - SX-39 = 沙溪兴工路39号工业园
  - SX-BCY = 沙溪宝翠园
- Built Shaxi inventory seed and section grouping
- Confirmed 13 Shaxi lease-package units and 13 contracts are valid
- Built Shaxi contract backbone view
- Imported current rent summary and vacancy summary staging
- Built first-pass 2026 YTD overdue review
- Seeded 6 matched SX-39 overdue backlog rows into financial_records
- Parked 3 SX-BCY shop overdue rows in unmatched review queue
