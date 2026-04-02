import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { stripe } from "@/lib/stripe";

export async function GET() {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      const origin = process.env.NEXT_PUBLIC_SITE_URL || "https://tuno.no";
      return NextResponse.redirect(new URL("/login", origin));
    }

    const { data: profile } = await supabase
      .from("profiles")
      .select("stripe_account_id")
      .eq("id", user.id)
      .single();

    if (!profile?.stripe_account_id) {
      const origin = process.env.NEXT_PUBLIC_SITE_URL || "https://tuno.no";
      return NextResponse.redirect(new URL("/dashboard?tab=settings", origin));
    }

    const loginLink = await stripe.accounts.createLoginLink(profile.stripe_account_id);
    return NextResponse.redirect(loginLink.url);
  } catch (err) {
    console.error("Connect dashboard error:", err);
    const origin = process.env.NEXT_PUBLIC_SITE_URL || "https://tuno.no";
    return NextResponse.redirect(new URL("/dashboard?tab=settings", origin));
  }
}
