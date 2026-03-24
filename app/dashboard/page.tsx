"use client";

import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import Link from "next/link";
import { CalendarOff, Plus, Building2 } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { getBookings } from "@/lib/utils/bookings";
import { deleteListingAction } from "@/app/(main)/bli-utleier/actions";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";
import BookingCard from "@/components/features/BookingCard";
import HostListingCard from "@/components/features/HostListingCard";
import { Booking, Listing } from "@/types";

function rowToListing(row: Record<string, unknown>): Listing {
  return {
    id: row.id as string,
    title: row.title as string,
    description: row.description as string,
    category: row.category as Listing["category"],
    images: row.images as string[],
    location: {
      city: row.city as string,
      region: row.region as string,
      address: row.address as string,
      lat: row.lat as number,
      lng: row.lng as number,
    },
    price: row.price as number,
    priceUnit: row.price_unit as Listing["priceUnit"],
    rating: row.rating as number,
    reviewCount: row.review_count as number,
    amenities: row.amenities as Listing["amenities"],
    host: {
      id: (row.host_id as string) || "unknown",
      name: row.host_name as string,
      avatar: row.host_avatar as string,
      responseRate: row.host_response_rate as number,
      responseTime: row.host_response_time as string,
      joinedYear: row.host_joined_year as number,
      listingsCount: row.host_listings_count as number,
    },
    maxVehicleLength: row.max_vehicle_length as number | undefined,
    spots: row.spots as number,
    tags: row.tags as Listing["tags"],
    instantBooking: row.instant_booking as boolean | undefined,
  };
}

export default function DashboardPage() {
  const searchParams = useSearchParams();
  const initialTab = searchParams.get("tab") === "listings" ? "listings" : "bookings";
  const [tab, setTab] = useState<"bookings" | "listings">(initialTab);
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [listings, setListings] = useState<Listing[]>([]);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    setBookings(getBookings());

    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) return;
      const { data: rows } = await supabase
        .from("listings")
        .select("*")
        .eq("host_id", data.user.id)
        .order("created_at", { ascending: false });
      if (rows) setListings(rows.map((r) => rowToListing(r as Record<string, unknown>)));
      setLoaded(true);
    });
  }, []);

  const handleDelete = async (id: string) => {
    try {
      await deleteListingAction(id);
      setListings((prev) => prev.filter((l) => l.id !== id));
    } catch (err) {
      alert(err instanceof Error ? err.message : "Kunne ikke slette");
    }
  };

  if (!loaded) return null;

  return (
    <Container className="py-10">
      {/* Tabs */}
      <div className="flex gap-1 border-b border-neutral-200">
        <button
          onClick={() => setTab("bookings")}
          className={`px-4 py-2.5 text-sm font-medium transition-colors ${
            tab === "bookings"
              ? "border-b-2 border-primary-600 text-primary-600"
              : "text-neutral-500 hover:text-neutral-700"
          }`}
        >
          Mine bestillinger
        </button>
        <button
          onClick={() => setTab("listings")}
          className={`px-4 py-2.5 text-sm font-medium transition-colors ${
            tab === "listings"
              ? "border-b-2 border-primary-600 text-primary-600"
              : "text-neutral-500 hover:text-neutral-700"
          }`}
        >
          Mine annonser
        </button>
      </div>

      {/* Bookings tab */}
      {tab === "bookings" && (
        <>
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
        </>
      )}

      {/* Listings tab */}
      {tab === "listings" && (
        <>
          <div className="mt-6 flex items-center justify-between">
            <p className="text-sm text-neutral-500">
              {listings.length} {listings.length === 1 ? "annonse" : "annonser"}
            </p>
            <Link href="/bli-utleier">
              <Button size="sm">
                <Plus className="mr-1.5 h-4 w-4" />
                Ny annonse
              </Button>
            </Link>
          </div>

          {listings.length === 0 ? (
            <div className="mt-12 flex flex-col items-center text-center">
              <div className="flex h-16 w-16 items-center justify-center rounded-full bg-neutral-100">
                <Building2 className="h-8 w-8 text-neutral-400" />
              </div>
              <h2 className="mt-4 text-lg font-semibold text-neutral-700">
                Du har ingen annonser ennå
              </h2>
              <p className="mt-1 text-sm text-neutral-500">
                Kom i gang som utleier og begynn å tjene penger på plassen din.
              </p>
              <Link href="/bli-utleier" className="mt-6">
                <Button>Bli utleier</Button>
              </Link>
            </div>
          ) : (
            <div className="mt-4 space-y-3">
              {listings.map((listing) => (
                <HostListingCard
                  key={listing.id}
                  listing={listing}
                  onDelete={handleDelete}
                />
              ))}
            </div>
          )}
        </>
      )}
    </Container>
  );
}
