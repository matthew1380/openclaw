import { notFound } from "next/navigation";
import { getDictionary, hasLocale, type Dictionary, type Locale } from "@/lib/dictionaries";
import {
  CURRENT_BILLING_MONTH,
  getDashboardCounts,
  getExceptions,
  getIssuedBills,
  type ExceptionRow,
  type IssuedBill,
} from "@/lib/shaxi/queries";

function fmtMoney(value: string | number | null | undefined, locale: Locale) {
  if (value == null) return "—";
  const n = typeof value === "string" ? Number(value) : value;
  if (!Number.isFinite(n)) return "—";
  return new Intl.NumberFormat(locale === "zh" ? "zh-CN" : "en-US", {
    style: "currency",
    currency: "CNY",
    maximumFractionDigits: 2,
  }).format(n);
}

export const dynamic = "force-dynamic";

export default async function DashboardPage({
  params,
}: {
  params: Promise<{ lang: string }>;
}) {
  const { lang } = await params;
  if (!hasLocale(lang)) notFound();
  const dict = await getDictionary(lang);

  const [counts, bills, exceptions] = await Promise.all([
    getDashboardCounts(),
    getIssuedBills(),
    getExceptions(),
  ]);

  return (
    <div className="space-y-6">
      <header className="flex flex-col gap-1">
        <h1 className="text-2xl font-semibold tracking-tight">{dict.dashboard.title}</h1>
        <p className="text-sm text-neutral-500">
          {dict.dashboard.subtitle} · {dict.dashboard.billingMonth}: {CURRENT_BILLING_MONTH}
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
        <Card label={dict.dashboard.cards.issuedCount} value={String(counts.issued_count)} />
        <Card label={dict.dashboard.cards.issuedTotal} value={fmtMoney(counts.issued_total, lang)} />
        <Card label={dict.dashboard.cards.outstanding} value={fmtMoney(counts.outstanding, lang)} highlight />
        <Card label={dict.dashboard.cards.draftCount} value={String(counts.draft_count)} />
        <Card label={dict.dashboard.cards.exceptionsPending} value={String(counts.exception_pending)} />
        <Card label={dict.dashboard.cards.holds} value={String(counts.exception_held)} />
      </section>

      <BillsTable dict={dict} locale={lang} bills={bills} />
      <ExceptionsTable dict={dict} exceptions={exceptions} />
    </div>
  );
}

function Card({
  label,
  value,
  highlight,
}: {
  label: string;
  value: string;
  highlight?: boolean;
}) {
  return (
    <div
      className={`rounded-lg border p-3 ${
        highlight
          ? "border-amber-300 bg-amber-50 dark:border-amber-700/50 dark:bg-amber-950/30"
          : "border-neutral-200 bg-white dark:border-neutral-800 dark:bg-neutral-900"
      }`}
    >
      <div className="text-xs text-neutral-500">{label}</div>
      <div className="mt-1 text-lg font-semibold tabular-nums">{value}</div>
    </div>
  );
}

