import { redirect } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { createClient } from "@/lib/supabase/server";
import { resolveNightlyPrice, type PricingRule, type PricingOverride } from "@/lib/pricing";
import Container from "@/components/ui/Container";
import { HostCalendarGrid, type CalendarCell, type CalendarListing } from "@/components/features/host-calendar/HostCalendarGrid";

const DAYS_AHEAD = 90;

function formatDate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${dd}`;
}

export default async function HostCalendarPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "hostCalendar" });
  const tDash = await getTranslations({ locale, namespace: "dashboard" });

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/${locale}/login?redirectTo=/dashboard/kalender`);

  // Hente alle host's aktive listings
  const { data: listings } = await supabase
    .from("listings")
    .select("id, title, price, images, spots, blocked_dates")
    .eq("host_id", user.id)
    .neq("is_active", false)
    .order("title");

  const allListings = listings || [];

  if (allListings.length === 0) {
    return (
      <Container className="py-8 lg:py-10">
        <Link
          href={{ pathname: "/dashboard", query: { tab: "listings" } }}
          className="inline-flex items-center gap-1.5 text-sm text-neutral-500 hover:text-neutral-700"
        >
          <ArrowLeft className="h-4 w-4" />
          {tDash("myListings")}
        </Link>
        <div className="mt-10 text-center">
          <h1 className="text-xl font-semibold text-neutral-900">{t("title")}</h1>
          <p className="mt-2 text-sm text-neutral-500">{t("noListings")}</p>
        </div>
      </Container>
    );
  }

  const listingIds = allListings.map((l) => l.id as string);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const startDate = formatDate(today);
  const endDate = formatDate(new Date(today.getTime() + DAYS_AHEAD * 86400000));

  const [bookingsRes, overridesRes, rulesRes] = await Promise.all([
    supabase
      .from("bookings")
      .select("listing_id, check_in, check_out, status, guest:user_id(full_name)")
      .in("listing_id", listingIds)
      .in("status", ["confirmed", "requested", "pending"])
      .gte("check_out", startDate)
      .lte("check_in", endDate),
    supabase
      .from("listing_pricing_overrides")
      .select("listing_id, date, price")
      .in("listing_id", listingIds)
      .gte("date", startDate)
      .lte("date", endDate),
    supabase
      .from("listing_pricing_rules")
      .select("*")
      .in("listing_id", listingIds),
  ]);

  const overrides: PricingOverride[] = (overridesRes.data || []).map((r) => ({
    listingId: r.listing_id as string,
    date: r.date as string,
    price: r.price as number,
  }));

  const rulesByListing = new Map<string, PricingRule[]>();
  for (const row of rulesRes.data || []) {
    const listingId = row.listing_id as string;
    if (!rulesByListing.has(listingId)) rulesByListing.set(listingId, []);
    rulesByListing.get(listingId)!.push({
      id: row.id as string,
      listingId,
      kind: row.kind as PricingRule["kind"],
      dayMask: (row.day_mask as number | null) ?? null,
      startDate: (row.start_date as string | null) ?? null,
      endDate: (row.end_date as string | null) ?? null,
      price: row.price as number,
    });
  }

  // Bygge booked-set per listing per dato
  const bookedByListingDate = new Map<string, { guestName: string | null; requested: boolean }>();
  for (const b of bookingsRes.data || []) {
    const listingId = b.listing_id as string;
    const guestRow = b.guest as unknown as { full_name?: string } | { full_name?: string }[] | null;
    const guestObj = Array.isArray(guestRow) ? guestRow[0] : guestRow;
    const guestName = guestObj?.full_name || null;
    const isRequested = (b.status as string) === "requested";
    const cursor = new Date((b.check_in as string) + "T00:00:00");
    const end = new Date((b.check_out as string) + "T00:00:00");
    while (cursor < end) {
      const key = `${listingId}:${formatDate(cursor)}`;
      const existing = bookedByListingDate.get(key);
      // Confirmed vinner over requested i visning
      if (!existing || (existing.requested && !isRequested)) {
        bookedByListingDate.set(key, { guestName, requested: isRequested });
      }
      cursor.setDate(cursor.getDate() + 1);
    }
  }

  // Bygge dato-array
  const dates: string[] = [];
  {
    const cursor = new Date(today);
    while (cursor < new Date(endDate + "T00:00:00")) {
      dates.push(formatDate(cursor));
      cursor.setDate(cursor.getDate() + 1);
    }
  }

  // Bygge celler for hver (listing, date)
  const cellsData: Record<string, CalendarCell> = {};
  const calendarListings: CalendarListing[] = allListings.map((listing) => {
    const listingId = listing.id as string;
    const basePrice = (listing.price as number) ?? 0;
    const blockedDates = new Set<string>(((listing.blocked_dates as string[] | null) || []));
    const listingRules = rulesByListing.get(listingId) || [];
    const listingOverrides = overrides.filter((o) => o.listingId === listingId);

    for (const date of dates) {
      const key = `${listingId}:${date}`;
      const booking = bookedByListingDate.get(key);

      if (booking) {
        cellsData[key] = {
          kind: "booked",
          requested: booking.requested,
          guestName: booking.guestName ?? undefined,
        };
        continue;
      }
      if (blockedDates.has(date)) {
        cellsData[key] = { kind: "blocked" };
        continue;
      }

      const dateObj = new Date(date + "T00:00:00");
      const { price, source } = resolveNightlyPrice(
        dateObj,
        basePrice,
        listingRules,
        listingOverrides,
      );
      cellsData[key] = {
        kind: "available",
        price,
        source,
      };
    }

    return {
      id: listingId,
      title: listing.title as string,
      thumbnail: ((listing.images as string[] | null) || [])[0],
      basePrice,
    };
  });

  return (
    <Container className="py-8 lg:py-10">
      <Link
        href={{ pathname: "/dashboard", query: { tab: "listings" } }}
        className="inline-flex items-center gap-1.5 text-sm text-neutral-500 hover:text-neutral-700"
      >
        <ArrowLeft className="h-4 w-4" />
        {tDash("myListings")}
      </Link>

      <div className="mt-4 mb-6">
        <h1 className="text-2xl font-semibold text-neutral-900">{t("title")}</h1>
        <p className="mt-1 text-sm text-neutral-500">{t("description")}</p>
      </div>

      <HostCalendarGrid
        listings={calendarListings}
        dates={dates}
        cells={cellsData}
      />
    </Container>
  );
}
