import { getTranslations } from "next-intl/server";
import Image from "next/image";
import { Link } from "@/i18n/navigation";
import { PARKING_ONLY } from "@/lib/config";
import {
  getPopularListings,
  getRecentRealListings,
  getAvailableTodayListings,
} from "@/lib/supabase/listings";
import ListingSection from "@/components/features/ListingSection";
import type { Listing } from "@/types";

export const dynamic = "force-dynamic";

export default async function HomePage() {
  const t = await getTranslations("home");
  let [recent, popular, availableToday] = await Promise.all([
    getRecentRealListings(12),
    getPopularListings(12),
    getAvailableTodayListings(12),
  ]);

  // Asker-pivoten: forsiden viser kun parkering. Camping-annonser beholdes i
  // basen og kommer tilbake når PARKING_ONLY slås av.
  if (PARKING_ONLY) {
    const onlyParking = (ls: Listing[]) => ls.filter((l) => l.category === "parking");
    recent = onlyParking(recent);
    popular = onlyParking(popular);
    availableToday = onlyParking(availableToday);
  }

  return (
    <div className="pb-8">
      {PARKING_ONLY && (
        <section className="bg-ink px-5 pb-10 pt-12 text-ink-text sm:pt-16">
          <div className="mx-auto max-w-5xl text-center">
            <span className="inline-block rounded-full bg-mint/15 px-4 py-1.5 text-sm font-semibold text-[#4fd6b2]">
              {t("heroEyebrow")}
            </span>
            <h1 className="mx-auto mt-6 max-w-3xl text-4xl font-bold leading-tight sm:text-6xl">
              {t("heroTitle")}
            </h1>
            <p className="mx-auto mt-4 max-w-xl text-lg font-medium leading-relaxed text-ink-muted">
              {t("heroSubtitle")}
            </p>
            <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
              <Link
                href="/search"
                className="rounded-full bg-mint px-8 py-3.5 text-base font-bold text-mint-ink transition-transform hover:scale-[1.02]"
              >
                {t("heroCtaFind")}
              </Link>
              <Link
                href="/tjen"
                className="rounded-full border border-ink-muted/50 px-8 py-3.5 text-base font-semibold text-ink-text transition-colors hover:bg-ink-elevated"
              >
                {t("heroCtaRentOut")}
              </Link>
            </div>
            <Image
              src="/tjen-illustration.png"
              alt=""
              aria-hidden="true"
              width={1101}
              height={442}
              className="mx-auto mt-10 w-full max-w-2xl"
              priority
            />
          </div>
        </section>
      )}

      {recent.length > 0 && (
        <ListingSection title={PARKING_ONLY ? t("recentParking") : t("recent")} listings={recent} />
      )}
      {popular.length > 0 && (
        <ListingSection title={PARKING_ONLY ? t("popularParking") : t("popular")} listings={popular} />
      )}
      {availableToday.length > 0 && (
        <ListingSection
          title={PARKING_ONLY ? t("availableTodayParking") : t("availableToday")}
          listings={availableToday}
        />
      )}
    </div>
  );
}
