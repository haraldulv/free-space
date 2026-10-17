import { getTranslations } from "next-intl/server";
import Image from "next/image";
import { Link } from "@/i18n/navigation";
import { APP_STORE_URL, PARKING_ONLY } from "@/lib/config";
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
  const tApp = await getTranslations("tjen");
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
    <div>
      {PARKING_ONLY && (
        <section className="px-5 pb-10 pt-12 sm:pt-16">
          <div className="mx-auto max-w-5xl text-center">
            <span className="inline-block rounded-full bg-[#46C185]/15 px-4 py-1.5 text-sm font-semibold text-[#0f7a5f]">
              {t("heroEyebrow")}
            </span>
            <h1 className="mx-auto mt-6 max-w-3xl text-4xl font-bold leading-tight text-neutral-900 sm:text-6xl">
              {t("heroTitle")}
            </h1>
            <p className="mx-auto mt-4 max-w-xl text-lg font-medium leading-relaxed text-neutral-600">
              {t("heroSubtitle")}
            </p>
            <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
              <Link
                href="/search"
                className="rounded-full bg-[#121412] px-8 py-3.5 text-base font-bold text-white transition-transform hover:scale-[1.02]"
              >
                {t("heroCtaFind")}
              </Link>
              <Link
                href="/tjen"
                className="rounded-full border border-neutral-300 px-8 py-3.5 text-base font-semibold text-neutral-900 transition-colors hover:bg-neutral-900/5"
              >
                {t("heroCtaRentOut")}
              </Link>
            </div>
          </div>
        </section>
      )}

      <div className="pb-8">
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

      {/* App-CTA på svart markedsflate, samme som /tjen. Holder forsiden
          støtt også før de første ekte annonsene er ute. */}
      {PARKING_ONLY && (
        <section className="bg-[#121412] px-5 py-16 text-center text-white">
          <div className="mx-auto max-w-xl">
            <Image
              src="/app-icon.png"
              alt=""
              aria-hidden="true"
              width={80}
              height={80}
              className="mx-auto h-20 w-20 rounded-[18px] shadow-[0_8px_24px_rgba(0,0,0,0.45)] ring-1 ring-white/15"
            />
            <h2 className="mt-6 text-3xl font-bold sm:text-4xl">{tApp("appTitle")}</h2>
            <p className="mx-auto mt-3 max-w-md text-base font-medium text-white/85">
              {tApp("appBody")}
            </p>
            <a
              href={APP_STORE_URL}
              className="mt-8 inline-block transition-transform hover:scale-[1.03]"
            >
              <Image
                src="/app-store-badge-nb-white.svg"
                alt={tApp("appStoreBadgeAlt")}
                width={168}
                height={56}
                className="h-14 w-auto"
              />
            </a>
            <div className="mt-4 flex justify-center">
              <span className="rounded-full border border-white/30 px-4 py-1.5 text-sm font-semibold text-white/80">
                {tApp("androidSoonPill")}
              </span>
            </div>
          </div>
        </section>
      )}
    </div>
  );
}
