"use client";

import { useEffect, useState } from "react";
import { useRouter, useSearchParams, useParams } from "next/navigation";
import { differenceInDays } from "date-fns";
import { createClient } from "@/lib/supabase/client";
import { saveBooking, generateBookingId } from "@/lib/utils/bookings";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";
import BookingSummary from "@/components/features/BookingSummary";
import { ShieldCheck } from "lucide-react";
import type { Listing } from "@/types";

export default function BookPage() {
  const router = useRouter();
  const params = useParams();
  const searchParams = useSearchParams();
  const [listing, setListing] = useState<Listing | null>(null);
  const [loading, setLoading] = useState(true);

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

  const nights = differenceInDays(checkOut, checkIn);
  const subtotal = listing.price * nights;
  const serviceFee = Math.round(subtotal * 0.1);
  const total = subtotal + serviceFee;

  const handleConfirm = () => {
    saveBooking({
      id: generateBookingId(),
      listingId: listing.id,
      listingTitle: listing.title,
      listingImage: listing.images[0],
      listingCategory: listing.category,
      location: `${listing.location.city}, ${listing.location.region}`,
      checkIn: checkIn.toISOString(),
      checkOut: checkOut.toISOString(),
      totalPrice: total,
      status: "confirmed",
      createdAt: new Date().toISOString(),
    });

    router.push("/book/confirmation");
  };

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
            <p className="mt-2 text-sm text-neutral-500">
              Dette er en demo — ingen ekte betaling vil bli gjennomført.
            </p>
            <div className="mt-6 flex items-center gap-2 rounded-lg bg-primary-50 p-3 text-sm text-primary-700">
              <ShieldCheck className="h-5 w-5 shrink-0" />
              Din bestilling er beskyttet av Free Space-garantien.
            </div>
            <Button
              onClick={handleConfirm}
              size="lg"
              className="mt-6 w-full"
            >
              Bekreft og bestill — {total} kr
            </Button>
          </div>
        </div>
      </div>
    </Container>
  );
}
