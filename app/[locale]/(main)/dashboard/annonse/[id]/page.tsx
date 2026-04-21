import { notFound, redirect } from "next/navigation";
import { ArrowLeft, MapPin, CalendarCheck, TrendingUp, Users, Pencil } from "lucide-react";
import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { createClient } from "@/lib/supabase/server";
import { getListingStats, getSpotStatsForListing } from "@/lib/supabase/stats";
import Container from "@/components/ui/Container";
import { SpotStatsGrid } from "./SpotStatsGrid";
import { PricingRulesPanel } from "./PricingRulesPanel";
import type { SpotMarker } from "@/types";

export default async function ListingOverviewPage({
  params,
}: {
  params: Promise<{ id: string; locale: string }>;
}) {
  const { id, locale } = await params;
  const t = await getTranslations({ locale, namespace: "hostStats" });
  const tDash = await getTranslations({ locale, namespace: "dashboard" });

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/${locale}/login?redirectTo=/dashboard/annonse/${id}`);

  const { data: listing } = await supabase
    .from("listings")
    .select("id, title, host_id, images, city, region, address, spots, spot_markers, instant_booking, is_active, price")
    .eq("id", id)
    .single();

  if (!listing) notFound();
  if (listing.host_id !== user.id) {
    redirect(`/${locale}/dashboard?tab=listings`);
  }

  const spotMarkers = (listing.spot_markers as SpotMarker[] | null) || [];
  const namedSpots = spotMarkers.filter((s): s is SpotMarker & { id: string } => !!s.id);

  const [stats30, stats90, spotStats, pricingRulesRes] = await Promise.all([
    getListingStats(id, 30),
    getListingStats(id, 90),
    namedSpots.length > 0
      ? getSpotStatsForListing(id, namedSpots.map((s) => ({ id: s.id, label: s.label })), 30)
      : Promise.resolve([]),
    supabase.from("listing_pricing_rules").select("*").eq("listing_id", id),
  ]);

  const pricingRules = pricingRulesRes.data || [];
  const weekendRule = pricingRules.find((r) => r.kind === "weekend");
  const seasonRules = pricingRules
    .filter((r) => r.kind === "season")
    .map((r) => ({
      id: r.id as string,
      startDate: r.start_date as string,
      endDate: r.end_date as string,
      price: r.price as number,
    }))
    .sort((a, b) => a.startDate.localeCompare(b.startDate));

  const upcomingQuery = await supabase
    .from("bookings")
    .select("id, check_in, check_out, total_price, status, selected_spot_ids, guest:user_id(full_name)")
    .eq("listing_id", id)
    .in("status", ["confirmed", "requested"])
    .gte("check_in", new Date().toISOString().split("T")[0])
    .order("check_in", { ascending: true })
    .limit(10);

  const upcoming = upcomingQuery.data || [];
  const heroImage = (listing.images as string[] | null)?.[0];

  return (
    <Container className="py-8 lg:py-10">
      <Link
        href={{ pathname: "/dashboard", query: { tab: "listings" } }}
        className="inline-flex items-center gap-1.5 text-sm text-neutral-500 hover:text-neutral-700"
      >
        <ArrowLeft className="h-4 w-4" />
        {tDash("myListings")}
      </Link>

      {/* Header */}
      <div className="mt-4 flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div className="flex items-center gap-4">
          {heroImage && (
            <div
              className="h-16 w-24 shrink-0 rounded-lg bg-neutral-100 bg-cover bg-center"
              style={{ backgroundImage: `url(${heroImage})` }}
            />
          )}
          <div>
            <h1 className="text-2xl font-semibold text-neutral-900">{listing.title}</h1>
            <p className="mt-1 flex items-center gap-1 text-sm text-neutral-500">
              <MapPin className="h-3.5 w-3.5" />
              {listing.city}, {listing.region}
            </p>
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Link
            href={`/listings/${listing.id}`}
            className="rounded-lg border border-neutral-200 bg-white px-3 py-2 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
          >
            {t("viewPublic")}
          </Link>
          <Link
            href={`/bli-utleier/rediger/${listing.id}`}
            className="inline-flex items-center gap-1.5 rounded-lg bg-neutral-900 px-3 py-2 text-sm font-medium text-white hover:bg-neutral-800"
          >
            <Pencil className="h-3.5 w-3.5" />
            {tDash("editListing")}
          </Link>
        </div>
      </div>

      {/* Stats banner */}
      <div className="mt-6 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatCard
          icon={TrendingUp}
          label={t("occupancy30")}
          value={`${stats30.occupancyPct}%`}
          sub={t("occupancy90Compare", { pct: stats90.occupancyPct })}
        />
        <StatCard
          icon={TrendingUp}
          label={t("revenue30")}
          value={`${stats30.revenue.toLocaleString("nb-NO")} kr`}
          sub={t("revenue90Compare", { kr: stats90.revenue.toLocaleString("nb-NO") })}
        />
        <StatCard
          icon={CalendarCheck}
          label={t("upcomingBookings")}
          value={String(stats30.upcomingBookings)}
          sub={stats30.nextCheckIn ? t("nextCheckIn", { date: stats30.nextCheckIn }) : t("noUpcoming")}
        />
        <StatCard
          icon={Users}
          label={t("capacity")}
          value={String(listing.spots ?? 1)}
          sub={namedSpots.length > 0 ? t("namedSpotsCount", { count: namedSpots.length }) : t("noNamedSpots")}
        />
      </div>

      {/* Pricing rules */}
      <PricingRulesPanel
        listingId={id}
        basePrice={(listing.price as number) ?? 0}
        initialWeekendPrice={(weekendRule?.price as number | undefined) ?? null}
        initialSeasonRules={seasonRules}
      />

      {/* Per-spot grid */}
      {namedSpots.length > 0 && (
        <div className="mt-10">
          <h2 className="text-lg font-semibold text-neutral-900">{t("spotBreakdown")}</h2>
          <p className="mt-1 text-sm text-neutral-500">{t("spotBreakdownDesc")}</p>
          <div className="mt-4">
            <SpotStatsGrid listingId={id} stats={spotStats} />
          </div>
        </div>
      )}

      {/* Upcoming bookings */}
      <div className="mt-10">
        <h2 className="text-lg font-semibold text-neutral-900">{t("upcomingTitle")}</h2>
        {upcoming.length === 0 ? (
          <p className="mt-2 text-sm text-neutral-500">{t("noUpcomingBookings")}</p>
        ) : (
          <div className="mt-4 overflow-hidden rounded-xl border border-neutral-200 bg-white">
            <table className="w-full text-sm">
              <thead className="bg-neutral-50 text-left text-xs uppercase tracking-wide text-neutral-500">
                <tr>
                  <th className="px-4 py-3">{t("guest")}</th>
                  <th className="px-4 py-3">{t("dates")}</th>
                  <th className="px-4 py-3">{t("status")}</th>
                  <th className="px-4 py-3 text-right">{t("amount")}</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-100">
                {upcoming.map((b) => {
                  const guestRow = b.guest as unknown as { full_name?: string } | { full_name?: string }[] | null;
                  const guestObj = Array.isArray(guestRow) ? guestRow[0] : guestRow;
                  const guestName = guestObj?.full_name || t("anonymousGuest");
                  return (
                    <tr key={b.id as string}>
                      <td className="px-4 py-3 font-medium text-neutral-900">{guestName}</td>
                      <td className="px-4 py-3 text-neutral-600">{b.check_in as string} → {b.check_out as string}</td>
                      <td className="px-4 py-3">
                        <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                          b.status === "requested"
                            ? "bg-amber-100 text-amber-800"
                            : "bg-green-100 text-green-800"
                        }`}>
                          {b.status === "requested" ? t("statusRequested") : t("statusConfirmed")}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-right font-medium">{(b.total_price as number).toLocaleString("nb-NO")} kr</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </Container>
  );
}

function StatCard({ icon: Icon, label, value, sub }: {
  icon: React.ElementType;
  label: string;
  value: string;
  sub?: string;
}) {
  return (
    <div className="rounded-xl border border-neutral-200 bg-white p-4">
      <div className="flex items-center gap-1.5 text-xs font-medium text-neutral-500">
        <Icon className="h-3.5 w-3.5" />
        {label}
      </div>
      <div className="mt-2 text-2xl font-semibold text-neutral-900">{value}</div>
      {sub && <div className="mt-1 text-xs text-neutral-500">{sub}</div>}
    </div>
  );
}
