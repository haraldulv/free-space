"use server";

import { createClient } from "@/lib/supabase/server";
import { sendPushToUser } from "@/lib/push";

async function getAuthUser() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Ikke innlogget");
  return { supabase, user };
}

/**
 * Tovei reviews (Airbnb-modell):
 * - Gjest anmelder host (default — beholdes for bakoverkompatibilitet hvis
 *   role ikke spesifiseres).
 * - Host anmelder gjest (role='host').
 * Begge anmeldelser holdes skjult for motparten til BEGGE har levert eller
 * 14 dager har passert (visibility-logikk i lib/supabase/reviews.ts).
 */
export async function createReviewAction(data: {
  bookingId: string;
  listingId: string;
  rating: number;
  comment: string;
}): Promise<{ error?: string }> {
  try {
    const { supabase, user } = await getAuthUser();

    const { data: booking } = await supabase
      .from("bookings")
      .select("id, user_id, host_id, status, check_out")
      .eq("id", data.bookingId)
      .single();

    if (!booking) return { error: "Bestilling ikke funnet" };

    const isGuest = booking.user_id === user.id;
    const isHost = booking.host_id === user.id;
    if (!isGuest && !isHost) return { error: "Ikke tilgang" };

    if (booking.status !== "confirmed") return { error: "Bestillingen er ikke fullført" };

    const today = new Date().toISOString().split("T")[0];
    if (booking.check_out > today) return { error: "Du kan skrive anmeldelse etter utsjekk" };

    const reviewerRole: "guest" | "host" = isHost ? "host" : "guest";
    const revieweeId = isHost ? booking.user_id : booking.host_id;

    // Sjekk at samme rolle ikke har skrevet allerede
    const { data: existing } = await supabase
      .from("reviews")
      .select("id")
      .eq("booking_id", data.bookingId)
      .eq("reviewer_role", reviewerRole)
      .maybeSingle();

    if (existing) return { error: "Du har allerede skrevet en anmeldelse for denne bestillingen" };

    const { error } = await supabase.from("reviews").insert({
      booking_id: data.bookingId,
      listing_id: data.listingId,
      user_id: user.id,
      reviewer_role: reviewerRole,
      reviewee_id: revieweeId,
      rating: data.rating,
      comment: data.comment,
    });

    if (error) return { error: error.message };

    // Sjekk om motparten allerede har levert — i så fall publiseres begge nå
    const { data: counterpart } = await supabase
      .from("reviews")
      .select("id")
      .eq("booking_id", data.bookingId)
      .neq("reviewer_role", reviewerRole)
      .maybeSingle();

    const bothPosted = !!counterpart;

    // Varsle motparten
    const { data: listing } = await supabase
      .from("listings")
      .select("title")
      .eq("id", data.listingId)
      .single();

    const listingTitle = listing?.title || "en plass";
    const counterpartId = isHost ? booking.user_id : booking.host_id;

    if (counterpartId) {
      const title = bothPosted
        ? "Anmeldelsen er publisert"
        : (isHost ? "Utleier har anmeldt deg" : "Du har fått en anmeldelse");
      const body = bothPosted
        ? `Begge anmeldelsene for ${listingTitle} er nå synlige.`
        : (isHost
            ? `Skriv din anmeldelse av oppholdet for å se hva utleier skrev.`
            : `Skriv din anmeldelse av gjesten for å se hva de skrev.`);

      await supabase.from("notifications").insert({
        user_id: counterpartId,
        type: "new_review",
        title,
        body,
        metadata: { bookingId: data.bookingId, listingId: data.listingId },
      });

      await sendPushToUser(
        counterpartId,
        title,
        body,
        { bookingId: data.bookingId, type: "new_review" },
      ).catch((err) => console.error("[Push] new_review failed:", err));
    }

    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

/**
 * Tovei-status for en booking sett fra innlogget bruker.
 * Brukes av BookingCard for å vise riktig review-UI (skriv / venter / publisert).
 */
export async function getBookingReviewStatusAction(bookingId: string): Promise<{
  myRole?: "guest" | "host";
  hasMyReview?: boolean;
  hasCounterpart?: boolean;
  counterpartVisible?: boolean;
  counterpart?: { rating: number; comment: string; createdAt: string } | null;
  error?: string;
}> {
  try {
    const { supabase, user } = await getAuthUser();

    const { data: booking } = await supabase
      .from("bookings")
      .select("user_id, host_id, check_out")
      .eq("id", bookingId)
      .single();

    if (!booking) return { error: "Bestilling ikke funnet" };
    if (booking.user_id !== user.id && booking.host_id !== user.id) {
      return { error: "Ikke tilgang" };
    }

    const myRole: "guest" | "host" = booking.host_id === user.id ? "host" : "guest";

    const { data: rows } = await supabase
      .from("reviews")
      .select("rating, comment, created_at, reviewer_role")
      .eq("booking_id", bookingId);

    const all = rows || [];
    const me = all.find((r) => r.reviewer_role === myRole);
    const other = all.find((r) => r.reviewer_role !== myRole);

    const checkoutAge = booking.check_out
      ? (Date.now() - new Date(booking.check_out).getTime()) / (1000 * 60 * 60 * 24)
      : 0;
    const counterpartVisible = !!other && (!!me || checkoutAge >= 14);

    return {
      myRole,
      hasMyReview: !!me,
      hasCounterpart: !!other,
      counterpartVisible,
      counterpart: counterpartVisible && other
        ? { rating: other.rating, comment: other.comment, createdAt: other.created_at }
        : null,
    };
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
