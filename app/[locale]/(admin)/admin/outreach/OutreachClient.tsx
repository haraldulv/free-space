"use client";

import { useEffect, useMemo, useRef, useState, useTransition } from "react";
import Link from "next/link";
import { ChevronLeft, Download, Mail, MapPin, Phone, Plus, RefreshCw, Search, Star, X } from "lucide-react";
import {
  OUTREACH_CATEGORY_LABELS,
  OUTREACH_STATUS_COLORS,
  OUTREACH_STATUS_LABELS,
  type OutreachCategory,
  type OutreachContactLogEntry,
  type OutreachEmailTemplate,
  type OutreachStatus,
  type OutreachTarget,
} from "@/types";
import OutreachMap from "./_components/OutreachMap";
import EmailComposer from "./_components/EmailComposer";
import TemplateManager from "./_components/TemplateManager";
import AddTargetModal from "./_components/AddTargetModal";
import {
  exportTargetsCSVAction,
  geocodeTargetAction,
  loadOutreachAction,
  loadTargetDetailAction,
  logNoteAction,
  sendTestOutreachEmailAction,
  updateTargetAction,
} from "./actions";

const CATEGORIES: OutreachCategory[] = ["rorbu", "hotell", "restaurant", "camping", "overnatting", "gård", "other"];

function googleMapsLink(placeId: string, name?: string): string {
  const q = encodeURIComponent(name ?? "");
  return `https://www.google.com/maps/search/?api=1&query=${q}&query_place_id=${encodeURIComponent(placeId)}`;
}
const STATUSES: OutreachStatus[] = [
  "not_contacted",
  "queued",
  "contacted",
  "no_response",
  "follow_up",
  "responded",
  "interested",
  "declined",
  "onboarded",
];

interface Props {
  initialTargets: OutreachTarget[];
  initialTemplates: OutreachEmailTemplate[];
}

