"use client";

import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import Link from "next/link";
import {
  CalendarCheck,
  CalendarOff,
  Plus,
  Building2,
  Heart,
  Megaphone,
  MessageCircle,
  Settings,
  Inbox,
  TrendingUp,
  DollarSign,
  Clock,
  ArrowUpRight,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { deleteListingAction, toggleListingActiveAction } from "@/app/[locale]/(main)/bli-utleier/actions";
import { cancelBookingAction } from "@/app/[locale]/(main)/book/actions";
import { getConversations } from "@/lib/supabase/chat";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";
import BookingCard from "@/components/features/BookingCard";
import HostListingCard from "@/components/features/HostListingCard";
import SettingsPanel from "@/components/features/SettingsPanel";
import ConversationList from "@/components/features/ConversationList";
import ChatView from "@/components/features/ChatView";
import { Booking, Listing, Conversation } from "@/types";

type Tab = "bookings" | "rentals" | "earnings" | "favorites" | "listings" | "messages" | "settings";

const allSidebarItems: { key: Tab; label: string; icon: React.ElementType; hostOnly?: boolean }[] = [
  { key: "bookings", label: "Mine bestillinger", icon: CalendarCheck },
  { key: "rentals", label: "Utleie", icon: Inbox, hostOnly: true },
  { key: "earnings", label: "Inntekter", icon: TrendingUp, hostOnly: true },
  { key: "favorites", label: "Favoritter", icon: Heart },
  { key: "messages", label: "Meldinger", icon: MessageCircle },
  { key: "listings", label: "Mine annonser", icon: Megaphone },
  { key: "settings", label: "Innstillinger", icon: Settings },
];

function groupBookings(items: Booking[]) {
  const today = new Date().toISOString().split("T")[0];
  const upcoming: Booking[] = [];
  const active: Booking[] = [];
  const past: Booking[] = [];

  for (const b of items) {
    if (b.status === "cancelled") {
      past.push(b);
    } else if (b.checkIn > today) {
      upcoming.push(b);
    } else if (b.checkOut >= today) {
      active.push(b);
    } else {
      past.push(b);
    }
  }

  return { upcoming, active, past };
}

function BookingSection({ title, items, variant = "guest", onCancel }: {
  title: string;
  items: Booking[];
  variant?: "guest" | "host";
  onCancel?: (id: string, reason?: string) => Promise<void>;
}) {
  if (items.length === 0) return null;
  return (
    <div>
      <h3 className="mb-3 text-sm font-medium text-neutral-500">{title}</h3>
      <div className="space-y-3">
        {items.map((b) => (
          <BookingCard key={b.id} booking={b} variant={variant} onCancel={onCancel} />
        ))}
      </div>
    </div>
  );
}

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
    vehicleType: (row.vehicle_type as Listing["vehicleType"]) || "motorhome",
    instantBooking: row.instant_booking as boolean | undefined,
    isActive: row.is_active as boolean | undefined,
    blockedDates: row.blocked_dates as string[] | undefined,
    checkInTime: (row.check_in_time as string) || "15:00",
    checkOutTime: (row.check_out_time as string) || "11:00",
  };
}

