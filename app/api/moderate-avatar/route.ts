import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { moderateAvatar } from "@/lib/moderation";

/**
 * Kalles av web (SettingsPanel) og iOS (ProfileView) rett etter at et nytt
 * profilbilde er lagret. Sjekker bildet med Claude; ved treff nulles
 * avatar_url server-side og admin varsles. Brukeren får beskjed i svaret.
 */
export async function POST(req: NextRequest) {
  const supabase = await createClient();
  const bearer = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  const { data: { user } } = bearer ? await supabase.auth.getUser(bearer) : await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { avatarUrl } = await req.json();
  const base = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  if (typeof avatarUrl !== "string" || !avatarUrl.startsWith(`${base}/storage/v1/object/public/avatars/${user.id}/`)) {
    return NextResponse.json({ error: "avatarUrl must be your own avatar" }, { status: 400 });
  }

  const result = await moderateAvatar(user.id, avatarUrl);
  return NextResponse.json(result);
}
