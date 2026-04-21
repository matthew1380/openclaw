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
