import { createClient } from "./server";
import type { Listing, SearchFilters, ListingCategory, Amenity } from "@/types";
import { vehicleLengths } from "@/types";

export interface CreateListingData {
  category: ListingCategory;
  title: string;
  description: string;
  spots: number;
  maxVehicleLength?: number;
  address: string;
  city: string;
  region: string;
  lat: number;
  lng: number;
  images: string[];
  amenities: Amenity[];
  price: number;
  priceUnit: "time" | "natt";
  instantBooking: boolean;
}

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
    instantBooking: row.instant_booking as boolean | undefined,
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

export async function getListingsByHost(hostId: string): Promise<Listing[]> {
  const supabase = await createClient();

  const { data, error } = await supabase
    .from("listings")
    .select("*")
    .eq("host_id", hostId)
    .order("created_at", { ascending: false });

  if (error) {
    console.error("getListingsByHost error:", error.message);
    return [];
  }

  return (data || []).map(rowToListing);
}

export async function createListing(input: CreateListingData, hostId: string): Promise<string> {
  const supabase = await createClient();

  // Ensure profile exists (Google OAuth may not trigger auto-create)
  const { data: profile } = await supabase
    .from("profiles")
    .select("full_name, avatar_url, response_rate, response_time, joined_year")
    .eq("id", hostId)
    .single();

  if (!profile) {
    // Fetch user metadata from auth and create profile
    const { data: { user } } = await supabase.auth.getUser();
    const fullName = user?.user_metadata?.full_name || user?.user_metadata?.name || "Anonym";
    const avatar = user?.user_metadata?.avatar_url || "";
    await supabase.from("profiles").insert({
      id: hostId,
      full_name: fullName,
      avatar_url: avatar,
      joined_year: new Date().getFullYear(),
    });
  }

  const id = crypto.randomUUID();

  const { error } = await supabase.from("listings").insert({
    id,
    host_id: hostId,
    title: input.title,
    description: input.description,
    category: input.category,
    city: input.city,
    region: input.region,
    address: input.address,
    lat: input.lat,
    lng: input.lng,
    price: input.price,
    price_unit: input.priceUnit,
    amenities: input.amenities,
    max_vehicle_length: input.maxVehicleLength || null,
    spots: input.spots,
    images: input.images,
    instant_booking: input.instantBooking,
    host_name: profile?.full_name || "Anonym",
    host_avatar: profile?.avatar_url || "",
    host_response_rate: profile?.response_rate || 0,
    host_response_time: profile?.response_time || "innen 1 time",
    host_joined_year: profile?.joined_year || new Date().getFullYear(),
    host_listings_count: 0,
  });

  if (error) throw new Error(error.message);
  return id;
}

export async function updateListing(id: string, input: Partial<CreateListingData>, hostId: string): Promise<void> {
  const supabase = await createClient();

  const updateData: Record<string, unknown> = {};
  if (input.title !== undefined) updateData.title = input.title;
  if (input.description !== undefined) updateData.description = input.description;
  if (input.category !== undefined) updateData.category = input.category;
  if (input.city !== undefined) updateData.city = input.city;
  if (input.region !== undefined) updateData.region = input.region;
  if (input.address !== undefined) updateData.address = input.address;
  if (input.lat !== undefined) updateData.lat = input.lat;
  if (input.lng !== undefined) updateData.lng = input.lng;
  if (input.price !== undefined) updateData.price = input.price;
  if (input.priceUnit !== undefined) updateData.price_unit = input.priceUnit;
  if (input.amenities !== undefined) updateData.amenities = input.amenities;
  if (input.maxVehicleLength !== undefined) updateData.max_vehicle_length = input.maxVehicleLength;
  if (input.spots !== undefined) updateData.spots = input.spots;
  if (input.images !== undefined) updateData.images = input.images;
  if (input.instantBooking !== undefined) updateData.instant_booking = input.instantBooking;

  const { error } = await supabase
    .from("listings")
    .update(updateData)
    .eq("id", id)
    .eq("host_id", hostId);

  if (error) throw new Error(error.message);
}

export async function deleteListing(id: string, hostId: string): Promise<void> {
  const supabase = await createClient();

  const { error } = await supabase
    .from("listings")
    .delete()
    .eq("id", id)
    .eq("host_id", hostId);

  if (error) throw new Error(error.message);
}
