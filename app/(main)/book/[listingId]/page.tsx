"use client";

import { useEffect, useState } from "react";
import { useRouter, useSearchParams, useParams } from "next/navigation";
import { differenceInDays } from "date-fns";
import { loadStripe } from "@stripe/stripe-js";
import { Elements, PaymentElement, useStripe, useElements } from "@stripe/react-stripe-js";
import { createClient } from "@/lib/supabase/client";
import { createBookingAction } from "../actions";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";
import BookingSummary from "@/components/features/BookingSummary";
import { ShieldCheck, Loader2 } from "lucide-react";
import type { Listing } from "@/types";

const stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!);

function PaymentForm({ total, bookingId }: { total: number; bookingId: string }) {
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
      setError(submitError.message || "Betalingen feilet");
      setProcessing(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <PaymentElement />
      {error && <p className="mt-3 text-sm text-red-600">{error}</p>}
      <div className="mt-6 flex items-center gap-2 rounded-lg bg-primary-50 p-3 text-sm text-primary-700">
        <ShieldCheck className="h-5 w-5 shrink-0" />
        Din bestilling er beskyttet av Free Space-garantien.
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
            Behandler...
          </span>
        ) : (
          `Betal — ${total} kr`
        )}
      </Button>
    </form>
  );
}

export default function BookPage() {
  const router = useRouter();
  const params = useParams();
  const searchParams = useSearchParams();
  const [listing, setListing] = useState<Listing | null>(null);
  const [loading, setLoading] = useState(true);
  const [clientSecret, setClientSecret] = useState("");
  const [bookingId, setBookingId] = useState("");
  const [creatingPayment, setCreatingPayment] = useState(false);
  const [error, setError] = useState("");

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
  const subtotal = listing ? listing.price * nights : 0;
  const serviceFee = Math.round(subtotal * 0.1);
  const total = subtotal + serviceFee;

  // Create booking + payment intent once listing is loaded
  useEffect(() => {
    if (!listing || nights <= 0 || clientSecret) return;

    setCreatingPayment(true);

    const checkInStr = searchParams.get("checkIn")!;
    const checkOutStr = searchParams.get("checkOut")!;

    // Format dates as YYYY-MM-DD for Supabase date columns
    const checkInDate = new Date(checkInStr);
    const checkOutDate = new Date(checkOutStr);
    const formatDate = (d: Date) =>
      `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

    createBookingAction({
      listingId: listing.id,
      checkIn: formatDate(checkInDate),
      checkOut: formatDate(checkOutDate),
      totalPrice: total,
    }).then((result) => {
      if (result.error) {
        setError(result.error);
      } else {
        setClientSecret(result.clientSecret!);
        setBookingId(result.bookingId!);
      }
      setCreatingPayment(false);
    });
  }, [listing, nights]);

  if (loading) {
    return (
      <Container className="py-10">
        <p className="text-neutral-500">Laster...</p>
      </Container>
    );
  }

  if (!listing || isNaN(checkIn.getTime()) || isNaN(checkOut.getTime())) {
    router.push("/");
    return null;
  }

  return (
    <Container className="py-10">
      <h1 className="text-2xl font-bold text-neutral-900">
        Bekreft bestillingen din
      </h1>
      <div className="mt-8 grid grid-cols-1 gap-8 lg:grid-cols-2">
        <div>
          <BookingSummary
            listing={listing}
            checkIn={checkIn}
            checkOut={checkOut}
            nights={nights}
            subtotal={subtotal}
            serviceFee={serviceFee}
            total={total}
          />
        </div>
        <div>
          <div className="rounded-xl border border-neutral-200 bg-white p-6">
            <h2 className="text-lg font-semibold text-neutral-900">
              Betaling
            </h2>

            {error && (
              <p className="mt-3 text-sm text-red-600">{error}</p>
            )}

            {creatingPayment && (
              <div className="mt-6 flex items-center justify-center gap-2 py-8 text-sm text-neutral-500">
                <Loader2 className="h-5 w-5 animate-spin" />
                Forbereder betaling...
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
                        colorPrimary: "#1a4fd6",
                        fontFamily: "DM Sans, system-ui, sans-serif",
                        borderRadius: "8px",
                      },
                    },
                    locale: "nb",
                  }}
                >
                  <PaymentForm total={total} bookingId={bookingId} />
                </Elements>
              </div>
            )}
          </div>
        </div>
      </div>
    </Container>
  );
}
