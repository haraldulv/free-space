"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

async function requireHostForListings(listingIds: string[]) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Ikke innlogget" as const };
  const { data: owned } = await supabase
    .from("listings")
    .select("id, host_id, blocked_dates")
    .in("id", listingIds);
  if (!owned || owned.length !== listingIds.length) return { error: "Ingen tilgang" as const };
  const notOwned = owned.find((l) => l.host_id !== user.id);
  if (notOwned) return { error: "Ingen tilgang" as const };
  return { supabase, user, listings: owned };
}

export async function bulkSetOverridesAction(
  items: Array<{ listingId: string; date: string; price: number }>,
): Promise<{ error?: string }> {
  if (items.length === 0) return {};
  const listingIds = Array.from(new Set(items.map((i) => i.listingId)));
  const ctx = await requireHostForListings(listingIds);
  if ("error" in ctx) return { error: ctx.error };

  const { error } = await ctx.supabase
    .from("listing_pricing_overrides")
    .upsert(
      items.map((i) => ({ listing_id: i.listingId, date: i.date, price: i.price })),
      { onConflict: "listing_id,date" },
    );
  if (error) return { error: error.message };

  revalidatePath(`/dashboard/kalender`);
  return {};
}

export async function bulkClearOverridesAction(
  items: Array<{ listingId: string; date: string }>,
): Promise<{ error?: string }> {
  if (items.length === 0) return {};
  const listingIds = Array.from(new Set(items.map((i) => i.listingId)));
  const ctx = await requireHostForListings(listingIds);
  if ("error" in ctx) return { error: ctx.error };

  // Slett én-og-én (Supabase mangler multi-column in-delete)
  for (const item of items) {
    await ctx.supabase
      .from("listing_pricing_overrides")
      .delete()
      .eq("listing_id", item.listingId)
      .eq("date", item.date);
  }

  revalidatePath(`/dashboard/kalender`);
  return {};
}

export async function bulkBlockDatesAction(
  items: Array<{ listingId: string; date: string }>,
): Promise<{ error?: string }> {
  if (items.length === 0) return {};
  const listingIds = Array.from(new Set(items.map((i) => i.listingId)));
  const ctx = await requireHostForListings(listingIds);
  if ("error" in ctx) return { error: ctx.error };

  // Grupper per listing + merge inn i eksisterende blocked_dates
  const byListing = new Map<string, Set<string>>();
  for (const item of items) {
    if (!byListing.has(item.listingId)) byListing.set(item.listingId, new Set());
    byListing.get(item.listingId)!.add(item.date);
  }

  for (const listing of ctx.listings) {
    const toAdd = byListing.get(listing.id as string);
    if (!toAdd) continue;
    const existing = new Set<string>((listing.blocked_dates as string[] | null) || []);
    for (const d of toAdd) existing.add(d);
    const next = Array.from(existing).sort();
    const { error } = await ctx.supabase
      .from("listings")
      .update({ blocked_dates: next })
      .eq("id", listing.id as string);
    if (error) return { error: error.message };
  }

  revalidatePath(`/dashboard/kalender`);
  return {};
}

export async function bulkUnblockDatesAction(
  items: Array<{ listingId: string; date: string }>,
): Promise<{ error?: string }> {
  if (items.length === 0) return {};
  const listingIds = Array.from(new Set(items.map((i) => i.listingId)));
  const ctx = await requireHostForListings(listingIds);
  if ("error" in ctx) return { error: ctx.error };

  const byListing = new Map<string, Set<string>>();
  for (const item of items) {
    if (!byListing.has(item.listingId)) byListing.set(item.listingId, new Set());
    byListing.get(item.listingId)!.add(item.date);
  }

  for (const listing of ctx.listings) {
    const toRemove = byListing.get(listing.id as string);
    if (!toRemove) continue;
    const existing: string[] = ((listing.blocked_dates as string[] | null) || []).filter(
      (d) => !toRemove.has(d),
    );
    const { error } = await ctx.supabase
      .from("listings")
      .update({ blocked_dates: existing })
      .eq("id", listing.id as string);
    if (error) return { error: error.message };
  }

  revalidatePath(`/dashboard/kalender`);
  return {};
}
