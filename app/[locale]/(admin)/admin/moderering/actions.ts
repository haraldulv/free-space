"use server";

import { createClient } from "@/lib/supabase/server";
import { createClient as createServiceClient } from "@supabase/supabase-js";
import { stripe } from "@/lib/stripe";
import { moderateListing, setListingModeration } from "@/lib/moderation";
import type { ModerationStatus } from "@/types";

function getServiceClient() {
  return createServiceClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );
}

async function requireAdmin() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Ikke innlogget");
  const { data: profile } = await supabase
    .from("profiles")
    .select("is_admin")
    .eq("id", user.id)
    .single();
  if (!profile?.is_admin) throw new Error("Ikke admin");
  return { supabase: getServiceClient(), user };
}

export interface ModerationListing {
  id: string;
  title: string;
  description: string | null;
  category: string;
  city: string | null;
  region: string | null;
  address: string | null;
  images: string[];
  created_at: string;
  is_active: boolean | null;
  moderation_status: ModerationStatus;
  moderation_reason: string | null;
  moderation_ai: Record<string, unknown> | null;
  moderated_at: string | null;
  host_stripe_ready: boolean;
  host_id: string | null;
  host: {
    full_name: string | null;
    email: string | null;
    created_at: string | null;
    stripe_account_id: string | null;
    stripe_onboarding_complete: boolean | null;
    listings_count: number;
  } | null;
}

export async function loadModerationAction(): Promise<{ listings?: ModerationListing[]; error?: string }> {
  try {
    const { supabase } = await requireAdmin();
    const { data, error } = await supabase
      .from("listings")
      .select("id, title, description, category, city, region, address, images, created_at, is_active, moderation_status, moderation_reason, moderation_ai, moderated_at, host_stripe_ready, host_id, host:host_id(full_name, created_at, stripe_account_id, stripe_onboarding_complete)")
      .order("created_at", { ascending: false })
      .limit(300);
    if (error) return { error: error.message };

    const rows = (data ?? []) as unknown as Array<Omit<ModerationListing, "host"> & { host: Omit<NonNullable<ModerationListing["host"]>, "email" | "listings_count"> | null }>;
    const hostIds = Array.from(new Set(rows.map((r) => r.host_id).filter((x): x is string => Boolean(x))));

    // E-post ligger i auth.users; hent via admin-API (batch per host).
    const emails = new Map<string, string | null>();
    await Promise.all(hostIds.map(async (id) => {
      const { data: u } = await supabase.auth.admin.getUserById(id);
      emails.set(id, u?.user?.email ?? null);
    }));
    const counts = new Map<string, number>();
    rows.forEach((r) => { if (r.host_id) counts.set(r.host_id, (counts.get(r.host_id) ?? 0) + 1); });

    const listings: ModerationListing[] = rows.map((r) => ({
      ...r,
      images: r.images ?? [],
      host: r.host
        ? { ...r.host, email: r.host_id ? emails.get(r.host_id) ?? null : null, listings_count: r.host_id ? counts.get(r.host_id) ?? 0 : 0 }
        : null,
    }));
    return { listings };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function approveListingAction(listingId: string): Promise<{ error?: string }> {
  try {
    const { user } = await requireAdmin();
    await setListingModeration(listingId, "approved", user.id);
    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function rejectListingAction(listingId: string, reason: string): Promise<{ error?: string }> {
  try {
    const { user } = await requireAdmin();
    await setListingModeration(listingId, "rejected", user.id, reason);
    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function rerunAiAction(listingId: string): Promise<{ error?: string; verdict?: string | null }> {
  try {
    const { supabase } = await requireAdmin();
    await supabase
      .from("listings")
      .update({ moderation_status: "pending", moderation_ai: null, moderation_reason: null, moderated_at: null, moderated_by: null })
      .eq("id", listingId);
    const result = await moderateListing(listingId);
    return { verdict: result?.verdict ?? null };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

async function deleteStoragePrefix(supabase: ReturnType<typeof getServiceClient>, prefix: string) {
  const { data: files } = await supabase.storage.from("listing-images").list(prefix, { limit: 1000 });
  if (files?.length) {
    await supabase.storage.from("listing-images").remove(files.map((f) => `${prefix}/${f.name}`));
  }
}

function storagePathFromUrl(url: string): string | null {
  const marker = "/storage/v1/object/public/listing-images/";
  const i = url.indexOf(marker);
  return i === -1 ? null : decodeURIComponent(url.slice(i + marker.length));
}

export async function deleteListingHardAction(listingId: string): Promise<{ error?: string }> {
  try {
    const { supabase } = await requireAdmin();
    const { data: listing } = await supabase.from("listings").select("images").eq("id", listingId).maybeSingle();
    const paths = ((listing?.images as string[] | null) ?? []).map(storagePathFromUrl).filter((p): p is string => Boolean(p));
    if (paths.length) {
      await supabase.storage.from("listing-images").remove(paths);
    }
    const { error } = await supabase.from("listings").delete().eq("id", listingId);
    if (error) return { error: error.message };
    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

/**
 * Sletter bruker fullstendig: alle annonser (+ bilder), storage-mappen,
 * auth.users (cascader profiles/bookings/notifications/...), og avviser
 * Stripe Connect-kontoen (reject reason=fraud) hvis den finnes.
 */
export async function deleteUserHardAction(userId: string, opts: { rejectStripe: boolean }): Promise<{ error?: string; stripe?: string }> {
  try {
    const { supabase, user } = await requireAdmin();
    if (userId === user.id) return { error: "Du kan ikke slette deg selv." };

    const { data: profile } = await supabase
      .from("profiles")
      .select("stripe_account_id, is_admin")
      .eq("id", userId)
      .maybeSingle();
    if (profile?.is_admin) return { error: "Kan ikke slette en admin herfra." };

    let stripeNote = "ingen Stripe-konto";
    if (profile?.stripe_account_id) {
      if (opts.rejectStripe) {
        try {
          await stripe.accounts.reject(profile.stripe_account_id, { reason: "fraud" });
          stripeNote = `Stripe-konto ${profile.stripe_account_id} avvist (fraud)`;
        } catch (err) {
          stripeNote = `Stripe reject feilet: ${err instanceof Error ? err.message : String(err)}`;
        }
      } else {
        stripeNote = `Stripe-konto ${profile.stripe_account_id} beholdt`;
      }
    }

    // Annonser (host_id blir SET NULL ved user-delete, så slett eksplisitt)
    const { data: listings } = await supabase.from("listings").select("id").eq("host_id", userId);
    if (listings?.length) {
      await supabase.from("listings").delete().in("id", listings.map((l) => l.id));
    }
    await deleteStoragePrefix(supabase, userId);

    const { error } = await supabase.auth.admin.deleteUser(userId);
    if (error) return { error: error.message, stripe: stripeNote };
    return { stripe: stripeNote };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}
