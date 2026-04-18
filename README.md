
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
This repo should become the project memory for the Rental OS build. Important decisions should not live only in chat history.
