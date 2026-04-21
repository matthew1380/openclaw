# DATABASE_SCHEMA.md

This file describes the current practical MVP schema direction for Rental OS.

It reflects both:
- the original core business tables
- the newer middle-layer structure needed for real-world rental truth

## Schema status
This is no longer just a theoretical draft.
The current Shaxi pilot already uses part of this structure in Supabase.

---

## 1. properties
Represents a top-level operating site.

### Current examples
- `SX-39` = 沙溪兴工路39号工业园
- `SX-BCY` = 沙溪宝翠园

### Current fields in live use (simplified)
- `id`
- `property_code`
- `property_name`
- `city`
- `district`
- `address_vague`
- `property_type`
- `total_units`
- `status`
- `created_at`

### Notes
A property is an operating site, not necessarily one legal certificate.

---

## 2. land_parcels
Represents legal parcel-level truth under a property.

### Purpose
Separates legal land/certificate structure from building and rental structure.

### Suggested fields
- `id`
- `property_id`
- `parcel_code`
- `parcel_name`
- `certificate_no_raw`
- `village_name`
- `notes`
- `created_at`

### Current Shaxi examples
- `SX39-Q1` / 一区 / `0233015`
- `SX39-Q2` / 二区 / `0230865`
- `SX39-Q3` / 三区 / `0231461`
- `SX39-Q4` / 四区 / `0230864`

---

## 3. building_registry
Represents the physical building/block layer.

### Purpose
Bridges legal parcel truth and operational rentable-area truth.

### Suggested fields
- `id`
- `property_id`
- `land_parcel_id`
- `building_code`
- `building_name`
- `parcel_building_label`
- `site_building_no`
- `section_group_name`
- `building_type`
- `certificate_no_raw`
- `source_asset_name`
- `source_address_raw`
- `gross_area_sqm`
- `land_piece_code` *(legacy text support if present)*
- `land_piece_name` *(legacy text support if present)*
- `is_active`
- `notes`
- `created_at`

### Current Shaxi examples
- `SX39-Q3-A` = 三区A栋
- `SX39-Q4-A` = 四区A栋
- `SX39-Q1-1` = 一区1栋
- `SX39-MULTI` = temporary cross-building grouping row

### Notes
`A/B/C` is only unique inside a parcel.
Do not treat `三区A栋` and `四区A栋` as the same building.

---

## 4. rentable_areas
Represents the physical or operational area that can be rented, reviewed, or tracked.

### Purpose
This is the true physical occupancy/vacancy layer.

### Suggested fields
- `id`
- `property_id`
- `building_id`
- `area_code`
- `area_name`
- `area_type`
- `floor_label`
- `card_or_room_label`
- `area_sqm`
- `leaseable_scope`
- `current_status`
- `section_group_name`
- `source_text_raw`
- `certificate_no_raw`
- `notes`
- `created_at`

### Current notes
Some rows are still:
- broad component seeds
- corrected components
- old primary package seeds kept for source-truth audit

### Important rule
Do not assume every `rentable_area` row is final physical truth.
Some still exist as temporary or broad component seeds and should be refined later.

---

## 5. units
Represents the **lease package layer** in the current MVP.

### Important interpretation
Although the table is called `units`, in the live Shaxi pilot it is functioning mainly as:
- lease package
- contract bundle
- current contract-level rentable grouping

### Current fields in live use (simplified)
- `id`
- `unit_code`
- `property_id`
- `unit_type`
- `building_code`
- `unit_number`
- `area_sqm`
- `base_rent`
- `status`
- `current_contract_id`
- `created_at`

### Notes
Do not treat current `units` rows as perfect physical areas.
Physical truth should come from `rentable_areas` + `lease_package_components`.

---

## 6. lease_package_components
Represents the relationship between a lease package (`units`) and one or more physical/operational areas.

### Purpose
This is the key bridge for real-world bundles.
One contract package may cover multiple buildings or multiple rentable areas.

### Suggested fields
- `id`
- `package_unit_id`
- `rentable_area_id`
- `component_role`
- `component_ratio`
- `is_estimated`
- `notes`
- `created_at`

### Current component roles seen in pilot
- `primary`
- `component`
- `corrected_component`

### Notes
This table is critical for bundled leases such as Shaxi master/head leases.

---

## 7. contacts
Represents tenants and other relevant contacts.

### Current fields in live use (simplified)
- `id`
- `contact_code`
- `contact_type`
- `name`
- `phone`
- `email`
- `wechat_id`
- `company_name`
- `position`
- `is_active`
- `created_at`

### Notes
Current live usage includes tenants and staff-related roles.

---

## 8. contracts
Represents lease agreements linked to package-level units.

### Current fields in live use (simplified)
- `id`
- `contract_code`
- `unit_id`
- `tenant_id`
- `landlord_op_entity_id`
- `receiving_account_hint`
- `start_date`
- `end_date`
- `monthly_rent`
- `deposit`
- `payment_day`
- `contract_status`
- `created_at`

### Important rule
Current `contracts` remain linked to package-level `units`, not directly to final physical rows.
The physical truth is reached through `lease_package_components`.

---

## 9. operating_entities
Represents the operating/legal income-collecting entity side.

### Current fields in live use (simplified)
- `id`
- `op_entity_code`
- `op_entity_name`
- `legal_parent_id`
- `city`
- `tax_regime`
- `default_bank_hint`
- `is_active`
- `created_at`

### Notes
Examples include Shaxi and BCY operator entities.

---

## 10. financial_records
Represents receivables, payment-related finance records, and seeded overdue backlog rows.

### Current fields in live use (simplified)
- `id`
- `record_code`
- `contract_id`
- `unit_id`
- `record_type`
- `direction`
- `amount`
- `period_start`
- `period_end`
- `due_date`
- `paid_date`
- `payment_method`
- `payment_reference`
- `bank_account_hint`
- `invoice_number`
- `status`
- `notes`
- `created_at`

### Important enum notes
Current live constraints include:
- `direction`: `income`, `expense`
- `record_type`: includes `rent`, `deposit`, `deposit_return`, utility types, fees, penalties, other income/expense

### Current seeded overdue rule
Some current rows are seeded overdue backlog rows created from the 2026 rent summary.
These are operational backlog rows, not final accounting truth.

---

## 11. staging / override / review tables
The current pilot also depends on staging and review tables for controlled cleanup.

### Examples already used
- rent summary staging tables
- BCY / Shaxi unit maps
- Shaxi tenant alias map
- Shaxi contract location override table
- Shaxi contract role map
- Shaxi scope review queue
- overdue seed staging tables

### Rule
Do not skip staging/review layers when source truth is messy.

---

## Current practical truth views
The app/reporting layer should prefer resolved/current-truth views rather than raw tables alone.

### Current examples already used in pilot
- contract backbone views
- overdue backlog views
- preferred physical-area views
- current-truth views

---

## Core calculated outputs needed for MVP
- active contract per package
- preferred current physical area per contract
- overdue backlog visibility
- vacancy / unclear area visibility
- days to contract expiry
- direct lease vs master lease vs sublease visibility

---

## Important schema rules
1. Do not collapse parcel, building, area, package, and contract truth into one table.
2. Keep raw/source wording available for audit.
3. Use resolved views for operations.
4. Use staging/review queues for ambiguous areas.
5. Add fields only when they solve a real operating problem.
