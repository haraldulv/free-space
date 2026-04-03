import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { stripe } from "@/lib/stripe";
import { SERVICE_FEE_RATE } from "@/lib/config";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

export async function POST(request: NextRequest) {
  try {
    // Authenticate via Bearer token
    const authHeader = request.headers.get("authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return NextResponse.json({ error: "Ikke innlogget" }, { status: 401 });
    }

    const token = authHeader.slice(7);
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return NextResponse.json({ error: "Ugyldig token" }, { status: 401 });
    }

    const body = await request.json();
    const { listingId, checkIn, checkOut, totalPrice, licensePlate, isRentalCar } = body as {
      listingId: string;
      checkIn: string;
      checkOut: string;
      totalPrice: number;
      licensePlate?: string;
      isRentalCar?: boolean;
    };

    if (!listingId || !checkIn || !checkOut || !totalPrice) {
      return NextResponse.json({ error: "Mangler påkrevde felt" }, { status: 400 });
    }

    // Check availability
    const { data: listing } = await supabase
      .from("listings")
      .select("spots, host_id, title")
      .eq("id", listingId)
      .single();

    if (!listing) {
      return NextResponse.json({ error: "Annonse ikke funnet" }, { status: 404 });
    }

    const { count } = await supabase
      .from("bookings")
      .select("id", { count: "exact", head: true })
      .eq("listing_id", listingId)
      .in("status", ["confirmed", "pending"])
      .lt("check_in", checkOut)
      .gt("check_out", checkIn);

    const available = listing.spots - (count || 0);
    if (available <= 0) {
      return NextResponse.json({ error: "Ingen ledige plasser for valgte datoer" });
    }

    // Verify host has Stripe Connect
    const { data: hostProfile } = await supabase
      .from("profiles")
      .select("stripe_account_id, stripe_onboarding_complete")
      .eq("id", listing.host_id)
      .single();

    if (!hostProfile?.stripe_account_id || !hostProfile?.stripe_onboarding_complete) {
      return NextResponse.json({ error: "Utleier har ikke satt opp utbetalinger ennå. Prøv igjen senere." });
    }

    // Insert booking
    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .insert({
        user_id: user.id,
        listing_id: listingId,
        check_in: checkIn,
        check_out: checkOut,
        total_price: totalPrice,
        status: "pending",
        payment_status: "pending",
        host_id: listing.host_id,
        license_plate: licensePlate || null,
        is_rental_car: isRentalCar || false,
      })
      .select("id")
      .single();

    if (bookingError) {
      return NextResponse.json({ error: bookingError.message }, { status: 500 });
    }

    // Create Stripe PaymentIntent (amount in øre)
    const paymentIntent = await stripe.paymentIntents.create({
      amount: totalPrice * 100,
      currency: "nok",
      metadata: {
        bookingId: booking.id,
        listingId,
        userId: user.id,
        listingTitle: listing.title,
        hostStripeAccountId: hostProfile.stripe_account_id,
        serviceFeeRate: String(SERVICE_FEE_RATE),
      },
    });

    // Save payment intent ID
    await supabase
      .from("bookings")
      .update({ payment_intent_id: paymentIntent.id })
      .eq("id", booking.id);

    return NextResponse.json({
      bookingId: booking.id,
      clientSecret: paymentIntent.client_secret,
      publishableKey: process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY,
    });
  } catch (err) {
    console.error("POST /api/bookings/create error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 }
    );
  }
}
