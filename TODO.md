# TODO.md

## Next Priority

### 1. Build prepared Shaxi contracts file
Create:

- `imports/cleaned/shaxi_contracts_prepared.csv`

using:

- `imports/raw/shaxi_contracts_raw.csv`
- `imports/cleaned/shaxi_mapped_locations.csv`

Requirements:
- keep all raw contract fields
- convert Excel serial dates into ISO dates
- attach mapped location fields where available
- add `location_mapping_status`
- keep unmatched/broad rows reviewable

### 2. Build prepared Shaxi area skeleton file
Create a prepared version of:

- `imports/raw/shaxi_area_skeleton_raw.csv`

Requirements:
- preserve raw source wording
- normalize obvious area/building labels
- do not collapse broad/bundled rows into false precision
- prepare for later staging import

### 3. Define staging import path into Supabase
Next stage after prepared CSVs:
- decide target staging tables
- decide insert/upsert rules
- import Shaxi only first

### 4. Keep all future work site-by-site
Current active pilot remains:
- `SX-39`
- `SX-BCY`

Do not expand to other sites until Shaxi prepared pipeline is stable.
