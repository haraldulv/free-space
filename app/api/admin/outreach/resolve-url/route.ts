import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

const FIELD_MASK = [
  "id",
  "displayName",
  "formattedAddress",
  "location",
  "rating",
  "userRatingCount",
  "nationalPhoneNumber",
  "internationalPhoneNumber",
  "websiteUri",
].join(",");

async function isAdmin(): Promise<boolean> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return false;
  const { data } = await supabase
    .from("profiles")
    .select("is_admin")
    .eq("id", user.id)
    .single();
  return data?.is_admin === true;
}

function getApiKey(): string {
  return process.env.GOOGLE_PLACES_API_KEY || process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY || "";
}

async function resolveFullUrl(url: string): Promise<string> {
  if (/maps\.app\.goo\.gl|goo\.gl\/maps/i.test(url)) {
    const res = await fetch(url, { redirect: "follow" });
    return res.url;
  }
  return url;
}

function extractPlaceId(url: string): string | null {
  try {
    const u = new URL(url);
    const qpid = u.searchParams.get("query_place_id");
    if (qpid) return qpid;
    const ftid = u.searchParams.get("ftid");
    if (ftid) return ftid;
  } catch { /* ignore */ }
  return null;
}

function extractPlaceName(url: string): string | null {
  const m = url.match(/\/place\/([^/@]+)/);
  if (m) return decodeURIComponent(m[1].replaceAll("+", " "));
  try {
    const u = new URL(url);
    const q = u.searchParams.get("q") || u.searchParams.get("query");
    if (q && !/^[\d.,-]+$/.test(q)) return q;
  } catch { /* ignore */ }
  return null;
}

function extractCoords(url: string): { lat: number; lng: number } | null {
  const m = url.match(/@(-?\d+\.\d+),(-?\d+\.\d+)/);
  if (m) return { lat: parseFloat(m[1]), lng: parseFloat(m[2]) };
  try {
    const u = new URL(url);
    const q = u.searchParams.get("q");
    if (q) {
      const cm = q.match(/^(-?\d+\.\d+),(-?\d+\.\d+)$/);
      if (cm) return { lat: parseFloat(cm[1]), lng: parseFloat(cm[2]) };
    }
  } catch { /* ignore */ }
  return null;
}

async function fetchPlaceDetails(placeId: string, apiKey: string) {
  const res = await fetch(
    `https://places.googleapis.com/v1/places/${placeId}?languageCode=no`,
    {
      headers: {
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask": FIELD_MASK,
      },
    },
  );
  if (!res.ok) return null;
  return res.json();
}

async function searchPlace(query: string, apiKey: string, coords?: { lat: number; lng: number } | null) {
  const body: Record<string, unknown> = {
    textQuery: query,
    languageCode: "no",
    maxResultCount: 1,
  };
  if (coords) {
    body.locationBias = {
      circle: { center: { latitude: coords.lat, longitude: coords.lng }, radius: 5000 },
    };
  }
  const res = await fetch("https://places.googleapis.com/v1/places:searchText", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": apiKey,
      "X-Goog-FieldMask": `places.${FIELD_MASK.replaceAll(",", ",places.")}`,
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) return null;
  const data = await res.json();
  return data.places?.[0] ?? null;
}

function placeToResult(place: Record<string, unknown>) {
  const loc = place.location as Record<string, number> | undefined;
  const dn = place.displayName as Record<string, string> | undefined;
  return {
    placeId: (place.id as string) || null,
    name: dn?.text || null,
    address: (place.formattedAddress as string) || null,
    phone: (place.nationalPhoneNumber as string) || (place.internationalPhoneNumber as string) || null,
    website: (place.websiteUri as string) || null,
    lat: loc?.latitude ?? null,
    lng: loc?.longitude ?? null,
    rating: (place.rating as number) ?? null,
    userRatingsTotal: (place.userRatingCount as number) ?? null,
  };
}

export async function POST(request: NextRequest) {
  if (!(await isAdmin())) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { url } = (await request.json()) as { url?: string };
  if (!url || typeof url !== "string") {
    return NextResponse.json({ error: "Mangler URL" }, { status: 400 });
  }

  const apiKey = getApiKey();
  if (!apiKey) {
    return NextResponse.json({ error: "Mangler GOOGLE_PLACES_API_KEY" }, { status: 500 });
  }

  try {
    const fullUrl = await resolveFullUrl(url.trim());
    const placeId = extractPlaceId(fullUrl);

    if (placeId) {
      const place = await fetchPlaceDetails(placeId, apiKey);
      if (place) return NextResponse.json(placeToResult(place));
    }

    const name = extractPlaceName(fullUrl);
    const coords = extractCoords(fullUrl);

    if (name) {
      const place = await searchPlace(name, apiKey, coords);
      if (place) return NextResponse.json(placeToResult(place));
    }

    if (coords) {
      const place = await searchPlace(`${coords.lat},${coords.lng}`, apiKey, coords);
      if (place) return NextResponse.json(placeToResult(place));
    }

    return NextResponse.json({ error: "Kunne ikke finne sted fra denne lenken. Prøv å legge til manuelt." }, { status: 404 });
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Ukjent feil";
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
