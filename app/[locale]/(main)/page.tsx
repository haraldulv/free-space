import { getTranslations } from "next-intl/server";
import { getListingsByTag, getRecentListings } from "@/lib/supabase/listings";
import ListingSection from "@/components/features/ListingSection";

export const dynamic = "force-dynamic";

export default async function HomePage() {
  const t = await getTranslations("home");
  const [popular, featured, availableToday, recent] = await Promise.all([
    getListingsByTag("popular"),
    getListingsByTag("featured"),
    getListingsByTag("available_today"),
    getRecentListings(12),
  ]);

  return (
    <div className="pb-8">
      <ListingSection title={t("popular")} listings={popular} />
      <ListingSection title={t("recent")} listings={recent} />
      <ListingSection title={t("featured")} listings={featured} />
      <ListingSection title={t("availableToday")} listings={availableToday} />
    </div>
  );
}
