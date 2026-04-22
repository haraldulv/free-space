import { createClient } from "./server";
import type { Listing, SearchFilters, ListingCategory, Amenity, SpotMarker, VehicleType } from "@/types";
import { vehicleFitsIn } from "@/types";
import { haversineKm } from "@/lib/geo";

/**
 * Deterministisk fuzz av lat/lng for listings med hide_exact_location=true.
 * Offset seedes fra listing id så kartet ikke hopper mellom forespørsler.
 * Resultat: fuzzed punkt ligger ~250-400m fra reelle koordinater.
 */
function fuzzCoords(lat: number, lng: number, seed: string): { lat: number; lng: number } {
  // Enkel string-hash — deterministisk, trenger ikke være kryptografisk
  let h = 0;
  for (let i = 0; i < seed.length; i++) {
    h = ((h << 5) - h) + seed.charCodeAt(i);
    h |= 0;
  }
  // Splitt hashen i to 16-bit verdier for lat/lng
  const r1 = ((h >>> 0) % 10000) / 10000; // 0..1
  const r2 = (((h >>> 0) >> 16) & 0xffff) / 0xffff; // 0..1
  // Polarkoordinater: vinkel [0, 2π), radius 250-450m
  const angle = r1 * Math.PI * 2;
  const metersRadius = 250 + r2 * 200;
  // 1° breddegrad ≈ 111 km. Lengdegrad skaleres av cos(lat).
  const latOffset = (metersRadius * Math.sin(angle)) / 111000;
  const lngOffset = (metersRadius * Math.cos(angle)) / (111000 * Math.max(0.1, Math.cos((lat * Math.PI) / 180)));
  return { lat: lat + latOffset, lng: lng + lngOffset };
}

export interface CreateListingData {
  category: ListingCategory;
  vehicleType: VehicleType;
  title: string;
  internalName?: string;
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
  checkinMessage?: string;
  checkoutMessage?: string;
  checkoutMessageSendHoursBefore?: number;
  extras?: { id: string; name: string; price: number; perNight: boolean }[];
  /** UI-only flag — bestemmer om pris settes per-plass eller uniform. Persisteres ikke. */
  perSpotPricing?: boolean;
  /** UI-only flag — bestemmer om velkomstmelding settes per-plass eller uniform. Persisteres ikke. */
  perSpotCheckinMessage?: boolean;
}

/**
 * Convert a Supabase row to our Listing type.
 * NB: når hide_exact_location=true fuzzes lat/lng og adresse strippes — dette
 * brukes på alle publikke lese-stier (søk, listing-detalj, forsiden). Host-redigering
 * går utenom (raw Supabase-query i edit-siden), så host ser ekte koordinater.
 */
