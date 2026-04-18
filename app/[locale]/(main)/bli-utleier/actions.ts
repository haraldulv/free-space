"use server";

import { createListing, updateListing, deleteListing, toggleListingActive, updateBlockedDates, type CreateListingData } from "@/lib/supabase/listings";
import { createClient } from "@/lib/supabase/server";

async function getAuthUserId(): Promise<string> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Ikke innlogget");
  return user.id;
}

export async function createListingAction(data: CreateListingData): Promise<{ id?: string; error?: string }> {
  try {
    const userId = await getAuthUserId();
    const id = await createListing(data, userId);
    return { id };
  } catch (err) {
    console.error("createListingAction error:", err);
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function updateListingAction(id: string, data: Partial<CreateListingData>): Promise<{ error?: string }> {
  try {
    const userId = await getAuthUserId();
    await updateListing(id, data, userId);
    return {};
  } catch (err) {
    console.error("updateListingAction error:", err);
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function deleteListingAction(id: string): Promise<void> {
  const userId = await getAuthUserId();
  return deleteListing(id, userId);
}

export async function toggleListingActiveAction(id: string, isActive: boolean): Promise<{ error?: string }> {
  try {
    const userId = await getAuthUserId();
    await toggleListingActive(id, userId, isActive);
    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function updateBlockedDatesAction(id: string, blockedDates: string[]): Promise<{ error?: string }> {
  try {
    const userId = await getAuthUserId();
    await updateBlockedDates(id, userId, blockedDates);
    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

/**
 * Oppdater blokkerte datoer for én plass innenfor en annonse.
 * Bevarer alle øvrige felt på spot_markers — bare blockedDates på matching spot endres.
 */
export async function updateSpotBlockedDatesAction(
  listingId: string,
  spotId: string,
  blockedDates: string[],
): Promise<{ error?: string }> {
  try {
    const userId = await getAuthUserId();
    const { createClient } = await import("@/lib/supabase/server");
    const supabase = await createClient();

    const { data: listing, error: fetchErr } = await supabase
      .from("listings")
      .select("host_id, spot_markers")
      .eq("id", listingId)
      .single();

    if (fetchErr || !listing) return { error: "Annonse ikke funnet" };
    if (listing.host_id !== userId) return { error: "Ikke tilgang" };

    const markers = (listing.spot_markers as Array<Record<string, unknown>>) || [];
    const updated = markers.map((m) =>
      m.id === spotId
        ? { ...m, blockedDates: blockedDates.length > 0 ? blockedDates : null }
        : m,
    );

    const { error: updateErr } = await supabase
      .from("listings")
      .update({ spot_markers: updated })
      .eq("id", listingId);

    if (updateErr) return { error: updateErr.message };
    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}
