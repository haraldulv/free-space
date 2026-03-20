"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { CalendarOff } from "lucide-react";
import { getBookings } from "@/lib/utils/bookings";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";
import BookingCard from "@/components/features/BookingCard";
import { Booking } from "@/types";

export default function DashboardPage() {
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    setBookings(getBookings());
    setLoaded(true);
  }, []);

  if (!loaded) return null;

  return (
    <Container className="py-10">
      <h1 className="text-2xl font-bold text-neutral-900">Mine bestillinger</h1>

      {bookings.length === 0 ? (
        <div className="mt-16 flex flex-col items-center text-center">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-neutral-100">
            <CalendarOff className="h-8 w-8 text-neutral-400" />
          </div>
          <h2 className="mt-4 text-lg font-semibold text-neutral-700">
            Ingen bestillinger ennå
          </h2>
          <p className="mt-1 text-sm text-neutral-500">
            Begynn å utforske og bestill din første parkering- eller campingplass.
          </p>
          <Link href="/" className="mt-6">
            <Button>Utforsk plasser</Button>
          </Link>
        </div>
      ) : (
        <div className="mt-6 space-y-4">
          {bookings.map((booking) => (
            <BookingCard key={booking.id} booking={booking} />
          ))}
        </div>
      )}
    </Container>
  );
}
