# Rental OS — Web Console

Next.js 16 + Tailwind 4 + Supabase (Postgres) operations console for the Shaxi rental pilot.

This replaces (will replace) the v2.4 Streamlit app in `scripts/shaxi_staff_app.py`.

## Status — v0.1 (skeleton)

What works today:
- `/` redirects to `/<locale>/dashboard` based on `Accept-Language` (default `zh`).
- `/zh/dashboard` and `/en/dashboard` both render live SX-39 data: 10 issued bills, ¥684,922.00 outstanding, 3 active business exceptions. Includes the v2.7 master-lease bills (华佑 ¥300k, 刘英 ¥55k) that the v1.9 candidate views miss.
- `/zh/bills` and `/en/bills` — issued bills detail.
- `/zh/exceptions` and `/en/exceptions` — `shaxi_business_exception_reviews` snapshot with translated decision statuses.
- Top-right toggle swaps between EN ↔ 中文 in place.

What is **not** yet implemented:
- Authentication (everyone hitting the URL gets full access). Anon-key + magic-link auth wiring is a TODO.
- Role separation (staff vs admin).
- Mutations: payment recording, exception decisions, bill approval.
- WeChat (tenant Mini Program / staff 企业微信) — designed for, not built.

## Setup

```bash
# from web/
cp .env.local.example .env.local
# edit .env.local — set SUPABASE_DB_URL (and the future Supabase auth keys)

npm install
npm run dev   # default port 3000; override with PORT=3210 npm run dev
```

DB access is via `pg` against the Supabase Session Pooler (IPv4 reachable). Use the same `SUPABASE_DB_URL` already in the repo root `.env`.

## Project layout

```
src/
  app/
    layout.tsx                 # root html shell
    [lang]/
      layout.tsx               # locale-scoped (Nav + main)
      page.tsx                 # → redirect to /[lang]/dashboard
      dashboard/page.tsx
      bills/page.tsx
      exceptions/page.tsx
  components/
    nav.tsx
    language-toggle.tsx
  lib/
    db.ts                      # pg pool to Supabase (server-only)
    dictionaries/{en,zh}.json  # translations
    dictionaries/index.ts      # getDictionary + Locale type
    shaxi/queries.ts           # SX-39 dashboard queries
  proxy.ts                     # locale gate (Next 16 renamed middleware → proxy)
```

## Notes

- All data fetches happen in Server Components via `pg`. No anon-key reads from the browser yet.
- Queries hit `rent_bills` / `bill_approval_reviews` / `shaxi_business_exception_reviews` directly, not the v1.9 candidate views — this is intentional so the v2.7 master-lease bills surface.
- `proxy.ts` redirects `/foo` to `/zh/foo` (or `/en/foo` if `Accept-Language` starts with `en`).
- Default locale is `zh` (rationale: 沙溪 staff are Chinese-speaking).
- Future WeChat: keep the data layer in `lib/shaxi/*.ts` provider-agnostic so a Mini Program backend or 企业微信 webhook can reuse it.
