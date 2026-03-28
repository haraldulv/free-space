import { createClient } from "./server";
import type { Listing, SearchFilters, ListingCategory, Amenity, SpotMarker, VehicleType } from "@/types";
import { vehicleFitsIn } from "@/types";

export interface CreateListingData {
  category: ListingCategory;
  vehicleType: VehicleType;
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
  spotMarkers?: SpotMarker[];
  hideExactLocation?: boolean;
  blockedDates?: string[];
  checkInTime?: string;
  checkOutTime?: string;
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
    spotMarkers: row.spot_markers as SpotMarker[] | undefined,
    hideExactLocation: row.hide_exact_location as boolean | undefined,
    vehicleType: (row.vehicle_type as VehicleType) || "motorhome",
    isActive: row.is_active as boolean | undefined,
    blockedDates: row.blocked_dates as string[] | undefined,
    checkInTime: (row.check_in_time as string) || "15:00",
    checkOutTime: (row.check_out_time as string) || "11:00",
  };
}

export async function searchListings(filters: SearchFilters): Promise<Listing[]> {
  const supabase = await createClient();

  let query = supabase.from("listings").select("*").neq("is_active", false);

  if (filters.category) {
    query = query.eq("category", filters.category);
  }

  // Only apply text filter if no coordinates (coordinates = place was selected)
  if (filters.query && filters.lat === undefined) {
    const q = `%${filters.query}%`;
    query = query.or(`title.ilike.${q},city.ilike.${q},region.ilike.${q},address.ilike.${q}`);
  }

  if (filters.vehicleType) {
    const acceptedTypes = vehicleFitsIn[filters.vehicleType];
    query = query.in("vehicle_type", acceptedTypes);
  }

  const { data, error } = await query.limit(500);

  if (error) {
    console.error("searchListings error:", error.message);
    return [];
  }

  let listings = (data || []).map(rowToListing);

  // Filter by distance if coordinates provided (default 20km radius)
  if (filters.lat !== undefined && filters.lng !== undefined) {
    const radius = filters.radiusKm ?? 20;
    listings = listings
      .map((l) => ({ listing: l, distance: haversineKm(filters.lat!, filters.lng!, l.location.lat, l.location.lng) }))
      .filter((item) => item.distance <= radius)
      .sort((a, b) => a.distance - b.distance)
      .map((item) => item.listing);
  }

  // Filter out listings with blocked dates overlapping the requested range
  if (filters.checkIn && filters.checkOut) {
    const requestedDates = getDateRange(filters.checkIn, filters.checkOut);
    listings = listings.filter((listing) => {
      if (!listing.blockedDates || listing.blockedDates.length === 0) return true;
      const blockedSet = new Set(listing.blockedDates);
      return !requestedDates.some((d) => blockedSet.has(d));
    });

    // Enrich listings with available spots count
    const listingIds = listings.map((l) => l.id);
    if (listingIds.length > 0) {
      const bookedCounts = await getBookedSpotsCounts(supabase, listingIds, filters.checkIn, filters.checkOut);
      listings = listings.map((l) => ({
        ...l,
        availableSpots: l.spots - (bookedCounts.get(l.id) || 0),
      }));
      // Filter out fully booked listings
      listings = listings.filter((l) => (l.availableSpots ?? l.spots) > 0);
    }
  }

  return listings;
}

/** Count booked spots per listing for a date range */
async function getBookedSpotsCounts(
  supabase: Awaited<ReturnType<typeof createClient>>,
  listingIds: string[],
  checkIn: string,
  checkOut: string,
): Promise<Map<string, number>> {
  const { data } = await supabase
    .from("bookings")
    .select("listing_id")
    .in("listing_id", listingIds)
    .in("status", ["confirmed", "pending"])
    .lt("check_in", checkOut)
    .gt("check_out", checkIn);

  const counts = new Map<string, number>();
  for (const row of data || []) {
    const id = row.listing_id as string;
    counts.set(id, (counts.get(id) || 0) + 1);
  }
  return counts;
}

/** Get available spots for a single listing in a date range */
export async function getAvailableSpots(
  listingId: string,
  checkIn: string,
  checkOut: string,
): Promise<number> {
  const supabase = await createClient();

  const { data: listing } = await supabase
    .from("listings")
    .select("spots")
    .eq("id", listingId)
    .single();

  if (!listing) return 0;

  const { count } = await supabase
    .from("bookings")
    .select("id", { count: "exact", head: true })
    .eq("listing_id", listingId)
    .in("status", ["confirmed", "pending"])
    .lt("check_in", checkOut)
    .gt("check_out", checkIn);

  return listing.spots - (count || 0);
}

/** Calculate distance between two coordinates in km */
function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/** Generate array of date strings between start and end (inclusive) */
function getDateRange(start: string, end: string): string[] {
  const dates: string[] = [];
  const current = new Date(start + "T00:00:00");
  const last = new Date(end + "T00:00:00");
  while (current <= last) {
    dates.push(`${current.getFullYear()}-${String(current.getMonth() + 1).padStart(2, "0")}-${String(current.getDate()).padStart(2, "0")}`);
    current.setDate(current.getDate() + 1);
  }
  return dates;
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
    vehicle_type: input.vehicleType || "motorhome",
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
    spot_markers: input.spotMarkers || [],
    hide_exact_location: input.hideExactLocation || false,
    blocked_dates: input.blockedDates || [],
    check_in_time: input.checkInTime || "15:00",
    check_out_time: input.checkOutTime || "11:00",
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
  if (input.vehicleType !== undefined) updateData.vehicle_type = input.vehicleType;
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
  if (input.spotMarkers !== undefined) updateData.spot_markers = input.spotMarkers;
  if (input.hideExactLocation !== undefined) updateData.hide_exact_location = input.hideExactLocation;
  if (input.blockedDates !== undefined) updateData.blocked_dates = input.blockedDates;
  if (input.checkInTime !== undefined) updateData.check_in_time = input.checkInTime;
  if (input.checkOutTime !== undefined) updateData.check_out_time = input.checkOutTime;

  const { error } = await supabase
    .from("listings")
    .update(updateData)
    .eq("id", id)
    .eq("host_id", hostId);

  if (error) throw new Error(error.message);
}

export async function toggleListingActive(id: string, hostId: string, isActive: boolean): Promise<void> {
  const supabase = await createClient();

  const { error } = await supabase
    .from("listings")
    .update({ is_active: isActive })
    .eq("id", id)
    .eq("host_id", hostId);

  if (error) throw new Error(error.message);
}

export async function updateBlockedDates(id: string, hostId: string, blockedDates: string[]): Promise<void> {
  const supabase = await createClient();

  const { error } = await supabase
    .from("listings")
    .update({ blocked_dates: blockedDates })
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
