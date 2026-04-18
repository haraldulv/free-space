import { notFound, redirect } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { createClient } from "@/lib/supabase/server";
import Container from "@/components/ui/Container";
import { SpotAvailabilityPanel } from "./SpotAvailabilityPanel";
import type { SpotMarker } from "@/types";

export default async function SpotDetailPage({
  params,
}: {
  params: Promise<{ id: string; spotId: string; locale: string }>;
}) {
  const { id, spotId, locale } = await params;
  const t = await getTranslations({ locale, namespace: "hostStats" });

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/${locale}/login?redirectTo=/dashboard/annonse/${id}/plass/${spotId}`);

  const { data: listing } = await supabase
    .from("listings")
    .select("id, title, host_id, spot_markers")
    .eq("id", id)
    .single();

  if (!listing) notFound();
  if (listing.host_id !== user.id) {
    redirect(`/${locale}/dashboard?tab=listings`);
  }

  const spotMarkers = (listing.spot_markers as SpotMarker[] | null) || [];
  const spot = spotMarkers.find((s) => s.id === spotId);
  if (!spot) notFound();

  const today = new Date().toISOString().split("T")[0];
  const { data: bookingRows } = await supabase
    .from("bookings")
    .select("id, check_in, check_out, status, total_price, selected_spot_ids, guest:user_id(full_name)")
    .eq("listing_id", id)
    .in("status", ["confirmed", "requested"])
    .gte("check_out", today)
    .order("check_in", { ascending: true });

  const spotBookings = (bookingRows || []).filter((b) =>
    ((b.selected_spot_ids as string[] | null) || []).includes(spotId),
  );

  // Datoer som er booket av faktiske bookinger (ikke manuell blokkering)
  const bookedDateSet = new Set<string>();
  for (const b of spotBookings) {
    const start = new Date(b.check_in as string);
    const end = new Date(b.check_out as string);
    const cursor = new Date(start);
    while (cursor < end) {
      bookedDateSet.add(
        `${cursor.getFullYear()}-${String(cursor.getMonth() + 1).padStart(2, "0")}-${String(cursor.getDate()).padStart(2, "0")}`,
      );
      cursor.setDate(cursor.getDate() + 1);
    }
  }

  return (
    <Container className="py-8 lg:py-10">
      <Link
        href={`/dashboard/annonse/${id}`}
        className="inline-flex items-center gap-1.5 text-sm text-neutral-500 hover:text-neutral-700"
      >
        <ArrowLeft className="h-4 w-4" />
        {listing.title}
      </Link>

      <div className="mt-4">
        <h1 className="text-2xl font-semibold text-neutral-900">
          {spot.label || t("unnamedSpot")}
        </h1>
        <p className="mt-1 text-sm text-neutral-500">
          {spot.price ? t("pricePerNight", { kr: spot.price }) : t("usesListingPrice")}
        </p>
      </div>

      <div className="mt-8 grid grid-cols-1 gap-8 lg:grid-cols-2">
        <SpotAvailabilityPanel
          listingId={id}
          spotId={spotId}
          initialBlockedDates={spot.blockedDates || []}
          bookedDates={Array.from(bookedDateSet).sort()}
        />

        <div>
          <h2 className="text-lg font-semibold text-neutral-900">{t("upcomingForSpot")}</h2>
          {spotBookings.length === 0 ? (
            <p className="mt-2 text-sm text-neutral-500">{t("noUpcomingForSpot")}</p>
          ) : (
            <ul className="mt-4 space-y-2">
              {spotBookings.map((b) => {
                const guestRow = b.guest as unknown as { full_name?: string } | { full_name?: string }[] | null;
                const guestObj = Array.isArray(guestRow) ? guestRow[0] : guestRow;
                const guestName = guestObj?.full_name || t("anonymousGuest");
                return (
                  <li
                    key={b.id as string}
                    className="rounded-lg border border-neutral-200 bg-white p-3"
                  >
                    <div className="flex items-baseline justify-between">
                      <p className="font-medium text-neutral-900">{guestName}</p>
                      <span className="text-sm font-semibold">
                        {(b.total_price as number).toLocaleString("nb-NO")} kr
                      </span>
                    </div>
                    <p className="mt-0.5 text-sm text-neutral-500">
                      {b.check_in as string} → {b.check_out as string}
                      {b.status === "requested" && (
                        <span className="ml-2 rounded-full bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-800">
                          {t("statusRequested")}
                        </span>
                      )}
                    </p>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      </div>
    </Container>
  );
}
