import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { z } from "zod";
import { createClient } from "@supabase/supabase-js";
import { ADMIN_EMAILS, AUTO_APPROVE_LISTINGS, SITE_URL } from "@/lib/config";
import {
  sendListingApprovedToHost,
  sendListingModerationAdminEmail,
  sendListingRejectedToHost,
} from "@/lib/email";
import { sendPushToAllAdmins, sendPushToUser } from "@/lib/push";

/**
 * AI-moderering av annonser og enkeltbilder.
 *
 * Kjøres server-side (aldri i klient) og er den ENESTE veien en annonse
 * går fra `moderation_status='pending'` til `'approved'` uten admin.
 * Databasen (RLS + trigger) sørger for at pending/flagged annonser aldri
 * vises offentlig, så en klient som hopper over dette laget får bare en
 * usynlig annonse — ikke en publisert en.
 */

// Haiku 4.5: 10x billigere enn Opus og mer enn godt nok til «plass eller dokument?».
// Bytt til "claude-opus-5" hvis vurderingene blir for grove.
const MODEL = "claude-haiku-4-5";

const ImageVerdict = z.object({
  index: z.number().int(),
  category: z.enum([
    "ok",
    "identity_document",
    "screenshot_or_text",
    "person_focused",
    "explicit_or_violent",
    "irrelevant",
    "unclear",
  ]),
  note: z.string(),
});

const ListingVerdict = z.object({
  /** approve = alt ser legitimt ut. flag = admin må se på det. */
  verdict: z.enum(["approve", "flag"]),
  confidence: z.enum(["low", "medium", "high"]),
  reasons: z.array(z.string()),
  images: z.array(ImageVerdict),
  text_quality: z.enum(["ok", "gibberish", "spam_or_offensive", "unclear"]),
});

export type ListingModerationResult = z.infer<typeof ListingVerdict>;

const SYSTEM_PROMPT = `Du er innholdsmoderator for Tuno, en norsk markedsplass der private og bedrifter leier ut parkeringsplasser og bobil-/campingplasser. Du vurderer om en ny annonse er en ekte, legitim annonse for en plass, eller om den bør stoppes for manuell gjennomgang.

Flagg annonsen ("flag") hvis noe av dette gjelder:
- Et bilde viser et identitetsdokument, pass, førerkort, bankkort, eller annet dokument med personopplysninger (uansett om det ser ekte eller falskt ut).
- Et bilde er et skjermbilde, en mal, et stock-bilde av en person, eller tydelig ikke tatt på stedet som leies ut.
- Et bilde fokuserer på en person/ansikt i stedet for plassen.
- Et bilde inneholder seksuelt, voldelig eller hatefullt innhold.
- Tittel eller beskrivelse er tullerier/tastaturmos (f.eks. "GFDSG SGDFSFGS"), spam, reklame for noe annet, eller støtende.
- Bildene har åpenbart ingenting med parkering, gårdsplass, tomt, camping, bobil eller uteområde å gjøre.

Godkjenn ("approve") når bildene viser en plausibel plass (innkjørsel, gårdsplass, parkering, gressplen, tomt, garasje, campingplass, utsikt fra plassen o.l.) og teksten er forståelig. Amatørbilder, dårlig lys og korte beskrivelser er helt normalt og skal IKKE flagges. Vær streng på dokumenter og personopplysninger, raus på bildekvalitet.

Svar kort og konkret på norsk i note/reasons.`;

function getClient(): Anthropic | null {
  if (!process.env.ANTHROPIC_API_KEY) return null;
  return new Anthropic();
}

function serviceClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );
}

interface ListingRow {
  id: string;
  host_id: string | null;
  title: string;
  description: string | null;
  category: string;
  city: string | null;
  address: string | null;
  images: string[] | null;
  moderation_status: string;
  host_stripe_ready: boolean;
}

