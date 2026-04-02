import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { stripe } from "@/lib/stripe";

export async function GET() {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.redirect(new URL("/login", process.env.NEXT_PUBLIC_SITE_URL || "https://tuno.no"));
    }

    const { data: profile } = await supabase
      .from("profiles")
      .select("stripe_account_id")
      .eq("id", user.id)
      .single();

    if (profile?.stripe_account_id) {
      const account = await stripe.accounts.retrieve(profile.stripe_account_id);

      if (account.charges_enabled) {
        await supabase
          .from("profiles")
          .update({ stripe_onboarding_complete: true })
          .eq("id", user.id);
      }
    }

    const origin = process.env.NEXT_PUBLIC_SITE_URL || "https://tuno.no";
    return NextResponse.redirect(new URL("/dashboard?tab=settings", origin));
  } catch (err) {
    console.error("Connect callback error:", err);
    const origin = process.env.NEXT_PUBLIC_SITE_URL || "https://tuno.no";
    return NextResponse.redirect(new URL("/dashboard?tab=settings", origin));
  }
}
