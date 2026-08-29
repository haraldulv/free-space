import { createClient } from "@supabase/supabase-js";
import { ADMIN_EMAILS } from "@/lib/config";

/**
 * Hvilke admin-brukere som skal få varsler (push + in-app). Kun profiler med
 * is_admin=true OG e-post i ADMIN_EMAILS. Andre admins (f.eks. Kim) beholder
 * admin-tilgang, men får ingen automatiske varsler.
 */
export async function getNotifyAdminIds(): Promise<string[]> {
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );
  const { data: admins } = await supabase.from("profiles").select("id").eq("is_admin", true);
  if (!admins?.length) return [];
  const wanted = new Set(ADMIN_EMAILS.map((e) => e.toLowerCase()));
  const ids: string[] = [];
  await Promise.all(
    admins.map(async (a) => {
      const { data } = await supabase.auth.admin.getUserById(a.id);
      const email = data?.user?.email?.toLowerCase();
      if (email && wanted.has(email)) ids.push(a.id);
    }),
  );
  return ids;
}
