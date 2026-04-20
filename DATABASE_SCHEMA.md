# DATABASE_SCHEMA.md

This file describes the current live schema direction and modeling rules for Rental OS.

## Schema status
The live Supabase schema already exists.
This file documents:
- the current core live tables
- the staging tables currently used for import
- the intended future layering logic

## Core design principle
Rental OS must separate:
1. asset / certificate layer
2. physical rentable inventory layer
3. lease / contract layer

These layers are not the same thing.

---

## Current live core tables

### 1. `properties`
Represents a major site / property group /园区 / operational property group.

Current real usage:
- a site like `沙溪兴工路39号工业园`

Important note:
A `property` is not the same thing as a certificate row.

---

### 2. `units`
Current MVP usage: may temporarily represent a leaseable package or operational unit.

Important note:
This table should not be assumed to be one physical legal unit per row.
For MVP, some rows may represent lease packages.

Fields currently observed include:
- `id`
- `unit_code`
- `property_id`
- `unit_type`
- `building_code`
- `floor`
- `unit_number`
- `area_sqm`
- `rent_pricing_type`
- `base_rent`
- `market_rent`
- `min_lease_months`
- `status`
- `current_contract_id`
- assignment fields
- `created_at`

### Current modeling caution
- `current_contract_id` must not be treated as the only source of truth
- occupancy should be derived from contracts and dates
- `building_code` is for management grouping, not raw source text
- full source package text should not be forced into short code fields

---

### 3. `contacts`
Represents tenants, staff, representatives, and other relevant contacts.

Observed contact types include:
- `tenant`
- `tenant_representative`
- `sub_tenant`
- `vendor`
- `staff_data_entry`
- `staff_collector`
- `staff_handler`
- `staff_leasing`
- `staff_accountant`
- `staff_manager`
- `owner_representative`
- `emergency_contact`

Important note:
One tenant contact may have multiple contracts.

---

### 4. `contracts`
Represents lease agreements.

Observed key fields include:
- `id`
- `contract_code`
- `unit_id`
- `tenant_id`
- `tenant_rep_id`
- `landlord_op_entity_id`
- `landlord_signatory_id`
- `receiving_account_hint`
- `invoice_entity_id`
- `start_date`
- `end_date`
- `monthly_rent`
- `deposit`
- `payment_day`
- assignment fields
- `pdf_url`
- `contract_status`
- `created_by`
- `created_at`

### Observed `contract_status` enum
- `draft`
- `pending`
- `active`
- `expiring_soon`
- `expired`
- `terminated`
- `renewed`

### Current modeling caution
A contract may describe a bundle/package of rentable space, not necessarily one simple physical room.

---

### 5. `financial_records`
Represents receivable / collection / settlement records used for MVP money visibility.

Observed key fields include:
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
- recorded/collected/confirmed fields
- receipt/invoice fields
- `status`
- `notes`
- `created_at`

### Observed `financial_status` enum
- `pending`
- `confirmed`
- `disputed`
- `waived`
- `refunded`
- `cancelled`

### MVP interpretation
For the current MVP, overdue is primarily derived from:
- `status = pending`
- due date passed
- paid date empty

---

### 6. `operating_entities`
Represents landlord/operator entities used in contracts and collections.

Observed key fields include:
- `id`
- `op_entity_code`
- `op_entity_name`
- `legal_parent_id`
- `city`
- `tax_regime`
- `default_bank_hint`
- `is_active`
- `created_at`

Important note:
This table is required because `contracts.landlord_op_entity_id` is not nullable.

---

## Current staging tables

### `stg_sx_staff`
Raw 沙溪 staff import staging

### `stg_sx_tenants`
Raw 沙溪 tenant/lease-package import staging

### `stg_sx_unit_map`
Temporary mapping between long lease-package source text and shorter operational codes

### `stg_asset_master_20260415`
Raw asset / certificate workbook staging layer

Important note:
`stg_asset_master_20260415` is raw source truth and must not be treated as final live property rows.

---

## Asset master modeling rules

### Rule A
One row in asset-master staging may represent:
- one certificate record
- one building
- part of a building
- multiple future rentable units
- a no-certificate asset
- a row with historical owner/address change notes

### Rule B
`房产证号` is raw source data, not a guaranteed unique key

### Rule C
`名称` is descriptive only, not a guaranteed unique key

### Rule D
`权属人` may contain both old owner and current owner change text

### Rule E
`房产地址` may contain both old address and updated address text

### Rule F
Rows with `无房产证` must be retained

---

## Intended future layering

### Layer 1 — asset / certificate layer
Possible future table(s):
- `asset_records`
- or equivalent cleaned asset master

### Layer 2 — physical rentable inventory layer
Possible future table(s):
- `physical_units`
- `buildings`
- `inventory_summary`

### Layer 3 — lease / contract layer
Existing:
- `contracts`

### Likely future relationship
If bundled leases remain common, the long-term model should likely include:
- `contract_units`
or equivalent many-to-many linking table

This is because one contract may cover multiple rentable units.

---

## Core calculated outputs needed for MVP
- active contract per unit/package
- overdue amount
- overdue days
- vacancy status
- days to lease expiry
- tenant / lease search view

---

## Important schema rules
1. Avoid fragile manual links where logic can determine current state
2. Do not allow AI-generated draft records to become final without review
3. Keep raw source truth separate from cleaned operational truth
4. Do not treat certificate rows as final rentable units automatically
5. Do not assume duplicate certificate numbers are data errors
6. Every field added should solve a real operating need
