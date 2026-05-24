"use server";

import { createClient } from "@/lib/supabase/server";
import {
  listOutreachTargets,
  getOutreachTargetById,
  updateOutreachTarget,
  upsertOutreachTarget,
  appendContactLog,
  listContactLogForTarget,
  listEmailTemplates,
  getDefaultTemplate,
  saveEmailTemplate,
  deleteEmailTemplate,
  applyTemplateVariables,
  type SaveTemplateInput,
  type UpdateOutreachPatch,
} from "@/lib/supabase/outreach";
import type {
  OutreachCategory,
  OutreachStatus,
  OutreachTarget,
  OutreachContactLogEntry,
  OutreachEmailTemplate,
} from "@/types";
import { sendHostOutreachEmail } from "@/lib/email";

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
  return { user };
}

export async function loadOutreachAction(filters: {
  area?: string;
  category?: OutreachCategory;
  status?: OutreachStatus;
  search?: string;
}): Promise<{ targets?: OutreachTarget[]; templates?: OutreachEmailTemplate[]; error?: string }> {
  try {
    await requireAdmin();
    const [targets, templates] = await Promise.all([
      listOutreachTargets(filters),
      listEmailTemplates(),
    ]);
    return { targets, templates };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Lasting feilet" };
  }
}

export async function loadTargetDetailAction(
  id: string,
): Promise<{ target?: OutreachTarget; log?: OutreachContactLogEntry[]; error?: string }> {
  try {
    await requireAdmin();
    const [target, log] = await Promise.all([
      getOutreachTargetById(id),
      listContactLogForTarget(id),
    ]);
    if (!target) return { error: "Fant ikke target" };
    return { target, log };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Lasting feilet" };
  }
}

export async function updateTargetAction(
  id: string,
  patch: UpdateOutreachPatch,
): Promise<{ target?: OutreachTarget; error?: string }> {
  try {
    await requireAdmin();
    const target = await updateOutreachTarget(id, patch);
    return { target };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Oppdatering feilet" };
  }
}

export async function logNoteAction(
  targetId: string,
  note: string,
): Promise<{ ok?: true; error?: string }> {
  try {
    await requireAdmin();
    await appendContactLog({
      targetId,
      contactType: "note",
      body: note,
    });
    return { ok: true };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Logging feilet" };
  }
}

export async function logPhoneCallAction(
  targetId: string,
  outcome: string,
  newStatus?: OutreachStatus,
): Promise<{ ok?: true; error?: string }> {
  try {
    const { user } = await requireAdmin();
    await appendContactLog({
      targetId,
      contactType: "phone",
      body: outcome,
      statusAfter: newStatus ?? null,
    });
    await updateOutreachTarget(targetId, {
      lastContactedAt: new Date().toISOString(),
      lastContactedBy: user.id,
      ...(newStatus ? { status: newStatus } : {}),
    });
    return { ok: true };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Logging feilet" };
  }
}

export async function sendOutreachEmailAction(
  targetId: string,
  payload: { subject: string; body: string; recipientEmail: string; templateId?: string },
): Promise<{ ok?: true; error?: string }> {
  try {
    const { user } = await requireAdmin();
    const target = await getOutreachTargetById(targetId);
    if (!target) return { error: "Fant ikke target" };

    const substituted = applyTemplateVariables(payload.body, { name: target.name });
    const substitutedSubject = applyTemplateVariables(payload.subject, { name: target.name });

    await sendHostOutreachEmail({
      to: payload.recipientEmail,
      subject: substitutedSubject,
      body: substituted,
    });

    await appendContactLog({
      targetId,
      contactType: "email",
      recipient: payload.recipientEmail,
      subject: substitutedSubject,
      body: substituted,
      statusAfter: "contacted",
    });

    const newStatus: OutreachStatus = target.status === "not_contacted" || target.status === "queued"
      ? "contacted"
      : target.status;

    await updateOutreachTarget(targetId, {
      email: payload.recipientEmail,
      lastContactedAt: new Date().toISOString(),
      lastContactedBy: user.id,
      status: newStatus,
    });

    return { ok: true };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "E-post-sending feilet" };
  }
}

export async function saveTemplateAction(
  payload: SaveTemplateInput,
): Promise<{ template?: OutreachEmailTemplate; error?: string }> {
  try {
    await requireAdmin();
    const template = await saveEmailTemplate(payload);
    return { template };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Lagring feilet" };
  }
}

export async function deleteTemplateAction(id: string): Promise<{ ok?: true; error?: string }> {
  try {
    await requireAdmin();
    await deleteEmailTemplate(id);
    return { ok: true };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Sletting feilet" };
  }
}

export async function getDefaultTemplateAction(): Promise<{ template?: OutreachEmailTemplate | null; error?: string }> {
  try {
    await requireAdmin();
    const template = await getDefaultTemplate();
    return { template };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Lasting feilet" };
  }
}