export default function DashboardPage() {
  const searchParams = useSearchParams();
  const tabParam = searchParams.get("tab");
  const conversationIdParam = searchParams.get("conversation");
  const initialTab: Tab =
    tabParam === "listings" || tabParam === "annonser" ? "listings"
    : tabParam === "rentals" ? "rentals"
    : tabParam === "earnings" || tabParam === "inntekter" ? "earnings"
    : tabParam === "favoritter" ? "favorites"
    : tabParam === "meldinger" || tabParam === "messages" || conversationIdParam ? "messages"
    : tabParam === "settings" ? "settings"
    : "bookings";
  const [tab, setTab] = useState<Tab>(initialTab);
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [rentals, setRentals] = useState<Booking[]>([]);
  const [listings, setListings] = useState<Listing[]>([]);
  const [favorites, setFavorites] = useState<Listing[]>([]);
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [selectedConvo, setSelectedConvo] = useState<Conversation | null>(null);
  const [userId, setUserId] = useState<string | null>(null);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) return;

      // Fetch bookings from Supabase
      const { data: bookingRows } = await supabase
        .from("bookings")
        .select("*, listings(title, images, category, city, region, address, lat, lng, check_in_time, check_out_time), host:host_id(full_name, phone, show_phone)")
        .eq("user_id", data.user.id)
        .order("created_at", { ascending: false });

      if (bookingRows) {
        const thirtyMinAgo = new Date(Date.now() - 30 * 60 * 1000).toISOString();

        // Auto-cleanup: delete pending bookings older than 30 minutes
        const stale = bookingRows.filter(
          (row) => row.status === "pending" && row.created_at < thirtyMinAgo
        );
        if (stale.length > 0) {
          await supabase
            .from("bookings")
            .delete()
            .in("id", stale.map((r) => r.id));
        }

        setBookings(
          bookingRows
            .filter((row) => !(row.status === "pending" && row.created_at < thirtyMinAgo))
            .map((row) => ({
              id: row.id,
              listingId: row.listing_id,
              listingTitle: (row.listings as Record<string, unknown>)?.title as string || "Ukjent",
              listingImage: ((row.listings as Record<string, unknown>)?.images as string[])?.[0] || "",
              listingCategory: (row.listings as Record<string, unknown>)?.category as Booking["listingCategory"] || "camping",
              location: `${(row.listings as Record<string, unknown>)?.city || ""}, ${(row.listings as Record<string, unknown>)?.region || ""}`,
              checkIn: row.check_in,
              checkOut: row.check_out,
              totalPrice: row.total_price,
              status: row.status as Booking["status"],
              createdAt: row.created_at,
              paymentStatus: row.payment_status,
              licensePlate: row.license_plate,
              isRentalCar: row.is_rental_car,
              checkInTime: (row.listings as Record<string, unknown>)?.check_in_time as string || "15:00",
              checkOutTime: (row.listings as Record<string, unknown>)?.check_out_time as string || "11:00",
              listingLat: (row.listings as Record<string, unknown>)?.lat as number,
              listingLng: (row.listings as Record<string, unknown>)?.lng as number,
              listingAddress: (row.listings as Record<string, unknown>)?.address as string,
              cancelledAt: row.cancelled_at,
              cancelledBy: row.cancelled_by,
              cancellationReason: row.cancellation_reason,
              refundAmount: row.refund_amount,
              hostName: (row.host as Record<string, unknown>)?.full_name as string || "",
              hostPhone: (row.host as Record<string, unknown>)?.show_phone ? (row.host as Record<string, unknown>)?.phone as string || "" : "",
            }))
        );

        // Look up conversations for guest bookings
        const { data: convoRows } = await supabase
          .from("conversations")
          .select("id, listing_id")
          .eq("guest_id", data.user.id);
        if (convoRows) {
          const convoMap = new Map<string, string>();
          for (const c of convoRows) convoMap.set(c.listing_id, c.id);
          setBookings((prev) => prev.map((b) => ({
            ...b,
            conversationId: convoMap.get(b.listingId) || undefined,
          })));
        }
      }

      // Fetch host rentals (bookings on user's listings)
      const { data: rentalRows } = await supabase
        .from("bookings")
        .select("*, listings(title, images, category, city, region, address, lat, lng, check_in_time, check_out_time), guest:user_id(full_name, avatar_url)")
        .eq("host_id", data.user.id)
        .order("created_at", { ascending: false });

      if (rentalRows) {
        setRentals(
          rentalRows.map((row) => ({
            id: row.id,
            listingId: row.listing_id,
            listingTitle: (row.listings as Record<string, unknown>)?.title as string || "Ukjent",
            listingImage: ((row.listings as Record<string, unknown>)?.images as string[])?.[0] || "",
            listingCategory: (row.listings as Record<string, unknown>)?.category as Booking["listingCategory"] || "camping",
            location: `${(row.listings as Record<string, unknown>)?.city || ""}, ${(row.listings as Record<string, unknown>)?.region || ""}`,
            checkIn: row.check_in,
            checkOut: row.check_out,
            totalPrice: row.total_price,
            status: row.status as Booking["status"],
            createdAt: row.created_at,
            paymentStatus: row.payment_status,
            licensePlate: row.license_plate,
            isRentalCar: row.is_rental_car,
            checkInTime: (row.listings as Record<string, unknown>)?.check_in_time as string || "15:00",
            checkOutTime: (row.listings as Record<string, unknown>)?.check_out_time as string || "11:00",
            listingAddress: (row.listings as Record<string, unknown>)?.address as string,
            guestName: (row.guest as Record<string, unknown>)?.full_name as string || "Anonym",
            guestAvatar: (row.guest as Record<string, unknown>)?.avatar_url as string || "",
            guestEmail: (row.guest as Record<string, unknown>)?.email as string || "",
            cancelledAt: row.cancelled_at,
            cancelledBy: row.cancelled_by,
            cancellationReason: row.cancellation_reason,
            refundAmount: row.refund_amount,
          }))
        );
      }

      // Fetch host listings
      const { data: rows } = await supabase
        .from("listings")
        .select("*")
        .eq("host_id", data.user.id)
        .order("created_at", { ascending: false });
      if (rows) setListings(rows.map((r) => rowToListing(r as Record<string, unknown>)));

      // Fetch favorites
      const { data: favRows } = await supabase
        .from("favorites")
        .select("listing_id, listings(*)")
        .eq("user_id", data.user.id)
        .order("created_at", { ascending: false });
      if (favRows) {
        setFavorites(
          favRows
            .filter((r) => r.listings)
            .map((r) => rowToListing(r.listings as unknown as Record<string, unknown>))
        );
      }

      // Fetch conversations
      setUserId(data.user.id);
      const convos = await getConversations(data.user.id);
      setConversations(convos);

      // Auto-select conversation from URL param
      if (conversationIdParam) {
        const match = convos.find((c) => c.id === conversationIdParam);
        if (match) {
          setSelectedConvo(match);
        } else {
          const { data: convoRow } = await supabase
            .from("conversations")
            .select(`*, guest:guest_id(full_name, avatar_url), host:host_id(full_name, avatar_url), listing:listing_id(title, images)`)
            .eq("id", conversationIdParam)
            .single();

          if (convoRow) {
            const isGuest = convoRow.guest_id === data.user.id;
            const otherUser = isGuest ? (convoRow.host as Record<string, unknown>) : (convoRow.guest as Record<string, unknown>);
            const listing = convoRow.listing as Record<string, unknown> | null;
            const newConvo: Conversation = {
              id: convoRow.id,
              listingId: convoRow.listing_id,
              guestId: convoRow.guest_id,
              hostId: convoRow.host_id,
              bookingId: convoRow.booking_id,
              lastMessageAt: convoRow.last_message_at,
              createdAt: convoRow.created_at,
              otherUserName: (otherUser?.full_name as string) || "Anonym",
              otherUserAvatar: (otherUser?.avatar_url as string) || "",
              listingTitle: (listing?.title as string) || "",
              listingImage: ((listing?.images as string[]) || [])[0] || "",
              lastMessageText: "",
              unreadCount: 0,
            };
            setConversations((prev) => [newConvo, ...prev]);
            setSelectedConvo(newConvo);
          }
        }
      }

      setLoaded(true);
    });
  }, [conversationIdParam]);

  const isHost = listings.length > 0 || rentals.length > 0;
  const sidebarItems = allSidebarItems.filter((item) => !item.hostOnly || isHost);

  const handleTabChange = (item: typeof sidebarItems[number]) => {
    setTab(item.key);
  };

  const handleCancelBooking = async (bookingId: string, reason?: string) => {
    const result = await cancelBookingAction(bookingId, reason);
    if (result.error) {
      alert(result.error);
      return;
    }
    setBookings((prev) =>
      prev.map((b) => (b.id === bookingId ? { ...b, status: "cancelled" as const, paymentStatus: "refunded" as const, refundAmount: result.refundAmount, cancelledBy: "guest" as const } : b))
    );
  };

  const handleCancelRental = async (bookingId: string, reason?: string) => {
    const result = await cancelBookingAction(bookingId, reason);
    if (result.error) {
      alert(result.error);
      return;
    }
    setRentals((prev) =>
      prev.map((b) => (b.id === bookingId ? { ...b, status: "cancelled" as const, paymentStatus: "refunded" as const, refundAmount: result.refundAmount, cancelledBy: "host" as const } : b))
    );
  };

  const handleDelete = async (id: string) => {
    try {
      await deleteListingAction(id);
      setListings((prev) => prev.filter((l) => l.id !== id));
    } catch (err) {
      alert(err instanceof Error ? err.message : "Kunne ikke slette");
    }
  };

  const handleToggleActive = async (id: string, isActive: boolean) => {
    const result = await toggleListingActiveAction(id, isActive);
    if (result.error) {
      alert(result.error);
      return;
    }
    setListings((prev) =>
      prev.map((l) => (l.id === id ? { ...l, isActive } : l))
    );
  };

  if (!loaded) {
    return (
      <div className="min-h-screen bg-neutral-50">
        <Container className="py-10">
          <div className="animate-pulse space-y-4">
            <div className="h-8 w-48 rounded bg-neutral-200" />
            <div className="h-64 rounded-xl bg-neutral-200" />
          </div>
        </Container>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-neutral-50">
      <Container className="py-8 lg:py-10">
        <h1 className="text-2xl font-semibold text-neutral-900">Dashboard</h1>

        <div className="mt-6 flex flex-col lg:flex-row lg:gap-10">
          {/* Sidebar — desktop */}
          <nav className="hidden lg:block w-56 shrink-0">
            <ul className="space-y-1">
              {sidebarItems.map((item) => {
                const Icon = item.icon;
                const isActive = tab === item.key;
                const unread = item.key === "messages" ? conversations.reduce((sum, c) => sum + (c.unreadCount || 0), 0) : 0;
                return (
                  <li key={item.key}>
                    <button
                      onClick={() => handleTabChange(item)}
                      className={`flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${
                        isActive
                          ? "bg-primary-50 text-primary-700"
                          : "text-neutral-600 hover:bg-neutral-100 hover:text-neutral-900"
                      }`}
                    >
                      <Icon className={`h-[18px] w-[18px] ${isActive ? "text-primary-600" : "text-neutral-400"}`} />
                      {item.label}
                      {unread > 0 && (
                        <span className="ml-auto flex h-5 min-w-[20px] items-center justify-center rounded-full bg-red-500 px-1.5 text-[10px] font-bold text-white">
                          {unread}
                        </span>
                      )}
                    </button>
                  </li>
                );
              })}
            </ul>
          </nav>

          {/* Mobile tabs */}
          <div className="flex gap-1 border-b border-neutral-200 overflow-x-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden lg:hidden">
            {sidebarItems.map((item) => {
              const isActive = tab === item.key;
              const unread = item.key === "messages" ? conversations.reduce((sum, c) => sum + (c.unreadCount || 0), 0) : 0;
              return (
                <button
                  key={item.key}
                  onClick={() => handleTabChange(item)}
                  className={`relative px-4 py-3 text-sm font-medium whitespace-nowrap transition-colors ${
                    isActive
                      ? "border-b-2 border-primary-600 text-primary-600"
                      : "text-neutral-500 hover:text-neutral-700"
                  }`}
                >
                  {item.label}
                  {unread > 0 && (
                    <span className="ml-1.5 inline-flex h-4 min-w-[16px] items-center justify-center rounded-full bg-red-500 px-1 text-[9px] font-bold text-white">
                      {unread}
                    </span>
                  )}
                </button>
              );
            })}
          </div>

          {/* Content */}
          <div className="flex-1 min-w-0">
            {/* Bookings */}
            {tab === "bookings" && (
              <>
                {bookings.length === 0 ? (
                  <div className="mt-12 lg:mt-16 flex flex-col items-center text-center">
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
                  <div className="mt-4 lg:mt-0 space-y-6">
                    {(() => {
                      const { upcoming, active, past } = groupBookings(bookings);
                      return (
                        <>
                          <BookingSection title="Aktive" items={active} onCancel={handleCancelBooking} />
                          <BookingSection title="Kommende" items={upcoming} onCancel={handleCancelBooking} />
                          <BookingSection title="Tidligere" items={past} onCancel={handleCancelBooking} />
                        </>
                      );
                    })()}
                  </div>
                )}
              </>
            )}

            {/* Rentals (host incoming bookings) */}
            {tab === "rentals" && (
              <>
                {rentals.length === 0 ? (
                  <div className="mt-12 lg:mt-16 flex flex-col items-center text-center">
                    <div className="flex h-16 w-16 items-center justify-center rounded-full bg-neutral-100">
                      <Inbox className="h-8 w-8 text-neutral-400" />
                    </div>
                    <h2 className="mt-4 text-lg font-semibold text-neutral-700">
                      Ingen utleie ennå
                    </h2>
                    <p className="mt-1 text-sm text-neutral-500">
                      Når noen booker en av plassene dine, dukker det opp her.
                    </p>
                  </div>
                ) : (
                  <div className="mt-4 lg:mt-0 space-y-6">
                    {(() => {
                      const { upcoming, active, past } = groupBookings(rentals);
                      return (
                        <>
                          <BookingSection title="Aktive" items={active} variant="host" onCancel={handleCancelRental} />
                          <BookingSection title="Kommende" items={upcoming} variant="host" onCancel={handleCancelRental} />
                          <BookingSection title="Tidligere" items={past} variant="host" />
                        </>
                      );
                    })()}
                  </div>
                )}
              </>
            )}

            {/* Earnings */}
            {tab === "earnings" && <EarningsTab rentals={rentals} listings={listings} />}

            {/* Favorites */}
            {tab === "favorites" && (
              <>
                {favorites.length === 0 ? (
                  <div className="mt-12 lg:mt-16 flex flex-col items-center text-center">
                    <div className="flex h-16 w-16 items-center justify-center rounded-full bg-neutral-100">
                      <Heart className="h-8 w-8 text-neutral-400" />
                    </div>
                    <h2 className="mt-4 text-lg font-semibold text-neutral-700">
                      Ingen favoritter ennå
                    </h2>
                    <p className="mt-1 text-sm text-neutral-500">
                      Trykk på hjertet på en annonse for å lagre den her.
                    </p>
                    <Link href="/search" className="mt-6">
                      <Button>Utforsk plasser</Button>
                    </Link>
                  </div>
                ) : (
                  <div className="mt-4 lg:mt-0 grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
                    {favorites.map((listing) => (
                      <Link key={listing.id} href={`/listings/${listing.id}`} className="group">
                        <div className="overflow-hidden rounded-xl border border-neutral-200 bg-white transition-all hover:shadow-md">
                          <div className="aspect-[7/5] relative overflow-hidden">
                            {listing.images[0] && (
                              <img
                                src={listing.images[0]}
                                alt={listing.title}
                                className="h-full w-full object-cover transition-transform group-hover:scale-105"
                              />
                            )}
                          </div>
                          <div className="p-3">
                            <h3 className="text-sm font-medium text-neutral-900 line-clamp-1">{listing.title}</h3>
                            <p className="text-xs text-neutral-500">{listing.location.city}, {listing.location.region}</p>
                            <p className="mt-1 text-sm">
                              <span className="font-semibold">{listing.price} kr</span>
                              <span className="text-neutral-500"> / {listing.priceUnit === "time" ? "time" : "natt"}</span>
                            </p>
                          </div>
                        </div>
                      </Link>
                    ))}
                  </div>
                )}
              </>
            )}

            {/* Listings */}
            {tab === "listings" && (
              <>
                <div className="mt-4 lg:mt-0 flex items-center justify-between">
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
                        onToggleActive={handleToggleActive}
                      />
                    ))}
                  </div>
                )}
              </>
            )}

            {/* Messages */}
            {tab === "messages" && (
              <div className="mt-4 lg:mt-0">
                <div className="overflow-hidden rounded-xl border border-neutral-200 bg-white" style={{ height: "min(600px, calc(100vh - 220px))" }}>
                  <div className="flex h-full">
                    <div className={`${selectedConvo ? "hidden lg:block" : ""} w-full lg:w-80 border-r border-neutral-200 overflow-y-auto`}>
                      <ConversationList
                        conversations={conversations}
                        selectedId={selectedConvo?.id}
                        onSelect={setSelectedConvo}
                      />
                    </div>
                    <div className={`${selectedConvo ? "" : "hidden lg:flex"} flex-1 flex flex-col`}>
                      {selectedConvo && userId ? (
                        <ChatView
                          conversationId={selectedConvo.id}
                          currentUserId={userId}
                          otherUserName={selectedConvo.otherUserName || "Anonym"}
                          listingTitle={selectedConvo.listingTitle || ""}
                          onBack={() => setSelectedConvo(null)}
                        />
                      ) : (
                        <div className="flex flex-1 items-center justify-center text-sm text-neutral-400">
                          Velg en samtale
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            )}

            {/* Settings */}
            {tab === "settings" && (
              <div className="mt-4 lg:mt-0">
                <SettingsPanel />
              </div>
            )}
          </div>
        </div>
      </Container>
    </div>
  );
}

