/**
 * Importer for Hygglo + Finn parkering-annonser → Tuno staging.
 *
 * Kjøring:
 *   1. Sett miljø-variabler (skaffes fra Vercel staging-environment):
 *        export SUPABASE_STAGING_URL="https://qqtgmcxzyuquunsxoqog.supabase.co"
 *        export SUPABASE_STAGING_SERVICE_ROLE_KEY="<service_role_key>"
 *   2. Velg modus:
 *        npx tsx scripts/import_parking_2026_05.ts --dry-run    # ingen DB/storage-endringer
 *        npx tsx scripts/import_parking_2026_05.ts --reset      # DELETE listings + bookings + favorites først
 *        npx tsx scripts/import_parking_2026_05.ts              # kun upsert (ingen reset)
 *
 * Idempotens: bruker (source, source_id) som unik nøkkel for upsert.
 */

import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { readFileSync, existsSync } from "node:fs";
import { resolve, basename } from "node:path";
import { randomUUID } from "node:crypto";
import sharp from "sharp";

// MARK: - Konstanter

const HOST_EMAIL = "haraldsalvesen@gmail.com";
const HOST_FULL_NAME = "Harald Salvesen";
const DATA_DIR = resolve(__dirname, "../data/external_imports/parking_2026_05");
const JSON_PATH = resolve(DATA_DIR, "parking.json");
const IMAGES_DIR = resolve(DATA_DIR, "images");
const STORAGE_BUCKET = "listing-images";
const STORAGE_PREFIX = "system-imports/parking_2026_05";

// MARK: - Typer for scrapet JSON

type ScrapedSellerType = "private" | "professional" | "wanted";
type ScrapedPeriodType = "DAY" | "WEEK" | "MONTH" | "YEAR";
type ScrapedParkingType = "GARAGE" | "OUTDOOR" | "PARKING_HOUSE" | null;

interface ScrapedPricePackage {
  period_type: ScrapedPeriodType;
  period_value: number;
  price_nok: number;
  source: "PLATFORM_TIER" | "DESCRIPTION_TEXT";
}

interface ScrapedOpeningHours {
  days_of_week: number[]; // 1=mandag … 7=søndag
  time_start: string;
  time_end: string;
}

interface ScrapedAd {
  source: "hygglo" | "finn";
  source_id: string;
  url: string;
  title: string;
  description: string;
  address: string;
  zip: string | null;
  municipality: string | null;
  fylke: string | null;
  lat: number;
  lng: number;
  currency: "NOK";
  min_rental_days: number | null;
  price_packages: ScrapedPricePackage[];
  opening_hours?: ScrapedOpeningHours[];
  parking_type: ScrapedParkingType;
  features: {
    ev_charging: boolean;
    heated: boolean;
    indoor: boolean;
    outdoor: boolean;
    surveillance: boolean;
    covered: boolean;
    gated: boolean;
    max_height_cm: number | null;
    max_length_cm: number | null;
  };
  primary_image_url: string;
  primary_image_local: string;
  primary_image_is_default?: boolean;
  image_urls: string[];
  seller_type: ScrapedSellerType;
  org_name: string | null;
  lease_period: string | null;
  deposit_nok?: number | null;
  floor?: string | null;
  contact_name?: string | null;
  contact_email?: string | null;
}

// MARK: - Hjelpere

function env(name: string, optional: false): string;
function env(name: string, optional: true): string | undefined;
function env(name: string, optional: boolean): string | undefined {
  const v = process.env[name];
  if (!v && !optional) {
    console.error(`❌ Mangler env-variabel: ${name}`);
    process.exit(1);
  }
  return v;
}

function logSection(title: string) {
  console.log("\n" + "═".repeat(70));
  console.log("  " + title);
  console.log("═".repeat(70));
}

interface CliOptions {
  dryRun: boolean;
  reset: boolean;
}

function parseArgs(): CliOptions {
  const args = process.argv.slice(2);
  return {
    dryRun: args.includes("--dry-run"),
    reset: args.includes("--reset"),
  };
}

// MARK: - Bruker-håndtering