export default function OutreachClient({ initialTargets, initialTemplates }: Props) {
  const [targets, setTargets] = useState<OutreachTarget[]>(initialTargets);
  const [templates, setTemplates] = useState<OutreachEmailTemplate[]>(initialTemplates);
  const [listWidth, setListWidth] = useState<number>(() => {
    if (typeof window === "undefined") return 40;
    const saved = window.localStorage.getItem("outreach_list_width");
    if (!saved) return 40;
    const n = Number(saved);
    return Number.isFinite(n) ? Math.max(20, Math.min(70, n)) : 40;
  });
  const splitContainerRef = useRef<HTMLDivElement>(null);
  const draggingRef = useRef(false);
  const [filterCategory, setFilterCategory] = useState<OutreachCategory | "">("");
  const [filterStatuses, setFilterStatuses] = useState<Set<OutreachStatus>>(new Set());
  const [search, setSearch] = useState("");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [hoveredId, setHoveredId] = useState<string | null>(null);
  const [contactLog, setContactLog] = useState<OutreachContactLogEntry[]>([]);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [discoverPending, startDiscover] = useTransition();
  const [discoverMessage, setDiscoverMessage] = useState<string | null>(null);
  const [showComposer, setShowComposer] = useState(false);
  const [showTemplates, setShowTemplates] = useState(false);
  const [showAddTarget, setShowAddTarget] = useState(false);

  const filtered = useMemo(() => {
    return targets.filter((t) => {
      if (filterCategory && t.category !== filterCategory) return false;
      if (filterStatuses.size > 0 && !t.statuses.some((s) => filterStatuses.has(s))) return false;
      if (search && !t.name.toLowerCase().includes(search.toLowerCase())) return false;
      return true;
    });
  }, [targets, filterCategory, filterStatuses, search]);

  const selected = useMemo(() => targets.find((t) => t.id === selectedId) ?? null, [targets, selectedId]);

  const counts = useMemo(() => {
    const c: Record<OutreachStatus, number> = {
      not_contacted: 0, queued: 0, contacted: 0, no_response: 0, follow_up: 0, responded: 0, interested: 0, declined: 0, onboarded: 0,
    };
    targets.forEach((t) => { t.statuses.forEach((s) => { c[s]++; }); });
    return c;
  }, [targets]);

  async function refresh() {
    const res = await loadOutreachAction({ area: "lofoten" });
    if (res.targets) setTargets(res.targets);
    if (res.templates) setTemplates(res.templates);
  }

  /* eslint-disable react-hooks/set-state-in-effect */
  useEffect(() => {
    if (!selectedId) {
      setContactLog((prev) => (prev.length === 0 ? prev : []));
      return;
    }
    let cancelled = false;
    setLoadingDetail(true);
    loadTargetDetailAction(selectedId).then((res) => {
      if (cancelled) return;
      setContactLog(res.log ?? []);
      setLoadingDetail(false);
    });
    return () => { cancelled = true; };
  }, [selectedId]);
  /* eslint-enable react-hooks/set-state-in-effect */

  function runDiscover() {
    setDiscoverMessage(null);
    startDiscover(async () => {
      try {
        const res = await fetch("/api/admin/outreach/discover", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ area: "lofoten" }),
        });
        const json = await res.json();
        if (!res.ok) {
          setDiscoverMessage(`Feil: ${json.error ?? "ukjent"}`);
          return;
        }
        const errs = Array.isArray(json.errors) ? json.errors : [];
        const summary = `Lagt til ${json.inserted}, oppdatert ${json.updated}, hoppet over ${json.skipped} (totalt ${json.totalFetched} fra Google)`;
        if (errs.length > 0) {
          setDiscoverMessage(`${summary}. Feil: ${errs.slice(0, 3).join(" | ")}${errs.length > 3 ? ` (+${errs.length - 3} til)` : ""}`);
        } else {
          setDiscoverMessage(summary);
        }
        await refresh();
      } catch (err) {
        setDiscoverMessage(`Feil: ${err instanceof Error ? err.message : "ukjent"}`);
      }
    });
  }

  const [testMailPending, setTestMailPending] = useState(false);
  const [testMailMsg, setTestMailMsg] = useState<string | null>(null);

  async function sendTestMail() {
    const email = prompt("Send test-mail til:", "haraldsalvesen@gmail.com");
    if (!email) return;
    setTestMailPending(true);
    setTestMailMsg(null);
    const res = await sendTestOutreachEmailAction(email);
    setTestMailPending(false);
    setTestMailMsg(res.error ? `Feil: ${res.error}` : `Test-mail sendt til ${email}`);
    setTimeout(() => setTestMailMsg(null), 5000);
  }

  async function toggleStatus(target: OutreachTarget, status: OutreachStatus) {
    const has = target.statuses.includes(status);
    const updated = has
      ? target.statuses.filter((s) => s !== status)
      : [...target.statuses, status];
    const final = updated.length === 0 ? ["not_contacted" as OutreachStatus] : updated;
    const res = await updateTargetAction(target.id, { statuses: final });
    if (res.target) {
      setTargets((prev) => prev.map((t) => (t.id === target.id ? res.target! : t)));
    }
  }

  async function saveEmail(target: OutreachTarget, email: string) {
    const res = await updateTargetAction(target.id, { email: email || null });
    if (res.target) {
      setTargets((prev) => prev.map((t) => (t.id === target.id ? res.target! : t)));
    }
  }

  async function saveContactPerson(target: OutreachTarget, cp: string) {
    const res = await updateTargetAction(target.id, { contactPerson: cp || null });
    if (res.target) {
      setTargets((prev) => prev.map((t) => (t.id === target.id ? res.target! : t)));
    }
  }

  async function downloadCSV() {
    const res = await exportTargetsCSVAction({
      area: "lofoten",
      category: filterCategory || undefined,
      statuses: filterStatuses.size > 0 ? [...filterStatuses] : undefined,
    });
    if (res.error) {
      alert(`Eksport feilet: ${res.error}`);
      return;
    }
    const blob = new Blob([res.csv ?? ""], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `outreach-lofoten-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  async function geocodeTarget(target: OutreachTarget): Promise<{ error?: string }> {
    const res = await geocodeTargetAction(target.id);
    if (res.target) {
      setTargets((prev) => prev.map((t) => (t.id === target.id ? res.target! : t)));
    }
    return { error: res.error };
  }

  async function logNote(target: OutreachTarget, note: string) {
    const res = await logNoteAction(target.id, note);
    if (res.ok) {
      const detail = await loadTargetDetailAction(target.id);
      if (detail.log) setContactLog(detail.log);
    }
  }

  function startSplitDrag(e: React.PointerEvent<HTMLDivElement>) {
    draggingRef.current = true;
    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
    e.preventDefault();
  }

  useEffect(() => {
    function onMove(e: PointerEvent) {
      if (!draggingRef.current || !splitContainerRef.current) return;
      const rect = splitContainerRef.current.getBoundingClientRect();
      const pct = ((e.clientX - rect.left) / rect.width) * 100;
      setListWidth(Math.max(20, Math.min(70, pct)));
    }
    function onUp() {
      if (!draggingRef.current) return;
      draggingRef.current = false;
      document.body.style.cursor = "";
      document.body.style.userSelect = "";
      try {
        window.localStorage.setItem("outreach_list_width", String(listWidth));
      } catch {
        // ignore storage errors (private mode etc.)
      }
    }
    window.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", onUp);
    return () => {
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
    };
  }, [listWidth]);

  return (
    <div className="h-[calc(100vh-58px)] w-full">
      {/* Header */}
      <div className="border-b border-neutral-200 bg-white px-4 py-3 sm:px-6">
        <div className="flex items-center gap-3">
          <Link href="/admin" className="text-sm text-neutral-500 hover:text-neutral-700">
            <ChevronLeft className="inline h-4 w-4" /> Admin
          </Link>
          <h1 className="text-lg font-semibold">Utleier-outreach · Lofoten</h1>
          <span className="text-sm text-neutral-500">{filtered.length} av {targets.length}</span>
        </div>

        {/* Status-pillrekke */}
        <div className="mt-2 flex flex-wrap gap-2">
          {STATUSES.map((s) => (
            <button
              key={s}
              onClick={() => setFilterStatuses((prev) => {
                const next = new Set(prev);
                if (next.has(s)) next.delete(s); else next.add(s);
                return next;
              })}
              className={`flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs ${
                filterStatuses.has(s) ? "border-neutral-900 bg-neutral-900 text-white" : "border-neutral-200 bg-white text-neutral-700"
              }`}
            >
              <span className="inline-block h-2 w-2 rounded-full" style={{ background: OUTREACH_STATUS_COLORS[s] }} />
              {OUTREACH_STATUS_LABELS[s]} ({counts[s]})
            </button>
          ))}
        </div>

        {/* Filtre + actions */}
        <div className="mt-3 flex flex-wrap items-center gap-2">
          <div className="relative">
            <Search className="absolute left-2.5 top-1/2 h-4 w-4 -translate-y-1/2 text-neutral-400" />
            <input
              type="text"
              placeholder="Søk navn"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="rounded-md border border-neutral-200 py-1.5 pl-8 pr-3 text-sm focus:border-primary-500 focus:outline-none"
            />
          </div>
          <select
            value={filterCategory}
            onChange={(e) => setFilterCategory(e.target.value as OutreachCategory | "")}
            className="rounded-md border border-neutral-200 px-2 py-1.5 text-sm"
          >
            <option value="">Alle kategorier</option>
            {CATEGORIES.map((c) => (
              <option key={c} value={c}>{OUTREACH_CATEGORY_LABELS[c]}</option>
            ))}
          </select>
          <button
            onClick={runDiscover}
            disabled={discoverPending}
            className="flex items-center gap-1.5 rounded-md bg-primary-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-primary-700 disabled:opacity-50"
          >
            <RefreshCw className={`h-4 w-4 ${discoverPending ? "animate-spin" : ""}`} />
            {discoverPending ? "Henter..." : "Hent fra Google"}
          </button>
          <button
            onClick={downloadCSV}
            className="flex items-center gap-1.5 rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm hover:bg-neutral-50"
          >
            <Download className="h-4 w-4" /> Eksporter CSV
          </button>
          <button
            onClick={() => setShowAddTarget(true)}
            className="flex items-center gap-1.5 rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm hover:bg-neutral-50"
          >
            <Plus className="h-4 w-4" /> Legg til
          </button>
          <button
            onClick={() => setShowTemplates(true)}
            className="rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm hover:bg-neutral-50"
          >
            Mal-bibliotek
          </button>
          <button
            onClick={sendTestMail}
            disabled={testMailPending}
            className="flex items-center gap-1.5 rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm hover:bg-neutral-50 disabled:opacity-50"
          >
            <Mail className="h-4 w-4" />
            {testMailPending ? "Sender..." : "Test-mail"}
          </button>
        </div>
        {testMailMsg && (
          <div className={`mt-2 rounded-md px-3 py-2 text-sm ${testMailMsg.startsWith("Feil") ? "bg-red-50 text-red-700" : "bg-primary-50 text-primary-700"}`}>
            {testMailMsg}
          </div>
        )}
        {discoverMessage && (
          <div
            className={`mt-2 rounded-md px-3 py-2 text-sm ${
              discoverMessage.startsWith("Feil")
                ? "bg-red-50 text-red-700"
                : "bg-primary-50 text-primary-700"
            }`}
          >
            {discoverMessage}
            <button
              onClick={() => setDiscoverMessage(null)}
              className="ml-2 text-xs underline opacity-70 hover:opacity-100"
            >
              lukk
            </button>
          </div>
        )}
      </div>

      {/* List + Map */}
      <div ref={splitContainerRef} className="flex h-[calc(100%-152px)]">
        <div
          style={{ width: `${listWidth}%`, minWidth: 280 }}
          className="overflow-y-auto bg-white"
        >
          {filtered.length === 0 ? (
            <div className="p-6 text-center text-sm text-neutral-500">
              {targets.length === 0
                ? "Ingen aktører enda. Trykk \"Hent fra Google\" for å starte."
                : "Ingen treff for valgte filtre."}
            </div>
          ) : (
            <ul>
              {filtered.map((t) => (
                <li
                  key={t.id}
                  onMouseEnter={() => setHoveredId(t.id)}
                  onMouseLeave={() => setHoveredId(null)}
                  onClick={() => setSelectedId(t.id)}
                  className={`cursor-pointer border-b border-neutral-100 px-4 py-3 transition-colors ${
                    selectedId === t.id ? "bg-primary-50" : hoveredId === t.id ? "bg-neutral-50" : ""
                  }`}
                >
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium text-neutral-900">{t.name}</p>
                      <div className="mt-1 flex flex-wrap gap-1">
                        {t.statuses.map((s) => (
                          <span
                            key={s}
                            className="rounded-full px-1.5 py-0.5 text-[10px] font-medium text-white"
                            style={{ background: OUTREACH_STATUS_COLORS[s] }}
                          >
                            {OUTREACH_STATUS_LABELS[s]}
                          </span>
                        ))}
                      </div>
                      <p className="mt-0.5 text-xs text-neutral-500">
                        {OUTREACH_CATEGORY_LABELS[t.category]}
                        {t.rating != null && (
                          <>
                            {" · "}<Star className="inline h-3 w-3 text-amber-500" /> {t.rating.toFixed(1)}
                            {t.userRatingsTotal ? ` (${t.userRatingsTotal})` : ""}
                          </>
                        )}
                      </p>
                      {t.contactPerson && (
                        <p className="mt-0.5 text-xs text-neutral-500">Kontakt: {t.contactPerson}</p>
                      )}
                      {t.address && (
                        <p className="mt-0.5 truncate text-xs text-neutral-500">{t.address}</p>
                      )}
                      <div className="mt-1 flex flex-wrap gap-2 text-[11px] text-neutral-500">
                        {t.phone && <span><Phone className="inline h-3 w-3" /> {t.phone}</span>}
                        {t.website && (
                          <a
                            href={t.website}
                            target="_blank"
                            rel="noopener noreferrer"
                            onClick={(e) => e.stopPropagation()}
                            className="text-primary-600 hover:underline"
                          >
                            Nettside
                          </a>
                        )}
                        <a
                          href={googleMapsLink(t.placeId, t.name)}
                          target="_blank"
                          rel="noopener noreferrer"
                          onClick={(e) => e.stopPropagation()}
                          className="text-primary-600 hover:underline"
                        >
                          Google Maps
                        </a>
                      </div>
                    </div>
                    <div className="flex flex-wrap gap-1">
                      {t.statuses.slice(0, 2).map((s) => (
                        <span key={s} className="rounded-full px-1.5 py-0.5 text-[10px] font-medium text-white" style={{ background: OUTREACH_STATUS_COLORS[s] }}>
                          {OUTREACH_STATUS_LABELS[s]}
                        </span>
                      ))}
                      {t.statuses.length > 2 && <span className="text-[10px] text-neutral-400">+{t.statuses.length - 2}</span>}
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div
          onPointerDown={startSplitDrag}
          className="group w-1 shrink-0 cursor-col-resize bg-neutral-200 transition-colors hover:bg-primary-500 active:bg-primary-500"
          title="Dra for å endre størrelse"
        >
          <div className="h-full w-1" />
        </div>

        <div className="relative h-full flex-1">
          <OutreachMap
            targets={filtered}
            selectedId={selectedId}
            hoveredId={hoveredId}
            onSelect={setSelectedId}
            onHover={setHoveredId}
          />
        </div>
      </div>

      {/* Detail-drawer */}
      {selected && (
        <DetailDrawer
          target={selected}
          contactLog={contactLog}
          loading={loadingDetail}
          templates={templates}
          onClose={() => setSelectedId(null)}
          onToggleStatus={(s) => toggleStatus(selected, s)}
          onSaveEmail={(e) => saveEmail(selected, e)}
          onSaveContactPerson={(cp) => saveContactPerson(selected, cp)}
          onLogNote={(n) => logNote(selected, n)}
          onGeocode={() => geocodeTarget(selected)}
          onOpenComposer={() => setShowComposer(true)}
        />
      )}

      {/* Email composer */}
      {selected && showComposer && (
        <EmailComposer
          target={selected}
          templates={templates}
          onClose={() => setShowComposer(false)}
          onSent={() => {
            setShowComposer(false);
            // Refresh log + target after send
            loadTargetDetailAction(selected.id).then((res) => {
              if (res.log) setContactLog(res.log);
              if (res.target) {
                setTargets((prev) => prev.map((t) => (t.id === selected.id ? res.target! : t)));
              }
            });
          }}
        />
      )}

      {/* Template manager */}
      {showTemplates && (
        <TemplateManager
          templates={templates}
          onClose={() => setShowTemplates(false)}
          onChanged={(updated) => setTemplates(updated)}
        />
      )}

      {/* Add target modal */}
      {showAddTarget && (
        <AddTargetModal
          onClose={() => setShowAddTarget(false)}
          onCreated={() => { setShowAddTarget(false); refresh(); }}
        />
      )}
    </div>
  );
}

// ─── Detail drawer ───────────────────────────────────────────────────────────

interface DrawerProps {
  target: OutreachTarget;
  contactLog: OutreachContactLogEntry[];
  loading: boolean;
  templates: OutreachEmailTemplate[];
  onClose: () => void;
  onToggleStatus: (s: OutreachStatus) => void;
  onSaveEmail: (e: string) => void;
  onSaveContactPerson: (cp: string) => void;
  onLogNote: (note: string) => void;
  onGeocode: () => Promise<{ error?: string }>;
  onOpenComposer: () => void;
}

function DetailDrawer({
  target, contactLog, loading,
  onClose, onToggleStatus, onSaveEmail, onSaveContactPerson, onLogNote, onGeocode, onOpenComposer,
}: DrawerProps) {
  const [email, setEmail] = useState(target.email ?? "");
  const [contactPerson, setContactPerson] = useState(target.contactPerson ?? "");
  const [noteText, setNoteText] = useState("");
  const [geocoding, setGeocoding] = useState(false);
  const [geoError, setGeoError] = useState<string | null>(null);

  // Resync when target changes
  useEffect(() => {
    setEmail(target.email ?? "");
    setContactPerson(target.contactPerson ?? "");
    setNoteText("");
    setGeoError(null);
  }, [target.id, target.email, target.contactPerson]);

  return (
    <div className="fixed inset-y-0 right-0 z-40 w-full max-w-md overflow-y-auto border-l border-neutral-200 bg-white shadow-xl">
      <div className="flex items-center justify-between border-b border-neutral-200 px-4 py-3">
        <div className="min-w-0">
          <h2 className="truncate text-base font-semibold">{target.name}</h2>
          <p className="text-xs text-neutral-500">{OUTREACH_CATEGORY_LABELS[target.category]} · {target.area}</p>
        </div>
        <button onClick={onClose} className="rounded p-1 hover:bg-neutral-100">
          <X className="h-4 w-4" />
        </button>
      </div>

      <div className="space-y-5 px-4 py-4">
        {/* Status tags */}
        <div>
          <label className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">Status</label>
          <div className="mt-1.5 flex flex-wrap gap-1.5">
            {STATUSES.map((s) => {
              const active = target.statuses.includes(s);
              return (
                <button
                  key={s}
                  onClick={() => onToggleStatus(s)}
                  className={`rounded-full px-2.5 py-1 text-xs font-medium transition-colors ${
                    active
                      ? "text-white"
                      : "border border-neutral-200 bg-white text-neutral-500 hover:bg-neutral-50"
                  }`}
                  style={active ? { background: OUTREACH_STATUS_COLORS[s] } : undefined}
                >
                  {OUTREACH_STATUS_LABELS[s]}
                </button>
              );
            })}
          </div>
        </div>

        {/* Contact info */}
        <div className="space-y-2">
          <label className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">Kontakt</label>
          {target.address && <p className="text-sm text-neutral-700">{target.address}</p>}
          {target.phone && (
            <p className="text-sm">
              <Phone className="inline h-3.5 w-3.5 text-neutral-500" />{" "}
              <a href={`tel:${target.phone}`} className="text-primary-600 hover:underline">{target.phone}</a>
            </p>
          )}
          {target.website && (
            <p className="text-sm">
              <a href={target.website} target="_blank" rel="noopener noreferrer" className="text-primary-600 hover:underline">
                {target.website}
              </a>
            </p>
          )}
          <p className="text-sm">
            <a
              href={googleMapsLink(target.placeId, target.name)}
              target="_blank"
              rel="noopener noreferrer"
              className="text-primary-600 hover:underline"
            >
              Vis i Google Maps
            </a>
          </p>
          {target.rating != null && (
            <p className="text-sm text-neutral-600">
              <Star className="inline h-3.5 w-3.5 text-amber-500" /> {target.rating.toFixed(1)} ({target.userRatingsTotal ?? 0} vurderinger)
            </p>
          )}
          {target.lat == null && (target.address || target.name) && (
            <div>
              <button
                onClick={async () => {
                  setGeocoding(true);
                  setGeoError(null);
                  const res = await onGeocode();
                  setGeocoding(false);
                  if (res?.error) setGeoError(res.error);
                }}
                disabled={geocoding}
                className="flex items-center gap-1.5 rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm hover:bg-neutral-50 disabled:opacity-50"
              >
                <MapPin className="h-4 w-4 text-neutral-500" />
                {geocoding ? "Finner posisjon..." : "Finn posisjon på kart"}
              </button>
              {geoError && <p className="mt-1 text-xs text-red-600">{geoError}</p>}
            </div>
          )}
        </div>

        {/* Kontaktperson */}
        <div>
          <label className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">
            Kontaktperson
          </label>
          <input
            type="text"
            value={contactPerson}
            onChange={(e) => setContactPerson(e.target.value)}
            onBlur={() => onSaveContactPerson(contactPerson)}
            placeholder="Navn på kontaktperson"
            className="mt-1 w-full rounded-md border border-neutral-200 px-2 py-2 text-sm"
          />
        </div>

        {/* E-post */}
        <div>
          <label className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">
            E-postadresse
          </label>
          <div className="mt-1 flex gap-2">
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              onBlur={() => onSaveEmail(email)}
              placeholder="kontakt@bedrift.no"
              className="flex-1 rounded-md border border-neutral-200 px-2 py-2 text-sm"
            />
            <button
              onClick={onOpenComposer}
              disabled={!email}
              className="flex items-center gap-1.5 rounded-md bg-primary-600 px-3 py-2 text-sm font-medium text-white hover:bg-primary-700 disabled:opacity-50"
            >
              <Mail className="h-4 w-4" /> Send mail
            </button>
          </div>
          {target.lastContactedAt && (
            <p className="mt-1 text-[11px] text-neutral-500">
              Sist kontaktet: {new Date(target.lastContactedAt).toLocaleString("nb-NO")}
            </p>
          )}
        </div>

        {/* Legg til notat */}
        <div className="rounded-lg border border-neutral-200 p-3">
          <p className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">Legg til notat</p>
          <textarea
            value={noteText}
            onChange={(e) => setNoteText(e.target.value)}
            placeholder="Hva ble sagt? Plan for oppfølging..."
            className="mt-2 h-24 w-full rounded-md border border-neutral-200 px-2 py-2 text-sm leading-relaxed"
          />
          <button
            onClick={() => {
              if (!noteText.trim()) return;
              onLogNote(noteText);
              setNoteText("");
            }}
            disabled={!noteText.trim()}
            className="mt-2 rounded-md bg-neutral-900 px-3 py-2 text-sm font-medium text-white hover:bg-neutral-800 disabled:opacity-50"
          >
            Lagre notat
          </button>
        </div>

        {/* Generelt notat (bevart, read-only) */}
        {target.notes && target.notes.trim() && (
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">Notat</p>
            <div className="mt-1 whitespace-pre-wrap rounded-md border border-neutral-200 bg-neutral-50 p-3 text-sm leading-relaxed text-neutral-700">
              {target.notes}
            </div>
          </div>
        )}

        {/* Historikk */}
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">Historikk</p>
          {loading ? (
            <p className="mt-2 text-sm text-neutral-500">Laster...</p>
          ) : contactLog.length === 0 ? (
            <p className="mt-2 text-sm text-neutral-500">Ingen kontakt-historikk enda.</p>
          ) : (
            <ul className="mt-2 space-y-3">
              {contactLog.map((e) => (
                <li key={e.id} className="rounded-md bg-neutral-50 p-3 text-sm">
                  <div className="flex justify-between text-xs text-neutral-500">
                    <span>
                      {e.contactType === "email" ? "E-post" : e.contactType === "phone" ? "Telefon" : "Notat"}
                      {e.contactedByName ? ` · ${e.contactedByName}` : ""}
                    </span>
                    <span>{new Date(e.createdAt).toLocaleString("nb-NO")}</span>
                  </div>
                  {e.subject && <p className="mt-1 font-medium text-neutral-700">{e.subject}</p>}
                  {e.recipient && <p className="text-neutral-500">Til: {e.recipient}</p>}
                  {e.body && (
                    <pre className="mt-1 whitespace-pre-wrap font-sans leading-relaxed text-neutral-700">{e.body}</pre>
                  )}
                  {e.statusAfter && (
                    <p className="mt-1 text-neutral-500">→ {OUTREACH_STATUS_LABELS[e.statusAfter as OutreachStatus] ?? e.statusAfter}</p>
                  )}
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  );
}
