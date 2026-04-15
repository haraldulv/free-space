import { NextRequest, NextResponse } from "next/server";
import { sendBookingConfirmation } from "@/lib/email";

export async function GET(request: NextRequest) {
  const secret = request.nextUrl.searchParams.get("secret");
  if (secret !== process.env.CRON_SECRET) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const to = request.nextUrl.searchParams.get("to") ?? "haraldsalvesen@gmail.com";
  const hasKey = !!process.env.RESEND_API_KEY;
  const keyPrefix = process.env.RESEND_API_KEY?.slice(0, 6) ?? null;

  console.log(`[Email-Test] hasKey=${hasKey} keyPrefix=${keyPrefix} to=${to}`);

  try {
    await sendBookingConfirmation(to, {
      guestName: "Harald",
      listingTitle: "Test-annonse (dev)",
      listingId: request.nextUrl.searchParams.get("listingId"),
      listingImage: request.nextUrl.searchParams.get("img"),
      checkIn: "2026-04-20",
      checkOut: "2026-04-21",
      totalPrice: 100,
      bookingId: "test-" + Date.now(),
    });
    console.log(`[Email-Test] OK sent to ${to}`);
    return NextResponse.json({ ok: true, to, hasKey, keyPrefix });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    const stack = err instanceof Error ? err.stack : null;
    console.error(`[Email-Test] FAILED to ${to}:`, message, stack);
    return NextResponse.json(
      { ok: false, to, hasKey, keyPrefix, error: message, stack },
      { status: 500 },
    );
  }
}
