import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { createAccountLink } from "@/lib/stripe";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const platform = searchParams.get("platform");
  const origin = process.env.NEXT_PUBLIC_SITE_URL || "https://tuno.no";

  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      if (platform === "ios") {
        return NextResponse.redirect("no.tuno.app://stripe/callback?error=not_authenticated");
      }
      return NextResponse.redirect(new URL("/login", origin));
    }

    const { data: profile } = await supabase
      .from("profiles")
      .select("stripe_account_id")
      .eq("id", user.id)
      .single();

    if (!profile?.stripe_account_id) {
      if (platform === "ios") {
        return NextResponse.redirect("no.tuno.app://stripe/callback?error=no_account");
      }
      return NextResponse.redirect(new URL("/dashboard?tab=settings", origin));
    }

    const platformParam = platform === "ios" ? "?platform=ios" : "";
    const url = await createAccountLink(
      profile.stripe_account_id,
      `${origin}/api/stripe/connect/callback${platformParam}`,
      `${origin}/api/stripe/connect/refresh${platformParam}`,
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
