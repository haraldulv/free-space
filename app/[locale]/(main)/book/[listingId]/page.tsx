"use client";

import { useEffect, useState } from "react";
import { useSearchParams, useParams } from "next/navigation";
import { differenceInDays } from "date-fns";
import { loadStripe } from "@stripe/stripe-js";
import { Elements, PaymentElement, useStripe, useElements } from "@stripe/react-stripe-js";
import { useLocale, useTranslations } from "next-intl";
import { useRouter } from "@/i18n/navigation";
import { stripeLocale } from "@/lib/i18n-helpers";
import { createClient } from "@/lib/supabase/client";
import { createBookingAction, previewPriceBreakdownAction } from "../actions";
import type { NightlyPriceEntry } from "@/types";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";
import BookingSummary from "@/components/features/BookingSummary";
import { ShieldCheck, Loader2, Car } from "lucide-react";
import type { Listing, SpotMarker, SelectedExtras } from "@/types";
import { SERVICE_FEE_RATE } from "@/lib/config";

function parseExtrasParam(raw: string | null): { listing: Record<string, number>; spots: Record<string, Record<string, number>> } {
  if (!raw) return { listing: {}, spots: {} };
  try {
    const parsed = JSON.parse(decodeURIComponent(raw));
    return {
      listing: parsed.listing || {},
      spots: parsed.spots || {},
    };
  } catch {
    return { listing: {}, spots: {} };
  }
}

const stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!);

function PaymentForm({ total, bookingId, requiresApproval }: { total: number; bookingId: string; requiresApproval: boolean }) {
  const t = useTranslations("booking");
  const stripe = useStripe();
  const elements = useElements();
  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!stripe || !elements) return;

    setProcessing(true);
    setError("");

    const { error: submitError } = await stripe.confirmPayment({
      elements,
      confirmParams: {
        return_url: `${window.location.origin}/book/confirmation?bookingId=${bookingId}`,
      },
    });

    if (submitError) {
      setError(submitError.message || t("paymentFailedMsg"));
      setProcessing(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <PaymentElement />
      {error && <p className="mt-3 text-sm text-red-600">{error}</p>}
      <div className="mt-6 flex items-center gap-2 rounded-lg bg-primary-50 p-3 text-sm text-primary-700">
        <ShieldCheck className="h-5 w-5 shrink-0" />
        {requiresApproval ? t("tunoGuaranteeRequest") : t("tunoGuarantee")}
      </div>
      <Button
        type="submit"
        size="lg"
        className="mt-4 w-full"
        disabled={!stripe || processing}
      >
        {processing ? (
          <span className="inline-flex items-center gap-2">
            <Loader2 className="h-4 w-4 animate-spin" />
            {t("processing")}
          </span>
        ) : requiresApproval ? (
          t("sendRequestAmount", { amount: total })
        ) : (
          t("payAmount", { amount: total })
        )}
      </Button>
    </form>
  );
}

