# PROJECT_MEMORY.md
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
