import { createClient } from "./server";
import type { Review } from "@/types";

const BLIND_WINDOW_DAYS = 14;

/**
 * Hent alle gjest-anmeldelser av en annonse (offentlig visning).
 * Host-anmeldelser av gjester vises ikke her — de hører til gjestens profil.
 */
export async function getListingReviews(listingId: string): Promise<Review[]> {
  const supabase = await createClient();

  const { data, error } = await supabase
    .from("reviews")
    .select("*, profiles:user_id(full_name, avatar_url)")
    .eq("listing_id", listingId)
    .eq("reviewer_role", "guest")
    .order("created_at", { ascending: false });

  if (error) {
    console.error("getListingReviews error:", error.message);
    return [];
  }

  return (data || []).map((row: Record<string, unknown>) => {
    const profile = row.profiles as Record<string, unknown> | null;
    return {
      id: row.id as string,
      bookingId: row.booking_id as string,
      listingId: row.listing_id as string,
      userId: row.user_id as string,
      rating: row.rating as number,
      comment: row.comment as string,
      createdAt: row.created_at as string,
      userName: (profile?.full_name as string) || "Anonym",
      userAvatar: (profile?.avatar_url as string) || "",
    };
  });
}

/**
 * Hent en spesifikk brukers anmeldelse for én booking, valgfritt med rolle.
 * Brukes for å sjekke om gjest/host har levert.
 */
export async function getUserReviewForBooking(
  bookingId: string,
  reviewerRole?: "guest" | "host",
): Promise<Review | null> {
  const supabase = await createClient();

  let query = supabase
    .from("reviews")
    .select("*")
    .eq("booking_id", bookingId);

  if (reviewerRole) {
    query = query.eq("reviewer_role", reviewerRole);
  }

  const { data, error } = await query.maybeSingle();

  if (error || !data) return null;

  return {
    id: data.id,
    bookingId: data.booking_id,
    listingId: data.listing_id,
    userId: data.user_id,
    rating: data.rating,
    comment: data.comment,
    createdAt: data.created_at,
  };
}

/**
 * Tovei-status for en booking sett fra parten som ber: har JEG levert?
 * Har MOTPARTEN levert? Skal motpartens vises (begge har levert eller >14d)?
 */
export type ReviewStatus = {
  myReview: Review | null;
  counterpart: Review | null;
  counterpartVisible: boolean;
  myRole: "guest" | "host";
};

export async function getBookingReviewStatus(
  bookingId: string,
  viewerId: string,
): Promise<ReviewStatus | null> {
  const supabase = await createClient();

  const { data: booking } = await supabase
    .from("bookings")
    .select("user_id, host_id, check_out")
    .eq("id", bookingId)
    .single();

  if (!booking) return null;

  const myRole: "guest" | "host" = booking.host_id === viewerId ? "host" : "guest";

  const { data: rows } = await supabase
    .from("reviews")
    .select("*")
    .eq("booking_id", bookingId);

  const all = (rows || []) as Array<Record<string, unknown>>;
  const me = all.find((r) => r.reviewer_role === myRole) || null;
  const other = all.find((r) => r.reviewer_role !== myRole) || null;

  // Blind-vinduet: motpartens review vises hvis BÅDE har levert,
  // ELLER hvis 14 dager har passert siden checkout.
  const checkoutAge = booking.check_out
    ? (Date.now() - new Date(booking.check_out as string).getTime()) / (1000 * 60 * 60 * 24)
    : 0;
  const counterpartVisible = !!other && (!!me || checkoutAge >= BLIND_WINDOW_DAYS);

  const toReview = (r: Record<string, unknown> | null): Review | null =>
    r
      ? {
          id: r.id as string,
          bookingId: r.booking_id as string,
          listingId: r.listing_id as string,
          userId: r.user_id as string,
          rating: r.rating as number,
          comment: r.comment as string,
          createdAt: r.created_at as string,
        }
      : null;

  return {
    myReview: toReview(me),
    counterpart: toReview(other),
    counterpartVisible,
    myRole,
  };
}

/**
 * Aggregert rating for en gjest (snitt av host-reviews om hen).
 * Brukes i HostRequestsView for å hjelpe host å bestemme.
 */
export async function getGuestRating(
  guestId: string,
): Promise<{ rating: number; count: number }> {
  const supabase = await createClient();

  const { data } = await supabase
    .from("profiles")
    .select("rating, review_count")
    .eq("id", guestId)
    .single();

  return {
    rating: (data?.rating as number) || 0,
    count: (data?.review_count as number) || 0,
  };
}
