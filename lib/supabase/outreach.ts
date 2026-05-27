import { createClient } from "./server";
import type {
  OutreachTarget,
  OutreachContactLogEntry,
  OutreachEmailTemplate,
  OutreachCategory,
  OutreachStatus,
  OutreachContactType,
} from "@/types";

interface RowOutreachTarget {
  id: string;
  place_id: string;
  name: string;
  category: OutreachCategory;
  area: string;
  address: string | null;
  phone: string | null;
  website: string | null;
  email: string | null;
  contact_person: string | null;
  lat: number | string | null;
  lng: number | string | null;
  rating: number | string | null;
  user_ratings_total: number | null;
  status: OutreachStatus;
  notes: string | null;
  last_contacted_at: string | null;
  last_contacted_by: string | null;
  follow_up_at: string | null;
  created_at: string;
  updated_at: string;
}

function rowToTarget(row: RowOutreachTarget): OutreachTarget {
  return {
    id: row.id,
    placeId: row.place_id,
    name: row.name,
    category: row.category,
    area: row.area,
    address: row.address,
    phone: row.phone,
    website: row.website,
    email: row.email,
    contactPerson: row.contact_person,
    lat: row.lat != null ? Number(row.lat) : null,
    lng: row.lng != null ? Number(row.lng) : null,
    rating: row.rating != null ? Number(row.rating) : null,
    userRatingsTotal: row.user_ratings_total,
    status: row.status,
    notes: row.notes,
    lastContactedAt: row.last_contacted_at,
    lastContactedBy: row.last_contacted_by,
    followUpAt: row.follow_up_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export interface ListOutreachFilters {
  area?: string;
  category?: OutreachCategory;
  status?: OutreachStatus;
  search?: string;
  limit?: number;
}

export async function listOutreachTargets(filters: ListOutreachFilters = {}): Promise<OutreachTarget[]> {
  const supabase = await createClient();
  let query = supabase
    .from("outreach_targets")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(filters.limit ?? 1000);

  if (filters.area) query = query.eq("area", filters.area);
  if (filters.category) query = query.eq("category", filters.category);
  if (filters.status) query = query.eq("status", filters.status);
  if (filters.search) query = query.ilike("name", `%${filters.search}%`);

  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []).map((r) => rowToTarget(r as RowOutreachTarget));
}

export async function getOutreachTargetById(id: string): Promise<OutreachTarget | null> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("outreach_targets")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  if (error) throw error;
  return data ? rowToTarget(data as RowOutreachTarget) : null;
}

export interface UpsertOutreachInput {
  placeId: string;
  name: string;
  category: OutreachCategory;
  area: string;
  address?: string | null;
  phone?: string | null;
  website?: string | null;
  email?: string | null;
  lat?: number | null;
  lng?: number | null;
  rating?: number | null;
  userRatingsTotal?: number | null;
  rawPlacesJson?: unknown;
}

export type UpsertOutcome = "inserted" | "updated" | "skipped";

/**
 * Idempotent upsert på place_id.
 *
 * Ved re-kjøring av Google-import:
 *  - Aldri overskrevet: status, notes, email, follow_up_at, last_contacted_at, last_contacted_by
 *  - Bare fylt hvis tomt i eksisterende rad: phone, website, address (preserver manuelle redigeringer)
 *  - Alltid oppdatert fra Google: name, category, lat, lng, rating, user_ratings_total
 */
