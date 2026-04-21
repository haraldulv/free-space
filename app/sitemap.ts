import type { MetadataRoute } from "next";
import { getAllActiveListingsForSitemap } from "@/lib/supabase/listings";
import { routing } from "@/i18n/routing";

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL || "https://tuno.no";

/**
 * Dynamisk sitemap: statiske sider + alle aktive listings på hvert locale.
 * Default-locale (nb) skrives uten prefix, øvrige med /en eller /de.
 */
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const listings = await getAllActiveListingsForSitemap();
  const now = new Date();

  const staticPaths = [
    { path: "", priority: 1.0 },
    { path: "/search", priority: 0.9 },
    { path: "/bli-utleier", priority: 0.7 },
    { path: "/vilkar", priority: 0.3 },
    { path: "/personvern", priority: 0.3 },
    { path: "/utleiervilkar", priority: 0.3 },
    { path: "/retningslinjer", priority: 0.3 },
  ];

  const localePrefix = (locale: string) => (locale === routing.defaultLocale ? "" : `/${locale}`);

  const entries: MetadataRoute.Sitemap = [];

  for (const locale of routing.locales) {
    for (const s of staticPaths) {
      entries.push({
        url: `${SITE_URL}${localePrefix(locale)}${s.path}`,
        lastModified: now,
        changeFrequency: "weekly",
        priority: s.priority,
      });
    }

    for (const listing of listings) {
      entries.push({
        url: `${SITE_URL}${localePrefix(locale)}/listings/${listing.id}`,
        lastModified: listing.createdAt ? new Date(listing.createdAt) : now,
        changeFrequency: "weekly",
        priority: 0.8,
      });
    }
  }

  return entries;
}
