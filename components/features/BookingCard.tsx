import Image from "next/image";
import { CalendarDays, MapPin, Car, Tent } from "lucide-react";
import Badge from "@/components/ui/Badge";
import { Booking } from "@/types";

interface BookingCardProps {
  booking: Booking;
}

export default function BookingCard({ booking }: BookingCardProps) {
  const CategoryIcon = booking.listingCategory === "parking" ? Car : Tent;
  const checkIn = new Date(booking.checkIn).toLocaleDateString("nb-NO");
  const checkOut = new Date(booking.checkOut).toLocaleDateString("nb-NO");

  return (
    <div className="flex gap-4 rounded-xl border border-neutral-200 bg-white p-4 transition-shadow hover:shadow-sm">
      <div className="relative h-20 w-20 shrink-0 overflow-hidden rounded-lg sm:h-24 sm:w-24">
        <Image
          src={booking.listingImage}
          alt={booking.listingTitle}
          fill
          className="object-cover"
          sizes="96px"
        />
      </div>
      <div className="flex flex-1 flex-col justify-between">
        <div>
          <div className="flex items-center gap-2">
            <Badge variant="primary">
              <CategoryIcon className="mr-1 h-3 w-3" />
              {booking.listingCategory === "parking" ? "Parkering" : "Campingplass"}
            </Badge>
            <Badge
              variant={
                booking.status === "confirmed" ? "primary"
                : booking.status === "pending" ? "secondary"
                : "secondary"
              }
            >
              {booking.status === "confirmed" ? "Bekreftet"
                : booking.status === "pending" ? "Venter"
                : "Kansellert"}
            </Badge>
          </div>
          <h3 className="mt-1 font-semibold text-neutral-900">
            {booking.listingTitle}
          </h3>
        </div>
        <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-neutral-500">
          <span className="flex items-center gap-1">
            <MapPin className="h-3.5 w-3.5" />
            {booking.location}
          </span>
          <span className="flex items-center gap-1">
            <CalendarDays className="h-3.5 w-3.5" />
            {checkIn} – {checkOut}
          </span>
          <span className="font-medium text-neutral-900">
            {booking.totalPrice} kr
          </span>
        </div>
      </div>
    </div>
  );
}
