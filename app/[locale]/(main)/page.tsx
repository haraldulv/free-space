import { getTranslations } from "next-intl/server";
import {
  getPopularListings,
  getRecentRealListings,
  getAvailableTodayListings,
} from "@/lib/supabase/listings";
import ListingSection from "@/components/features/ListingSection";

export const dynamic = "force-dynamic";

export default async function HomePage() {
  const t = await getTranslations("home");
  const [recent, popular, availableToday] = await Promise.all([
    getRecentRealListings(12),
    getPopularListings(12),
    getAvailableTodayListings(12),
  ]);

  return (
    <div className="pb-8">
      {recent.length > 0 && <ListingSection title={t("recent")} listings={recent} />}
      {popular.length > 0 && <ListingSection title={t("popular")} listings={popular} />}
      {availableToday.length > 0 && (
        <ListingSection title={t("availableToday")} listings={availableToday} />
      )}
    </div>
  );
}
