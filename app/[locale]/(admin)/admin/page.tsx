"use client";

import { useEffect, useState } from "react";
import { adminDeleteListingAction, adminCancelBookingAction, adminToggleListingAction, loadAdminDataAction, loadMessagesAction, loadSupportMessagesAction, loadSupportUserInfoAction, sendSupportMessageAction } from "./actions";
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
  BarChart3,
  TrendingUp,
  DollarSign,
  UserPlus,
  LifeBuoy,
  Send,
} from "lucide-react";
import { SERVICE_FEE_RATE } from "@/lib/config";

type Tab = "overview" | "bookings" | "users" | "listings" | "messages" | "support";

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

interface AdminSupportConversation {
  id: string;
  guest_id: string;
  created_at: string;
  last_message_at: string;
  type: string;
  unread_count: number;
  last_message: { content: string; created_at: string; sender_id: string } | null;
  guest: { full_name: string | null; avatar_url: string | null } | null;
}

interface AdminSupportMessage {
  id: string;
  content: string;
  created_at: string;
  sender_id: string;
  sender: { full_name: string } | null;
}

interface SupportUserInfo {
  profile: {
    id: string;
    full_name: string | null;
    avatar_url: string | null;
    created_at: string;
    stripe_account_id: string | null;
    stripe_onboarding_complete: boolean | null;
    bio: string | null;
    is_admin: boolean;
  } | null;
  email: string | null;
  emailConfirmed: boolean;
  createdAt: string | undefined;
  lastSignInAt: string | undefined;
  provider: string;
  bookingsAsGuest: Array<{ id: string; status: string; total_price: number; check_in: string; check_out: string; created_at: string; listing: { title: string } | null }>;
  bookingsAsHost: Array<{ id: string; status: string; total_price: number; check_in: string; check_out: string; created_at: string; listing: { title: string } | null }>;
  listings: Array<{ id: string; title: string; city: string; is_active: boolean }>;
  totalSpent: number;
  totalEarned: number;
}

const tabs: { key: Tab; label: string; icon: React.ElementType }[] = [
  { key: "overview", label: "Oversikt", icon: BarChart3 },
  { key: "bookings", label: "Bookings", icon: CalendarCheck },
  { key: "users", label: "Brukere", icon: Users },
  { key: "listings", label: "Annonser", icon: Megaphone },
  { key: "messages", label: "Meldinger", icon: MessageCircle },
  { key: "support", label: "Support", icon: LifeBuoy },
];

