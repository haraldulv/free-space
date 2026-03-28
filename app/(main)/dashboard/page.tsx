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
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { deleteListingAction, toggleListingActiveAction } from "@/app/(main)/bli-utleier/actions";
import { cancelBookingAction } from "@/app/(main)/book/actions";
import { getConversations } from "@/lib/supabase/chat";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";
import BookingCard from "@/components/features/BookingCard";
import HostListingCard from "@/components/features/HostListingCard";
import SettingsPanel from "@/components/features/SettingsPanel";
import ConversationList from "@/components/features/ConversationList";
import ChatView from "@/components/features/ChatView";
import { Booking, Listing, Conversation } from "@/types";

type Tab = "bookings" | "favorites" | "listings" | "messages" | "settings";

const sidebarItems: { key: Tab; label: string; icon: React.ElementType }[] = [
  { key: "bookings", label: "Mine bestillinger", icon: CalendarCheck },
  { key: "favorites", label: "Favoritter", icon: Heart },
  { key: "messages", label: "Meldinger", icon: MessageCircle },
  { key: "listings", label: "Mine annonser", icon: Megaphone },
  { key: "settings", label: "Innstillinger", icon: Settings },
];

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
    : tabParam === "favoritter" ? "favorites"
    : tabParam === "meldinger" || tabParam === "messages" || conversationIdParam ? "messages"
    : tabParam === "settings" ? "settings"
    : "bookings";
  const [tab, setTab] = useState<Tab>(initialTab);
  const [bookings, setBookings] = useState<Booking[]>([]);
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
        .select("*, listings(title, images, category, city, region)")
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

  const handleTabChange = (item: typeof sidebarItems[number]) => {
    setTab(item.key);
  };

  const handleCancelBooking = async (bookingId: string) => {
    const result = await cancelBookingAction(bookingId);
    if (result.error) {
      alert(result.error);
      return;
    }
    setBookings((prev) =>
      prev.map((b) => (b.id === bookingId ? { ...b, status: "cancelled" as const } : b))
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
                  <div className="mt-4 lg:mt-0 space-y-4">
                    {bookings.map((booking) => (
                      <BookingCard key={booking.id} booking={booking} onCancel={handleCancelBooking} />
                    ))}
                  </div>
                )}
              </>
            )}

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
