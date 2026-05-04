import { NextResponse } from "next/server";

/**
 * Slår opp poststed for et norsk postnummer via Bring sin offentlige API.
 * Brukes for å auto-fylle "By" når host taster postnummer i adresse-skjema.
 *
 * GET /api/postal-lookup?postnr=0150
 * → { city: "OSLO" } eller { city: null } hvis ikke gyldig.
 */
export const runtime = "nodejs";

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const postnr = (searchParams.get("postnr") || "").trim();

  if (!/^\d{4}$/.test(postnr)) {
    return NextResponse.json({ city: null }, { status: 200 });
  }

  try {
    const url = `https://api.bring.com/shippingguide/api/postalCode.json?clientUrl=tuno.no&pnr=${postnr}`;
    const res = await fetch(url, {
      headers: { "User-Agent": "Tuno/1.0 (postal-lookup)" },
      // Cache opp i 24 t — postnumre endrer seg sjelden.
      next: { revalidate: 86400 },
    });
    if (!res.ok) {
      return NextResponse.json({ city: null }, { status: 200 });
    }
    const data = (await res.json()) as { valid?: boolean; result?: string };
    if (data.valid === true && typeof data.result === "string" && data.result.length > 0) {
      return NextResponse.json({ city: data.result }, { status: 200 });
    }
    return NextResponse.json({ city: null }, { status: 200 });
  } catch {
    // Bring nede eller nettverksfeil — la host taste manuelt.
    return NextResponse.json({ city: null }, { status: 200 });
  }
}
