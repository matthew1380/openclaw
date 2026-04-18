# Rental OS Repo Starter Files

Use the following as the starting files in your GitHub repo.

---

# 1. README.md

```markdown
# Rental OS

Rental OS is an internal rental management system being built to help manage rental assets, tenants, leases, charges, payments, overdue items, vacancy, and lease expiry.

## Current project status
This project is in MVP restart phase.

The goal of the first version is to let the operator quickly answer these questions:
- Who is the tenant in this unit?
- What lease is currently active?
- What is overdue?
- Which units are vacant?
- Which leases are expiring soon?

## Current scope of MVP
The MVP focuses on:
- Properties
- Units
- Tenants / Contacts
- Leases
- Charges
- Payments
- Overdue status
- Vacancy status
- Lease expiry visibility

The broader control-tower vision is intentionally excluded for now.

## Official project direction
- Project phase: Rental OS first
- Official database: Supabase
- Official hosting direction: Tencent Cloud
- Official code home: GitHub
- Preferred main AI builder: Kimi Code

## Planned version-1 additions after core flow works
- Invoices
- Utilities
- Maintenance
- Tasks / reminders
- Approvals

## Core workflow target
The first complete working flow should support:
1. Create property
2. Create unit
3. Add tenant / contact
4. Create lease
5. Add charges
6. Record payment
7. Show overdue
8. Show vacancy
9. Show lease expiry
10. Search tenant and lease information quickly

## What is blocked right now
The current project is blocked by app-to-database connection and setup.

## Repo rules
Before changing code:
1. Read `PROJECT_MEMORY.md`
2. Read `DATABASE_SCHEMA.md`
3. Read `TODO.md`
4. Make the smallest safe change
5. Update `CHANGELOG.md`
6. Update documentation if schema or workflow changes

## Immediate next milestone
Produce a usable internal MVP within one month.

## Definition of MVP success
The MVP is successful only if it can be used to:
- Search tenant and lease info fast
- Identify overdue payments clearly
- Show vacancy clearly
- Show active leases and upcoming expiry

## Notes
This repo should become the project memory for the Rental OS build. Important decisions should not live only in chat history.
```

---

# 2. PROJECT_MEMORY.md

```markdown
# PROJECT_MEMORY.md

## Project name
Rental OS

## Project purpose
Rental OS is the first serious internal system for managing rental operations.

It is meant to reduce dependence on scattered files, scattered people, and temporary memory.

## Current business goals
The system must help quickly answer:
- who is the tenant
- which unit they are in
- what lease is active
- what is overdue
- which units are vacant
- which leases are expiring soon

## Project phase
Current phase: MVP restart

This project is being treated as **Rental OS first**, not as the full business control tower.

## Founder / current owner
- Sole current owner: Matthew Wong

## Current known official assets
### GitHub
- Repo starting point: `matthew1380/openclaw`

### Supabase
- Official project name: 利兴强租赁系统
- Current state: exists, but app connection/setup is stuck

### Hosting
- Preferred hosting direction: Tencent Cloud
- Current server starting point exists on Tencent Cloud
- Current state: infrastructure exists, but full app deployment is not yet working cleanly

### File storage
- Current state: files are mainly on local computer
- Desired state: structured storage moved to Tencent Cloud environment

## Current blockers
1. Repo is not yet a clean production project structure
2. App-to-database connection is stuck
3. File storage is still local and fragmented
4. Project memory is not yet fully externalized into the repo

## MVP scope
### Core MVP entities
- Properties
- Units
- Contacts / Tenants
- Leases
- Charges
- Payments
- Overdue
- Vacancy
- Lease expiry visibility

### Requested additional version-1 items
- Invoices
- Utilities
- Maintenance
- Tasks / reminders
- Approvals

## MVP delivery target
- Target: usable internal MVP within one month

## Most important business priorities
1. Find tenant / lease information fast
2. Know overdue payments clearly
3. Know vacancy clearly

## Project rules
### Rule 1
Do not expand into the broader control tower until Rental OS MVP works.

### Rule 2
Do not rely on chat history as project memory.

### Rule 3
Any code or schema change must update the relevant repo files.

### Rule 4
The first working layer must be reliable before adding more features.

## First working layer
1. property
2. unit
3. tenant / contact
4. lease
5. charges
6. payments
7. overdue
8. vacancy
9. lease expiry
10. fast search

## Current open questions
- What exact files are available for import right now?
- What is the current Supabase schema state?
- What exact app stack will be used for MVP?
- What is the exact Tencent Cloud folder/storage structure?

## Update rule
Whenever the project changes, update:
- `PROJECT_MEMORY.md`
- `TODO.md`
- `CHANGELOG.md`
- `DATABASE_SCHEMA.md` if schema changed
```

---

# 3. DATABASE_SCHEMA.md

