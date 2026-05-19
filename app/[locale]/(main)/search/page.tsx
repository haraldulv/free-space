import { searchListings } from "@/lib/supabase/listings";
import { ListingCategory, VehicleType, PricePackagePeriodType } from "@/types";
import SearchResultsView from "@/components/features/search/SearchResultsView";

export const dynamic = "force-dynamic";

interface SearchPageProps {
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>;
}

const VALID_PERIOD_TYPES: ReadonlyArray<PricePackagePeriodType> = ["DAY", "WEEK", "MONTH", "YEAR"];

function parsePeriodTypes(raw: string | string[] | undefined): PricePackagePeriodType[] | undefined {
  if (!raw) return undefined;
  const parts = (Array.isArray(raw) ? raw.join(",") : raw).split(",").map((s) => s.trim()).filter(Boolean);
  const valid = parts.filter((p): p is PricePackagePeriodType => VALID_PERIOD_TYPES.includes(p as PricePackagePeriodType));
  return valid.length > 0 ? valid : undefined;
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
  // ÅPNINGSTIDER PAUSET pre-launch — re-aktiver post-launch
  // const openingHours: "any" | "always" | "limited" =
  //   params.openingHours === "always" || params.openingHours === "limited"
  //     ? params.openingHours
  //     : "any";

  const rentalPeriodTypes = parsePeriodTypes(params.period);

  const listings = await searchListings({
    query,
    category,
    vehicleType,
    checkIn,
    checkOut,
    lat,
    lng,
    // openingHours,
    rentalPeriodTypes,
  });

  return (
    <SearchResultsView
      listings={listings}
      query={query}
      category={category}
      vehicleType={vehicleType}
      checkIn={checkIn}
      checkOut={checkOut}
      // openingHours={openingHours}
      rentalPeriodTypes={rentalPeriodTypes}
    />
  );
}
