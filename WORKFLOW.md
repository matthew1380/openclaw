# WORKFLOW.md

## Current Stage Snapshot (2026-04-23)

The local working pattern is now:

1. Put source files in `imports/raw/`
2. Run local preparation scripts from `scripts/`
3. Inspect outputs in:
   - `imports/cleaned/`
   - `imports/review/`
4. Build stage-ready exports from prepared cleaned + review outputs
5. Import stage-ready data into Supabase staging tables
6. Only after review, promote from staging into final truth tables

### Current important raw files
- `imports/raw/shaxi_contracts_raw.csv`
- `imports/raw/shaxi_area_skeleton_raw.csv`
- `imports/raw/locations.csv`
- `imports/raw/rent_summary.csv`

### Current important prepared outputs
- `imports/cleaned/shaxi_mapped_locations.csv`
- `imports/review/shaxi_mapping_review_queue.csv`
- `imports/cleaned/shaxi_contracts_prepared.csv`
- `imports/review/shaxi_contracts_mapping_review.csv`
- `imports/cleaned/shaxi_area_skeleton_prepared.csv`
- `imports/review/shaxi_area_skeleton_review.csv`

### Current stage-ready exports
- `imports/cleaned/shaxi_contracts_stage_ready.csv` (10 rows)
- `imports/cleaned/shaxi_area_stage_ready.csv` (14 rows)
- `imports/cleaned/shaxi_area_stage_canonical.csv` (11 rows)

### Current Supabase staging tables
- `public.stg_shaxi_contracts_prepared` (10 rows)
- `public.stg_shaxi_areas_prepared` (11 rows)

### Current next step
Define promotion logic from staging tables into final structure:
- `stg_shaxi_areas_prepared` -> candidate `rentable_areas` logic
- `stg_shaxi_contracts_prepared` -> candidate contract/package linkage logic

This becomes the bridge between Supabase staging and final operational truth.