export async function resolveGoogleMapsUrlAction(rawUrl: string): Promise<{
  placeId?: string | null;
  name?: string | null;
  address?: string | null;
  phone?: string | null;
  website?: string | null;
  lat?: number | null;
  lng?: number | null;
  rating?: number | null;
  userRatingsTotal?: number | null;
  error?: string;
}> {
  try {
    await requireAdmin();
    const apiKey = process.env.GOOGLE_PLACES_API_KEY || process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY || "";
    if (!apiKey) return { error: "Mangler GOOGLE_PLACES_API_KEY" };

    let url = rawUrl.trim();
    if (/maps\.app\.goo\.gl|goo\.gl\/maps/i.test(url)) {
      const res = await fetch(url, { redirect: "follow" });
      url = res.url;
    }

    const placeId = (() => {
      try {
        const u = new URL(url);
        return u.searchParams.get("query_place_id") || u.searchParams.get("ftid") || null;
      } catch { return null; }
    })();

    const placeName = (() => {
      const m = url.match(/\/place\/([^/@]+)/);
      if (m) return decodeURIComponent(m[1].replaceAll("+", " "));
      try {
        const u = new URL(url);
        const q = u.searchParams.get("q") || u.searchParams.get("query");
        if (q && !/^[\d.,-]+$/.test(q)) return q;
      } catch { /* ignore */ }
      return null;
    })();

    const coords = (() => {
      const m = url.match(/@(-?\d+\.\d+),(-?\d+\.\d+)/);
      if (m) return { lat: parseFloat(m[1]), lng: parseFloat(m[2]) };
      return null;
    })();

    const fieldMask = "id,displayName,formattedAddress,location,rating,userRatingCount,nationalPhoneNumber,internationalPhoneNumber,websiteUri";

    const toResult = (p: Record<string, unknown>) => {
      const loc = p.location as Record<string, number> | undefined;
      const dn = p.displayName as Record<string, string> | undefined;
      return {
        placeId: (p.id as string) || null,
        name: dn?.text || null,
        address: (p.formattedAddress as string) || null,
        phone: (p.nationalPhoneNumber as string) || (p.internationalPhoneNumber as string) || null,
        website: (p.websiteUri as string) || null,
        lat: loc?.latitude ?? null,
        lng: loc?.longitude ?? null,
        rating: (p.rating as number) ?? null,
        userRatingsTotal: (p.userRatingCount as number) ?? null,
      };
    };

    if (placeId) {
      const r = await fetch(`https://places.googleapis.com/v1/places/${placeId}?languageCode=no`, {
        headers: { "X-Goog-Api-Key": apiKey, "X-Goog-FieldMask": fieldMask },
      });
      if (r.ok) return toResult(await r.json());
    }

    const searchForPlace = async (query: string) => {
      const body: Record<string, unknown> = { textQuery: query, languageCode: "no", maxResultCount: 1 };
      if (coords) body.locationBias = { circle: { center: { latitude: coords.lat, longitude: coords.lng }, radius: 5000 } };
      const r = await fetch("https://places.googleapis.com/v1/places:searchText", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Goog-Api-Key": apiKey, "X-Goog-FieldMask": `places.${fieldMask.replaceAll(",", ",places.")}` },
        body: JSON.stringify(body),
      });
      if (!r.ok) return null;
      const d = await r.json();
      return d.places?.[0] ?? null;
    };

    if (placeName) {
      const p = await searchForPlace(placeName);
      if (p) return toResult(p);
    }

    if (coords) {
      const p = await searchForPlace(`${coords.lat},${coords.lng}`);
      if (p) return toResult(p);
    }

    return { error: "Kunne ikke finne sted fra denne lenken. Prøv å legge til manuelt." };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Oppslag feilet" };
  }
}

export async function createManualTargetAction(input: {
  name: string;
  category: OutreachCategory;
  area?: string;
  address?: string;
  phone?: string;
  website?: string;
  email?: string;
  lat?: number;
  lng?: number;
  rating?: number;
  userRatingsTotal?: number;
  placeId?: string;
}): Promise<{ target?: OutreachTarget; error?: string }> {
  try {
    await requireAdmin();
    const placeId = input.placeId || `manual_${crypto.randomUUID()}`;
    const { target } = await upsertOutreachTarget({
      placeId,
      name: input.name,
      category: input.category,
      area: input.area || "lofoten",
      address: input.address,
      phone: input.phone,
      website: input.website,
      email: input.email,
      lat: input.lat,
      lng: input.lng,
      rating: input.rating,
      userRatingsTotal: input.userRatingsTotal,
    });
    return { target: target ?? undefined };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Opprettelse feilet" };
  }
}

export async function exportTargetsCSVAction(filters: {
  area?: string;
  category?: OutreachCategory;
  status?: OutreachStatus;
}): Promise<{ csv?: string; error?: string }> {
  try {
    await requireAdmin();
    const targets = await listOutreachTargets(filters);
    const headers = [
      "name", "category", "area", "status",
      "address", "phone", "website", "email",
      "rating", "user_ratings_total",
      "last_contacted_at", "follow_up_at", "notes",
    ];
    const escape = (v: string | number | null | undefined): string => {
      if (v == null) return "";
      const s = String(v);
      return /[",\n]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s;
    };
    const rows = targets.map((t) =>
      [
        t.name, t.category, t.area, t.status,
        t.address ?? "", t.phone ?? "", t.website ?? "", t.email ?? "",
        t.rating ?? "", t.userRatingsTotal ?? "",
        t.lastContactedAt ?? "", t.followUpAt ?? "", t.notes ?? "",
      ].map(escape).join(","),
    );
    return { csv: [headers.join(","), ...rows].join("\n") };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Eksport feilet" };
  }
}
