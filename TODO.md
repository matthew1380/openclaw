# TODO.md

## Next Priority

### 1. Define promotion logic from staging tables into final structure
- `stg_shaxi_areas_prepared` -> candidate `rentable_areas` logic
- `stg_shaxi_contracts_prepared` -> candidate contract/package linkage logic
- Keep review files unresolved until manually confirmed

### 2. Add legacy mapping rule for 原建泰第1座
- Map `原建泰第1座` -> `一区1栋`
- Update prepared area logic so this row can leave review

### 3. Keep all future work site-by-site
Current active pilot remains:
- `SX-39`
- `SX-BCY`

Do not expand to other sites until Shaxi promotion pipeline is stable.