export async function upsertOutreachTarget(input: UpsertOutreachInput): Promise<{ outcome: UpsertOutcome; target: OutreachTarget | null }> {
  const supabase = await createClient();

  const { data: existing } = await supabase
    .from("outreach_targets")
    .select("id, address, phone, website")
    .eq("place_id", input.placeId)
    .maybeSingle();

  if (existing) {
    // Category beholdes som den ble satt ved første innsetting. Et sted som dukker opp
    // både i "rorbu Lofoten" og senere i "overnatting Lofoten"-søket skal beholde "rorbu".
    const updatePayload: Record<string, unknown> = {
      name: input.name,
      area: input.area,
      lat: input.lat ?? null,
      lng: input.lng ?? null,
      rating: input.rating ?? null,
      user_ratings_total: input.userRatingsTotal ?? null,
      raw_places_json: input.rawPlacesJson ?? null,
    };
    // Bare fyll inn fra Google hvis feltet er tomt i eksisterende rad.
    if (!existing.address && input.address) updatePayload.address = input.address;
    if (!existing.phone && input.phone) updatePayload.phone = input.phone;
    if (!existing.website && input.website) updatePayload.website = input.website;

    const { data, error } = await supabase
      .from("outreach_targets")
      .update(updatePayload)
      .eq("id", existing.id)
      .select("*")
      .single();
    if (error) throw error;
    return { outcome: "updated", target: rowToTarget(data as RowOutreachTarget) };
  }

  const insertPayload = {
    place_id: input.placeId,
    name: input.name,
    category: input.category,
    area: input.area,
    address: input.address ?? null,
    phone: input.phone ?? null,
    website: input.website ?? null,
    email: input.email ?? null,
    lat: input.lat ?? null,
    lng: input.lng ?? null,
    rating: input.rating ?? null,
    user_ratings_total: input.userRatingsTotal ?? null,
    raw_places_json: input.rawPlacesJson ?? null,
  };

  const { data, error } = await supabase
    .from("outreach_targets")
    .insert(insertPayload)
    .select("*")
    .single();
  if (error) throw error;
  return { outcome: "inserted", target: rowToTarget(data as RowOutreachTarget) };
}

export interface UpdateOutreachPatch {
  status?: OutreachStatus;
  notes?: string | null;
  email?: string | null;
  phone?: string | null;
  contactPerson?: string | null;
  followUpAt?: string | null;
  lastContactedAt?: string | null;
  lastContactedBy?: string | null;
}

export async function updateOutreachTarget(id: string, patch: UpdateOutreachPatch): Promise<OutreachTarget> {
  const supabase = await createClient();
  const dbPatch: Record<string, unknown> = {};
  if (patch.status !== undefined) dbPatch.status = patch.status;
  if (patch.notes !== undefined) dbPatch.notes = patch.notes;
  if (patch.email !== undefined) dbPatch.email = patch.email;
  if (patch.phone !== undefined) dbPatch.phone = patch.phone;
  if (patch.contactPerson !== undefined) dbPatch.contact_person = patch.contactPerson;
  if (patch.followUpAt !== undefined) dbPatch.follow_up_at = patch.followUpAt;
  if (patch.lastContactedAt !== undefined) dbPatch.last_contacted_at = patch.lastContactedAt;
  if (patch.lastContactedBy !== undefined) dbPatch.last_contacted_by = patch.lastContactedBy;

  const { data, error } = await supabase
    .from("outreach_targets")
    .update(dbPatch)
    .eq("id", id)
    .select("*")
    .single();
  if (error) throw error;
  return rowToTarget(data as RowOutreachTarget);
}

export interface AppendContactLogInput {
  targetId: string;
  contactType: OutreachContactType;
  recipient?: string | null;
  subject?: string | null;
  body?: string | null;
  statusAfter?: string | null;
}

export async function appendContactLog(input: AppendContactLogInput): Promise<OutreachContactLogEntry> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const { data, error } = await supabase
    .from("outreach_contact_log")
    .insert({
      target_id: input.targetId,
      contacted_by: user?.id ?? null,
      contact_type: input.contactType,
      recipient: input.recipient ?? null,
      subject: input.subject ?? null,
      body: input.body ?? null,
      status_after: input.statusAfter ?? null,
    })
    .select("*")
    .single();
  if (error) throw error;
  return {
    id: data.id,
    targetId: data.target_id,
    contactedBy: data.contacted_by,
    contactedByName: null,
    contactType: data.contact_type,
    recipient: data.recipient,
    subject: data.subject,
    body: data.body,
    statusAfter: data.status_after,
    createdAt: data.created_at,
  };
}