async function findOrCreateHostUser(supabase: SupabaseClient, opts: CliOptions): Promise<string> {
  logSection(`Bruker: ${HOST_EMAIL}`);

  if (opts.dryRun) {
    const fakeId = "00000000-0000-0000-0000-000000000000";
    console.log(`🟡 DRY-RUN: hopper over auth-kall, bruker placeholder ${fakeId}`);
    return fakeId;
  }

  // List opp og finn etter e-post (admin API kan ikke hente direkte etter e-post i alle versjoner)
  let page = 1;
  const perPage = 100;
  while (true) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage });
    if (error) throw new Error(`auth.admin.listUsers feilet: ${error.message}`);
    const found = data.users.find((u) => (u.email ?? "").toLowerCase() === HOST_EMAIL);
    if (found) {
      console.log(`✅ Fant eksisterende bruker: ${found.id}`);
      return found.id;
    }
    if (data.users.length < perPage) break;
    page += 1;
  }

  if (opts.dryRun) {
    const fakeId = "00000000-0000-0000-0000-000000000000";
    console.log(`🟡 DRY-RUN: ville opprettet bruker. Bruker placeholder ${fakeId}`);
    return fakeId;
  }

  console.log(`➕ Bruker finnes ikke — oppretter via auth.admin.createUser`);
  const { data: created, error: createErr } = await supabase.auth.admin.createUser({
    email: HOST_EMAIL,
    email_confirm: true,
    user_metadata: { full_name: HOST_FULL_NAME },
  });
  if (createErr || !created.user) {
    throw new Error(`auth.admin.createUser feilet: ${createErr?.message ?? "ukjent"}`);
  }
  console.log(`✅ Opprettet bruker: ${created.user.id}`);

  // DB-trigger handle_new_user oppretter normalt profil — men hvis ikke, sett den
  const { data: existing } = await supabase
    .from("profiles")
    .select("id")
    .eq("id", created.user.id)
    .maybeSingle();
  if (!existing) {
    const { error: profileErr } = await supabase.from("profiles").insert({
      id: created.user.id,
      full_name: HOST_FULL_NAME,
      avatar_url: "",
      joined_year: new Date().getFullYear(),
    });
    if (profileErr) throw new Error(`profiles.insert feilet: ${profileErr.message}`);
  }
  return created.user.id;
}

// MARK: - Bilde-upload

interface ImageUploadResult {
  publicUrl: string;
  storagePath: string;
}

async function uploadImage(
  supabase: SupabaseClient,
  ad: ScrapedAd,
  opts: CliOptions,
): Promise<ImageUploadResult | null> {
  const localFileName = basename(ad.primary_image_local);
  const localPath = resolve(IMAGES_DIR, localFileName);

  if (!existsSync(localPath)) {
    console.warn(`⚠️  Mangler bilde på disk: ${localFileName} (annonse ${ad.source}/${ad.source_id})`);
    return null;
  }

  const ext = localFileName.split(".").pop()?.toLowerCase() ?? "jpg";

  let buffer: Buffer = readFileSync(localPath);
  let uploadExt = ext;
  let contentType = "image/jpeg";

  if (ext === "svg") {
    // Rasteriser default SVG til 1200x800 PNG.
    buffer = await sharp(buffer)
      .resize(1200, 800, { fit: "cover", background: { r: 245, g: 245, b: 245 } })
      .png()
      .toBuffer();
    uploadExt = "png";
    contentType = "image/png";
  } else if (ext === "png") {
    contentType = "image/png";
  } else if (ext === "webp") {
    contentType = "image/webp";
  } else {
    contentType = "image/jpeg";
  }

  const storagePath = `${STORAGE_PREFIX}/${ad.source}__${ad.source_id}.${uploadExt}`;

  if (opts.dryRun) {
    return { publicUrl: `<dry-run>${storagePath}`, storagePath };
  }

  const { error: uploadErr } = await supabase.storage.from(STORAGE_BUCKET).upload(storagePath, buffer, {
    upsert: true,
    contentType,
  });
  if (uploadErr) {
    console.error(`❌ Upload feilet for ${storagePath}: ${uploadErr.message}`);
    return null;
  }
  const { data: pub } = supabase.storage.from(STORAGE_BUCKET).getPublicUrl(storagePath);
  return { publicUrl: pub.publicUrl, storagePath };
}

