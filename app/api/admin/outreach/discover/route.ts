import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { upsertOutreachTarget } from "@/lib/supabase/outreach";
import type { OutreachCategory } from "@/types";
import type { UpsertOutreachInput, UpsertOutcome } from "@/lib/supabase/outreach";

// Discover kan ta 2-3 min på første kjøring (~14 queries × 4 sentre × opptil 3 sider).
export const maxDuration = 300;

/**
 * POST /api/admin/outreach/discover
 *
 * Body: { area?: "Lofoten", categories?: OutreachCategory[] }
 *
 * Kjører Google Places API (New) Text Search per kategori, henter Place Details
 * for telefon/web, og upserter til outreach_targets.
 *
 * Auth: enten innlogget admin (UI) eller `Authorization: Bearer <CRON_SECRET>` (CLI/test).
 */

interface PlaceSearchResult {
  id: string;
  displayName?: { text?: string };
  formattedAddress?: string;
  location?: { latitude?: number; longitude?: number };
  rating?: number;
  userRatingCount?: number;
  nationalPhoneNumber?: string;
  internationalPhoneNumber?: string;
  websiteUri?: string;
  types?: string[];
}

interface PlaceSearchResponse {
  places?: PlaceSearchResult[];
  nextPageToken?: string;
}

const SEARCH_FIELD_MASK = [
  "places.id",
  "places.displayName",
  "places.formattedAddress",
  "places.location",
  "places.rating",
  "places.userRatingCount",
  "places.nationalPhoneNumber",
  "places.internationalPhoneNumber",
  "places.websiteUri",
  "places.types",
  "nextPageToken",
].join(",");

// Search-queries per kategori. Vi søker hver query fra alle sentre under for å unngå
// Google sitt 60-treff-tak per (query, locationBias)-kombinasjon.
const CATEGORY_QUERIES: Record<OutreachCategory, string[]> = {
  rorbu: ["rorbuer Lofoten", "rorbu utleie Lofoten", "sjøhus Lofoten"],
  hotell: ["hotell Lofoten", "boutique hotel Lofoten"],
  restaurant: ["restaurant Lofoten", "spisested Lofoten"],
  camping: ["camping Lofoten", "bobilplass Lofoten", "campingplass Lofoten"],
  overnatting: [
    "overnatting Lofoten",
    "hytter Lofoten",
    "hytteutleie Lofoten",
    "feriebolig Lofoten",
    "Airbnb Lofoten",
    "vandrerhjem Lofoten",
    "B&B Lofoten",
    "gjestehus Lofoten",
  ],
  // Gård er en import/manuell-kategori; ingen auto-discovery via Google.
  gård: [],
  other: [],
};

// Flere sentre for å dekke hele Lofoten-arkipelet. Google Places Text Search krever
// radius <= 50000m (50km). Vi multiplexer queries på tvers av disse 4 senterne så
// flere unike treff fra hver del av arkipelet kommer med.
const AREA_CENTERS: Record<string, Array<{ lat: number; lng: number; radiusMeters: number; label: string }>> = {
  lofoten: [
    { lat: 68.23, lng: 14.56, radiusMeters: 30000, label: "svolvær" },   // Øst-Lofoten
    { lat: 68.15, lng: 13.61, radiusMeters: 30000, label: "leknes" },    // Sentral-Lofoten
    { lat: 67.93, lng: 13.10, radiusMeters: 30000, label: "reine" },     // Sør-Lofoten
    { lat: 67.66, lng: 12.69, radiusMeters: 30000, label: "værøy-røst" }, // Ytre Lofoten
  ],
};

async function isAuthorized(request: NextRequest): Promise<boolean> {
  // CRON_SECRET-fallback for CLI/test.
  const auth = request.headers.get("authorization");
  if (auth && process.env.CRON_SECRET && auth === `Bearer ${process.env.CRON_SECRET}`) {
    return true;
  }

  // Admin-session.
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return false;
  const { data: profile } = await supabase
    .from("profiles")
    .select("is_admin")
    .eq("id", user.id)
    .single();
  return profile?.is_admin === true;
}

