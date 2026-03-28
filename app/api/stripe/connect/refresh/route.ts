import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { createAccountLink } from "@/lib/stripe";

export async function GET() {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      const origin = process.env.NEXT_PUBLIC_SITE_URL || "https://spotshare.no";
      return NextResponse.redirect(new URL("/login", origin));
    }

    const { data: profile } = await supabase
      .from("profiles")
      .select("stripe_account_id")
      .eq("id", user.id)
      .single();

    if (!profile?.stripe_account_id) {
      const origin = process.env.NEXT_PUBLIC_SITE_URL || "https://spotshare.no";
      return NextResponse.redirect(new URL("/dashboard?tab=settings", origin));
    }

    const origin = process.env.NEXT_PUBLIC_SITE_URL || "https://spotshare.no";
    const url = await createAccountLink(
      profile.stripe_account_id,
      `${origin}/api/stripe/connect/callback`,
      `${origin}/api/stripe/connect/refresh`,
    );

    return NextResponse.redirect(url);
  } catch (err) {
    console.error("Connect refresh error:", err);
    const origin = process.env.NEXT_PUBLIC_SITE_URL || "https://spotshare.no";
    return NextResponse.redirect(new URL("/dashboard?tab=settings", origin));
  }
}
