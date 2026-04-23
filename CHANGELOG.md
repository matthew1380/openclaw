# CHANGELOG.md

## 2026-04-23

- Tooling and workflow baseline complete:
  - Kimi Code confirmed working in VS Code
  - GitHub workflow confirmed working
  - Local workflow folders established: `imports/raw/`, `imports/cleaned/`, `imports/review/`
  - `.gitignore` excludes local batch/import files
- Script status: `rent_summary_cleaner.py`, `shaxi_parcel_building_mapper.py`, `vacancy_summary_cleaner.py` are stable for current stage.
- Script refinements:
  - `rent_summary_cleaner.py`: supports real Shaxi confidence labels; `high_confidence_candidate` treated as clean/high; `needs_manual_review` remains review-triggering
  - `shaxi_parcel_building_mapper.py`: normalizes full-address Shaxi strings before matching (removes common site prefix, converts parcel brackets like `（三区）` -> `三区`, removes `【原...】` legacy suffixes, normalizes floor wording such as `二层` -> `2层`); broad bundled descriptions still sent to review
  - `vacancy_summary_cleaner.py`: broad area names marked unclear even with only one active contract
- Raw source preparation completed:
  - `imports/raw/shaxi_contracts_raw.csv` — combined from `shaxi_tenants_zhongming.csv` + `shaxi_tenants_jingda.csv`; blank rows and instruction rows removed
  - `imports/raw/shaxi_area_skeleton_raw.csv` — combined from `shaxi_buildings_zhongming.csv` + `shaxi_buildings_jingda.csv`; correct source columns used
  - `imports/raw/locations.csv` — extracted from `shaxi_contracts_raw.csv`
- Cleaned / review outputs created and verified:
  - `imports/cleaned/shaxi_mapped_locations.csv`
  - `imports/review/shaxi_mapping_review_queue.csv`
  - `imports/cleaned/shaxi_contracts_prepared.csv`
  - `imports/review/shaxi_contracts_mapping_review.csv`
  - `imports/cleaned/shaxi_area_skeleton_prepared.csv`
  - `imports/review/shaxi_area_skeleton_review.csv`
- Prepared contract logic completed:
  - Excel serial dates converted to ISO dates
  - Mapped fields attached from `shaxi_mapped_locations.csv`
  - Low-confidence/broad bundle rows preserved but marked `review_required`
  - Precise mapped rows marked `mapped`
- Prepared area logic completed:
  - Current parcel/building inferred from `property_internal_name` where possible
  - Building scope normalized from `building_name_raw`
  - Broad floor-range rows remain `review_required`
  - Precise rows such as `首层` / `首层1卡` / `夹层` are prepared
  - Known unresolved row remains: `一区 原建泰第1座` still `review_required` because current parcel/building inference for that legacy naming is not yet handled
- Stage-ready exports completed:
  - `imports/cleaned/shaxi_contracts_stage_ready.csv` (10 rows)
  - `imports/cleaned/shaxi_area_stage_ready.csv` (14 rows)
  - `imports/cleaned/shaxi_area_stage_canonical.csv` (11 rows)
- Supabase staging completed:
  - Created and loaded `public.stg_shaxi_contracts_prepared` (10 rows)
  - Created and loaded `public.stg_shaxi_areas_prepared` (11 rows)
- Current interpretation / business rules recorded:
  - Broad bundle rows stay out of stage-ready contract import
  - Broad floor-range area rows stay out of stage-ready area import
  - Shaxi remains the active pilot site
  - Current work is still a preparation/staging pipeline, not final promotion into all final truth tables

## 2026-04-22

- Set up Kimi Code in VS Code and confirmed repo-based workflow is working.
- Added and refined 3 local cleanup / preparation scripts:
  - `scripts/rent_summary_cleaner.py`
  - `scripts/shaxi_parcel_building_mapper.py`
  - `scripts/vacancy_summary_cleaner.py`
- Completed real mini-batch tests for all 3 scripts.
- Refined `rent_summary_cleaner.py` to support real Shaxi confidence labels:
  - `high_confidence_candidate` now maps to clean/high
  - `needs_manual_review` remains review-triggering
- Refined `shaxi_parcel_building_mapper.py` to normalize full-address Shaxi strings before matching:
  - removes common site prefix
  - converts parcel brackets like `（三区）` to `三区`
  - removes `【原...】` legacy suffixes
  - normalizes floor wording such as `二层 -> 2层`
  - keeps broad bundled descriptions in review
- Refined `vacancy_summary_cleaner.py` so broad area names are marked `unclear` even when only one active contract exists.
- Real mini-batch results:
  - rent summary cleaner: `3 cleaned / 1 review`
  - Shaxi mapper: precise rows mapped, broad bundled rows stayed in review
  - vacancy cleaner: `20 occupied / 0 vacant / 6 unclear`
- Created local workflow folders:
  - `imports/raw/`
  - `imports/cleaned/`
  - `imports/review/`
- Added `.gitignore` rules so local import/test data is not committed.
- Converted uploaded Excel workbooks to CSV and copied selected raw inputs into `imports/raw/`.
- Built `imports/raw/shaxi_contracts_raw.csv` from Shaxi tenant CSVs.
- Built `imports/raw/shaxi_area_skeleton_raw.csv` from Shaxi building CSVs using corrected source-column mapping.
- Built `imports/raw/locations.csv` from `shaxi_contracts_raw.csv` and ran mapping successfully.
- Confirmed GitHub is up to date after script/doc commits.

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
- Added `scripts/rent_summary_cleaner.py` for staging rent summary CSV cleanup with review queue routing
- Added `scripts/vacancy_summary_cleaner.py` for vacancy/occupancy reporting from area and contract CSVs
- Added `scripts/shaxi_parcel_building_mapper.py` for mapping raw Chinese location strings to normalized parcel/building/area codes
- Updated `AGENTS.md` repo structure to reflect new `scripts/` directory

## 2026-04-21 (revised scripts)
- Revised `scripts/rent_summary_cleaner.py` to match real pilot fields:
  `property_code_hint`, `rent_collector`, `property_group`, `tenant_name`,
  `paying_unit_text`, `monthly_rent_due`, `received_ytd`, `expected_rent_ytd_simple`,
  `ytd_gap_simple`, `overdue_confidence`, `remarks`.
  - Never guesses `unit_code` or `contract_code`.
  - Normalizes `overdue_confidence` flexibly to high/medium/low/unknown;
    unmapped values route to review queue.
  - Cross-checks `ytd_gap_simple` against `expected - received`.
- Revised `scripts/shaxi_parcel_building_mapper.py` to treat broad vague remainders
  (e.g. `主租区域`, `整栋`, `首层及2至4楼` without card specificity) as
  low-confidence review items. Consolidated duplicate regex logic.
- Revised `scripts/vacancy_summary_cleaner.py`:
  - Understands contract hierarchy (`direct_lease`, `master_lease`, `sublease`).
  - Master/sub overlap marked `occupied` only when component roles confirm
    structural expectation (`primary` master + `component`/`corrected_component` subleases).
  - Outputs readable `unit_code`; requires `--units` CSV if `contracts.csv` lacks `unit_code`.
  - Documents expected input CSV schemas in script docstring.
