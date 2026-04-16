import { searchListings } from "@/lib/supabase/listings";
import { ListingCategory, VehicleType } from "@/types";
import SearchResultsView from "@/components/features/search/SearchResultsView";

export const dynamic = "force-dynamic";

interface SearchPageProps {
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>;
}

export default async function SearchPage({ searchParams }: SearchPageProps) {
  const params = await searchParams;

  const query =
    typeof params.query === "string" ? params.query : undefined;
  const category =
    params.category === "parking" || params.category === "camping"
      ? (params.category as ListingCategory)
      : undefined;
  const vehicleType =
    params.vehicle === "car" ||
    params.vehicle === "campervan" ||
    params.vehicle === "motorhome"
      ? (params.vehicle as VehicleType)
      : undefined;

  const checkIn = typeof params.checkIn === "string" ? params.checkIn : undefined;
  const checkOut = typeof params.checkOut === "string" ? params.checkOut : undefined;
  const lat = typeof params.lat === "string" ? parseFloat(params.lat) : undefined;
  const lng = typeof params.lng === "string" ? parseFloat(params.lng) : undefined;

  const listings = await searchListings({ query, category, vehicleType, checkIn, checkOut, lat, lng });

  return (
    <SearchResultsView
      listings={listings}
      query={query}
      category={category}
      vehicleType={vehicleType}
      checkIn={checkIn}
      checkOut={checkOut}
    />
  );
}