// MARK: - Mapping JSON → listing-rad

interface SpotMarkerRow {
  id: string;
  lat: number;
  lng: number;
  label: string;
  pricePackages: { periodType: ScrapedPeriodType; periodValue: number; priceNok: number }[];
}

interface ListingRow {
  id: string;
  host_id: string;
  title: string;
  description: string;
  category: "parking";
  vehicle_type: "car";
  city: string;
  region: string;
  address: string;
  lat: number;
  lng: number;
  price: number;
  price_unit: "time";
  amenities: string[];
  spots: number;
  images: string[];
  instant_booking: false;
  spot_markers: SpotMarkerRow[];
  hide_exact_location: false;
  is_active: true;
  blocked_dates: string[];
  check_in_time: string;
  check_out_time: string;
  extras: never[];
  opening_hours: Record<string, string | null> | null;
  min_stay_days: number | null;
  parking_type: ScrapedParkingType;
  rental_period_types: ScrapedPeriodType[];
  source: "hygglo" | "finn";
  source_id: string;
  host_name: string;
  host_avatar: string;
  host_response_rate: number;
  host_response_time: string;
  host_joined_year: number;
  host_listings_count: number;
  tags: string[];
}

const WEEKDAY_KEYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"] as const;

function buildOpeningHours(hours: ScrapedOpeningHours[] | undefined): Record<string, string | null> | null {
  if (!hours || hours.length === 0) return null;
  // Hvis det er flere bånd (f.eks. annenhver-uke 8-16/10-20), kan vi ikke representere det → returner null.
  // Sjekk at alle band-times er identiske før vi bygger en "alle dager"-record.
  // For 1 band: tagg dagene som er inkludert.
  const map: Record<string, string | null> = { mon: null, tue: null, wed: null, thu: null, fri: null, sat: null, sun: null };

  // Hvis det er ett band: bruk det.
  if (hours.length === 1) {
    const band = hours[0];
    const time = `${band.time_start}-${band.time_end}`;
    for (const d of band.days_of_week) {
      const key = WEEKDAY_KEYS[d - 1];
      if (key) map[key] = time;
    }
    return map;
  }

  // Flere band — sjekk om hver dag har én konsistent tid på tvers av band.
  // Hvis annenhver-uke (samme dag har to ulike tider), returner null (døgnåpen).
  const tempMap: Record<string, Set<string>> = {
    mon: new Set(), tue: new Set(), wed: new Set(), thu: new Set(),
    fri: new Set(), sat: new Set(), sun: new Set(),
  };
  for (const band of hours) {
    const time = `${band.time_start}-${band.time_end}`;
    for (const d of band.days_of_week) {
      const key = WEEKDAY_KEYS[d - 1];
      if (key) tempMap[key].add(time);
    }
  }
  // Hvis noen dag har > 1 unik tid → ambivalent (annenhver-uke), returner null.
  for (const k of WEEKDAY_KEYS) {
    if (tempMap[k].size > 1) return null;
  }
  for (const k of WEEKDAY_KEYS) {
    const t = Array.from(tempMap[k])[0];
    map[k] = t ?? null;
  }
  return map;
}

/** Strippe null-bytes ( ) som Postgres ikke aksepterer i text-kolonner. */
function sanitizeText(s: string | null | undefined): string {
  if (!s) return "";
  return s.replace(/ /g, "").trim();
}

function deriveCity(ad: ScrapedAd): string {
  return sanitizeText(ad.municipality ?? ad.fylke?.split(",")[0]?.trim() ?? "Norge");
}

function deriveRegion(ad: ScrapedAd): string {
  return sanitizeText(ad.fylke?.split(",").map((s) => s.trim()).pop() ?? "");
}

