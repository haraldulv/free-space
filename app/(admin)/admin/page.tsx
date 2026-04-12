"use client";

import { useEffect, useState } from "react";
import { adminDeleteListingAction, adminCancelBookingAction, adminToggleListingAction, loadAdminDataAction, loadMessagesAction } from "./actions";
import {
  CalendarCheck,
  Users,
  Megaphone,
  MessageCircle,
  Trash2,
  XCircle,
  Eye,
  EyeOff,
  ChevronDown,
  Search,
} from "lucide-react";

type Tab = "bookings" | "users" | "listings" | "messages";

interface AdminBooking {
  id: string;
  check_in: string;
  check_out: string;
  total_price: number;
  status: string;
  payment_status: string;
  created_at: string;
  cancelled_by: string | null;
  refund_amount: number | null;
  guest: { full_name: string } | null;
  host: { full_name: string } | null;
  listing: { title: string } | null;
}

interface AdminUser {
  id: string;
  full_name: string | null;
  email: string | null;
  avatar_url: string | null;
  is_admin: boolean;
  created_at: string;
  stripe_account_id: string | null;
  stripe_onboarding_complete: boolean | null;
}

interface AdminListing {
  id: string;
  title: string;
  city: string;
  region: string;
  price: number;
  category: string;
  vehicle_type: string;
  is_active: boolean;
  created_at: string;
  images: string[];
  host: { full_name: string } | null;
}

interface AdminConversation {
  id: string;
  created_at: string;
  last_message_at: string;
  guest: { full_name: string } | null;
  host: { full_name: string } | null;
  listing: { title: string } | null;
  messages?: AdminMessage[];
}

interface AdminMessage {
  id: string;
  content: string;
  created_at: string;
  sender: { full_name: string } | null;
}

const tabs: { key: Tab; label: string; icon: React.ElementType }[] = [
  { key: "bookings", label: "Bookings", icon: CalendarCheck },
  { key: "users", label: "Brukere", icon: Users },
  { key: "listings", label: "Annonser", icon: Megaphone },
  { key: "messages", label: "Meldinger", icon: MessageCircle },
];

