import { NextRequest, NextResponse } from "next/server";
import { sendHostOutreachEmail } from "@/lib/email";
import { applyTemplateVariables } from "@/lib/supabase/outreach";

export async function GET(request: NextRequest) {
  const secret = request.nextUrl.searchParams.get("secret");
  if (secret !== process.env.CRON_SECRET) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const to = request.nextUrl.searchParams.get("to") ?? "haraldsalvesen@gmail.com";

  const body = applyTemplateVariables(
    `Hei {name},

Vi i Tuno har laget en plattform der private og profesjonelle utleiere kan leie ut parkering og bobil-/campingplasser direkte til reisende.

Vi ser at Lofoten har enormt mye bobil- og campervan-trafikk hver sommer, og vi tror du kunne tjent godt på å åpne plassen din for besøkende.

Hva du får:
• Tjen penger på plass du allerede har
• Du bestemmer selv pris, regler og tilgjengelighet
• Daglig utbetaling rett til din konto

Det er gratis å opprette en annonse.

Sjekk ut Tuno: {tuno_link}
Last ned appen: {app_store_link}

Spørsmål? Bare svar på denne mailen.

Vennlig hilsen,
Harald
Tuno`,
    { name: "Test-bedrift AS" },
  );

  try {
    await sendHostOutreachEmail({
      to,
      subject: "Tjen penger på plassen din med Tuno",
      body,
    });
    return NextResponse.json({ ok: true, to });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ ok: false, to, error: message }, { status: 500 });
  }
}