function buildListingRow(
  ad: ScrapedAd,
  hostId: string,
  imageUrl: string | null,
): ListingRow {
  const dailyPackages = ad.price_packages.filter((p) => p.period_type === "DAY" && p.period_value === 1);
  const lowestDay = dailyPackages.length > 0 ? Math.min(...dailyPackages.map((p) => p.price_nok)) : 0;

  const pricePackages = ad.price_packages.map((p) => ({
    periodType: p.period_type,
    periodValue: p.period_value,
    priceNok: p.price_nok,
  }));

  const periodTypes = Array.from(new Set(ad.price_packages.map((p) => p.period_type)));

  const amenities: string[] = [];
  if (ad.features.ev_charging) amenities.push("ev_charging");
  if (ad.features.surveillance) amenities.push("security_camera");
  if (ad.features.covered) amenities.push("covered");
  if (ad.features.gated) amenities.push("gated");

  const spotId = randomUUID();
  const spotMarker: SpotMarkerRow = {
    id: spotId,
    lat: ad.lat,
    lng: ad.lng,
    label: "Plass 1",
    pricePackages,
  };

  return {
    id: randomUUID(),
    host_id: hostId,
    title: sanitizeText(ad.title) || "Parkeringsplass",
    description: sanitizeText(ad.description),
    category: "parking",
    vehicle_type: "car",
    city: deriveCity(ad),
    region: deriveRegion(ad),
    address: sanitizeText(ad.address),
    lat: ad.lat,
    lng: ad.lng,
    price: lowestDay,
    price_unit: "time", // parkering = kr/dag (vises som "døgn"/"dag" i UI)
    amenities,
    spots: 1,
    images: imageUrl ? [imageUrl] : [],
    instant_booking: false, // alle import-annonser går som forespørsel
    spot_markers: [spotMarker],
    hide_exact_location: false,
    is_active: true,
    blocked_dates: [],
    check_in_time: "00:00",
    check_out_time: "23:59",
    extras: [],
    opening_hours: buildOpeningHours(ad.opening_hours),
    min_stay_days: ad.min_rental_days,
    parking_type: ad.parking_type,
    rental_period_types: periodTypes,
    source: ad.source,
    source_id: ad.source_id,
    host_name: HOST_FULL_NAME,
    host_avatar: "",
    host_response_rate: 0,
    host_response_time: "innen 1 time",
    host_joined_year: new Date().getFullYear(),
    host_listings_count: 0,
    tags: [],
  };
}

// MARK: - Main

async function deleteAllStagingData(supabase: SupabaseClient, opts: CliOptions) {
  logSection("RESET: sletter alle listings + relaterte rader");

  // For hver tabell: en kolonne som garantert har en ikke-null verdi (PK eller del av PK).
  const tables: { name: string; matchColumn: string }[] = [
    { name: "listing_pricing_overrides", matchColumn: "listing_id" },
    { name: "listing_pricing_rules", matchColumn: "id" },
    { name: "reviews", matchColumn: "id" },
    { name: "messages", matchColumn: "id" },
    { name: "conversations", matchColumn: "id" },
    { name: "favorites", matchColumn: "user_id" },
    { name: "bookings", matchColumn: "id" },
    { name: "listings", matchColumn: "id" },
  ];

  for (const { name, matchColumn } of tables) {
    if (opts.dryRun) {
      const { count } = await supabase.from(name).select("*", { count: "exact", head: true });
      console.log(`🟡 DRY-RUN: ville slettet ${count ?? "?"} rad(er) fra ${name}`);
      continue;
    }
    console.log(`Sletter alle rader i ${name}...`);
    const { error } = await supabase.from(name).delete().not(matchColumn, "is", null);
    if (error) {
      console.error(`❌ DELETE ${name} feilet: ${error.message}`);
      throw error;
    }
  }
  console.log("✅ Reset fullført");
}