async function runClaudeOnListing(listing: ListingRow): Promise<ListingModerationResult | null> {
  const client = getClient();
  if (!client) {
    console.warn("[Moderation] ANTHROPIC_API_KEY mangler; annonse blir liggende som pending");
    return null;
  }

  const images = (listing.images ?? []).slice(0, 10);
  const content: Anthropic.ContentBlockParam[] = [];
  images.forEach((url, i) => {
    content.push({ type: "text", text: `Bilde ${i + 1}:` });
    content.push({ type: "image", source: { type: "url", url } });
  });
  content.push({
    type: "text",
    text: [
      `Kategori: ${listing.category}`,
      `Tittel: ${listing.title}`,
      `Sted: ${[listing.address, listing.city].filter(Boolean).join(", ")}`,
      `Beskrivelse: ${listing.description ?? ""}`,
      "",
      `Antall bilder: ${images.length}. Vurder annonsen.`,
    ].join("\n"),
  });

  const response = await client.messages.parse({
    model: MODEL,
    max_tokens: 4000,
    output_config: { format: zodOutputFormat(ListingVerdict) }, // effort støttes ikke på Haiku 4.5
    system: SYSTEM_PROMPT,
    messages: [{ role: "user", content }],
  });

  if (response.stop_reason === "refusal") {
    return {
      verdict: "flag",
      confidence: "low",
      reasons: ["Modellen avviste å vurdere innholdet. Sjekk manuelt."],
      images: [],
      text_quality: "unclear",
    };
  }
  return response.parsed_output ?? null;
}

/**
 * Kjør full moderering på én annonse. Idempotent: hopper over hvis den
 * ikke lenger er pending. Returnerer resultatet (eller null hvis hoppet
 * over / API utilgjengelig).
 */
export async function moderateListing(listingId: string): Promise<ListingModerationResult | null> {
  const supabase = serviceClient();
  const { data: listing, error } = await supabase
    .from("listings")
    .select("id, host_id, title, description, category, city, address, images, moderation_status, host_stripe_ready")
    .eq("id", listingId)
    .maybeSingle<ListingRow>();

  if (error || !listing) {
    console.error("[Moderation] listing not found", listingId, error?.message);
    return null;
  }
  if (listing.moderation_status !== "pending") {
    return null;
  }

  let result: ListingModerationResult | null = null;
  try {
    result = await runClaudeOnListing(listing);
  } catch (err) {
    console.error("[Moderation] Claude error:", err);
  }

  if (!result) {
    // Ingen dom. Annonsen forblir pending (usynlig). Varsle admin så den
    // ikke blir liggende, men ikke spam ved hver sweep: kun første gang.
    await supabase
      .from("listings")
      .update({ moderation_ai: { error: "no_result", at: new Date().toISOString() } })
      .eq("id", listingId)
      .is("moderation_ai", null);
    return null;
  }

  const approve = AUTO_APPROVE_LISTINGS && result.verdict === "approve";
  const newStatus = approve ? "approved" : "flagged";
  const reason = approve ? null : result.reasons.join(" · ");

  await supabase
    .from("listings")
    .update({
      moderation_status: newStatus,
      moderation_reason: reason,
      moderation_ai: { ...result, model: MODEL, at: new Date().toISOString() },
      moderated_at: new Date().toISOString(),
      moderated_by: null,
    })
    .eq("id", listingId)
    .eq("moderation_status", "pending");

  await notifyAfterModeration(listing, newStatus, result);
  return result;
}