```markdown
# DATABASE_SCHEMA.md

This file describes the intended MVP data structure for Rental OS.

## Schema status
This is the target MVP schema draft and must be updated as the real database is confirmed.

---

## 1. properties
Represents a building, site, dorm block, factory, shop cluster, or other rentable asset group.

### Suggested fields
- id
- property_code
- property_name
- property_type
- address
- city
- area
- total_units
- notes
- created_at
- updated_at

---

## 2. units
Represents an individual rentable unit such as a room, shop, office, parking space, or other unit.

### Suggested fields
- id
- property_id
- unit_code
- unit_name
- unit_type
- floor
- size
- status
- base_rent
- notes
- created_at
- updated_at

### Notes
`status` should eventually be derived from active lease logic where possible, not only manually typed.

---

## 3. contacts
Represents tenants and other relevant contacts.

### Suggested fields
- id
- contact_name
- company_name
- phone
- whatsapp
- wechat
- email
- id_number_or_license
- contact_type
- notes
- created_at
- updated_at

### Notes
This table should support both individual and company tenants.

---

## 4. leases
Represents lease agreements linking a contact to a unit for a period of time.

### Suggested fields
- id
- property_id
- unit_id
- contact_id
- lease_number
- lease_start_date
- lease_end_date
- handover_date
- rent_amount
- deposit_amount
- payment_frequency
- billing_cycle
- status
- contract_file_path
- remarks
- created_at
- updated_at

### Key logic
- One unit can have many leases over time
- Only one lease should be active for a unit at a time
- Active lease should be calculated reliably

---

## 5. charges
Represents money that should be paid.

### Suggested fields
- id
- lease_id
- charge_type
- charge_period_start
- charge_period_end
- due_date
- amount_due
- currency
- status
- remarks
- created_at
- updated_at

### Example charge types
- rent
- management fee
- electricity
- water
- utility adjustment
- deposit-related charge
- other

---

## 6. payments
Represents money that was actually paid.

### Suggested fields
- id
- lease_id
- charge_id
- payment_date
- amount_paid
- currency
- payment_method
- reference_number
- payer_name
- notes
- created_at
- updated_at

### Notes
A payment may eventually need to support partial payments or one payment covering multiple charges depending on real workflow.

---

## 7. invoices
Version-1 extension table after the core layer works.

### Suggested fields
- id
- lease_id
- charge_id
- invoice_number
- invoice_date
- invoice_amount
- invoice_status
- invoice_file_path
- notes
- created_at
- updated_at

---

## 8. utilities
Version-1 extension table after the core layer works.

### Suggested fields
- id
- unit_id
- utility_type
- reading_start
- reading_end
- usage_amount
- billing_period_start
- billing_period_end
- amount
- notes
- created_at
- updated_at

---

## 9. maintenance
Version-1 extension table after the core layer works.

### Suggested fields
- id
- property_id
- unit_id
- issue_type
- description
- reported_date
- status
- assigned_to
- cost
- notes
- created_at
- updated_at

---

## 10. tasks
Version-1 extension table after the core layer works.

### Suggested fields
- id
- related_type
- related_id
- task_title
- task_description
- due_date
- priority
- status
- assigned_to
- notes
- created_at
- updated_at

---

## 11. approvals
Version-1 extension table after the core layer works.

### Suggested fields
- id
- related_type
- related_id
- approval_type
- requested_by
- approved_by
- approval_status
- approval_date
- notes
- created_at
- updated_at

---

## Core calculated outputs needed for MVP
- active lease per unit
- overdue amount
- overdue days
- vacancy status
- days to lease expiry

## Important schema rules
1. Avoid fragile manual links where logic can determine current state
2. Do not allow AI-generated draft records to become final without review
3. Keep core tables stable before expanding features
4. Every field added should solve a real operating need
```

---

# 4. TODO.md

```markdown
# TODO.md

## Current objective
Build a usable Rental OS MVP in one month.

## Top business priorities
1. Fast tenant / lease search
2. Overdue visibility
3. Vacancy visibility

---

## Phase 1 — Foundation
- [ ] Confirm GitHub repo structure and make it official
- [ ] Add README.md
- [ ] Add PROJECT_MEMORY.md
- [ ] Add DATABASE_SCHEMA.md
- [ ] Add CHANGELOG.md
- [ ] Add TODO.md
- [ ] Review current Supabase project structure
- [ ] Review current Tencent Cloud server state
- [ ] Decide final MVP app stack
- [ ] Create structured cloud file storage plan

---

## Phase 2 — Database and data model
- [ ] Inspect current Supabase schema
- [ ] Clean or rebuild tables as needed
- [ ] Finalize properties table
- [ ] Finalize units table
- [ ] Finalize contacts table
- [ ] Finalize leases table
- [ ] Finalize charges table
- [ ] Finalize payments table
- [ ] Define core calculations
- [ ] Prepare data import plan from existing files

---

## Phase 3 — First working product flow
- [ ] Create property page or form
- [ ] Create unit page or form
- [ ] Create contact / tenant page or form
- [ ] Create lease page or form
- [ ] Create charge entry flow
- [ ] Create payment entry flow
- [ ] Show overdue list
- [ ] Show vacancy list
- [ ] Show lease expiry list
- [ ] Add search for tenant / lease / unit

---

## Phase 4 — Real data testing
- [ ] Import sample real data
- [ ] Test tenant lookup
- [ ] Test active lease lookup
- [ ] Test overdue calculation
- [ ] Test vacancy logic
- [ ] Test lease expiry visibility
- [ ] Fix broken connection/setup issues

---

## Phase 5 — Version-1 extension items
- [ ] Add invoices
- [ ] Add utilities
- [ ] Add maintenance
- [ ] Add tasks / reminders
- [ ] Add approvals

---

## Definition of done for MVP
- [ ] Can search tenant and lease info fast
- [ ] Can identify overdue payments clearly
- [ ] Can identify vacancy clearly
- [ ] Can see lease expiry clearly
- [ ] App is actually usable
- [ ] Database connection is stable
- [ ] Repo documentation is updated
```

---

# 5. CHANGELOG.md

```markdown
# CHANGELOG.md

## 2026-04-18
- Created initial project restart documentation
- Defined Rental OS as the first project scope
- Confirmed Supabase as official database starting point
- Confirmed Tencent Cloud as preferred hosting direction
- Confirmed one-month internal MVP goal
- Confirmed top priorities: tenant/lease lookup, overdue, vacancy
```
# openclaw
