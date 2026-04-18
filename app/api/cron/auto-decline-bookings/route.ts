import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { declineBookingAction } from "@/app/[locale]/(main)/book/actions";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

export async function GET(request: NextRequest) {
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const now = new Date().toISOString();

    const { data: expired } = await supabase
      .from("bookings")
      .select("id")
      .eq("status", "requested")
      .lt("approval_deadline", now);

    if (!expired || expired.length === 0) {
      return NextResponse.json({ declined: 0 });
    }

    let declined = 0;
    for (const booking of expired) {
      const result = await declineBookingAction(booking.id, {
        autoDeclined: true,
        allowCron: true,
      });
      if (!result.error) declined++;
      else console.error(`Auto-decline ${booking.id}: ${result.error}`);
    }

    return NextResponse.json({ declined, checked: expired.length });
  } catch (err) {
    console.error("Auto-decline error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