async function notifyAfterModeration(
  listing: ListingRow,
  status: "approved" | "flagged",
  result: ListingModerationResult,
) {
  const supabase = serviceClient();
  const adminUrl = `${SITE_URL}/admin/moderering?listing=${listing.id}`;

  let hostName = "Ukjent";
  let hostEmail: string | null = null;
  if (listing.host_id) {
    const [{ data: profile }, { data: authUser }] = await Promise.all([
      supabase.from("profiles").select("full_name").eq("id", listing.host_id).maybeSingle(),
      supabase.auth.admin.getUserById(listing.host_id),
    ]);
    hostName = profile?.full_name ?? hostName;
    hostEmail = authUser?.user?.email ?? null;
  }

  // Admin: e-post + push + in-app notification
  const adminTitle = status === "flagged"
    ? `⚠️ Annonse flagget: ${listing.title}`
    : `Ny annonse godkjent: ${listing.title}`;
  const adminBody = status === "flagged"
    ? result.reasons.join(" · ")
    : `${hostName} · ${listing.city ?? ""} · ${(listing.images ?? []).length} bilder${listing.host_stripe_ready ? "" : " · Stripe ikke verifisert (skjult inntil da)"}`;

  await Promise.all([
    sendListingModerationAdminEmail(ADMIN_EMAILS, {
      status,
      listingId: listing.id,
      listingTitle: listing.title,
      hostName,
      hostEmail,
      city: listing.city,
      images: listing.images ?? [],
      result,
      adminUrl,
      stripeReady: listing.host_stripe_ready,
    }).catch((err) => console.error("[Moderation] admin email failed:", err)),
    sendPushToAllAdmins(adminTitle, adminBody, { type: "admin_moderation", listingId: listing.id }),
    insertAdminNotifications(adminTitle, adminBody, listing.id),
  ]);

  // Host: kun ved godkjenning (avslag sendes av admin manuelt med begrunnelse)
  if (status === "approved" && listing.host_id) {
    const hostTitle = "Annonsen din er godkjent 🎉";
    const hostBody = listing.host_stripe_ready
      ? `«${listing.title}» er nå synlig for leietakere.`
      : `«${listing.title}» blir synlig så snart Stripe har verifisert utleierkontoen din.`;
    await Promise.all([
      supabase.from("notifications").insert({
        user_id: listing.host_id,
        type: "listing_approved",
        title: hostTitle,
        body: hostBody,
        metadata: { listingId: listing.id },
      }),
      sendPushToUser(listing.host_id, hostTitle, hostBody, { type: "listing_approved", listingId: listing.id }),
      hostEmail
        ? sendListingApprovedToHost(hostEmail, { hostName, listingTitle: listing.title, listingId: listing.id, stripeReady: listing.host_stripe_ready })
            .catch((err) => console.error("[Moderation] host email failed:", err))
        : Promise.resolve(),
    ]);
  }
}

async function insertAdminNotifications(title: string, body: string, listingId: string) {
  const supabase = serviceClient();
  const { data: admins } = await supabase.from("profiles").select("id").eq("is_admin", true);
  if (!admins?.length) return;
  await supabase.from("notifications").insert(
    admins.map((a) => ({
      user_id: a.id,
      type: "admin_moderation",
      title,
      body,
      metadata: { listingId },
    })),
  );
}

/**
 * Admin-handling: godkjenn/avvis. Kalles fra admin server actions med
 * service-klient. Sender varsel til host.
 */
