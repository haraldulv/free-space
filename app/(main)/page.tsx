import {
  getPopularListings,
  getFeaturedListings,
  getAvailableTodayListings,
} from "@/data/mock-listings";
import ListingSection from "@/components/features/ListingSection";

export default function HomePage() {
  const popular = getPopularListings();
  const featured = getFeaturedListings();
  const availableToday = getAvailableTodayListings();

  return (
    <div className="pb-8">
      <ListingSection title="Populære i Norge" listings={popular} />
      <ListingSection title="Fremhevede i Norge" listings={featured} />
      <ListingSection title="Tilgjengelig i dag" listings={availableToday} />
    </div>
  );
}