export async function listContactLogForTarget(targetId: string): Promise<OutreachContactLogEntry[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("outreach_contact_log")
    .select("id, target_id, contacted_by, contact_type, recipient, subject, body, status_after, created_at, profiles:contacted_by ( full_name )")
    .eq("target_id", targetId)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return (data ?? []).map((r) => {
    const row = r as unknown as {
      id: string;
      target_id: string;
      contacted_by: string | null;
      contact_type: OutreachContactType;
      recipient: string | null;
      subject: string | null;
      body: string | null;
      status_after: string | null;
      created_at: string;
      profiles?: { full_name: string | null } | { full_name: string | null }[] | null;
    };
    const profileRow = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
    return {
      id: row.id,
      targetId: row.target_id,
      contactedBy: row.contacted_by,
      contactedByName: profileRow?.full_name ?? null,
      contactType: row.contact_type,
      recipient: row.recipient,
      subject: row.subject,
      body: row.body,
      statusAfter: row.status_after,
      createdAt: row.created_at,
    };
  });
}

function rowToTemplate(row: Record<string, unknown>): OutreachEmailTemplate {
  return {
    id: row.id as string,
    name: row.name as string,
    subject: row.subject as string,
    body: row.body as string,
    isDefault: row.is_default as boolean,
    createdBy: (row.created_by as string | null) ?? null,
    createdAt: row.created_at as string,
    updatedAt: row.updated_at as string,
  };
}

export async function listEmailTemplates(): Promise<OutreachEmailTemplate[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("outreach_email_templates")
    .select("*")
    .order("is_default", { ascending: false })
    .order("name");
  if (error) throw error;
  return (data ?? []).map(rowToTemplate);
}

export async function getDefaultTemplate(): Promise<OutreachEmailTemplate | null> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("outreach_email_templates")
    .select("*")
    .eq("is_default", true)
    .maybeSingle();
  if (error) throw error;
  return data ? rowToTemplate(data) : null;
}

export interface SaveTemplateInput {
  id?: string;
  name: string;
  subject: string;
  body: string;
  isDefault?: boolean;
}

export async function saveEmailTemplate(input: SaveTemplateInput): Promise<OutreachEmailTemplate> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  // Hvis denne settes default — fjern default fra de andre først.
  if (input.isDefault) {
    await supabase.from("outreach_email_templates").update({ is_default: false }).eq("is_default", true);
  }

  if (input.id) {
    const { data, error } = await supabase
      .from("outreach_email_templates")
      .update({
        name: input.name,
        subject: input.subject,
        body: input.body,
        is_default: input.isDefault ?? false,
      })
      .eq("id", input.id)
      .select("*")
      .single();
    if (error) throw error;
    return rowToTemplate(data);
  }

  const { data, error } = await supabase
    .from("outreach_email_templates")
    .insert({
      name: input.name,
      subject: input.subject,
      body: input.body,
      is_default: input.isDefault ?? false,
      created_by: user?.id ?? null,
    })
    .select("*")
    .single();
  if (error) throw error;
  return rowToTemplate(data);
}

export async function deleteEmailTemplate(id: string): Promise<void> {
  const supabase = await createClient();
  const { error } = await supabase.from("outreach_email_templates").delete().eq("id", id);
  if (error) throw error;
}

/**
 * Substituer variabler i mailmal. Støttede placeholders: {name}, {tuno_link}, {app_store_link}.
 */
export function applyTemplateVariables(text: string, vars: { name?: string; contactPerson?: string; tunoLink?: string; appStoreLink?: string }): string {
  return text
    .replaceAll("{name}", vars.name ?? "")
    .replaceAll("{contact_person}", vars.contactPerson ?? "")
    .replaceAll("{tuno_link}", vars.tunoLink ?? "https://tuno.no/utleier")
    .replaceAll("{app_store_link}", vars.appStoreLink ?? "https://apps.apple.com/no/app/tuno-motorhome-and-parking/id6761529990");
}
