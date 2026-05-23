"use server";

import { createClient } from "@/lib/supabase/server";
import {
  listOutreachTargets,
  getOutreachTargetById,
  updateOutreachTarget,
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
