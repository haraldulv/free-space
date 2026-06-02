import { defineRouting } from "next-intl/routing";

export const routing = defineRouting({
  locales: ["nb", "en", "de"] as const,
  defaultLocale: "nb",
  localePrefix: "as-needed",
  // Norsk er alltid standard. Uten dette ville next-intl forhandle språk ut fra
  // mottakerens Accept-Language/cookie og kunne sende nakne lenker (f.eks. en
  // outreach-mail til /utleier) til /en/utleier. Eksplisitte /en og /de virker
  // fortsatt, og språkbytte i menyen (locale-aware Link) er upåvirket.
  localeDetection: false,
});

export type Locale = (typeof routing.locales)[number];
