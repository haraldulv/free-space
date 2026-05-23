import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { listOutreachTargets, listEmailTemplates } from "@/lib/supabase/outreach";
import OutreachClient from "./OutreachClient";

export const dynamic = "force-dynamic";

interface PageProps {
  params: Promise<{ locale: string }>;
}

export default async function OutreachPage({ params }: PageProps) {
  const { locale } = await params;

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    redirect(`/${locale}/login?redirectTo=/${locale}/admin/outreach`);
  }
  const { data: profile } = await supabase
    .from("profiles")
    .select("is_admin")
    .eq("id", user.id)
    .single();
  if (!profile?.is_admin) {
    redirect(`/${locale}/`);
  }

  const [targets, templates] = await Promise.all([
    listOutreachTargets({ area: "lofoten", limit: 1000 }),
    listEmailTemplates(),
  ]);

  return <OutreachClient initialTargets={targets} initialTemplates={templates} />;
}
