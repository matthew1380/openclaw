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
