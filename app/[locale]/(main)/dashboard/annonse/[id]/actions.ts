"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { WEEKEND_DAY_MASK } from "@/lib/pricing";

async function requireHost(listingId: string) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { error: "Ikke innlogget" as const };
  const { data: listing } = await supabase
    .from("listings")
    .select("host_id")
    .eq("id", listingId)
    .single();
  if (!listing || listing.host_id !== user.id) return { error: "Ingen tilgang" as const };
  return { supabase, user, listingId };
}

export async function setWeekendPriceAction(
  listingId: string,
  price: number | null,
): Promise<{ error?: string }> {
  const ctx = await requireHost(listingId);
  if ("error" in ctx) return { error: ctx.error };
  const supabase = ctx.supabase;

  // Slett eksisterende helg-regel (bare én tillatt per listing for nå)
  await supabase
    .from("listing_pricing_rules")
    .delete()
    .eq("listing_id", listingId)
    .eq("kind", "weekend");

  if (price != null && price > 0) {
    const { error } = await supabase.from("listing_pricing_rules").insert({
      listing_id: listingId,
      kind: "weekend",
      day_mask: WEEKEND_DAY_MASK,
      price,
    });
    if (error) return { error: error.message };
  }

  revalidatePath(`/dashboard/annonse/${listingId}`);
  return {};
}

export async function addSeasonRuleAction(
  listingId: string,
  startDate: string,
  endDate: string,
  price: number,
): Promise<{ error?: string }> {
  const ctx = await requireHost(listingId);
  if ("error" in ctx) return { error: ctx.error };
  if (!startDate || !endDate || startDate > endDate) return { error: "Ugyldig dato-range" };
  if (price <= 0) return { error: "Pris må være positiv" };

  const { error } = await ctx.supabase.from("listing_pricing_rules").insert({
    listing_id: listingId,
    kind: "season",
    start_date: startDate,
    end_date: endDate,
    price,
  });
  if (error) return { error: error.message };

  revalidatePath(`/dashboard/annonse/${listingId}`);
  return {};
}

export async function removeRuleAction(
  listingId: string,
  ruleId: string,
): Promise<{ error?: string }> {
  const ctx = await requireHost(listingId);
  if ("error" in ctx) return { error: ctx.error };

  const { error } = await ctx.supabase
    .from("listing_pricing_rules")
    .delete()
    .eq("id", ruleId)
    .eq("listing_id", listingId);
  if (error) return { error: error.message };

  revalidatePath(`/dashboard/annonse/${listingId}`);
  return {};
}