export default function AdminPage() {
  const [tab, setTab] = useState<Tab>("bookings");
  const [bookings, setBookings] = useState<AdminBooking[]>([]);
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [listings, setListings] = useState<AdminListing[]>([]);
  const [conversations, setConversations] = useState<AdminConversation[]>([]);
  const [expandedConvo, setExpandedConvo] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    loadAdminDataAction().then((data) => {
      setBookings(data.bookings as unknown as AdminBooking[]);
      setUsers(data.users as unknown as AdminUser[]);
      setListings(data.listings as unknown as AdminListing[]);
      setConversations(data.conversations as unknown as AdminConversation[]);
      setLoaded(true);
    });
  }, []);

  const loadMessages = async (convoId: string) => {
    if (expandedConvo === convoId) {
      setExpandedConvo(null);
      return;
    }
    const data = await loadMessagesAction(convoId);

    setConversations((prev) =>
      prev.map((c) => c.id === convoId ? { ...c, messages: data as unknown as AdminMessage[] } : c)
    );
    setExpandedConvo(convoId);
  };

  const handleCancelBooking = async (bookingId: string) => {
    const reason = prompt("Årsak til kansellering (valgfritt):");
    const result = await adminCancelBookingAction(bookingId, reason || undefined);
    if (result.error) { alert(result.error); return; }
    setBookings((prev) =>
      prev.map((b) => b.id === bookingId ? { ...b, status: "cancelled", cancelled_by: "host", refund_amount: result.refundAmount ?? null } : b)
    );
  };

  const handleDeleteListing = async (listingId: string) => {
    if (!confirm("Er du sikker på at du vil slette denne annonsen?")) return;
    const result = await adminDeleteListingAction(listingId);
    if (result.error) { alert(result.error); return; }
    setListings((prev) => prev.filter((l) => l.id !== listingId));
  };

  const handleToggleListing = async (listingId: string, isActive: boolean) => {
    const result = await adminToggleListingAction(listingId, isActive);
    if (result.error) { alert(result.error); return; }
    setListings((prev) =>
      prev.map((l) => l.id === listingId ? { ...l, is_active: isActive } : l)
    );
  };

  const q = search.toLowerCase();

  if (!loaded) {
    return (
      <div className="mx-auto max-w-7xl px-4 py-10 sm:px-6">
        <div className="animate-pulse space-y-4">
          <div className="h-8 w-48 rounded bg-neutral-200" />
          <div className="h-64 rounded-xl bg-neutral-200" />
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold text-neutral-900">Admin</h1>
        <div className="flex gap-4 text-sm text-neutral-500">
          <span>{bookings.length} bookings</span>
          <span>{users.length} brukere</span>
          <span>{listings.length} annonser</span>
        </div>
      </div>

      {/* Tabs */}
      <div className="mt-6 flex gap-1 border-b border-neutral-200">
        {tabs.map((t) => {
          const Icon = t.icon;
          const isActive = tab === t.key;
          return (
            <button
              key={t.key}
              onClick={() => { setTab(t.key); setSearch(""); }}
              className={`flex items-center gap-2 px-4 py-3 text-sm font-medium transition-colors ${
                isActive
                  ? "border-b-2 border-primary-600 text-primary-600"
                  : "text-neutral-500 hover:text-neutral-700"
              }`}
            >
              <Icon className="h-4 w-4" />
              {t.label}
            </button>
          );
        })}
      </div>

      {/* Search */}
      <div className="mt-4 relative">
        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-neutral-400" />
        <input
          type="text"
          placeholder="Søk..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full rounded-lg border border-neutral-200 py-2.5 pl-10 pr-4 text-sm focus:border-primary-500 focus:outline-none"
        />
      </div>

      {/* Content */}
      <div className="mt-4">
        {/* Bookings */}
        {tab === "bookings" && (
          <div className="overflow-x-auto rounded-xl border border-neutral-200 bg-white">
            <table className="w-full text-sm">
              <thead className="border-b border-neutral-100 bg-neutral-50">
                <tr>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Annonse</th>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Gjest</th>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Utleier</th>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Datoer</th>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Pris</th>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Status</th>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Handlinger</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-100">
                {bookings
                  .filter((b) => !q || (b.listing?.title || "").toLowerCase().includes(q) || (b.guest?.full_name || "").toLowerCase().includes(q) || (b.host?.full_name || "").toLowerCase().includes(q))
                  .map((b) => (
                  <tr key={b.id} className="hover:bg-neutral-50">
                    <td className="px-4 py-3 font-medium">{b.listing?.title || "—"}</td>
                    <td className="px-4 py-3 text-neutral-600">{b.guest?.full_name || "—"}</td>
                    <td className="px-4 py-3 text-neutral-600">{b.host?.full_name || "—"}</td>
                    <td className="px-4 py-3 text-neutral-500">{b.check_in} → {b.check_out}</td>
                    <td className="px-4 py-3">{b.total_price} kr</td>
                    <td className="px-4 py-3">
                      <span className={`inline-flex rounded-full px-2 py-0.5 text-xs font-semibold ${
                        b.status === "confirmed" ? "bg-green-100 text-green-700"
                        : b.status === "pending" ? "bg-amber-100 text-amber-700"
                        : "bg-red-100 text-red-700"
                      }`}>
                        {b.status === "confirmed" ? "Bekreftet" : b.status === "pending" ? "Venter" : "Kansellert"}
                      </span>
                      {b.refund_amount != null && b.status === "cancelled" && (
                        <span className="ml-1 text-xs text-neutral-400">({b.refund_amount} kr refundert)</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      {(b.status === "confirmed" || b.status === "pending") && (
                        <button
                          onClick={() => handleCancelBooking(b.id)}
                          className="flex items-center gap-1 text-xs text-red-500 hover:text-red-700"
                        >
                          <XCircle className="h-3.5 w-3.5" />
                          Kanseller
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Users */}
        {tab === "users" && (
          <div className="overflow-x-auto rounded-xl border border-neutral-200 bg-white">
            <table className="w-full text-sm">
              <thead className="border-b border-neutral-100 bg-neutral-50">
                <tr>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Navn</th>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">E-post</th>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Rolle</th>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Stripe</th>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Registrert</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-100">
                {users
                  .filter((u) => !q || (u.full_name || "").toLowerCase().includes(q) || (u.email || "").toLowerCase().includes(q))
                  .map((u) => (
                  <tr key={u.id} className="hover:bg-neutral-50">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        {u.avatar_url ? (
                          <img src={u.avatar_url} alt="" className="h-7 w-7 rounded-full object-cover" />
                        ) : (
                          <div className="flex h-7 w-7 items-center justify-center rounded-full bg-neutral-200 text-xs font-medium text-neutral-600">
                            {(u.full_name || "?")[0]}
                          </div>
                        )}
                        <span className="font-medium">{u.full_name || "Anonym"}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-neutral-500">{u.email || "—"}</td>
                    <td className="px-4 py-3">
                      <div className="flex gap-1">
                        {u.is_admin && (
                          <span className="rounded-full bg-red-100 px-2 py-0.5 text-xs font-semibold text-red-700">Admin</span>
                        )}
                        {u.stripe_account_id && (
                          <span className="rounded-full bg-blue-100 px-2 py-0.5 text-xs font-semibold text-blue-700">Utleier</span>
                        )}
                        {!u.is_admin && !u.stripe_account_id && (
                          <span className="rounded-full bg-neutral-100 px-2 py-0.5 text-xs font-semibold text-neutral-500">Bruker</span>
                        )}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      {u.stripe_onboarding_complete ? (
                        <span className="text-green-600 text-xs">Aktiv</span>
                      ) : u.stripe_account_id ? (
                        <span className="text-amber-600 text-xs">Ufullstendig</span>
                      ) : (
                        <span className="text-neutral-300 text-xs">—</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-neutral-500">
                      {new Date(u.created_at).toLocaleDateString("nb-NO")}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Listings */}
        {tab === "listings" && (
          <div className="overflow-x-auto rounded-xl border border-neutral-200 bg-white">
            <table className="w-full text-sm">
              <thead className="border-b border-neutral-100 bg-neutral-50">
                <tr>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Annonse</th>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Utleier</th>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Sted</th>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Pris</th>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Type</th>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Status</th>
                  <th className="px-4 py-3 text-left font-medium text-neutral-600">Handlinger</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-100">
                {listings
                  .filter((l) => !q || l.title.toLowerCase().includes(q) || (l.host?.full_name || "").toLowerCase().includes(q) || l.city.toLowerCase().includes(q))
                  .map((l) => (
                  <tr key={l.id} className={`hover:bg-neutral-50 ${!l.is_active ? "opacity-50" : ""}`}>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        {l.images?.[0] ? (
                          <img src={l.images[0]} alt="" className="h-10 w-10 rounded-lg object-cover" />
                        ) : (
                          <div className="h-10 w-10 rounded-lg bg-neutral-100" />
                        )}
                        <a href={`/listings/${l.id}`} target="_blank" className="font-medium hover:text-primary-600">
                          {l.title}
                        </a>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-neutral-600">{l.host?.full_name || "—"}</td>
                    <td className="px-4 py-3 text-neutral-500">{l.city}, {l.region}</td>
                    <td className="px-4 py-3">{l.price} kr/natt</td>
                    <td className="px-4 py-3">
                      <span className="rounded-full bg-neutral-100 px-2 py-0.5 text-xs text-neutral-600">
                        {l.vehicle_type === "motorhome" ? "Bobil" : l.vehicle_type === "campervan" ? "Campingbil" : "Bil"}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <span className={`inline-flex rounded-full px-2 py-0.5 text-xs font-semibold ${l.is_active ? "bg-green-100 text-green-700" : "bg-neutral-100 text-neutral-500"}`}>
                        {l.is_active ? "Aktiv" : "Inaktiv"}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => handleToggleListing(l.id, !l.is_active)}
                          className="text-neutral-400 hover:text-neutral-700"
                          title={l.is_active ? "Deaktiver" : "Aktiver"}
                        >
                          {l.is_active ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                        </button>
                        <button
                          onClick={() => handleDeleteListing(l.id)}
                          className="text-neutral-400 hover:text-red-600"
                          title="Slett"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Messages */}
        {tab === "messages" && (
          <div className="space-y-3">
            {conversations
              .filter((c) => !q || (c.guest?.full_name || "").toLowerCase().includes(q) || (c.host?.full_name || "").toLowerCase().includes(q) || (c.listing?.title || "").toLowerCase().includes(q))
              .map((c) => (
              <div key={c.id} className="rounded-xl border border-neutral-200 bg-white">
                <button
                  onClick={() => loadMessages(c.id)}
                  className="flex w-full items-center justify-between px-4 py-3 text-left hover:bg-neutral-50"
                >
                  <div className="flex items-center gap-4">
                    <div>
                      <p className="text-sm font-medium">
                        {c.guest?.full_name || "Gjest"} ↔ {c.host?.full_name || "Utleier"}
                      </p>
                      <p className="text-xs text-neutral-500">{c.listing?.title || "Ukjent annonse"}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="text-xs text-neutral-400">
                      {new Date(c.last_message_at).toLocaleDateString("nb-NO")}
                    </span>
                    <ChevronDown className={`h-4 w-4 text-neutral-400 transition-transform ${expandedConvo === c.id ? "rotate-180" : ""}`} />
                  </div>
                </button>
                {expandedConvo === c.id && c.messages && (
                  <div className="border-t border-neutral-100 px-4 py-3 max-h-80 overflow-y-auto space-y-2">
                    {c.messages.length === 0 ? (
                      <p className="text-sm text-neutral-400">Ingen meldinger</p>
                    ) : (
                      c.messages.map((m) => (
                        <div key={m.id} className="flex gap-2">
                          <span className="shrink-0 text-xs font-semibold text-neutral-700 w-24 truncate">
                            {m.sender?.full_name || "Anonym"}
                          </span>
                          <span className="text-sm text-neutral-600 flex-1">{m.content}</span>
                          <span className="shrink-0 text-xs text-neutral-300">
                            {new Date(m.created_at).toLocaleString("nb-NO", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" })}
                          </span>
                        </div>
                      ))
                    )}
                  </div>
                )}
              </div>
            ))}
            {conversations.length === 0 && (
              <p className="py-12 text-center text-neutral-400">Ingen samtaler ennå</p>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