export default function AdminPage() {
  const [tab, setTab] = useState<Tab>("overview");
  const [bookings, setBookings] = useState<AdminBooking[]>([]);
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [listings, setListings] = useState<AdminListing[]>([]);
  const [conversations, setConversations] = useState<AdminConversation[]>([]);
  const [supportConversations, setSupportConversations] = useState<AdminSupportConversation[]>([]);
  const [activeSupportId, setActiveSupportId] = useState<string | null>(null);
  const [supportMessages, setSupportMessages] = useState<AdminSupportMessage[]>([]);
  const [supportUserInfo, setSupportUserInfo] = useState<SupportUserInfo | null>(null);
  const [loadingUserInfo, setLoadingUserInfo] = useState(false);
  const [supportDraft, setSupportDraft] = useState("");
  const [sendingSupport, setSendingSupport] = useState(false);
  const [currentAdminId, setCurrentAdminId] = useState<string | null>(null);
  const [expandedConvo, setExpandedConvo] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    loadAdminDataAction().then((data) => {
      setBookings(data.bookings as unknown as AdminBooking[]);
      setUsers(data.users as unknown as AdminUser[]);
      setListings(data.listings as unknown as AdminListing[]);
      setConversations(data.conversations as unknown as AdminConversation[]);
      setSupportConversations(data.supportConversations as unknown as AdminSupportConversation[]);
      setCurrentAdminId(data.currentAdminId);
      setLoaded(true);
    });
  }, []);

  const totalSupportUnread = supportConversations.reduce((sum, c) => sum + (c.unread_count || 0), 0);

  const openSupport = async (convo: AdminSupportConversation) => {
    if (activeSupportId === convo.id) {
      setActiveSupportId(null);
      setSupportMessages([]);
      setSupportUserInfo(null);
      return;
    }
    setActiveSupportId(convo.id);
    setSupportUserInfo(null);
    setLoadingUserInfo(true);
    const [msgs, info] = await Promise.all([
      loadSupportMessagesAction(convo.id),
      loadSupportUserInfoAction(convo.guest_id),
    ]);
    setSupportMessages(msgs as unknown as AdminSupportMessage[]);
    setSupportUserInfo(info as unknown as SupportUserInfo);
    setLoadingUserInfo(false);
    // Lokalt: marker som lest så badge oppdateres uten refresh.
    setSupportConversations((prev) =>
      prev.map((c) => c.id === convo.id ? { ...c, unread_count: 0 } : c)
    );
  };

  const sendSupport = async () => {
    if (!activeSupportId || !supportDraft.trim()) return;
    setSendingSupport(true);
    const result = await sendSupportMessageAction(activeSupportId, supportDraft);
    setSendingSupport(false);
    if (result.error) {
      alert(result.error);
      return;
    }
    setSupportDraft("");
    // Refresh meldinger + bump samtalen til toppen.
    const data = await loadSupportMessagesAction(activeSupportId);
    setSupportMessages(data as unknown as AdminSupportMessage[]);
    setSupportConversations((prev) => {
      const idx = prev.findIndex((c) => c.id === activeSupportId);
      if (idx === -1) return prev;
      const updated = { ...prev[idx], last_message_at: new Date().toISOString(), unread_count: 0 };
      return [updated, ...prev.filter((_, i) => i !== idx)];
    });
  };

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
          const badge = t.key === "support" ? totalSupportUnread : 0;
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
              {badge > 0 && (
                <span className="inline-flex h-5 min-w-[20px] items-center justify-center rounded-full bg-primary-600 px-1.5 text-[10px] font-bold text-white">
                  {badge}
                </span>
              )}
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
        {/* Overview */}
        {tab === "overview" && <OverviewTab bookings={bookings} users={users} listings={listings} />}

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

        {/* Support */}
        {tab === "support" && (
          <div className="grid grid-cols-1 gap-4 lg:grid-cols-[280px_1fr_300px]">
            {/* Liste over support-samtaler */}
            <div className="rounded-xl border border-neutral-200 bg-white max-h-[70vh] overflow-y-auto">
              {supportConversations.length === 0 ? (
                <p className="py-12 px-4 text-center text-sm text-neutral-400">Ingen support-samtaler ennå</p>
              ) : (
                supportConversations
                  .filter((c) => !q || (c.guest?.full_name || "").toLowerCase().includes(q))
                  .map((c) => {
                    const isActive = activeSupportId === c.id;
                    const hasUnread = c.unread_count > 0 && !isActive;
                    return (
                      <button
                        key={c.id}
                        onClick={() => openSupport(c)}
                        className={`flex w-full items-start gap-3 border-b border-neutral-100 px-4 py-3 text-left transition-colors ${
                          isActive ? "bg-primary-50" : "hover:bg-neutral-50"
                        }`}
                      >
                        {c.guest?.avatar_url ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={c.guest.avatar_url} alt="" className="h-9 w-9 shrink-0 rounded-full object-cover" />
                        ) : (
                          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-neutral-200 text-xs font-semibold text-neutral-600">
                            {(c.guest?.full_name || "?")[0]}
                          </div>
                        )}
                        <div className="min-w-0 flex-1">
                          <div className="flex items-baseline justify-between gap-2">
                            <p className={`truncate text-sm ${hasUnread ? "font-bold" : "font-medium"}`}>
                              {c.guest?.full_name || "Anonym"}
                            </p>
                            <span className="shrink-0 text-[10px] text-neutral-400">
                              {new Date(c.last_message_at).toLocaleString("nb-NO", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" })}
                            </span>
                          </div>
                          {c.last_message?.content && (
                            <p className={`mt-0.5 truncate text-xs ${hasUnread ? "text-neutral-700" : "text-neutral-400"}`}>
                              {c.last_message.content}
                            </p>
                          )}
                        </div>
                        {hasUnread && (
                          <span className="mt-1 flex h-5 min-w-[20px] items-center justify-center rounded-full bg-primary-600 px-1.5 text-[10px] font-bold text-white">
                            {c.unread_count}
                          </span>
                        )}
                      </button>
                    );
                  })
              )}
            </div>

            {/* Chat-panel */}
            <div className="flex h-[70vh] flex-col rounded-xl border border-neutral-200 bg-white">
              {!activeSupportId ? (
                <div className="flex flex-1 items-center justify-center text-sm text-neutral-400">
                  Velg en samtale fra venstre for å lese og svare
                </div>
              ) : (
                <>
                  <div className="flex-1 overflow-y-auto px-4 py-3 space-y-2">
                    {supportMessages.length === 0 ? (
                      <p className="text-sm text-neutral-400">Ingen meldinger ennå</p>
                    ) : (
                      supportMessages.map((m, i) => {
                        const isMe = m.sender_id === currentAdminId;
                        const prev = i > 0 ? supportMessages[i - 1] : null;
                        const showHeader = !prev || prev.sender_id !== m.sender_id;
                        return (
                          <div key={m.id} className={`flex flex-col ${isMe ? "items-end" : "items-start"}`}>
                            {showHeader && (
                              <div className={`mb-1 flex items-baseline gap-2 px-1 ${isMe ? "flex-row-reverse" : ""}`}>
                                <span className="text-xs font-semibold text-neutral-700">
                                  {isMe ? "Tuno-support" : (m.sender?.full_name || "Anonym")}
                                </span>
                                <span className="text-[10px] text-neutral-400">
                                  {new Date(m.created_at).toLocaleString("nb-NO", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" })}
                                </span>
                              </div>
                            )}
                            <div
                              className={`max-w-[75%] whitespace-pre-wrap rounded-2xl px-3.5 py-2 text-sm ${
                                isMe
                                  ? "bg-primary-600 text-white"
                                  : "bg-neutral-100 text-neutral-900"
                              }`}
                            >
                              {m.content}
                            </div>
                          </div>
                        );
                      })
                    )}
                  </div>
                  <div className="border-t border-neutral-100 p-3">
                    <div className="flex items-end gap-2">
                      <textarea
                        value={supportDraft}
                        onChange={(e) => setSupportDraft(e.target.value)}
                        onKeyDown={(e) => {
                          if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
                            e.preventDefault();
                            sendSupport();
                          }
                        }}
                        rows={2}
                        placeholder="Svar som Tuno-support…"
                        className="flex-1 resize-none rounded-lg border border-neutral-200 px-3 py-2 text-sm focus:border-primary-500 focus:outline-none"
                      />
                      <button
                        onClick={sendSupport}
                        disabled={sendingSupport || !supportDraft.trim()}
                        className="flex items-center gap-1 rounded-lg bg-primary-600 px-3 py-2 text-sm font-semibold text-white disabled:opacity-50"
                      >
                        <Send className="h-4 w-4" />
                        Send
                      </button>
                    </div>
                  </div>
                </>
              )}
            </div>

            {/* Bruker-info-panel */}
            <div className="rounded-xl border border-neutral-200 bg-white max-h-[70vh] overflow-y-auto">
              {!activeSupportId ? (
                <p className="py-12 px-4 text-center text-sm text-neutral-400">Brukerinfo vises når du velger en samtale</p>
              ) : loadingUserInfo || !supportUserInfo ? (
                <p className="py-12 px-4 text-center text-sm text-neutral-400">Laster brukerinfo…</p>
              ) : (
                <SupportUserInfoPanel info={supportUserInfo} />
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function OverviewTab({ bookings, users, listings }: { bookings: AdminBooking[]; users: AdminUser[]; listings: AdminListing[] }) {
  const confirmedBookings = bookings.filter((b) => b.status === "confirmed" || b.payment_status === "paid");
  const totalRevenue = confirmedBookings.reduce((sum, b) => sum + b.total_price, 0);
  const platformFee = Math.round(totalRevenue * SERVICE_FEE_RATE / (1 + SERVICE_FEE_RATE));
  const cancelledBookings = bookings.filter((b) => b.status === "cancelled");
  const totalRefunded = cancelledBookings.reduce((sum, b) => sum + (b.refund_amount || 0), 0);
  const activeListings = listings.filter((l) => l.is_active);
  const hosts = users.filter((u) => u.stripe_account_id);

  const now = new Date();
  const thisMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

  // Monthly revenue (last 6 months)
  const months: { label: string; key: string }[] = [];
  for (let i = 5; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    months.push({
      label: d.toLocaleDateString("nb-NO", { month: "short" }),
      key: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`,
    });
  }

  const monthlyData = months.map((m) => {
    const monthBookings = confirmedBookings.filter((b) => b.created_at?.startsWith(m.key));
    const revenue = monthBookings.reduce((sum, b) => sum + b.total_price, 0);
    const fee = Math.round(revenue * SERVICE_FEE_RATE / (1 + SERVICE_FEE_RATE));
    return { ...m, revenue, fee, count: monthBookings.length };
  });

  const maxRevenue = Math.max(...monthlyData.map((m) => m.revenue), 1);

  // New users this month
  const newUsersThisMonth = users.filter((u) => u.created_at?.startsWith(thisMonth)).length;

  // Recent bookings (last 5)
  const recentBookings = bookings.slice(0, 5);

  // Top listings by bookings
  const listingBookingCount = new Map<string, number>();
  for (const b of confirmedBookings) {
    const title = b.listing?.title || "Ukjent";
    listingBookingCount.set(title, (listingBookingCount.get(title) || 0) + 1);
  }
  const topListings = Array.from(listingBookingCount.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5);

  return (
    <div className="space-y-6">
      {/* Stat cards */}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard icon={DollarSign} label="Total omsetning" value={`${totalRevenue.toLocaleString("nb-NO")} kr`} sub={`${platformFee.toLocaleString("nb-NO")} kr plattformavgift`} color="green" />
        <StatCard icon={CalendarCheck} label="Bookings" value={String(confirmedBookings.length)} sub={`${cancelledBookings.length} kansellert (${totalRefunded.toLocaleString("nb-NO")} kr refundert)`} color="blue" />
        <StatCard icon={Megaphone} label="Annonser" value={`${activeListings.length} aktive`} sub={`${listings.length} totalt, ${hosts.length} utleiere`} color="purple" />
        <StatCard icon={UserPlus} label="Brukere" value={String(users.length)} sub={`${newUsersThisMonth} nye denne måneden`} color="amber" />
      </div>

      {/* Charts row */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        {/* Monthly revenue chart */}
        <div className="rounded-xl border border-neutral-200 bg-white p-5">
          <h3 className="flex items-center gap-2 text-sm font-semibold text-neutral-700">
            <TrendingUp className="h-4 w-4 text-primary-600" />
            Månedlig omsetning
          </h3>
          <div className="mt-4 flex items-end gap-3 h-44">
            {monthlyData.map((m) => (
              <div key={m.key} className="flex flex-1 flex-col items-center gap-1">
                <span className="text-xs font-medium text-neutral-700">
                  {m.revenue > 0 ? `${m.revenue.toLocaleString("nb-NO")}` : ""}
                </span>
                <div className="w-full flex flex-col items-center">
                  <div
                    className="w-full max-w-10 rounded-t-md bg-primary-500 transition-all"
                    style={{ height: `${Math.max((m.revenue / maxRevenue) * 120, m.revenue > 0 ? 4 : 0)}px` }}
                  />
                  <div
                    className="w-full max-w-10 rounded-b-md bg-primary-200"
                    style={{ height: `${Math.max((m.fee / maxRevenue) * 120, m.fee > 0 ? 2 : 0)}px` }}
                  />
                </div>
                <span className="text-xs text-neutral-400">{m.label}</span>
              </div>
            ))}
          </div>
          <div className="mt-3 flex items-center gap-4 text-xs text-neutral-400">
            <span className="flex items-center gap-1"><span className="inline-block h-2 w-2 rounded-sm bg-primary-500" /> Omsetning</span>
            <span className="flex items-center gap-1"><span className="inline-block h-2 w-2 rounded-sm bg-primary-200" /> Plattformavgift</span>
          </div>
        </div>

        {/* Top listings */}
        <div className="rounded-xl border border-neutral-200 bg-white p-5">
          <h3 className="flex items-center gap-2 text-sm font-semibold text-neutral-700">
            <BarChart3 className="h-4 w-4 text-primary-600" />
            Mest populære annonser
          </h3>
          <div className="mt-4 space-y-3">
            {topListings.length === 0 ? (
              <p className="text-sm text-neutral-400">Ingen bookings ennå</p>
            ) : (
              topListings.map(([title, count], i) => (
                <div key={i} className="flex items-center gap-3">
                  <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-neutral-100 text-xs font-bold text-neutral-500">
                    {i + 1}
                  </span>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-neutral-700 truncate">{title}</p>
                    <div className="mt-1 h-1.5 w-full rounded-full bg-neutral-100">
                      <div
                        className="h-1.5 rounded-full bg-primary-500"
                        style={{ width: `${(count / (topListings[0]?.[1] || 1)) * 100}%` }}
                      />
                    </div>
                  </div>
                  <span className="text-sm font-semibold text-neutral-600">{count}</span>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      {/* Recent bookings */}
      <div className="rounded-xl border border-neutral-200 bg-white p-5">
        <h3 className="text-sm font-semibold text-neutral-700">Siste bookings</h3>
        <div className="mt-3 divide-y divide-neutral-100">
          {recentBookings.map((b) => (
            <div key={b.id} className="flex items-center justify-between py-3">
              <div>
                <p className="text-sm font-medium text-neutral-700">{b.listing?.title || "—"}</p>
                <p className="text-xs text-neutral-400">{b.guest?.full_name || "Anonym"} → {b.host?.full_name || "Utleier"}</p>
              </div>
              <div className="text-right">
                <p className="text-sm font-semibold">{b.total_price} kr</p>
                <span className={`text-xs ${b.status === "confirmed" ? "text-green-600" : b.status === "pending" ? "text-amber-600" : "text-red-500"}`}>
                  {b.status === "confirmed" ? "Bekreftet" : b.status === "pending" ? "Venter" : "Kansellert"}
                </span>
              </div>
            </div>
          ))}
          {recentBookings.length === 0 && (
            <p className="py-4 text-sm text-neutral-400">Ingen bookings ennå</p>
          )}
        </div>
      </div>
    </div>
  );
}

const statColors = {
  green: "bg-green-50 text-green-600",
  blue: "bg-blue-50 text-blue-600",
  purple: "bg-purple-50 text-purple-600",
  amber: "bg-amber-50 text-amber-600",
};

function StatCard({ icon: Icon, label, value, sub, color }: {
  icon: React.ElementType;
  label: string;
  value: string;
  sub: string;
  color: keyof typeof statColors;
}) {
  return (
    <div className="rounded-xl border border-neutral-200 bg-white p-4">
      <div className="flex items-center gap-3">
        <div className={`flex h-9 w-9 items-center justify-center rounded-lg ${statColors[color]}`}>
          <Icon className="h-5 w-5" />
        </div>
        <div>
          <p className="text-xs text-neutral-500">{label}</p>
          <p className="text-lg font-bold text-neutral-900">{value}</p>
        </div>
      </div>
      <p className="mt-2 text-xs text-neutral-400">{sub}</p>
    </div>
  );
}

function SupportUserInfoPanel({ info }: { info: SupportUserInfo }) {
  const profile = info.profile;
  const isHost = info.listings.length > 0 || info.bookingsAsHost.length > 0;
  const stripeStatus = profile?.stripe_account_id
    ? (profile.stripe_onboarding_complete ? "Onboarding ferdig" : "Onboarding pågår")
    : "Ingen Stripe-konto";

  const fmtDate = (iso?: string | null) =>
    iso ? new Date(iso).toLocaleDateString("nb-NO", { day: "2-digit", month: "short", year: "numeric" }) : "—";

  return (
    <div className="p-4 space-y-4">
      {/* Header */}
      <div className="flex flex-col items-center text-center">
        {profile?.avatar_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={profile.avatar_url} alt="" className="h-16 w-16 rounded-full object-cover" />
        ) : (
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-neutral-200 text-xl font-semibold text-neutral-600">
            {(profile?.full_name || "?")[0]}
          </div>
        )}
        <p className="mt-2 text-base font-semibold text-neutral-900">{profile?.full_name || "Anonym"}</p>
        {info.email && (
          <a href={`mailto:${info.email}`} className="text-xs text-primary-600 hover:underline">
            {info.email}
          </a>
        )}
        <div className="mt-2 flex flex-wrap justify-center gap-1">
          {profile?.is_admin && (
            <span className="rounded-full bg-red-100 px-2 py-0.5 text-[10px] font-semibold text-red-700">Admin</span>
          )}
          {isHost && (
            <span className="rounded-full bg-purple-100 px-2 py-0.5 text-[10px] font-semibold text-purple-700">Vert</span>
          )}
          {!info.emailConfirmed && (
            <span className="rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-semibold text-amber-700">Ikke verifisert</span>
          )}
        </div>
      </div>

      {/* Konto-meta */}
      <div className="rounded-lg bg-neutral-50 p-3 text-xs space-y-1.5">
        <div className="flex justify-between">
          <span className="text-neutral-500">Registrert</span>
          <span className="text-neutral-900">{fmtDate(info.createdAt)}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-neutral-500">Sist sett</span>
          <span className="text-neutral-900">{fmtDate(info.lastSignInAt)}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-neutral-500">Pålogging</span>
          <span className="text-neutral-900 capitalize">{info.provider}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-neutral-500">Stripe</span>
          <span className="text-neutral-900">{stripeStatus}</span>
        </div>
      </div>

      {/* Aktivitet */}
      <div className="grid grid-cols-2 gap-2">
        <div className="rounded-lg border border-neutral-100 p-2">
          <p className="text-[10px] uppercase tracking-wide text-neutral-400">Som gjest</p>
          <p className="mt-0.5 text-sm font-semibold">{info.bookingsAsGuest.length} bookings</p>
          <p className="text-[10px] text-neutral-500">{info.totalSpent.toLocaleString("nb-NO")} kr brukt</p>
        </div>
        <div className="rounded-lg border border-neutral-100 p-2">
          <p className="text-[10px] uppercase tracking-wide text-neutral-400">Som vert</p>
          <p className="mt-0.5 text-sm font-semibold">{info.bookingsAsHost.length} bookings</p>
          <p className="text-[10px] text-neutral-500">{info.totalEarned.toLocaleString("nb-NO")} kr tjent</p>
        </div>
      </div>

      {/* Annonser */}
      {info.listings.length > 0 && (
        <div>
          <p className="text-[10px] uppercase tracking-wide text-neutral-400 mb-1">Annonser ({info.listings.length})</p>
          <div className="space-y-1">
            {info.listings.slice(0, 5).map((l) => (
              <div key={l.id} className="flex items-center justify-between rounded-md bg-neutral-50 px-2 py-1.5 text-xs">
                <div className="min-w-0 flex-1">
                  <p className="truncate font-medium text-neutral-900">{l.title}</p>
                  <p className="truncate text-[10px] text-neutral-500">{l.city}</p>
                </div>
                <span className={`shrink-0 text-[10px] ${l.is_active ? "text-green-600" : "text-neutral-400"}`}>
                  {l.is_active ? "Aktiv" : "Inaktiv"}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Siste bookings */}
      {(info.bookingsAsGuest.length > 0 || info.bookingsAsHost.length > 0) && (
        <div>
          <p className="text-[10px] uppercase tracking-wide text-neutral-400 mb-1">Siste bookings</p>
          <div className="space-y-1">
            {[...info.bookingsAsGuest, ...info.bookingsAsHost]
              .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
              .slice(0, 5)
              .map((b) => (
                <div key={b.id} className="rounded-md bg-neutral-50 px-2 py-1.5 text-xs">
                  <div className="flex items-center justify-between">
                    <p className="truncate font-medium text-neutral-900">{b.listing?.title || "—"}</p>
                    <span className={`shrink-0 text-[10px] ${
                      b.status === "confirmed" ? "text-green-600"
                      : b.status === "cancelled" ? "text-red-500"
                      : "text-amber-600"
                    }`}>
                      {b.status === "confirmed" ? "OK" : b.status === "cancelled" ? "✗" : "…"}
                    </span>
                  </div>
                  <p className="truncate text-[10px] text-neutral-500">
                    {b.check_in} → {b.check_out} · {b.total_price.toLocaleString("nb-NO")} kr
                  </p>
                </div>
              ))}
          </div>
        </div>
      )}

      {profile?.bio && (
        <div>
          <p className="text-[10px] uppercase tracking-wide text-neutral-400 mb-1">Bio</p>
          <p className="text-xs text-neutral-700 whitespace-pre-wrap">{profile.bio}</p>
        </div>
      )}
    </div>
  );
}
