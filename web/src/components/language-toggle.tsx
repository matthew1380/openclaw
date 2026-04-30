"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { Locale } from "@/lib/dictionaries";

type Props = {
  current: Locale;
  label: string;
};

export function LanguageToggle({ current, label }: Props) {
  const pathname = usePathname();
  const target: Locale = current === "en" ? "zh" : "en";
  const swapped = pathname.replace(
    new RegExp(`^/${current}(?=/|$)`),
    `/${target}`,
  );
  return (
    <Link
      href={swapped || `/${target}`}
      className="rounded-md border border-neutral-300 bg-white px-3 py-1.5 text-sm font-medium text-neutral-800 hover:bg-neutral-50 dark:border-neutral-700 dark:bg-neutral-900 dark:text-neutral-100 dark:hover:bg-neutral-800"
      aria-label="Switch language"
    >
      {label}
    </Link>
  );
}
