import Image from "next/image";
import { CalendarDays, MapPin, Clock } from "lucide-react";
import Badge from "@/components/ui/Badge";
import { Listing } from "@/types";

interface BookingSummaryProps {
  listing: Listing;
  checkIn: Date;
  checkOut: Date;
  nights: number;
  subtotal: number;
  serviceFee: number;
  total: number;
  checkInTime?: string;
  checkOutTime?: string;
}

export default function BookingSummary({
  listing,
  checkIn,
  checkOut,
  nights,
  subtotal,
  serviceFee,
  total,
  checkInTime,
  checkOutTime,
}: BookingSummaryProps) {
  const priceLabel = listing.priceUnit === "time" ? "dag" : "natt";

  return (
    <div className="rounded-xl border border-neutral-200 bg-white p-6">
      <div className="flex gap-4">
        <div className="relative h-24 w-24 shrink-0 overflow-hidden rounded-lg">
          <Image
            src={listing.images[0]}
            alt={listing.title}
            fill
            className="object-cover"
            sizes="96px"
          />
        </div>
        <div>
          <Badge>
            {listing.category === "parking" ? "Parkering" : "Campingplass"}
          </Badge>
          <h3 className="mt-1 font-semibold text-neutral-900">
            {listing.title}
          </h3>
          <div className="mt-1 flex items-center gap-1 text-sm text-neutral-500">
            <MapPin className="h-3.5 w-3.5" />
            {listing.location.city}, {listing.location.region}
          </div>
        </div>
      </div>

      <div className="mt-6 space-y-3 border-t border-neutral-100 pt-4">
        <div className="flex items-center gap-2 text-sm text-neutral-600">
          <CalendarDays className="h-4 w-4 text-neutral-400" />
          {checkIn.toLocaleDateString("nb-NO")} –{" "}
          {checkOut.toLocaleDateString("nb-NO")}
        </div>
        <div className="flex items-center gap-2 text-sm text-neutral-500">
          <Clock className="h-4 w-4 text-neutral-400" />
          Innsjekk fra {checkInTime || "15:00"} / Utsjekk innen {checkOutTime || "11:00"}
        </div>
      </div>

      <div className="mt-4 space-y-2 border-t border-neutral-100 pt-4 text-sm">
        <div className="flex justify-between text-neutral-600">
          <span>
            {listing.price} kr &times; {nights}{" "}
            {nights === 1
              ? priceLabel
              : priceLabel === "dag"
              ? "dager"
              : "netter"}
          </span>
          <span>{subtotal} kr</span>
        </div>
        <div className="flex justify-between text-neutral-600">
          <span>Serviceavgift</span>
          <span>{serviceFee} kr</span>
        </div>
        <div className="flex justify-between border-t border-neutral-100 pt-2 text-base font-semibold text-neutral-900">
          <span>Totalt</span>
          <span>{total} kr</span>
        </div>
      </div>
    </div>
  );
}
