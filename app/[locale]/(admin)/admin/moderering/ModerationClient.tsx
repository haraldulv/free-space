"use client";

import { useCallback, useEffect, useMemo, useRef, useState, useTransition } from "react";
import Link from "next/link";
import {
  AlertTriangle,
  Check,
  ChevronLeft,
  Clock,
  ExternalLink,
  RefreshCw,
  ShieldCheck,
  ShieldOff,
  Sparkles,
  Trash2,
  UserX,
  X,
} from "lucide-react";
import type { ModerationStatus } from "@/types";
import ReportsPanel from "./ReportsPanel";
import SignupSwitch from "./SignupSwitch";
import {
  approveListingAction,
  deleteListingHardAction,
  deleteUserHardAction,
  loadModerationAction,
  rejectListingAction,
  rerunAiAction,
  type ModerationListing,
} from "./actions";

type Filter = "flagged" | "pending" | "approved" | "rejected" | "all";

const STATUS_LABEL: Record<ModerationStatus, string> = {
  pending: "Venter på AI",
  flagged: "Flagget",
  approved: "Godkjent",
  rejected: "Avvist",
};

const STATUS_STYLE: Record<ModerationStatus, string> = {
  pending: "bg-neutral-100 text-neutral-700",
  flagged: "bg-red-100 text-red-700",
  approved: "bg-green-100 text-green-700",
  rejected: "bg-neutral-800 text-white",
};

interface AiImage { index: number; category: string; note: string }
interface AiResult {
  verdict?: string;
  confidence?: string;
  reasons?: string[];
  images?: AiImage[];
  text_quality?: string;
  model?: string;
  at?: string;
  error?: string;
}