const SERVICE_FEE = 0.10;

function EarningsTab({ rentals, listings }: { rentals: Booking[]; listings: Listing[] }) {
  const confirmedRentals = rentals.filter((r) => r.status === "confirmed" && r.paymentStatus === "paid");
  const transferredRentals = rentals.filter((r) => r.paymentStatus === "paid");

  const totalRevenue = confirmedRentals.reduce((sum, r) => sum + r.totalPrice, 0);
  const hostShare = Math.round(totalRevenue * (1 - SERVICE_FEE));
  const platformFee = totalRevenue - hostShare;

  const now = new Date();
  const thisMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
  const thisMonthEarnings = confirmedRentals
    .filter((r) => r.createdAt?.startsWith(thisMonth))
    .reduce((sum, r) => sum + Math.round(r.totalPrice * (1 - SERVICE_FEE)), 0);

  // Monthly earnings (last 6 months)
  const months: { label: string; key: string }[] = [];
  for (let i = 5; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    months.push({
      label: d.toLocaleDateString("nb-NO", { month: "short" }),
      key: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`,
    });
  }
  const monthlyData = months.map((m) => {
    const mRentals = confirmedRentals.filter((r) => r.createdAt?.startsWith(m.key));
    const earnings = mRentals.reduce((sum, r) => sum + Math.round(r.totalPrice * (1 - SERVICE_FEE)), 0);
    return { ...m, earnings, count: mRentals.length };
  });
  const maxEarnings = Math.max(...monthlyData.map((m) => m.earnings), 1);

  // Per-listing breakdown
  const listingEarnings = new Map<string, { title: string; image: string; earnings: number; count: number }>();
  for (const r of confirmedRentals) {
    const existing = listingEarnings.get(r.listingId) || { title: r.listingTitle, image: r.listingImage || "", earnings: 0, count: 0 };
    existing.earnings += Math.round(r.totalPrice * (1 - SERVICE_FEE));
    existing.count += 1;
    listingEarnings.set(r.listingId, existing);
  }
  const listingBreakdown = Array.from(listingEarnings.entries())
    .sort((a, b) => b[1].earnings - a[1].earnings);

  return (
    <div className="mt-4 lg:mt-0 space-y-6">
      {/* Stat cards */}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <div className="rounded-xl border border-neutral-200 bg-white p-4">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-green-50 text-green-600">
              <DollarSign className="h-5 w-5" />
            </div>
            <div>
              <p className="text-xs text-neutral-500">Totalt tjent</p>
              <p className="text-lg font-bold text-neutral-900">{hostShare.toLocaleString("nb-NO")} kr</p>
            </div>
          </div>
          <p className="mt-2 text-xs text-neutral-400">{platformFee.toLocaleString("nb-NO")} kr i plattformavgift</p>
        </div>
        <div className="rounded-xl border border-neutral-200 bg-white p-4">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
              <TrendingUp className="h-5 w-5" />
            </div>
            <div>
              <p className="text-xs text-neutral-500">Denne måneden</p>
              <p className="text-lg font-bold text-neutral-900">{thisMonthEarnings.toLocaleString("nb-NO")} kr</p>
            </div>
          </div>
        </div>
        <div className="rounded-xl border border-neutral-200 bg-white p-4">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-green-50 text-green-600">
              <ArrowUpRight className="h-5 w-5" />
            </div>
            <div>
              <p className="text-xs text-neutral-500">Bookings</p>
              <p className="text-lg font-bold text-neutral-900">{confirmedRentals.length}</p>
            </div>
          </div>
        </div>
        <div className="rounded-xl border border-neutral-200 bg-white p-4">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-amber-50 text-amber-600">
              <Clock className="h-5 w-5" />
            </div>
            <div>
              <p className="text-xs text-neutral-500">Aktive annonser</p>
              <p className="text-lg font-bold text-neutral-900">{listings.filter((l) => l.isActive).length}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Monthly chart */}
      <div className="rounded-xl border border-neutral-200 bg-white p-5">
        <h3 className="flex items-center gap-2 text-sm font-semibold text-neutral-700">
          <TrendingUp className="h-4 w-4 text-primary-600" />
          Månedlig inntekt
        </h3>
        <div className="mt-4 flex items-end gap-3 h-44">
          {monthlyData.map((m) => (
            <div key={m.key} className="flex flex-1 flex-col items-center gap-1">
              <span className="text-xs font-medium text-neutral-700">
                {m.earnings > 0 ? `${m.earnings.toLocaleString("nb-NO")}` : ""}
              </span>
              <div
                className="w-full max-w-10 rounded-t-md bg-primary-500 transition-all"
                style={{ height: `${Math.max((m.earnings / maxEarnings) * 120, m.earnings > 0 ? 4 : 0)}px` }}
              />
              <span className="text-xs text-neutral-400">{m.label}</span>
              {m.count > 0 && <span className="text-[10px] text-neutral-300">{m.count} booking{m.count > 1 ? "s" : ""}</span>}
            </div>
          ))}
        </div>
      </div>

      {/* Per-listing breakdown */}
      <div className="rounded-xl border border-neutral-200 bg-white p-5">
        <h3 className="text-sm font-semibold text-neutral-700">Inntekt per annonse</h3>
        <div className="mt-4 space-y-4">
          {listingBreakdown.length === 0 ? (
            <p className="text-sm text-neutral-400">Ingen inntekter ennå</p>
          ) : (
            listingBreakdown.map(([id, data]) => (
              <div key={id} className="flex items-center gap-4">
                {data.image ? (
                  <img src={data.image} alt="" className="h-12 w-12 rounded-lg object-cover" />
                ) : (
                  <div className="h-12 w-12 rounded-lg bg-neutral-100" />
                )}
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-neutral-700 truncate">{data.title}</p>
                  <p className="text-xs text-neutral-400">{data.count} booking{data.count > 1 ? "s" : ""}</p>
                  <div className="mt-1 h-1.5 w-full rounded-full bg-neutral-100">
                    <div
                      className="h-1.5 rounded-full bg-primary-500"
                      style={{ width: `${(data.earnings / (listingBreakdown[0]?.[1]?.earnings || 1)) * 100}%` }}
                    />
                  </div>
                </div>
                <span className="text-sm font-bold text-neutral-900">{data.earnings.toLocaleString("nb-NO")} kr</span>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Recent payouts */}
      <div className="rounded-xl border border-neutral-200 bg-white p-5">
        <h3 className="text-sm font-semibold text-neutral-700">Siste bookings</h3>
        <div className="mt-3 divide-y divide-neutral-100">
          {transferredRentals.slice(0, 10).map((r) => {
            const hostAmount = Math.round(r.totalPrice * (1 - SERVICE_FEE));
            return (
              <div key={r.id} className="flex items-center justify-between py-3">
                <div>
                  <p className="text-sm font-medium text-neutral-700">{r.listingTitle}</p>
                  <p className="text-xs text-neutral-400">
                    {r.guestName || "Gjest"} · {new Date(r.checkIn).toLocaleDateString("nb-NO")} – {new Date(r.checkOut).toLocaleDateString("nb-NO")}
                  </p>
                </div>
                <div className="text-right">
                  <p className="text-sm font-semibold">{hostAmount.toLocaleString("nb-NO")} kr</p>
                  <span className={`text-xs ${r.status === "confirmed" ? "text-green-600" : "text-red-500"}`}>
                    {r.status === "confirmed" ? "Bekreftet" : "Kansellert"}
                  </span>
                </div>
              </div>
            );
          })}
          {transferredRentals.length === 0 && (
            <p className="py-4 text-sm text-neutral-400">Ingen bookings ennå</p>
          )}
        </div>
      </div>
    </div>
  );
}