async function main() {
  const opts = parseArgs();

  const url = env("SUPABASE_STAGING_URL", false);
  const key = env("SUPABASE_STAGING_SERVICE_ROLE_KEY", false);

  console.log(`🚀 Tuno parkering-importer (${opts.dryRun ? "DRY-RUN" : "LIVE"}${opts.reset ? " + RESET" : ""})`);
  console.log(`   URL: ${url}`);
  console.log(`   Datafil: ${JSON_PATH}`);
  console.log(`   Bilder: ${IMAGES_DIR}`);

  const supabase = createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // 1) Last og filtrer JSON
  const raw = readFileSync(JSON_PATH, "utf-8");
  const allAds: ScrapedAd[] = JSON.parse(raw);
  const wanted = allAds.filter((a) => a.seller_type === "wanted");
  const ads = allAds.filter((a) => a.seller_type !== "wanted");
  console.log(`📋 Lastet ${allAds.length} annonser (hopper over ${wanted.length} wanted → importerer ${ads.length})`);

  // 2) Bruker
  const hostId = await findOrCreateHostUser(supabase, opts);

  // 3) Reset (valgfritt, krever --reset)
  if (opts.reset) {
    await deleteAllStagingData(supabase, opts);
  }

  // 4) Last opp bilder (parallelt i batches)
  logSection(`Bilde-upload (${ads.length} bilder → bucket ${STORAGE_BUCKET}/${STORAGE_PREFIX})`);
  const imageMap = new Map<string, string>(); // (source/source_id) → public URL
  const BATCH = 8;
  for (let i = 0; i < ads.length; i += BATCH) {
    const batch = ads.slice(i, i + BATCH);
    const results = await Promise.all(batch.map((ad) => uploadImage(supabase, ad, opts)));
    for (let j = 0; j < batch.length; j++) {
      const result = results[j];
      if (result) imageMap.set(`${batch[j].source}/${batch[j].source_id}`, result.publicUrl);
    }
    if ((i + BATCH) % 80 === 0 || i + BATCH >= ads.length) {
      console.log(`   ${Math.min(i + BATCH, ads.length)} / ${ads.length} bilder lastet opp`);
    }
  }

  // 5) Bygg + upsert listing-rader
  logSection(`Listing-upsert (${ads.length} rader)`);
  const rows = ads.map((ad) => buildListingRow(ad, hostId, imageMap.get(`${ad.source}/${ad.source_id}`) ?? null));

  if (opts.dryRun) {
    console.log("🟡 DRY-RUN: ville upsertet følgende prøve (3 første):");
    console.log(JSON.stringify(rows.slice(0, 3), null, 2));
    return;
  }

  // Upsert i batches av 50 — Supabase tåler større, men 50 er trygt og gir god feilrapport
  const UPSERT_BATCH = 50;
  let processed = 0;
  for (let i = 0; i < rows.length; i += UPSERT_BATCH) {
    const chunk = rows.slice(i, i + UPSERT_BATCH);
    const { error } = await supabase
      .from("listings")
      .upsert(chunk, { onConflict: "source,source_id" });
    if (error) {
      console.error(`❌ Upsert feilet på batch ${i}-${i + chunk.length}: ${error.message}`);
      // Print første rad i batchen for debug
      console.error("   Første rad i batch:", JSON.stringify(chunk[0], null, 2));
      throw error;
    }
    processed += chunk.length;
    console.log(`   ${processed} / ${rows.length} listings upsertet`);
  }

  // 6) Sluttrapport
  logSection("Sluttrapport");
  const counts = {
    hygglo: ads.filter((a) => a.source === "hygglo").length,
    finn: ads.filter((a) => a.source === "finn").length,
    parking_type_garage: ads.filter((a) => a.parking_type === "GARAGE").length,
    parking_type_outdoor: ads.filter((a) => a.parking_type === "OUTDOOR").length,
    parking_type_house: ads.filter((a) => a.parking_type === "PARKING_HOUSE").length,
    parking_type_null: ads.filter((a) => a.parking_type == null).length,
    with_opening_hours: ads.filter((a) => (a.opening_hours ?? []).length > 0).length,
  };
  for (const [k, v] of Object.entries(counts)) console.log(`   ${k}: ${v}`);
  console.log(`✅ Ferdig. ${rows.length} annonser i staging.`);
}

main().catch((e) => {
  console.error("\n💥 IMPORTEREN KRÆSJET:", e);
  process.exit(1);
});