function BillsTable({
  dict,
  locale,
  bills,
}: {
  dict: Dictionary;
  locale: Locale;
  bills: IssuedBill[];
}) {
  return (
    <section className="overflow-hidden rounded-lg border border-neutral-200 bg-white dark:border-neutral-800 dark:bg-neutral-900">
      <div className="flex items-center justify-between border-b border-neutral-200 px-4 py-3 dark:border-neutral-800">
        <h2 className="text-sm font-semibold">{dict.dashboard.tables.issuedBills}</h2>
        <span className="text-xs text-neutral-500 tabular-nums">{bills.length}</span>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-neutral-50 text-left text-xs uppercase tracking-wide text-neutral-500 dark:bg-neutral-950">
            <tr>
              <th className="px-4 py-2 font-medium">{dict.dashboard.columns.tenant}</th>
              <th className="px-4 py-2 font-medium">{dict.dashboard.columns.area}</th>
              <th className="px-4 py-2 text-right font-medium">{dict.dashboard.columns.amount}</th>
              <th className="px-4 py-2 font-medium">{dict.dashboard.columns.status}</th>
              <th className="px-4 py-2 font-medium">{dict.dashboard.columns.approvedBy}</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100 dark:divide-neutral-800">
            {bills.map((b) => (
              <tr key={b.bill_id}>
                <td className="px-4 py-2">
                  <div className="font-medium">{b.tenant_name || "—"}</div>
                  {b.contract_code ? (
                    <div className="text-xs text-neutral-500">{b.contract_code}</div>
                  ) : null}
                </td>
                <td className="px-4 py-2">
                  <div className="font-medium">{b.area_name || b.area_code || "—"}</div>
                  {b.area_code && b.area_name ? (
                    <div className="text-xs text-neutral-500">{b.area_code}</div>
                  ) : null}
                </td>
                <td className="px-4 py-2 text-right tabular-nums">{fmtMoney(b.amount_due, locale)}</td>
                <td className="px-4 py-2">
                  <span className="inline-flex items-center rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-medium text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-300">
                    {b.bill_status}
                  </span>
                </td>
                <td className="px-4 py-2 text-neutral-700 dark:text-neutral-200">
                  {b.reviewed_by || "—"}
                </td>
              </tr>
            ))}
            {bills.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-4 py-6 text-center text-sm text-neutral-500">
                  —
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function ExceptionsTable({
  dict,
  exceptions,
}: {
  dict: Dictionary;
  exceptions: ExceptionRow[];
}) {
  type ExceptionKey = keyof Dictionary["exceptions"];
  const tx = (raw: string | null | undefined): string => {
    if (!raw) return "—";
    return (dict.exceptions as Record<string, string>)[raw as ExceptionKey] ?? raw;
  };
  return (
    <section className="overflow-hidden rounded-lg border border-neutral-200 bg-white dark:border-neutral-800 dark:bg-neutral-900">
      <div className="flex items-center justify-between border-b border-neutral-200 px-4 py-3 dark:border-neutral-800">
        <h2 className="text-sm font-semibold">{dict.dashboard.tables.exceptions}</h2>
        <span className="text-xs text-neutral-500 tabular-nums">{exceptions.length}</span>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-neutral-50 text-left text-xs uppercase tracking-wide text-neutral-500 dark:bg-neutral-950">
            <tr>
              <th className="px-4 py-2 font-medium">{dict.dashboard.columns.tenant}</th>
              <th className="px-4 py-2 font-medium">{dict.dashboard.columns.area}</th>
              <th className="px-4 py-2 font-medium">{dict.dashboard.columns.exceptionType}</th>
              <th className="px-4 py-2 font-medium">{dict.dashboard.columns.decisionStatus}</th>
              <th className="px-4 py-2 font-medium">{dict.dashboard.columns.decisionBy}</th>
              <th className="px-4 py-2 font-medium">{dict.dashboard.columns.noteSnippet}</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100 dark:divide-neutral-800">
            {exceptions.map((e) => (
              <tr key={e.id}>
                <td className="px-4 py-2 font-medium">{e.tenant_name}</td>
                <td className="px-4 py-2">{e.area_code || "—"}</td>
                <td className="px-4 py-2">{tx(e.exception_type)}</td>
                <td className="px-4 py-2">
                  <DecisionPill status={e.decision_status} label={tx(e.decision_status)} />
                </td>
                <td className="px-4 py-2">{e.decision_by || "—"}</td>
                <td className="px-4 py-2 text-neutral-600 dark:text-neutral-400">
                  {e.decision_note_snippet || "—"}
                </td>
              </tr>
            ))}
            {exceptions.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-6 text-center text-sm text-neutral-500">
                  —
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function DecisionPill({ status, label }: { status: string; label: string }) {
  const tone =
    status === "pending_decision"
      ? "bg-amber-100 text-amber-800 dark:bg-amber-950/40 dark:text-amber-200"
      : status === "keep_on_hold"
        ? "bg-rose-100 text-rose-800 dark:bg-rose-950/40 dark:text-rose-200"
        : "bg-emerald-100 text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-200";
  return (
    <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${tone}`}>
      {label}
    </span>
  );
}
