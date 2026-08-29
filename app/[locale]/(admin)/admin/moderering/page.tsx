import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import ModerationClient from "./ModerationClient";

export const dynamic = "force-dynamic";

interface PageProps {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ listing?: string; tab?: string; report?: string }>;
}

export default async function ModerationPage({ params, searchParams }: PageProps) {
  const { locale } = await params;
  const { listing, tab, report } = await searchParams;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/${locale}/login?redirectTo=/${locale}/admin/moderering`);

  const { data: profile } = await supabase
    .from("profiles")
    .select("is_admin")
    .eq("id", user.id)
    .single();
  if (!profile?.is_admin) redirect(`/${locale}/`);

  const initialView = tab === "reports" ? "reports" : tab === "content" ? "content" : "listings";
  return <ModerationClient focusListingId={listing ?? null} currentAdminId={user.id} initialView={initialView} focusReportId={report ?? null} />;
}
