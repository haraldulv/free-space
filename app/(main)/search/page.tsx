import { searchListings } from "@/data/mock-listings";
import { ListingCategory, VehicleType } from "@/types";
import SearchResultsView from "@/components/features/search/SearchResultsView";

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
    params.vehicle === "van" ||
    params.vehicle === "campervan" ||
    params.vehicle === "motorhome"
      ? (params.vehicle as VehicleType)
      : undefined;

  const listings = searchListings({ query, category, vehicleType });

  return (
    <SearchResultsView
      listings={listings}
      query={query}
      category={category}
      vehicleType={vehicleType}
    />
  );
}
