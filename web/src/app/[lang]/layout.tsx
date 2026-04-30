import { notFound } from "next/navigation";
import { Nav } from "@/components/nav";
import { getDictionary, hasLocale, locales } from "@/lib/dictionaries";

export const dynamic = "force-dynamic";

export async function generateStaticParams() {
  return locales.map((lang) => ({ lang }));
}

export default async function LocaleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ lang: string }>;
}) {
  const { lang } = await params;
  if (!hasLocale(lang)) notFound();

  const dict = await getDictionary(lang);
  return (
    <>
      <Nav locale={lang} dict={dict} />
      <main className="mx-auto w-full max-w-6xl px-4 py-6">{children}</main>
    </>
  );
}
