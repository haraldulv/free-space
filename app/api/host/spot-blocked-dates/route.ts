import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

/**
 * Bearer-auth-versjon av updateSpotBlockedDatesAction for iOS.
 */
export async function POST(request: NextRequest) {
  try {
    const authHeader = request.headers.get("authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return NextResponse.json({ error: "Ikke innlogget" }, { status: 401 });
    }

    const token = authHeader.slice(7);
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return NextResponse.json({ error: "Ugyldig token" }, { status: 401 });
    }

    const { listingId, spotId, blockedDates } = await request.json() as {
      listingId: string;
      spotId: string;
      blockedDates: string[];
    };

    if (!listingId || !spotId || !Array.isArray(blockedDates)) {
      return NextResponse.json({ error: "Mangler felt" }, { status: 400 });
    }

    const { data: listing } = await supabase
      .from("listings")
      .select("host_id, spot_markers")
      .eq("id", listingId)
      .single();

    if (!listing) return NextResponse.json({ error: "Annonse ikke funnet" }, { status: 404 });
    if (listing.host_id !== user.id) {
      return NextResponse.json({ error: "Ikke tilgang" }, { status: 403 });
    }

    const markers = (listing.spot_markers as Array<Record<string, unknown>>) || [];
    const updated = markers.map((m) =>
      m.id === spotId
        ? { ...m, blockedDates: blockedDates.length > 0 ? blockedDates : null }
        : m,
    );

    const { error: updateErr } = await supabase
      .from("listings")
      .update({ spot_markers: updated })
      .eq("id", listingId);

    if (updateErr) return NextResponse.json({ error: updateErr.message }, { status: 500 });

    return NextResponse.json({ ok: true });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
