# WORKFLOW.md

## Purpose
This file defines the repeatable local workflow for Rental OS data imports, cleanup, review, and reporting.

This repo does **not** store live tenant data or source operational CSVs in Git.
Live schema and data remain in Supabase.
Local import files stay outside Git tracking.

---

## Local folder structure

```text
openclaw/
├─ scripts/
├─ imports/
│  ├─ raw/
│  ├─ cleaned/
│  └─ review/
├─ README.md
├─ PROJECT_MEMORY.md
├─ DATABASE_SCHEMA.md
├─ TODO.md
├─ CHANGELOG.md
├─ AGENTS.md
└─ .gitignore