async function searchTextPaged(
  apiKey: string,
  textQuery: string,
  locationBias: { lat: number; lng: number; radiusMeters: number },
  maxPages = 3,
): Promise<PlaceSearchResult[]> {
  const results: PlaceSearchResult[] = [];
  let pageToken: string | undefined;

  for (let page = 0; page < maxPages; page++) {
    const body: Record<string, unknown> = {
      textQuery,
      locationBias: {
        circle: {
          center: { latitude: locationBias.lat, longitude: locationBias.lng },
          radius: locationBias.radiusMeters,
        },
      },
      languageCode: "no",
      regionCode: "no",
    };
    if (pageToken) body.pageToken = pageToken;

    const res = await fetch("https://places.googleapis.com/v1/places:searchText", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask": SEARCH_FIELD_MASK,
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const errBody = await res.text();
      throw new Error(`Places searchText failed (${res.status}): ${errBody}`);
    }

    const json = (await res.json()) as PlaceSearchResponse;
    if (json.places) results.push(...json.places);
    if (!json.nextPageToken) break;
    pageToken = json.nextPageToken;
    // Places API krever liten delay før nextPageToken er aktivt.
    await new Promise((r) => setTimeout(r, 2000));
  }

  return results;
}

export async function POST(request: NextRequest) {
  if (!(await isAuthorized(request))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  // Foretrekk server-side key; fall tilbake til public Maps-key (allerede har Places API enabled
  // per CLAUDE.md) for å gjøre MVP-oppstart enkel. Anbefales å skille keyene senere.
  const apiKey = process.env.GOOGLE_PLACES_API_KEY ?? process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;
  if (!apiKey) {
    return NextResponse.json(
      { error: "Mangler GOOGLE_PLACES_API_KEY / NEXT_PUBLIC_GOOGLE_MAPS_API_KEY" },
      { status: 500 },
    );
  }

  const body = (await request.json().catch(() => ({}))) as {
    area?: string;
    categories?: OutreachCategory[];
  };
  const area = body.area ?? "lofoten";
  const centers = AREA_CENTERS[area];
  if (!centers || centers.length === 0) {
    return NextResponse.json({ error: `Ukjent area: ${area}` }, { status: 400 });
  }

  const categories: OutreachCategory[] = body.categories ?? [
    "rorbu",
    "hotell",
    "restaurant",
    "camping",
    "overnatting",
  ];

  const stats = { inserted: 0, updated: 0, skipped: 0, totalFetched: 0, errors: [] as string[] };
  const seenPlaceIds = new Set<string>();

  for (const category of categories) {
    const queries = CATEGORY_QUERIES[category] ?? [];
    for (const q of queries) {
      for (const center of centers) {
        try {
          const results = await searchTextPaged(apiKey, q, center);
          stats.totalFetched += results.length;

          for (const place of results) {
            if (!place.id) {
              stats.skipped++;
              continue;
            }
            if (seenPlaceIds.has(place.id)) {
              stats.skipped++;
              continue;
            }
            seenPlaceIds.add(place.id);

            const upsertInput: UpsertOutreachInput = {
              placeId: place.id,
              name: place.displayName?.text ?? "Ukjent",
              category,
              area,
              address: place.formattedAddress ?? null,
              phone: place.nationalPhoneNumber ?? place.internationalPhoneNumber ?? null,
              website: place.websiteUri ?? null,
              lat: place.location?.latitude ?? null,
              lng: place.location?.longitude ?? null,
              rating: place.rating ?? null,
              userRatingsTotal: place.userRatingCount ?? null,
              rawPlacesJson: place as unknown,
            };

            try {
              const { outcome } = await upsertOutreachTarget(upsertInput);
              stats[outcome as Exclude<UpsertOutcome, "skipped">]++;
            } catch (err) {
              stats.errors.push(
                `${place.displayName?.text ?? place.id}: ${err instanceof Error ? err.message : "ukjent"}`,
              );
            }
          }
        } catch (err) {
          stats.errors.push(`Query "${q}" (${center.label}): ${err instanceof Error ? err.message : "ukjent"}`);
        }
      }
    }
  }

  return NextResponse.json({ ok: true, area, categories, ...stats });
}
