import { NextRequest, NextResponse } from "next/server";

interface SafeSearchAnnotation {
  adult: string;
  spoof: string;
  medical: string;
  violence: string;
  racy: string;
}

const BLOCKED_LEVELS = ["LIKELY", "VERY_LIKELY"];

export async function POST(req: NextRequest) {
  const apiKey = process.env.GOOGLE_CLOUD_VISION_API_KEY;
  if (!apiKey) {
    // If no API key configured, skip moderation (dev/staging)
    return NextResponse.json({ approved: true });
  }

  const { imageUrl } = await req.json();
  if (!imageUrl || typeof imageUrl !== "string") {
    return NextResponse.json({ error: "imageUrl required" }, { status: 400 });
  }

  try {
    const response = await fetch(
      `https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          requests: [
            {
              image: { source: { imageUri: imageUrl } },
              features: [{ type: "SAFE_SEARCH_DETECTION" }],
            },
          ],
        }),
      },
    );

    if (!response.ok) {
      console.error("Vision API error:", response.status, await response.text());
      // Don't block uploads if Vision API is down
      return NextResponse.json({ approved: true });
    }

    const data = await response.json();
    const annotation: SafeSearchAnnotation | undefined =
      data.responses?.[0]?.safeSearchAnnotation;

    if (!annotation) {
      return NextResponse.json({ approved: true });
    }

    const violations: string[] = [];

    if (BLOCKED_LEVELS.includes(annotation.adult)) {
      violations.push("seksuelt innhold");
    }
    if (BLOCKED_LEVELS.includes(annotation.violence)) {
      violations.push("voldelig innhold");
    }
    if (BLOCKED_LEVELS.includes(annotation.racy)) {
      violations.push("upassende innhold");
    }

    if (violations.length > 0) {
      return NextResponse.json({
        approved: false,
        reason: `Bildet ble blokkert: ${violations.join(", ")}. Tuno har nulltoleranse for støtende innhold.`,
      });
    }

    return NextResponse.json({ approved: true });
  } catch (err) {
    console.error("Image moderation error:", err);
    // Don't block uploads on moderation errors
    return NextResponse.json({ approved: true });
  }
}
