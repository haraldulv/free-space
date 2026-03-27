import { createClient } from "./server";
import type { Review } from "@/types";

export async function getListingReviews(listingId: string): Promise<Review[]> {
  const supabase = await createClient();

  const { data, error } = await supabase
    .from("reviews")
    .select("*, profiles:user_id(full_name, avatar_url)")
    .eq("listing_id", listingId)
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

export async function getUserReviewForBooking(bookingId: string): Promise<Review | null> {
  const supabase = await createClient();

  const { data, error } = await supabase
    .from("reviews")
    .select("*")
    .eq("booking_id", bookingId)
    .maybeSingle();

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
