"use server";

import { createClient } from "@/lib/supabase/server";

async function getAuthUser() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Ikke innlogget");
  return { supabase, user };
}

export async function getProfileAction(): Promise<{
  profile?: {
    id: string;
    email: string;
    fullName: string;
    avatar: string;
    responseRate: number;
    responseTime: string;
    joinedYear: number;
    stripeOnboardingComplete?: boolean;
    stripeAccountId?: string;
    phone: string;
    showPhone: boolean;
  };
  error?: string;
}> {
  try {
    const { supabase, user } = await getAuthUser();

    const { data: profile } = await supabase
      .from("profiles")
      .select("full_name, avatar_url, response_rate, response_time, joined_year, stripe_account_id, stripe_onboarding_complete, phone, show_phone")
      .eq("id", user.id)
      .single();

    return {
      profile: {
        id: user.id,
        email: user.email || "",
        fullName: profile?.full_name || user.user_metadata?.full_name || "",
        avatar: profile?.avatar_url || user.user_metadata?.avatar_url || "",
        responseRate: profile?.response_rate || 0,
        responseTime: profile?.response_time || "innen 1 time",
        joinedYear: profile?.joined_year || new Date().getFullYear(),
        stripeOnboardingComplete: profile?.stripe_onboarding_complete || false,
        stripeAccountId: profile?.stripe_account_id ? `****${profile.stripe_account_id.slice(-4)}` : undefined,
        phone: profile?.phone || "",
        showPhone: profile?.show_phone || false,
      },
    };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function updateProfileAction(data: {
  fullName: string;
  phone?: string;
  showPhone?: boolean;
}): Promise<{ error?: string }> {
  try {
    const { supabase, user } = await getAuthUser();

    const updates: Record<string, unknown> = { full_name: data.fullName };
    if (data.phone !== undefined) updates.phone = data.phone || null;
    if (data.showPhone !== undefined) updates.show_phone = data.showPhone;

    const { error } = await supabase
      .from("profiles")
      .update(updates)
      .eq("id", user.id);

    if (error) return { error: error.message };

    // Also update auth metadata so navbar shows updated name
    await supabase.auth.updateUser({
      data: { full_name: data.fullName },
    });

    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function updateAvatarAction(avatarUrl: string): Promise<{ error?: string }> {
  try {
    const { supabase, user } = await getAuthUser();

    const { error } = await supabase
      .from("profiles")
      .update({ avatar_url: avatarUrl })
      .eq("id", user.id);

    if (error) return { error: error.message };

    await supabase.auth.updateUser({
      data: { avatar_url: avatarUrl },
    });

    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function deleteAccountAction(): Promise<{ error?: string }> {
  try {
    const { supabase, user } = await getAuthUser();

    // Delete profile (cascades to favorites, bookings, listings)
    const { error } = await supabase
      .from("profiles")
      .delete()
      .eq("id", user.id);

    if (error) return { error: error.message };

    // Sign out the user (full auth.users deletion requires service role key)
    await supabase.auth.signOut();

    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}