export default function BookPage() {
  const t = useTranslations("booking");
  const tCommon = useTranslations("common");
  const locale = useLocale();
  const router = useRouter();
  const params = useParams();
  const searchParams = useSearchParams();
  const [listing, setListing] = useState<Listing | null>(null);
  const [loading, setLoading] = useState(true);
  const [clientSecret, setClientSecret] = useState("");
  const [bookingId, setBookingId] = useState("");
  const [requiresApproval, setRequiresApproval] = useState(false);
  const [creatingPayment, setCreatingPayment] = useState(false);
  const [error, setError] = useState("");
  const [licensePlate, setLicensePlate] = useState("");
  const [isRentalCar, setIsRentalCar] = useState(false);
  const [vehicleReady, setVehicleReady] = useState(false);
  const [priceBreakdown, setPriceBreakdown] = useState<NightlyPriceEntry[] | null>(null);

  useEffect(() => {
    const supabase = createClient();
    supabase
      .from("listings")
      .select("*")
      .eq("id", params.listingId as string)
      .single()
      .then(({ data }) => {
        if (data) {
          setListing({
            id: data.id,
            title: data.title,
            description: data.description,
            category: data.category,
            images: data.images,
            location: { city: data.city, region: data.region, address: data.address, lat: data.lat, lng: data.lng },
            price: data.price,
            priceUnit: data.price_unit,
            rating: data.rating,
            reviewCount: data.review_count,
            amenities: data.amenities,
            host: { id: data.host_id || "unknown", name: data.host_name, avatar: data.host_avatar, responseRate: data.host_response_rate, responseTime: data.host_response_time, joinedYear: data.host_joined_year, listingsCount: data.host_listings_count },
            maxVehicleLength: data.max_vehicle_length,
            spots: data.spots,
            tags: data.tags,
            checkInTime: data.check_in_time || "15:00",
            checkOutTime: data.check_out_time || "11:00",
            spotMarkers: data.spot_markers || [],
            extras: data.extras || [],
          });
        }
        setLoading(false);
      });
  }, [params.listingId]);

  const checkIn = new Date(searchParams.get("checkIn") || "");
  const checkOut = new Date(searchParams.get("checkOut") || "");

  const nights = !isNaN(checkIn.getTime()) && !isNaN(checkOut.getTime())
    ? differenceInDays(checkOut, checkIn)
    : 0;

  const selectedSpotIds = (searchParams.get("spots") || "").split(",").filter(Boolean);
  const extrasFromUrl = parseExtrasParam(searchParams.get("extras"));

  const selectedSpots: SpotMarker[] = (listing?.spotMarkers || []).filter(
    (s) => s.id && selectedSpotIds.includes(s.id),
  );

  const hasPerSpotPricing = selectedSpots.some((s) => s.price != null);
  // Hvis vi har breakdown fra server og ingen per-spot-pricing, bruk den.
  const perNightFromBreakdown = priceBreakdown?.reduce((sum, n) => sum + n.price, 0) ?? null;
  const baseTotal = listing
    ? hasPerSpotPricing
      ? selectedSpots.reduce((sum, s) => sum + (s.price ?? listing.price) * nights, 0)
      : perNightFromBreakdown != null
        ? perNightFromBreakdown * Math.max(1, selectedSpots.length || 1)
        : selectedSpots.length > 0
          ? selectedSpots.reduce((sum, s) => sum + (s.price ?? listing.price) * nights, 0)
          : listing.price * nights
    : 0;

  const listingExtrasTotal = listing
    ? (listing.extras || []).reduce((sum, extra) => {
        const qty = extrasFromUrl.listing[extra.id] || 0;
        return sum + extra.price * (extra.perNight ? nights : 1) * qty;
      }, 0)
    : 0;

  const spotExtrasTotal = selectedSpots.reduce((sum, spot) => {
    const spotQtys = extrasFromUrl.spots[spot.id!] || {};
    return sum + (spot.extras || []).reduce((acc, extra) => {
      const qty = spotQtys[extra.id] || 0;
      return acc + extra.price * (extra.perNight ? nights : 1) * qty;
    }, 0);
  }, 0);

  const subtotal = baseTotal + listingExtrasTotal + spotExtrasTotal;
  const serviceFee = Math.round(subtotal * SERVICE_FEE_RATE);
  const total = subtotal + serviceFee;

  // Build structured selectedExtras for server
  const buildSelectedExtras = (): SelectedExtras => {
    const listingEntries = Object.entries(extrasFromUrl.listing)
      .filter(([, qty]) => qty > 0)
      .map(([id, qty]) => {
        const extra = (listing?.extras || []).find((e) => e.id === id);
        if (!extra) return null;
        return {
          id: extra.id,
          name: extra.name,
          price: extra.price,
          perNight: extra.perNight,
          quantity: qty,
          message: extra.message,
        };
      })
      .filter((x): x is NonNullable<typeof x> => x !== null);

    const spotEntries: Record<string, ReturnType<typeof Object>> = {};
    Object.entries(extrasFromUrl.spots).forEach(([spotId, qtys]) => {
      const spot = selectedSpots.find((s) => s.id === spotId);
      if (!spot) return;
      const entries = Object.entries(qtys as Record<string, number>)
        .filter(([, qty]) => qty > 0)
        .map(([id, qty]) => {
          const extra = (spot.extras || []).find((e) => e.id === id);
          if (!extra) return null;
          return {
            id: extra.id,
            name: extra.name,
            price: extra.price,
            perNight: extra.perNight,
            quantity: qty,
            message: extra.message,
          };
        })
        .filter((x): x is NonNullable<typeof x> => x !== null);
      if (entries.length > 0) spotEntries[spotId] = entries;
    });

    return {
      listing: listingEntries.length > 0 ? listingEntries : undefined,
      spots: Object.keys(spotEntries).length > 0 ? (spotEntries as SelectedExtras["spots"]) : undefined,
    };
  };

  // Hent pris-breakdown fra server når datoer/listing er satt
  useEffect(() => {
    if (!listing || nights <= 0) return;
    const checkInStr = searchParams.get("checkIn");
    const checkOutStr = searchParams.get("checkOut");
    if (!checkInStr || !checkOutStr) return;
    const formatDate = (d: Date) =>
      `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    previewPriceBreakdownAction({
      listingId: listing.id,
      checkIn: formatDate(new Date(checkInStr)),
      checkOut: formatDate(new Date(checkOutStr)),
    }).then((result) => {
      setPriceBreakdown(result.breakdown);
    });
  }, [listing, nights, searchParams]);

  // Create booking + payment intent once vehicle info is submitted
  useEffect(() => {
    if (!listing || nights <= 0 || clientSecret || !vehicleReady) return;

    setCreatingPayment(true);

    const checkInStr = searchParams.get("checkIn")!;
    const checkOutStr = searchParams.get("checkOut")!;

    const checkInDate = new Date(checkInStr);
    const checkOutDate = new Date(checkOutStr);
    const formatDate = (d: Date) =>
      `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

    createBookingAction({
      listingId: listing.id,
      checkIn: formatDate(checkInDate),
      checkOut: formatDate(checkOutDate),
      totalPrice: total,
      licensePlate: isRentalCar ? undefined : licensePlate.trim().toUpperCase(),
      isRentalCar,
      selectedSpotIds: selectedSpotIds.length > 0 ? selectedSpotIds : undefined,
      selectedExtras: buildSelectedExtras(),
    }).then((result) => {
      if (result.error) {
        setError(result.error);
      } else {
        setClientSecret(result.clientSecret!);
        setBookingId(result.bookingId!);
        setRequiresApproval(!!result.requiresApproval);
      }
      setCreatingPayment(false);
    });
  }, [vehicleReady]);

  if (loading) {
    return (
      <Container className="py-10">
        <p className="text-neutral-500">{tCommon("loading")}</p>
      </Container>
    );
  }

  if (!listing || isNaN(checkIn.getTime()) || isNaN(checkOut.getTime())) {
    router.push("/");
    return null;
  }

  if (nights <= 0) {
    return (
      <Container className="py-10">
        <h1 className="text-2xl font-bold text-neutral-900">{t("invalidBooking")}</h1>
        <p className="mt-4 text-neutral-500">
          {t("invalidDatesExplain")}
        </p>
        <Button className="mt-6" onClick={() => router.back()}>
          {t("goBack")}
        </Button>
      </Container>
    );
  }

  return (
    <Container className="py-10">
      <h1 className="text-2xl font-bold text-neutral-900">
        {t("confirmBooking")}
      </h1>
      <div className="mt-8 grid grid-cols-1 gap-8 lg:grid-cols-2">
        <div>
          <BookingSummary
            listing={listing}
            checkIn={checkIn}
            checkOut={checkOut}
            nights={nights}
            baseAmount={baseTotal}
            selectedExtras={buildSelectedExtras()}
            selectedSpotCount={selectedSpots.length || undefined}
            priceBreakdown={priceBreakdown ?? undefined}
            subtotal={subtotal}
            serviceFee={serviceFee}
            total={total}
            checkInTime={listing.checkInTime}
            checkOutTime={listing.checkOutTime}
          />
        </div>
        <div className="space-y-6">
          {/* Vehicle info */}
          {!vehicleReady && (
            <div className="rounded-xl border border-neutral-200 bg-white p-6">
              <h2 className="text-lg font-semibold text-neutral-900">
                {t("vehicle")}
              </h2>
              <p className="mt-1 text-sm text-neutral-500">
                {t("vehicleExplain")}
              </p>
              <div className="mt-4 space-y-4">
                {!isRentalCar && (
                  <div>
                    <label htmlFor="licensePlate" className="mb-1.5 block text-sm font-medium text-neutral-700">
                      {t("licensePlate")}
                    </label>
                    <div className="relative">
                      <Car className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-neutral-400" />
                      <input
                        id="licensePlate"
                        type="text"
                        value={licensePlate}
                        onChange={(e) => setLicensePlate(e.target.value.toUpperCase())}
                        placeholder={t("licensePlatePlaceholder")}
                        className="w-full rounded-lg border border-neutral-200 py-2.5 pl-10 pr-3 text-sm uppercase tracking-wider placeholder:normal-case placeholder:tracking-normal focus:border-primary-500 focus:ring-1 focus:ring-primary-500 focus:outline-none"
                      />
                    </div>
                  </div>
                )}
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={isRentalCar}
                    onChange={(e) => setIsRentalCar(e.target.checked)}
                    className="h-4 w-4 rounded border-neutral-300 text-primary-600 focus:ring-primary-500"
                  />
                  <span className="text-sm text-neutral-600">
                    {t("rentalCarLabel")}
                  </span>
                </label>
                <Button
                  className="w-full"
                  disabled={!isRentalCar && !licensePlate.trim()}
                  onClick={() => setVehicleReady(true)}
                >
                  {t("continueToPayment")}
                </Button>
              </div>
            </div>
          )}

          {/* Payment */}
          <div className={`rounded-xl border border-neutral-200 bg-white p-6 ${!vehicleReady ? "opacity-50 pointer-events-none" : ""}`}>
            <h2 className="text-lg font-semibold text-neutral-900">
              {t("payment")}
            </h2>

            {error && (
              <p className="mt-3 text-sm text-red-600">{error}</p>
            )}

            {creatingPayment && !error && (
              <div className="mt-6 flex items-center justify-center gap-2 py-8 text-sm text-neutral-500">
                <Loader2 className="h-5 w-5 animate-spin" />
                {t("preparingPayment")}
              </div>
            )}

            {clientSecret && (
              <div className="mt-6">
                <Elements
                  stripe={stripePromise}
                  options={{
                    clientSecret,
                    appearance: {
                      theme: "stripe",
                      variables: {
                        colorPrimary: "#46C185",
                        fontFamily: "DM Sans, system-ui, sans-serif",
                        borderRadius: "8px",
                      },
                    },
                    locale: stripeLocale(locale),
                  }}
                >
                  <PaymentForm total={total} bookingId={bookingId} requiresApproval={requiresApproval} />
                </Elements>
              </div>
            )}
          </div>
        </div>
      </div>
    </Container>
  );
}
