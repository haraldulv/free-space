import { createClient } from "./server";
import type { Listing, SearchFilters } from "@/types";
import { vehicleLengths } from "@/types";

/** Convert a Supabase row to our Listing type */
function rowToListing(row: Record<string, unknown>): Listing {
  return {
    id: row.id as string,
    title: row.title as string,
    description: row.description as string,
    category: row.category as Listing["category"],
    images: row.images as string[],
    location: {
      city: row.city as string,
      region: row.region as string,
      address: row.address as string,
      lat: row.lat as number,
      lng: row.lng as number,
    },
    price: row.price as number,
    priceUnit: row.price_unit as Listing["priceUnit"],
    rating: row.rating as number,
    reviewCount: row.review_count as number,
    amenities: row.amenities as Listing["amenities"],
    host: {
      id: (row.host_id as string) || "unknown",
      name: row.host_name as string,
      avatar: row.host_avatar as string,
      responseRate: row.host_response_rate as number,
      responseTime: row.host_response_time as string,
      joinedYear: row.host_joined_year as number,
      listingsCount: row.host_listings_count as number,
    },
    maxVehicleLength: row.max_vehicle_length as number | undefined,
    spots: row.spots as number,
    tags: row.tags as Listing["tags"],
  };
}

export async function searchListings(filters: SearchFilters): Promise<Listing[]> {
  const supabase = await createClient();

  let query = supabase.from("listings").select("*");

  if (filters.category) {
    query = query.eq("category", filters.category);
  }

  if (filters.query) {
    const q = `%${filters.query}%`;
    query = query.or(`title.ilike.${q},city.ilike.${q},region.ilike.${q}`);
  }

  if (filters.vehicleType) {
    const length = vehicleLengths[filters.vehicleType];
    query = query.or(`max_vehicle_length.is.null,max_vehicle_length.gte.${length}`);
  }

  const { data, error } = await query.limit(500);

  if (error) {
    console.error("searchListings error:", error.message);
    return [];
  }

  return (data || []).map(rowToListing);
}

export async function getListingById(id: string): Promise<Listing | null> {
  const supabase = await createClient();

  const { data, error } = await supabase
    .from("listings")
    .select("*")
    .eq("id", id)
    .single();

  if (error || !data) return null;
  return rowToListing(data);
}

export async function getListingsByTag(tag: string, limit = 20): Promise<Listing[]> {
  const supabase = await createClient();

  const { data, error } = await supabase
    .from("listings")
    .select("*")
    .contains("tags", [tag])
    .limit(limit);

  if (error) {
    console.error("getListingsByTag error:", error.message);
    return [];
  }

  return (data || []).map(rowToListing);
}

export async function getAllListingIds(): Promise<string[]> {
  const supabase = await createClient();

  const { data, error } = await supabase
    .from("listings")
    .select("id");

  if (error) return [];
  return (data || []).map((r) => r.id);
}
