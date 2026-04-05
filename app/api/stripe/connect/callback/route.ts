import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { stripe } from "@/lib/stripe";

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

    let onboardingComplete = false;
    if (profile?.stripe_account_id) {
      const account = await stripe.accounts.retrieve(profile.stripe_account_id);

      if (account.charges_enabled) {
        await supabase
          .from("profiles")
          .update({ stripe_onboarding_complete: true })
          .eq("id", user.id);
        onboardingComplete = true;
      }
    }

    if (platform === "ios") {
      return NextResponse.redirect(
        `no.tuno.app://stripe/callback?success=${onboardingComplete}`
      );
    }
    return NextResponse.redirect(new URL("/dashboard?tab=settings", origin));
  } catch (err) {
    console.error("Connect callback error:", err);
    if (platform === "ios") {
      return NextResponse.redirect("no.tuno.app://stripe/callback?error=unknown");
    }
    return NextResponse.redirect(new URL("/dashboard?tab=settings", origin));
  }
}
