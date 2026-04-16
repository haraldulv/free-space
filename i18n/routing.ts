import { defineRouting } from "next-intl/routing";

export const routing = defineRouting({
  locales: ["nb", "en", "de"] as const,
  defaultLocale: "nb",
  localePrefix: "as-needed",
});

export type Locale = (typeof routing.locales)[number];
