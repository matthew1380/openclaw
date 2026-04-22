# WORKFLOW.md

## Current Stage Snapshot (2026-04-22)

The local working pattern is now:

1. put source files in `imports/raw/`
2. run local preparation scripts from `scripts/`
3. inspect outputs in:
   - `imports/cleaned/`
   - `imports/review/`
4. only after review, prepare later staging imports into Supabase

### Current important raw files
- `imports/raw/shaxi_contracts_raw.csv`
- `imports/raw/shaxi_area_skeleton_raw.csv`
- `imports/raw/locations.csv`
- `imports/raw/rent_summary.csv`

### Current important outputs
- `imports/cleaned/shaxi_mapped_locations.csv`
- `imports/review/shaxi_mapping_review_queue.csv`
- `imports/cleaned/vacancy_report.csv`
- `imports/review/vacancy_unclear_queue.csv`
- `imports/cleaned/rent_summary_cleaned.csv`
- `imports/review/rent_summary_review_queue.csv`

### Current next step
Build:
- `imports/cleaned/shaxi_contracts_prepared.csv`

This becomes the bridge between raw Shaxi contract input and later controlled staging import into Supabase.