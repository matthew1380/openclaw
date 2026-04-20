# TODO.md

## Current objective
Build a usable Rental OS MVP in one month.

## Top business priorities
1. Fast tenant / lease search
2. Overdue visibility
3. Vacancy visibility

---

## Phase 1 — Foundation
- [ ] Confirm GitHub repo structure and make it official
- [ ] Add README.md
- [ ] Add PROJECT_MEMORY.md
- [ ] Add DATABASE_SCHEMA.md
- [ ] Add DECISIONS.md
- [ ] Add CHANGELOG.md
- [ ] Add TODO.md
- [ ] Review current Tencent Cloud server state
- [ ] Decide final MVP app stack
- [ ] Create structured cloud file storage plan

---

## Phase 2 — Current live schema and import control
- [x] Confirm current Supabase schema is usable enough to continue
- [x] Confirm current core live tables
- [x] Create 沙溪 staging tables
- [x] Create asset-master staging table
- [x] Import 沙溪 staff staging
- [x] Import 沙溪 tenant staging
- [x] Import asset master workbook staging
- [x] Insert 沙溪 staff contacts
- [x] Insert 沙溪 tenant contacts
- [ ] Finalize unit/package mapping logic for 沙溪
- [ ] Finalize contract import for 沙溪
- [ ] Import financial records / arrears source
- [ ] Validate overdue logic with real data

---

## Phase 3 — Asset-master cleanup and grouping
- [ ] Remove or flag source-noise/header rows from asset-master staging
- [ ] Review duplicate certificate numbers, do not delete blindly
- [ ] Flag owner-change rows
- [ ] Flag changed-address rows
- [ ] Flag 无房产证 rows
- [ ] Define cleaned current-owner field logic
- [ ] Define cleaned current-address field logic
- [ ] Design property grouping logic from asset-master staging
- [ ] Decide how to derive physical rentable inventory from asset-master rows

---

## Phase 4 — First working product flow
- [ ] Create tenant / lease search page
- [ ] Create vacancy page
- [ ] Create overdue page
- [ ] Create lease expiry page
- [ ] Create property page or form
- [ ] Create contact / tenant page or form
- [ ] Create contract page or form
- [ ] Create financial-record entry flow
- [ ] Add search for tenant / lease / unit

---

## Phase 5 — Real data testing
- [ ] Test tenant lookup with real records
- [ ] Test active contract lookup
- [ ] Test overdue calculation
- [ ] Test vacancy logic
- [ ] Test lease expiry visibility
- [ ] Fix connection/setup issues in the live app
- [ ] Confirm app is actually usable by operator

---

## Phase 6 — Version-1 extension items
- [ ] Add invoices
- [ ] Add utilities
- [ ] Add maintenance
- [ ] Add tasks / reminders
- [ ] Add approvals

---

## Definition of done for MVP
- [ ] Can search tenant and lease info fast
- [ ] Can identify overdue payments clearly
- [ ] Can identify vacancy clearly
- [ ] Can see lease expiry clearly
- [ ] App is actually usable
- [ ] Database connection is stable
- [ ] Raw source truth is preserved
- [ ] Repo documentation is updated
