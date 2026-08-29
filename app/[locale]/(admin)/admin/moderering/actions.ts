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
  const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  if (aal?.currentLevel !== "aal2") throw new Error("Tofaktor kreves. Åpne /admin/mfa.");
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

// ---------------------------------------------------------------------
// Rapporter + innholdsflagg
// ---------------------------------------------------------------------

export interface AdminReport {
  id: string;
  target_type: "listing" | "user" | "conversation" | "review";
  target_id: string;
  reason: string;
  details: string | null;
  status: "open" | "reviewed" | "dismissed";
  admin_note: string | null;
  created_at: string;
  reporter: { full_name: string | null } | null;
  target_label: string;
  target_user_id: string | null;
}

export interface AdminContentFlag {
  id: string;
  content_type: "message" | "review" | "avatar";
  content_id: string;
  author_id: string | null;
  severity: "low" | "medium" | "high";
  category: string;
  reason: string | null;
  excerpt: string | null;
  status: "open" | "reviewed" | "dismissed";
  created_at: string;
  author: { full_name: string | null } | null;
  content_exists: boolean;
}

export async function loadReportsAction(): Promise<{ reports?: AdminReport[]; flags?: AdminContentFlag[]; error?: string }> {
  try {
    const { supabase } = await requireAdmin();
    const [{ data: reports, error: e1 }, { data: flags, error: e2 }] = await Promise.all([
      supabase
        .from("reports")
        .select("id, target_type, target_id, reason, details, status, admin_note, created_at, reporter:reporter_id(full_name)")
        .order("created_at", { ascending: false })
        .limit(200),
      supabase
        .from("content_flags")
        .select("id, content_type, content_id, author_id, severity, category, reason, excerpt, status, created_at, author:author_id(full_name)")
        .order("created_at", { ascending: false })
        .limit(200),
    ]);
    if (e1) return { error: e1.message };
    if (e2) return { error: e2.message };

    type RawReport = Omit<AdminReport, "target_label" | "target_user_id" | "reporter"> & { reporter: { full_name: string | null } | { full_name: string | null }[] | null };
    const rawReports = (reports ?? []) as unknown as RawReport[];

    const listingIds = rawReports.filter((r) => r.target_type === "listing").map((r) => r.target_id);
    const userIds = rawReports.filter((r) => r.target_type === "user").map((r) => r.target_id);
    const convIds = rawReports.filter((r) => r.target_type === "conversation").map((r) => r.target_id);
    const [{ data: ls }, { data: us }, { data: cs }] = await Promise.all([
      listingIds.length ? supabase.from("listings").select("id, title, host_id").in("id", listingIds) : Promise.resolve({ data: [] as Array<{ id: string; title: string; host_id: string | null }> }),
      userIds.length ? supabase.from("profiles").select("id, full_name").in("id", userIds) : Promise.resolve({ data: [] as Array<{ id: string; full_name: string | null }> }),
      convIds.length ? supabase.from("conversations").select("id, guest_id, host_id, guest:guest_id(full_name), host:host_id(full_name)").in("id", convIds) : Promise.resolve({ data: [] as unknown[] }),
    ]);

    const out: AdminReport[] = rawReports.map((r) => {
      let target_label = r.target_id;
      let target_user_id: string | null = null;
      if (r.target_type === "listing") {
        const l = (ls ?? []).find((x) => x.id === r.target_id);
        target_label = l?.title ?? r.target_id;
        target_user_id = l?.host_id ?? null;
      } else if (r.target_type === "user") {
        const u = (us ?? []).find((x) => x.id === r.target_id);
        target_label = u?.full_name ?? r.target_id;
        target_user_id = r.target_id;
      } else if (r.target_type === "conversation") {
        const c = (cs as Array<{ id: string; guest_id: string; host_id: string; guest: { full_name: string } | null; host: { full_name: string } | null }> | null ?? []).find((x) => x.id === r.target_id);
        target_label = c ? `${c.guest?.full_name ?? "?"} ↔ ${c.host?.full_name ?? "?"}` : r.target_id;
      }
      const reporter = Array.isArray(r.reporter) ? r.reporter[0] ?? null : r.reporter;
      return { ...r, reporter, target_label, target_user_id };
    });

    type RawFlag = Omit<AdminContentFlag, "author" | "content_exists"> & { author: { full_name: string | null } | { full_name: string | null }[] | null };
    const rawFlags = (flags ?? []) as unknown as RawFlag[];
    const msgIds = rawFlags.filter((f) => f.content_type === "message").map((f) => f.content_id);
    const revIds = rawFlags.filter((f) => f.content_type === "review").map((f) => f.content_id);
    const [{ data: ms }, { data: rs }] = await Promise.all([
      msgIds.length ? supabase.from("messages").select("id").in("id", msgIds) : Promise.resolve({ data: [] as Array<{ id: string }> }),
      revIds.length ? supabase.from("reviews").select("id").in("id", revIds) : Promise.resolve({ data: [] as Array<{ id: string }> }),
    ]);
    const outFlags: AdminContentFlag[] = rawFlags.map((f) => ({
      ...f,
      author: Array.isArray(f.author) ? f.author[0] ?? null : f.author,
      content_exists:
        f.content_type === "message" ? (ms ?? []).some((m) => m.id === f.content_id)
        : f.content_type === "review" ? (rs ?? []).some((r) => r.id === f.content_id)
        : true,
    }));

    return { reports: out, flags: outFlags };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function resolveReportAction(id: string, status: "reviewed" | "dismissed", note?: string): Promise<{ error?: string }> {
  try {
    const { supabase, user } = await requireAdmin();
    const { error } = await supabase
      .from("reports")
      .update({ status, admin_note: note?.trim() || null, handled_by: user.id, handled_at: new Date().toISOString() })
      .eq("id", id);
    return error ? { error: error.message } : {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function resolveFlagAction(id: string, status: "reviewed" | "dismissed"): Promise<{ error?: string }> {
  try {
    const { supabase, user } = await requireAdmin();
    const { error } = await supabase
      .from("content_flags")
      .update({ status, handled_by: user.id, handled_at: new Date().toISOString() })
      .eq("id", id);
    return error ? { error: error.message } : {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

/** Sletter flagget innhold (melding/anmeldelse) og markerer flagget som behandlet. */
export async function deleteFlaggedContentAction(flagId: string): Promise<{ error?: string }> {
  try {
    const { supabase, user } = await requireAdmin();
    const { data: flag } = await supabase.from("content_flags").select("content_type, content_id").eq("id", flagId).maybeSingle();
    if (!flag) return { error: "Flagg ikke funnet" };
    if (flag.content_type === "message") {
      await supabase.from("messages").update({ content: "[Meldingen ble fjernet av Tuno]" }).eq("id", flag.content_id);
    } else if (flag.content_type === "review") {
      await supabase.from("reviews").delete().eq("id", flag.content_id);
    }
    await supabase
      .from("content_flags")
      .update({ status: "reviewed", handled_by: user.id, handled_at: new Date().toISOString() })
      .eq("id", flagId);
    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

// ---------------------------------------------------------------------
// Nødbryter for registrering
// ---------------------------------------------------------------------

export async function loadSignupSettingAction(): Promise<{ enabled: boolean; reason: string; lastSweepAt: string | null; sweepAgeMin: number | null }> {
  const { supabase } = await requireAdmin();
  const { data } = await supabase.from("app_settings").select("key, value").in("key", ["signups_enabled", "signups_disabled_reason", "last_sweep_at"]);
  const get = (k: string) => data?.find((r) => r.key === k)?.value;
  return {
    enabled: get("signups_enabled") !== false,
    reason: typeof get("signups_disabled_reason") === "string" ? (get("signups_disabled_reason") as string) : "",
    lastSweepAt: typeof get("last_sweep_at") === "string" ? (get("last_sweep_at") as string) : null,
    sweepAgeMin: typeof get("last_sweep_at") === "string" ? (Date.now() - new Date(get("last_sweep_at") as string).getTime()) / 60_000 : null,
  };
}

export async function setSignupsEnabledAction(enabled: boolean, reason?: string): Promise<{ error?: string }> {
  try {
    const { supabase, user } = await requireAdmin();
    const now = new Date().toISOString();
    const { error } = await supabase.from("app_settings").update({ value: enabled, updated_at: now, updated_by: user.id }).eq("key", "signups_enabled");
    if (error) return { error: error.message };
    await supabase.from("app_settings").update({ value: enabled ? "" : (reason?.trim() || `Stengt manuelt av admin ${now}`), updated_at: now, updated_by: user.id }).eq("key", "signups_disabled_reason");
    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}
