import { notFound } from "next/navigation";
import { getDictionary, hasLocale, type Dictionary } from "@/lib/dictionaries";
import { getExceptions } from "@/lib/shaxi/queries";

export const dynamic = "force-dynamic";

export default async function ExceptionsPage({
  params,
}: {
  params: Promise<{ lang: string }>;
}) {
  const { lang } = await params;
  if (!hasLocale(lang)) notFound();
  const dict = await getDictionary(lang);
  const exceptions = await getExceptions();
  type ExceptionKey = keyof Dictionary["exceptions"];
  const tx = (raw: string | null | undefined): string => {
    if (!raw) return "—";
    return (dict.exceptions as Record<string, string>)[raw as ExceptionKey] ?? raw;
  };
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold tracking-tight">{dict.nav.exceptions}</h1>
      <section className="overflow-hidden rounded-lg border border-neutral-200 bg-white dark:border-neutral-800 dark:bg-neutral-900">
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
                  <td className="px-4 py-2">{tx(e.decision_status)}</td>
                  <td className="px-4 py-2">{e.decision_by || "—"}</td>
                  <td className="px-4 py-2 text-neutral-600 dark:text-neutral-400">
                    {e.decision_note_snippet || "—"}
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
