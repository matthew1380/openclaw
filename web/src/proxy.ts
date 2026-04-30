import { NextRequest, NextResponse } from "next/server";
import { defaultLocale, locales } from "@/lib/dictionaries";

const STATIC_PATHS = ["/_next", "/favicon.ico", "/robots.txt", "/api"];

function pickLocaleFromHeader(req: NextRequest): string {
  const accept = req.headers.get("accept-language") ?? "";
  if (accept.toLowerCase().startsWith("zh")) return "zh";
  if (accept.toLowerCase().startsWith("en")) return "en";
  return defaultLocale;
}

export function proxy(req: NextRequest) {
  const { pathname } = req.nextUrl;

  if (STATIC_PATHS.some((p) => pathname.startsWith(p))) {
    return NextResponse.next();
  }

  const hasLocale = locales.some(
    (loc) => pathname === `/${loc}` || pathname.startsWith(`/${loc}/`),
  );
  if (hasLocale) return NextResponse.next();

  const locale = pickLocaleFromHeader(req);
  const url = req.nextUrl.clone();
  url.pathname = `/${locale}${pathname === "/" ? "" : pathname}`;
  return NextResponse.redirect(url);
}

export const config = {
  matcher: ["/((?!_next|.*\\..*).*)"],
};
