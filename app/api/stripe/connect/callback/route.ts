import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { createClient as createServiceClient } from "@supabase/supabase-js";
import { stripe } from "@/lib/stripe";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const platform = searchParams.get("platform");
  const uid = searchParams.get("uid");
  const origin = process.env.NEXT_PUBLIC_SITE_URL || "https://tuno.no";

  try {
    // Use service role client with uid param (works from SFSafariViewController)
    // Fall back to cookie auth for web
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

    let onboardingComplete = false;
    if (profile?.stripe_account_id) {
      const account = await stripe.accounts.retrieve(profile.stripe_account_id);

      if (account.charges_enabled) {
        await db
          .from("profiles")
          .update({ stripe_onboarding_complete: true })
          .eq("id", userId);
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