export async function setListingModeration(
  listingId: string,
  status: "approved" | "rejected",
  adminId: string,
  reason?: string,
) {
  const supabase = serviceClient();
  const { data: listing } = await supabase
    .from("listings")
    .select("id, host_id, title, host_stripe_ready")
    .eq("id", listingId)
    .maybeSingle<Pick<ListingRow, "id" | "host_id" | "title" | "host_stripe_ready">>();
  if (!listing) throw new Error("Annonse ikke funnet");

  const { error } = await supabase
    .from("listings")
    .update({
      moderation_status: status,
      moderation_reason: reason?.trim() || null,
      moderated_at: new Date().toISOString(),
      moderated_by: adminId,
    })
    .eq("id", listingId);
  if (error) throw new Error(error.message);

  if (!listing.host_id) return;

  let hostName = "der";
  let hostEmail: string | null = null;
  const [{ data: profile }, { data: authUser }] = await Promise.all([
    supabase.from("profiles").select("full_name").eq("id", listing.host_id).maybeSingle(),
    supabase.auth.admin.getUserById(listing.host_id),
  ]);
  hostName = profile?.full_name ?? hostName;
  hostEmail = authUser?.user?.email ?? null;

  if (status === "approved") {
    const title = "Annonsen din er godkjent 🎉";
    const body = listing.host_stripe_ready
      ? `«${listing.title}» er nå synlig for leietakere.`
      : `«${listing.title}» blir synlig så snart Stripe har verifisert utleierkontoen din.`;
    await Promise.all([
      supabase.from("notifications").insert({ user_id: listing.host_id, type: "listing_approved", title, body, metadata: { listingId } }),
      sendPushToUser(listing.host_id, title, body, { type: "listing_approved", listingId }),
      hostEmail ? sendListingApprovedToHost(hostEmail, { hostName, listingTitle: listing.title, listingId, stripeReady: listing.host_stripe_ready }).catch(() => {}) : Promise.resolve(),
    ]);
  } else {
    const title = "Annonsen din ble ikke godkjent";
    const body = reason?.trim()
      ? `«${listing.title}»: ${reason.trim()}`
      : `«${listing.title}» oppfyller ikke retningslinjene våre. Ta kontakt med support@tuno.no om du mener dette er feil.`;
    await Promise.all([
      supabase.from("notifications").insert({ user_id: listing.host_id, type: "listing_rejected", title, body, metadata: { listingId } }),
      sendPushToUser(listing.host_id, title, body, { type: "listing_rejected", listingId }),
      hostEmail ? sendListingRejectedToHost(hostEmail, { hostName, listingTitle: listing.title, reason: reason?.trim() || null }).catch(() => {}) : Promise.resolve(),
    ]);
  }
}

// ---------------------------------------------------------------------
// Enkeltbilde (brukes av /api/moderate-image ved opplasting)
// ---------------------------------------------------------------------

const SingleImageVerdict = z.object({
  category: z.enum([
    "ok",
    "identity_document",
    "screenshot_or_text",
    "person_focused",
    "explicit_or_violent",
    "irrelevant",
    "unclear",
  ]),
  note: z.string(),
});

const IMAGE_BLOCK_MESSAGES: Record<string, string> = {
  identity_document: "Bildet ser ut som et ID-dokument eller kort med personopplysninger. Last opp bilder av plassen i stedet.",
  screenshot_or_text: "Bildet ser ut som et skjermbilde eller en mal. Last opp ekte bilder av plassen.",
  person_focused: "Bildet fokuserer på en person. Last opp bilder av selve plassen.",
  explicit_or_violent: "Bildet inneholder upassende innhold. Tuno har nulltoleranse for støtende innhold.",
  irrelevant: "Bildet ser ikke ut til å vise en parkerings- eller campingplass.",
};

export async function moderateImageWithClaude(
  imageUrl: string,
): Promise<{ approved: boolean; reason?: string; category?: string }> {
  const client = getClient();
  if (!client) return { approved: true };

  try {
    const response = await client.messages.parse({
      model: MODEL,
      max_tokens: 1000,
      output_config: { format: zodOutputFormat(SingleImageVerdict) },
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: [
            { type: "image", source: { type: "url", url: imageUrl } },
            { type: "text", text: "Klassifiser dette ene bildet som annonsebilde for en parkerings-/campingplass." },
          ],
        },
      ],
    });
    if (response.stop_reason === "refusal") {
      return { approved: false, reason: IMAGE_BLOCK_MESSAGES.explicit_or_violent, category: "refusal" };
    }
    const out = response.parsed_output;
    if (!out) return { approved: true };
    if (out.category === "ok" || out.category === "unclear") {
      return { approved: true, category: out.category };
    }
    return { approved: false, reason: IMAGE_BLOCK_MESSAGES[out.category], category: out.category };
  } catch (err) {
    console.error("[Moderation] single image error:", err);
    // Opplastingssjekken er kun rask tilbakemelding; annonsesjekken er porten.
    return { approved: true };
  }
}
