import { redirect } from "next/navigation";
import { hasLocale } from "@/lib/dictionaries";
import { notFound } from "next/navigation";

export default async function LocaleIndex({
  params,
}: {
  params: Promise<{ lang: string }>;
}) {
  const { lang } = await params;
  if (!hasLocale(lang)) notFound();
  redirect(`/${lang}/dashboard`);
}
