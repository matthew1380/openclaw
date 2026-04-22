# PROJECT_MEMORY.md

## Current Working State (2026-04-22)

### Shaxi local pipeline status
The local Shaxi preparation pipeline is now partially operational.

Completed:
- raw Shaxi tenant sources combined into `imports/raw/shaxi_contracts_raw.csv`
- raw Shaxi building sources combined into `imports/raw/shaxi_area_skeleton_raw.csv`
- raw contract location text extracted into `imports/raw/locations.csv`
- Shaxi location mapping now works on normalized full-address source text
- broad bundled Shaxi area labels remain intentionally review-first

### Current script status
Stable enough for current stage:
- `rent_summary_cleaner.py`
- `shaxi_parcel_building_mapper.py`
- `vacancy_summary_cleaner.py`

### Real-data test results
- rent summary cleaner: `3 cleaned / 1 review`
  - known review row: 珍美
- mapper:
  - precise rows such as `三区A栋首层1卡`, `三区A栋首层2卡`, `三区A栋二层`, `四区B栋首层`, `四区C栋` mapped successfully
  - broad bundled rows stayed in review
- vacancy cleaner:
  - `20 occupied / 0 vacant / 6 unclear`
  - broad unresolved area names now correctly surface as unclear

### Current interpretation rule
Broad area labels are not treated as final operational truth even when linked to active contracts.
Examples:
- `三区A栋主租区域`
- `四区A栋2至4楼`
- `四区B栋首层及2至4楼`
- large cross-building bundle rows

These remain review-first.

### Immediate next deliverable
Build:
- `imports/cleaned/shaxi_contracts_prepared.csv`

from:
- `imports/raw/shaxi_contracts_raw.csv`
- `imports/cleaned/shaxi_mapped_locations.csv`

including:
- Excel serial date conversion
- mapped location fields
- mapping status field
