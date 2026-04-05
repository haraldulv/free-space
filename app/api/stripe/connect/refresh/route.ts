import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { createClient as createServiceClient } from "@supabase/supabase-js";
import { createAccountLink } from "@/lib/stripe";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const platform = searchParams.get("platform");
  const uid = searchParams.get("uid");
  const origin = process.env.NEXT_PUBLIC_SITE_URL || "https://tuno.no";

  try {
    // Use uid param or fall back to cookie auth
    let userId: string | null = null;

    if (uid) {
      userId = uid;
    } else {
      const supabase = await createClient();
      const { data: { user } } = await supabase.auth.getUser();
      userId = user?.id ?? null;
    }

    if (!userId) {
      if (platform === "ios") {
        return NextResponse.redirect("no.tuno.app://stripe/callback?error=not_authenticated");
      }
      return NextResponse.redirect(new URL("/login", origin));
    }

    const db = createServiceClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );

    const { data: profile } = await db
      .from("profiles")
      .select("stripe_account_id")
      .eq("id", userId)
      .single();

    if (!profile?.stripe_account_id) {
      if (platform === "ios") {
        return NextResponse.redirect("no.tuno.app://stripe/callback?error=no_account");
      }
      return NextResponse.redirect(new URL("/dashboard?tab=settings", origin));
    }

    const params = platform === "ios" ? `?platform=ios&uid=${userId}` : `?uid=${userId}`;
    const url = await createAccountLink(
      profile.stripe_account_id,
      `${origin}/api/stripe/connect/callback${params}`,
      `${origin}/api/stripe/connect/refresh${params}`,
    );

    return NextResponse.redirect(url);
  } catch (err) {
    console.error("Connect refresh error:", err);
    if (platform === "ios") {
      return NextResponse.redirect("no.tuno.app://stripe/callback?error=unknown");
    }
    return NextResponse.redirect(new URL("/dashboard?tab=settings", origin));
  }
}
