"use client";

import { useRouter, useSearchParams, useParams } from "next/navigation";
import { differenceInDays } from "date-fns";
import { getListingById } from "@/data/mock-listings";
import { saveBooking, generateBookingId } from "@/lib/utils/bookings";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";
import BookingSummary from "@/components/features/BookingSummary";
import { ShieldCheck } from "lucide-react";

export default function BookPage() {
  const router = useRouter();
  const params = useParams();
  const searchParams = useSearchParams();

  const listing = getListingById(params.listingId as string);
  const checkIn = new Date(searchParams.get("checkIn") || "");
  const checkOut = new Date(searchParams.get("checkOut") || "");

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