function fmt(iso: string | null) {
  if (!iso) return "";
  return new Date(iso).toLocaleString("nb-NO", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" });
}

type View = "listings" | "reports" | "content";

export default function ModerationClient({ focusListingId, currentAdminId, initialView, focusReportId }: { focusListingId: string | null; currentAdminId: string; initialView: View; focusReportId: string | null }) {
  const [view, setView] = useState<View>(initialView);
  const [listings, setListings] = useState<ModerationListing[]>([]);
  const [filter, setFilter] = useState<Filter>("flagged");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [busyId, setBusyId] = useState<string | null>(null);
  const [rejecting, setRejecting] = useState<{ id: string; reason: string } | null>(null);
  const [deletingUser, setDeletingUser] = useState<{ listing: ModerationListing; rejectStripe: boolean } | null>(null);
  const [lightbox, setLightbox] = useState<string | null>(null);
  const [, startTransition] = useTransition();

  const focusApplied = useRef(false);

  const reload = useCallback(async () => {
    const res = await loadModerationAction();
    if (res.error) {
      setError(res.error);
    } else {
      const rows = res.listings ?? [];
      setListings(rows);
      // Deep-link fra e-post/push: hopp til riktig fane og scroll til annonsen.
      if (focusListingId && !focusApplied.current) {
        const target = rows.find((l) => l.id === focusListingId);
        if (target) {
          focusApplied.current = true;
          setFilter(target.moderation_status === "approved" ? "approved" : target.moderation_status === "rejected" ? "rejected" : target.moderation_status === "pending" ? "pending" : "flagged");
          setTimeout(() => document.getElementById(`listing-${focusListingId}`)?.scrollIntoView({ behavior: "smooth", block: "center" }), 50);
        }
      }
    }
    setLoading(false);
  }, [focusListingId]);

  useEffect(() => {
    queueMicrotask(() => { void reload(); });
  }, [reload]);

  const counts = useMemo(() => {
    const c: Record<Filter, number> = { flagged: 0, pending: 0, approved: 0, rejected: 0, all: listings.length };
    listings.forEach((l) => { c[l.moderation_status] += 1; });
    return c;
  }, [listings]);

  const visible = useMemo(
    () => (filter === "all" ? listings : listings.filter((l) => l.moderation_status === filter)),
    [listings, filter],
  );

  const run = async (id: string, fn: () => Promise<{ error?: string }>) => {
    setBusyId(id);
    setError("");
    const res = await fn();
    if (res.error) setError(res.error);
    await reload();
    setBusyId(null);
  };

  const tabs: { key: Filter; label: string; icon: React.ElementType }[] = [
    { key: "flagged", label: "Flagget", icon: AlertTriangle },
    { key: "pending", label: "Venter", icon: Clock },
    { key: "approved", label: "Godkjent", icon: Check },
    { key: "rejected", label: "Avvist", icon: X },
    { key: "all", label: "Alle", icon: Sparkles },
  ];

  return (
    <div className="mx-auto max-w-6xl px-4 py-6">
      <div className="flex items-center justify-between gap-4">
        <div>
          <Link href="/admin" className="inline-flex items-center gap-1 text-sm text-neutral-500 hover:text-neutral-700">
            <ChevronLeft className="h-4 w-4" /> Admin
          </Link>
          <h1 className="mt-1 text-2xl font-bold text-neutral-900">Moderering</h1>
          <p className="text-sm text-neutral-500">
            Nye annonser er skjult til AI (eller du) har godkjent dem, og til hosten er Stripe-verifisert.
          </p>
        </div>
        <button
          onClick={() => startTransition(() => { reload(); })}
          className="flex items-center gap-2 rounded-lg border border-neutral-200 px-3 py-2 text-sm text-neutral-600 hover:bg-neutral-50"
        >
          <RefreshCw className="h-4 w-4" /> Oppdater
        </button>
      </div>

      {error && (
        <div className="mt-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>
      )}

      <SignupSwitch />

      <div className="mt-6 flex gap-2">
        {([["listings", "Annonser"], ["reports", "Rapporter"], ["content", "Flagget innhold"]] as [View, string][]).map(([k, label]) => (
          <button
            key={k}
            onClick={() => setView(k)}
            className={`rounded-full px-4 py-1.5 text-sm font-medium ${view === k ? "bg-neutral-900 text-white" : "bg-neutral-100 text-neutral-700 hover:bg-neutral-200"}`}
          >
            {label}
          </button>
        ))}
      </div>

      {view !== "listings" && <ReportsPanel mode={view} focusReportId={focusReportId} />}

      {view === "listings" && (<>
      <div className="mt-6 flex gap-1 border-b border-neutral-200">
        {tabs.map((t) => {
          const Icon = t.icon;
          const active = filter === t.key;
          return (
            <button
              key={t.key}
              onClick={() => setFilter(t.key)}
              className={`flex items-center gap-2 px-4 py-3 text-sm font-medium transition-colors ${
                active ? "border-b-2 border-primary-600 text-primary-600" : "text-neutral-500 hover:text-neutral-700"
              }`}
            >
              <Icon className="h-4 w-4" />
              {t.label}
              <span className={`inline-flex h-5 min-w-[20px] items-center justify-center rounded-full px-1.5 text-[10px] font-bold ${
                t.key === "flagged" && counts.flagged > 0 ? "bg-red-600 text-white" : "bg-neutral-100 text-neutral-600"
              }`}>
                {counts[t.key]}
              </span>
            </button>
          );
        })}
      </div>

      {loading ? (
        <p className="mt-8 text-sm text-neutral-500">Laster...</p>
      ) : visible.length === 0 ? (
        <div className="mt-8 rounded-xl border border-dashed border-neutral-200 p-10 text-center text-sm text-neutral-500">
          Ingenting her.
        </div>
      ) : (
        <div className="mt-4 space-y-4">
          {visible.map((l) => {
            const ai = (l.moderation_ai ?? null) as AiResult | null;
            const busy = busyId === l.id;
            const canToggleVisible = l.moderation_status === "approved" && l.host_stripe_ready && l.is_active !== false;
            return (
              <div
                key={l.id}
                id={`listing-${l.id}`}
                className={`rounded-xl border bg-white p-4 ${
                  l.moderation_status === "flagged" ? "border-red-200" : "border-neutral-200"
                } ${focusListingId === l.id ? "ring-2 ring-primary-500" : ""}`}
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${STATUS_STYLE[l.moderation_status]}`}>
                        {STATUS_LABEL[l.moderation_status]}
                      </span>
                      <span className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium ${
                        l.host_stripe_ready ? "bg-green-50 text-green-700" : "bg-amber-50 text-amber-700"
                      }`}>
                        {l.host_stripe_ready ? <ShieldCheck className="h-3 w-3" /> : <ShieldOff className="h-3 w-3" />}
                        {l.host_stripe_ready ? "Stripe verifisert" : "Stripe ikke verifisert"}
                      </span>
                      <span className={`rounded-full px-2 py-0.5 text-xs ${canToggleVisible ? "bg-primary-50 text-primary-700" : "bg-neutral-100 text-neutral-500"}`}>
                        {canToggleVisible ? "Synlig for publikum" : "Skjult"}
                      </span>
                    </div>
                    <h2 className="mt-2 truncate text-lg font-semibold text-neutral-900">
                      {l.title}
                      <Link href={`/listings/${l.id}`} target="_blank" className="ml-2 inline-flex align-middle text-neutral-400 hover:text-neutral-700">
                        <ExternalLink className="h-4 w-4" />
                      </Link>
                    </h2>
                    <p className="text-sm text-neutral-500">
                      {l.category} · {[l.address, l.city, l.region].filter(Boolean).join(", ")} · opprettet {fmt(l.created_at)}
                    </p>
                    <p className="mt-1 text-sm text-neutral-700">
                      <span className="font-medium">{l.host?.full_name ?? "Ukjent host"}</span>
                      {l.host?.email && <span className="text-neutral-500"> · {l.host.email}</span>}
                      {l.host?.created_at && <span className="text-neutral-400"> · bruker siden {fmt(l.host.created_at)}</span>}
                      {l.host && <span className="text-neutral-400"> · {l.host.listings_count} annonse{l.host.listings_count === 1 ? "" : "r"}</span>}
                    </p>
                  </div>

                  <div className="flex flex-wrap gap-2">
                    {l.moderation_status !== "approved" && (
                      <button
                        disabled={busy}
                        onClick={() => run(l.id, () => approveListingAction(l.id))}
                        className="flex items-center gap-1.5 rounded-lg bg-primary-600 px-3 py-2 text-sm font-medium text-white hover:bg-primary-700 disabled:opacity-50"
                      >
                        <Check className="h-4 w-4" /> Godkjenn
                      </button>
                    )}
                    {l.moderation_status !== "rejected" && (
                      <button
                        disabled={busy}
                        onClick={() => setRejecting({ id: l.id, reason: l.moderation_reason ?? "" })}
                        className="flex items-center gap-1.5 rounded-lg border border-neutral-200 px-3 py-2 text-sm font-medium text-neutral-700 hover:bg-neutral-50 disabled:opacity-50"
                      >
                        <X className="h-4 w-4" /> Avvis
                      </button>
                    )}
                    <button
                      disabled={busy}
                      onClick={() => run(l.id, () => rerunAiAction(l.id))}
                      title="Kjør AI-sjekk på nytt"
                      className="flex items-center gap-1.5 rounded-lg border border-neutral-200 px-3 py-2 text-sm text-neutral-600 hover:bg-neutral-50 disabled:opacity-50"
                    >
                      <Sparkles className="h-4 w-4" /> AI
                    </button>
                    <button
                      disabled={busy}
                      onClick={() => { if (confirm(`Slette annonsen «${l.title}» permanent (inkl. bilder)?`)) run(l.id, () => deleteListingHardAction(l.id)); }}
                      className="flex items-center gap-1.5 rounded-lg border border-neutral-200 px-3 py-2 text-sm text-neutral-600 hover:bg-red-50 hover:text-red-700 disabled:opacity-50"
                    >
                      <Trash2 className="h-4 w-4" /> Slett
                    </button>
                    {l.host_id && l.host_id !== currentAdminId && (
                      <button
                        disabled={busy}
                        onClick={() => setDeletingUser({ listing: l, rejectStripe: true })}
                        className="flex items-center gap-1.5 rounded-lg border border-red-200 px-3 py-2 text-sm text-red-700 hover:bg-red-50 disabled:opacity-50"
                      >
                        <UserX className="h-4 w-4" /> Slett bruker
                      </button>
                    )}
                  </div>
                </div>

                {l.images.length > 0 ? (
                  <div className="mt-3 flex gap-2 overflow-x-auto pb-1">
                    {l.images.map((url, i) => {
                      const v = ai?.images?.find((x) => x.index === i + 1);
                      const bad = v && v.category !== "ok" && v.category !== "unclear";
                      return (
                        <button key={url} onClick={() => setLightbox(url)} className="shrink-0 text-left">
                          {/* eslint-disable-next-line @next/next/no-img-element */}
                          <img
                            src={url}
                            alt=""
                            className={`h-28 w-40 rounded-lg object-cover ${bad ? "ring-2 ring-red-500" : "border border-neutral-200"}`}
                          />
                          {v && (
                            <p className={`mt-1 w-40 truncate text-[11px] ${bad ? "text-red-600" : "text-neutral-500"}`} title={v.note}>
                              {v.category}{v.note ? `: ${v.note}` : ""}
                            </p>
                          )}
                        </button>
                      );
                    })}
                  </div>
                ) : (
                  <p className="mt-3 text-sm text-neutral-400">Ingen bilder.</p>
                )}

                {l.description && (
                  <p className="mt-3 whitespace-pre-line text-sm text-neutral-700">{l.description}</p>
                )}

                <div className="mt-3 rounded-lg bg-neutral-50 p-3 text-sm">
                  {ai?.error ? (
                    <p className="text-amber-700">AI-sjekk ikke kjørt ennå (mangler ANTHROPIC_API_KEY?). Sweep prøver igjen hvert 5. minutt.</p>
                  ) : ai?.verdict ? (
                    <>
                      <p className="font-medium text-neutral-800">
                        AI: {ai.verdict === "approve" ? "godkjenn" : "flagg"} ({ai.confidence}) · tekst: {ai.text_quality}
                        {ai.at && <span className="font-normal text-neutral-400"> · {fmt(ai.at)}</span>}
                      </p>
                      {ai.reasons && ai.reasons.length > 0 && (
                        <ul className="mt-1 list-disc pl-5 text-neutral-700">
                          {ai.reasons.map((r, i) => <li key={i}>{r}</li>)}
                        </ul>
                      )}
                    </>
                  ) : (
                    <p className="text-neutral-500">Ingen AI-vurdering.</p>
                  )}
                  {l.moderation_reason && l.moderation_status === "rejected" && (
                    <p className="mt-2 text-neutral-800"><span className="font-medium">Begrunnelse til host:</span> {l.moderation_reason}</p>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      </>)}

      {rejecting && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={() => setRejecting(null)}>
          <div className="w-full max-w-md rounded-xl bg-white p-5" onClick={(e) => e.stopPropagation()}>
            <h3 className="text-lg font-semibold text-neutral-900">Avvis annonse</h3>
            <p className="mt-1 text-sm text-neutral-500">Begrunnelsen sendes til hosten på e-post og push.</p>
            <textarea
              autoFocus
              value={rejecting.reason}
              onChange={(e) => setRejecting({ ...rejecting, reason: e.target.value })}
              rows={4}
              placeholder="F.eks. Bildene viser ikke plassen som leies ut."
              className="mt-3 w-full rounded-lg border border-neutral-200 p-3 text-sm focus:border-primary-500 focus:outline-none"
            />
            <div className="mt-4 flex justify-end gap-2">
              <button onClick={() => setRejecting(null)} className="rounded-lg px-3 py-2 text-sm text-neutral-600 hover:bg-neutral-50">Avbryt</button>
              <button
                onClick={() => { const r = rejecting; setRejecting(null); run(r.id, () => rejectListingAction(r.id, r.reason)); }}
                className="rounded-lg bg-neutral-900 px-3 py-2 text-sm font-medium text-white hover:bg-neutral-800"
              >
                Avvis og varsle host
              </button>
            </div>
          </div>
        </div>
      )}

      {deletingUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={() => setDeletingUser(null)}>
          <div className="w-full max-w-md rounded-xl bg-white p-5" onClick={(e) => e.stopPropagation()}>
            <h3 className="text-lg font-semibold text-red-700">Slett bruker permanent</h3>
            <p className="mt-2 text-sm text-neutral-700">
              <span className="font-medium">{deletingUser.listing.host?.full_name}</span>
              {deletingUser.listing.host?.email && <> ({deletingUser.listing.host.email})</>}
              {" "}slettes fra auth, med alle annonser ({deletingUser.listing.host?.listings_count}), bilder, bookinger og meldinger. Kan ikke angres.
            </p>
            {deletingUser.listing.host?.stripe_account_id && (
              <label className="mt-3 flex items-start gap-2 text-sm text-neutral-700">
                <input
                  type="checkbox"
                  checked={deletingUser.rejectStripe}
                  onChange={(e) => setDeletingUser({ ...deletingUser, rejectStripe: e.target.checked })}
                  className="mt-0.5"
                />
                <span>Avvis Stripe-kontoen ({deletingUser.listing.host.stripe_account_id}) som svindel</span>
              </label>
            )}
            <div className="mt-4 flex justify-end gap-2">
              <button onClick={() => setDeletingUser(null)} className="rounded-lg px-3 py-2 text-sm text-neutral-600 hover:bg-neutral-50">Avbryt</button>
              <button
                onClick={async () => {
                  const d = deletingUser;
                  setDeletingUser(null);
                  if (!d.listing.host_id) return;
                  setBusyId(d.listing.id);
                  const res = await deleteUserHardAction(d.listing.host_id, { rejectStripe: d.rejectStripe });
                  if (res.error) setError(`${res.error}${res.stripe ? ` (${res.stripe})` : ""}`);
                  else if (res.stripe) setError("");
                  await reload();
                  setBusyId(null);
                  if (!res.error && res.stripe) alert(`Bruker slettet. ${res.stripe}.`);
                }}
                className="rounded-lg bg-red-600 px-3 py-2 text-sm font-medium text-white hover:bg-red-700"
              >
                Slett bruker
              </button>
            </div>
          </div>
        </div>
      )}

      {lightbox && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4" onClick={() => setLightbox(null)}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={lightbox} alt="" className="max-h-full max-w-full rounded-lg" />
        </div>
      )}
    </div>
  );
}
