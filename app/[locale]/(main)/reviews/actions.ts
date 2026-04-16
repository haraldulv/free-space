"use server";

import { createClient } from "@/lib/supabase/server";

async function getAuthUser() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Ikke innlogget");
  return { supabase, user };
}

export async function createReviewAction(data: {
  bookingId: string;
  listingId: string;
  rating: number;
  comment: string;
}): Promise<{ error?: string }> {
  try {
    const { supabase, user } = await getAuthUser();

    // Verify booking belongs to user and is confirmed
    const { data: booking } = await supabase
      .from("bookings")
      .select("id, user_id, status, check_out")
      .eq("id", data.bookingId)
      .single();

    if (!booking) return { error: "Bestilling ikke funnet" };
    if (booking.user_id !== user.id) return { error: "Ikke tilgang" };
    if (booking.status !== "confirmed") return { error: "Bestillingen er ikke fullført" };

    const today = new Date().toISOString().split("T")[0];
    if (booking.check_out > today) return { error: "Du kan skrive anmeldelse etter utsjekk" };

    // Check if review already exists
    const { data: existing } = await supabase
      .from("reviews")
      .select("id")
      .eq("booking_id", data.bookingId)
      .maybeSingle();

    if (existing) return { error: "Du har allerede skrevet en anmeldelse for denne bestillingen" };

    const { error } = await supabase.from("reviews").insert({
      booking_id: data.bookingId,
      listing_id: data.listingId,
      user_id: user.id,
      rating: data.rating,
      comment: data.comment,
    });

    if (error) return { error: error.message };

    // Notify host
    const { data: listing } = await supabase
      .from("listings")
      .select("host_id, title")
      .eq("id", data.listingId)
      .single();

    if (listing?.host_id) {
      await supabase.from("notifications").insert({
        user_id: listing.host_id,
        type: "new_review",
        title: "Ny anmeldelse",
        body: `Noen har gitt ${data.rating} stjerner til ${listing.title}`,
        metadata: { listingId: data.listingId, reviewRating: data.rating },
      });
    }

    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function deleteReviewAction(reviewId: string): Promise<{ error?: string }> {
  try {
    const { supabase, user } = await getAuthUser();

    const { error } = await supabase
      .from("reviews")
      .delete()
      .eq("id", reviewId)
      .eq("user_id", user.id);

    if (error) return { error: error.message };
    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}
