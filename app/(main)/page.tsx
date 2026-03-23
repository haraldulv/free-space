import { getListingsByTag } from "@/lib/supabase/listings";
import ListingSection from "@/components/features/ListingSection";

export const dynamic = "force-dynamic";

export default async function HomePage() {
  const [popular, featured, availableToday] = await Promise.all([
    getListingsByTag("popular"),
    getListingsByTag("featured"),
    getListingsByTag("available_today"),
  ]);

  return (
    <div className="pb-8">
      <ListingSection title="Populære i Norge" listings={popular} />
      <ListingSection title="Fremhevede i Norge" listings={featured} />
      <ListingSection title="Tilgjengelig i dag" listings={availableToday} />
    </div>
  );
}
