# PROJECT_MEMORY.md

## Current Working State (2026-04-23)

### Shaxi pipeline status
The local Shaxi preparation pipeline is now complete through staging.

Completed:
- Raw Shaxi tenant sources combined into `imports/raw/shaxi_contracts_raw.csv`
- Raw Shaxi building sources combined into `imports/raw/shaxi_area_skeleton_raw.csv`
- Raw contract location text extracted into `imports/raw/locations.csv`
- Shaxi location mapping works on normalized full-address source text
- Broad bundled Shaxi area labels remain intentionally review-first
- Prepared contract and area files built with review queues preserved
- Stage-ready exports created:
  - `shaxi_contracts_stage_ready.csv` = 10 rows
  - `shaxi_area_stage_ready.csv` = 14 rows
  - `shaxi_area_stage_canonical.csv` = 11 rows
- Supabase staging tables created and loaded:
  - `public.stg_shaxi_contracts_prepared` = 10 rows
  - `public.stg_shaxi_areas_prepared` = 11 rows

### Current script status
Stable enough for current stage:
- `rent_summary_cleaner.py`
- `shaxi_parcel_building_mapper.py`
- `vacancy_summary_cleaner.py`

### Real-data test results
- Rent summary cleaner: `3 cleaned / 1 review`
  - known review row: 珍美
- Mapper:
  - precise rows such as `三区A栋首层1卡`, `三区A栋首层2卡`, `三区A栋二层`, `四区B栋首层`, `四区C栋` mapped successfully
  - broad bundled rows stayed in review
- Vacancy cleaner:
  - `20 occupied / 0 vacant / 6 unclear`
  - broad unresolved area names now correctly surface as unclear

### Current interpretation rules
Broad area labels are not treated as final operational truth even when linked to active contracts.
Examples:
- `三区A栋主租区域`
- `四区A栋2至4楼`
- `四区B栋首层及2至4楼`
- large cross-building bundle rows

These remain review-first.

Broad bundle rows stay out of stage-ready contract import.
Broad floor-range area rows stay out of stage-ready area import.

Current work is still a preparation/staging pipeline, not final promotion into all final truth tables.

### Known unresolved item
`一区 原建泰第1座` remains `review_required` because current parcel/building inference for that legacy naming is not yet handled. Next rule to add: `原建泰第1座` -> `一区1栋`.

### Immediate next deliverable
Define promotion logic from staging tables into final structure:
- `stg_shaxi_areas_prepared` -> candidate `rentable_areas` logic
- `stg_shaxi_contracts_prepared` -> candidate contract/package linkage logic
