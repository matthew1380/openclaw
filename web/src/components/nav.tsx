import Link from "next/link";
import { LanguageToggle } from "@/components/language-toggle";
import type { Dictionary, Locale } from "@/lib/dictionaries";

type Props = {
  locale: Locale;
  dict: Dictionary;
};

export function Nav({ locale, dict }: Props) {
  const items = [
    { href: `/${locale}/dashboard`, label: dict.nav.dashboard },
    { href: `/${locale}/bills`, label: dict.nav.bills },
    { href: `/${locale}/exceptions`, label: dict.nav.exceptions },
  ];
  return (
    <header className="sticky top-0 z-30 border-b border-neutral-200 bg-white/85 backdrop-blur dark:border-neutral-800 dark:bg-neutral-950/85">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3">
        <Link
          href={`/${locale}/dashboard`}
          className="flex items-center gap-2 text-sm font-semibold tracking-tight"
        >
          <span className="inline-flex h-7 w-7 items-center justify-center rounded-md bg-neutral-900 text-xs font-bold text-white dark:bg-white dark:text-neutral-900">
            ROS
          </span>
          <span>{dict.common.appName}</span>
          <span className="hidden text-xs font-normal text-neutral-500 sm:inline">
            · {dict.common.site}
          </span>
        </Link>
        <nav className="flex items-center gap-1">
          {items.map((it) => (
            <Link
              key={it.href}
              href={it.href}
              className="rounded-md px-3 py-1.5 text-sm font-medium text-neutral-700 hover:bg-neutral-100 dark:text-neutral-200 dark:hover:bg-neutral-800"
            >
              {it.label}
            </Link>
          ))}
          <div className="ml-2">
            <LanguageToggle current={locale} label={dict.common.switchLanguage} />
          </div>
        </nav>
      </div>
    </header>
  );
}
