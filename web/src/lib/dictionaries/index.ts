import "server-only";

const dictionaries = {
  en: () => import("./en.json").then((m) => m.default),
  zh: () => import("./zh.json").then((m) => m.default),
} as const;

export type Locale = keyof typeof dictionaries;
export const locales = Object.keys(dictionaries) as Locale[];
export const defaultLocale: Locale = "zh";

export function hasLocale(value: string): value is Locale {
  return value in dictionaries;
}

export type Dictionary = Awaited<ReturnType<(typeof dictionaries)[Locale]>>;

export async function getDictionary(locale: Locale): Promise<Dictionary> {
  return dictionaries[locale]();
}
