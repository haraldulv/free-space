import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { moderateImageWithClaude } from "@/lib/moderation";

/**
 * Rask tilbakemelding ved bildeopplasting (web + iOS). To lag:
 *   1) Google SafeSearch (nakenhet/vold) hvis nøkkel finnes
 *   2) Claude vision (ID-dokumenter, skjermbilder, personfokus, irrelevant)
 *
 * NB: Dette er UX-laget. Porten som faktisk hindrer publisering er
 * annonse-modereringen i lib/moderation.ts + RLS (annonser er usynlige
 * til de er godkjent). Denne ruten kan derfor "fail open" ved API-feil.
 *
 * Krever innlogget bruker og at URL-en peker på vår egen storage-bucket,
 * så ruten ikke kan misbrukes som gratis bildeklassifisering.
 */

interface SafeSearchAnnotation {
  adult: string;
  spoof: string;
  medical: string;
  violence: string;
  racy: string;
}

const BLOCKED_LEVELS = ["LIKELY", "VERY_LIKELY"];

function isOwnStorageUrl(url: string): boolean {
  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!base) return false;
  return url.startsWith(`${base}/storage/v1/object/public/listing-images/`);
}

async function safeSearch(imageUrl: string): Promise<{ approved: boolean; reason?: string }> {
  const apiKey = process.env.GOOGLE_CLOUD_VISION_API_KEY;
  if (!apiKey) return { approved: true };

  try {
    const response = await fetch(
      `https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          requests: [{ image: { source: { imageUri: imageUrl } }, features: [{ type: "SAFE_SEARCH_DETECTION" }] }],
        }),
      },
    );
    if (!response.ok) {
      console.error("Vision API error:", response.status, await response.text());
      return { approved: true };
    }
    const data = await response.json();
    const annotation: SafeSearchAnnotation | undefined = data.responses?.[0]?.safeSearchAnnotation;
    if (!annotation) return { approved: true };

    const violations: string[] = [];
    if (BLOCKED_LEVELS.includes(annotation.adult)) violations.push("seksuelt innhold");
    if (BLOCKED_LEVELS.includes(annotation.violence)) violations.push("voldelig innhold");
    if (BLOCKED_LEVELS.includes(annotation.racy)) violations.push("upassende innhold");

    if (violations.length > 0) {
      return {
        approved: false,
        reason: `Bildet ble blokkert: ${violations.join(", ")}. Tuno har nulltoleranse for støtende innhold.`,
      };
    }
    return { approved: true };
  } catch (err) {
    console.error("Image moderation error:", err);
    return { approved: true };
  }
}

export async function POST(req: NextRequest) {
  // Auth: cookie-sesjon (web) eller Bearer access token (iOS)
  const supabase = await createClient();
  const bearer = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  const { data: { user } } = bearer
    ? await supabase.auth.getUser(bearer)
    : await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { imageUrl } = await req.json();
  if (!imageUrl || typeof imageUrl !== "string") {
    return NextResponse.json({ error: "imageUrl required" }, { status: 400 });
  }
  if (!isOwnStorageUrl(imageUrl)) {
    return NextResponse.json({ error: "imageUrl must point to listing-images" }, { status: 400 });
  }

  const safe = await safeSearch(imageUrl);
  if (!safe.approved) {
    return NextResponse.json(safe);
  }

  const ai = await moderateImageWithClaude(imageUrl);
  return NextResponse.json({ approved: ai.approved, reason: ai.reason, category: ai.category });
}
