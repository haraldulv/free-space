import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { stripe } from "@/lib/stripe";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

// Aktive booking-statuser som blokkerer sletting. Brukeren må kansellere
// (eller la dem løpe ut) før kontoen kan fjernes — speiles av tekst i
// SettingsView footer ("Aktive bookinger må avsluttes før du sletter").
const ACTIVE_STATUSES = [
  "pending",
  "requested",
  "confirmed",
  "awaiting_host",
  "awaiting_guest",
  "awaiting_payment",
];

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

    const userId = user.id;
    const today = new Date().toISOString().slice(0, 10);

    // 1) Blokker hvis det finnes aktive (ikke utløpte) bookinger der bruker er
    //    enten gjest eller vert. Stripe-refund + payout-håndtering ved sletting
    //    er for komplekst å gjøre trygt automatisk — tving brukeren til å
    //    kansellere først via normal flyt.
    const { data: activeBookings } = await supabase
      .from("bookings")
      .select("id, status, check_out")
      .or(`user_id.eq.${userId},host_id.eq.${userId}`)
      .in("status", ACTIVE_STATUSES);

    const blocking = (activeBookings ?? []).filter(
      (b) => !b.check_out || b.check_out >= today,
    );
    if (blocking.length > 0) {
      return NextResponse.json(
        {
          error: `Du har ${blocking.length} aktive bookinger. Kanseller dem først, eller kontakt support@tuno.no.`,
        },
        { status: 400 },
      );
    }

    // 2) Hent Stripe Connect-ID før vi sletter profilen.
    const { data: profile } = await supabase
      .from("profiles")
      .select("stripe_account_id")
      .eq("id", userId)
      .single();

    // 3) Slett brukerens listings. FK listings.host_id → profiles.id er
    //    ON DELETE SET NULL, så vi må slette aktivt for å rydde dem (ellers
    //    blir annonser hengende i søk med NULL host). Cascade rydder
    //    bookings, reviews, conversations, listing_pricing_*, favorites.
    const { error: listingsErr } = await supabase
      .from("listings")
      .delete()
      .eq("host_id", userId);
    if (listingsErr) {
      console.error("[User Delete] listings delete failed:", listingsErr.message);
      return NextResponse.json(
        { error: "Kunne ikke slette annonser: " + listingsErr.message },
        { status: 500 },
      );
    }

    // 4) bookings.host_id har ingen ON DELETE-regel — fjerner gjenværende
    //    rader (skal være tomt etter steg 3 siden bookings cascadeer fra
    //    listings, men dette er safety net for inkonsistente FK-stater).
    await supabase.from("bookings").delete().eq("host_id", userId);

    // 5) Stripe Connect: vi sletter ikke kontoen (Stripe nekter dersom det er
    //    aktiv balanse eller pågående payouts), men flagger metadata så
    //    Connect-listen kan vises som "slettet av bruker" senere.
    if (profile?.stripe_account_id) {
      try {
        await stripe.accounts.update(profile.stripe_account_id, {
          metadata: {
            deleted_by_user_at: new Date().toISOString(),
            deleted_user_id: userId,
          },
        });
      } catch (err) {
        console.warn(
          "[User Delete] Stripe account flag failed:",
          err instanceof Error ? err.message : err,
        );
      }
    }

    // 6) Slett auth.users → CASCADE rydder profiles, device_tokens,
    //    favorites, notifications, reviews (both reviewer + reviewee FK),
    //    messages, conversations, booking_offers, vipps_native_intents.
    const { error: deleteAuthErr } = await supabase.auth.admin.deleteUser(userId);
    if (deleteAuthErr) {
      console.error("[User Delete] auth.admin.deleteUser failed:", deleteAuthErr.message);
      return NextResponse.json(
        { error: "Kunne ikke slette konto: " + deleteAuthErr.message },
        { status: 500 },
      );
    }

    console.log(`[User Delete] User ${userId.slice(0, 8)}... fully deleted`);
    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error("[User Delete] Unexpected error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