function rowToListing(row: Record<string, unknown>): Listing {
  const id = row.id as string;
  const rawLat = row.lat as number;
  const rawLng = row.lng as number;
  const hideExact = row.hide_exact_location as boolean | undefined;
  const { lat: shownLat, lng: shownLng } = hideExact
    ? fuzzCoords(rawLat, rawLng, id)
    : { lat: rawLat, lng: rawLng };
  const shownAddress = hideExact ? "" : (row.address as string);

  return {
    id,
    title: row.title as string,
    internalName: (row.internal_name as string | null) ?? undefined,
    description: row.description as string,
    category: row.category as Listing["category"],
    images: row.images as string[],
    location: {
      city: row.city as string,
      region: row.region as string,
      address: shownAddress,
      lat: shownLat,
      lng: shownLng,
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
    checkinMessage: row.checkin_message as string | undefined,
    checkoutMessage: row.checkout_message as string | undefined,
    checkoutMessageSendHoursBefore: row.checkout_message_send_hours_before as number | undefined,
    extras: (row.extras as Listing["extras"]) || [],
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
    .select("listing_id, selected_spot_ids")
    .in("listing_id", listingIds)
    .in("status", ["confirmed", "pending", "requested"])
    .lt("check_in", checkOut)
    .gt("check_out", checkIn);

  const counts = new Map<string, number>();
  for (const row of data || []) {
    const id = row.listing_id as string;
    const spotIds = row.selected_spot_ids as string[] | null;
    const increment = spotIds && spotIds.length > 0 ? spotIds.length : 1;
    counts.set(id, (counts.get(id) || 0) + increment);
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

  const { data: overlapping } = await supabase
    .from("bookings")
    .select("selected_spot_ids")
    .eq("listing_id", listingId)
    .in("status", ["confirmed", "pending", "requested"])
    .lt("check_in", checkOut)
    .gt("check_out", checkIn);

  const bookedCount = (overlapping || []).reduce((sum, row) => {
    const ids = row.selected_spot_ids as string[] | null;
    return sum + (ids && ids.length > 0 ? ids.length : 1);
  }, 0);

  return listing.spots - bookedCount;
}

/**
 * Hent hvilke spot-IDer som allerede er booket for en gitt annonse + datorange.
 * Returneres som Set. Legacy bookings (null selected_spot_ids) returneres ikke her —
 * de blokkerer hele annonsen via getAvailableSpots-kalkulasjonen istedenfor.
 */
export async function getBookedSpotIds(
  listingId: string,
  checkIn: string,
  checkOut: string,
): Promise<Set<string>> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("bookings")
    .select("selected_spot_ids")
    .eq("listing_id", listingId)
    .in("status", ["confirmed", "pending", "requested"])
    .lt("check_in", checkOut)
    .gt("check_out", checkIn);

  const booked = new Set<string>();
  for (const row of data || []) {
    const ids = row.selected_spot_ids as string[] | null;
    (ids || []).forEach((id) => booked.add(id));
  }
  return booked;
}

/**
 * Hent alle fremtidige bookede datoer for en annonse.
 * - perSpot: datoer bookede per spot-ID (for annonser med spot markers)
 * - perDateCount: antall plasser booket per dato (for kapasitets-baserte annonser)
 *   — en booking med selected_spot_ids=[a,b] teller som 2, null/tom teller som 1.
 */
export async function getFutureBookedDates(
  listingId: string,
): Promise<{ perSpot: Record<string, string[]>; perDateCount: Record<string, number> }> {
  const supabase = await createClient();
  const today = new Date().toISOString().slice(0, 10);

  const { data } = await supabase
    .from("bookings")
    .select("check_in, check_out, selected_spot_ids")
    .eq("listing_id", listingId)
    .in("status", ["confirmed", "pending", "requested"])
    .gte("check_out", today);

  const perSpot: Record<string, Set<string>> = {};
  const perDateCount: Record<string, number> = {};

  for (const row of data || []) {
    const checkIn = row.check_in as string;
    const checkOut = row.check_out as string;
    const spotIds = row.selected_spot_ids as string[] | null;
    const occupies = spotIds && spotIds.length > 0 ? spotIds.length : 1;

    const cursor = new Date(checkIn + "T00:00:00");
    const end = new Date(checkOut + "T00:00:00");
    while (cursor < end) {
      const d = cursor.toISOString().slice(0, 10);
      perDateCount[d] = (perDateCount[d] || 0) + occupies;
      if (spotIds && spotIds.length > 0) {
        for (const sid of spotIds) {
          if (!perSpot[sid]) perSpot[sid] = new Set();
          perSpot[sid].add(d);
        }
      }
      cursor.setDate(cursor.getDate() + 1);
    }
  }

  return {
    perSpot: Object.fromEntries(
      Object.entries(perSpot).map(([k, v]) => [k, Array.from(v).sort()]),
    ),
    perDateCount,
  };
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
    .neq("is_active", false)
    .limit(limit);

  if (error) {
    console.error("getListingsByTag error:", error.message);
    return [];
  }

  return (data || []).map(rowToListing);
}

export async function getRecentListings(limit = 12): Promise<Listing[]> {
  const supabase = await createClient();

  const { data, error } = await supabase
    .from("listings")
    .select("*")
    .neq("is_active", false)
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) {
    console.error("getRecentListings error:", error.message);
    return [];
  }

  return (data || []).map(rowToListing);
}

export async function getAllListingIds(): Promise<string[]> {
  const supabase = await createClient();

  const { data, error } = await supabase
    .from("listings")
    .select("id")
    .neq("is_active", false);

  if (error) return [];
  return (data || []).map((r) => r.id);
}

export async function getAllActiveListingsForSitemap(): Promise<Array<{ id: string; createdAt: string | null }>> {
  const supabase = await createClient();

  const { data, error } = await supabase
    .from("listings")
    .select("id, created_at")
    .neq("is_active", false);

  if (error) return [];
  return (data || []).map((r) => ({ id: r.id as string, createdAt: (r.created_at as string) || null }));
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
    internal_name: input.internalName?.trim() || null,
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
    checkin_message: input.checkinMessage || null,
    checkout_message: input.checkoutMessage || null,
    checkout_message_send_hours_before: input.checkoutMessageSendHoursBefore ?? 2,
    extras: input.extras || [],
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
  if (input.internalName !== undefined) updateData.internal_name = input.internalName?.trim() || null;
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
  if (input.checkinMessage !== undefined) updateData.checkin_message = input.checkinMessage || null;
  if (input.checkoutMessage !== undefined) updateData.checkout_message = input.checkoutMessage || null;
  if (input.checkoutMessageSendHoursBefore !== undefined) {
    updateData.checkout_message_send_hours_before = input.checkoutMessageSendHoursBefore;
  }
  if (input.extras !== undefined) updateData.extras = input.extras;

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
