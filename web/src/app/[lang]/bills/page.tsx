import { notFound } from "next/navigation";
import { getDictionary, hasLocale, type Locale } from "@/lib/dictionaries";
import { CURRENT_BILLING_MONTH, getIssuedBills } from "@/lib/shaxi/queries";

function fmtMoney(value: string | number, locale: Locale) {
  const n = typeof value === "string" ? Number(value) : value;
  return new Intl.NumberFormat(locale === "zh" ? "zh-CN" : "en-US", {
    style: "currency",
    currency: "CNY",
    maximumFractionDigits: 2,
  }).format(n);
}

export const dynamic = "force-dynamic";

export default async function BillsPage({
  params,
}: {
  params: Promise<{ lang: string }>;
}) {
  const { lang } = await params;
  if (!hasLocale(lang)) notFound();
  const dict = await getDictionary(lang);
  const bills = await getIssuedBills();
  const total = bills.reduce((s, b) => s + Number(b.amount_due), 0);
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-2xl font-semibold tracking-tight">{dict.nav.bills}</h1>
        <span className="text-sm text-neutral-500 tabular-nums">
          {dict.dashboard.billingMonth}: {CURRENT_BILLING_MONTH} · {bills.length} · {fmtMoney(total, lang)}
        </span>
      </header>
      <section className="overflow-hidden rounded-lg border border-neutral-200 bg-white dark:border-neutral-800 dark:bg-neutral-900">
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
                  <td className="px-4 py-2 text-right tabular-nums">{fmtMoney(b.amount_due, lang)}</td>
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
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
