"use client";

import { useEffect, useMemo, useState, useTransition } from "react";
import Link from "next/link";
import { ChevronLeft, Download, Mail, Phone, RefreshCw, Search, Star, X } from "lucide-react";
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
import {
  exportTargetsCSVAction,
  loadOutreachAction,
  loadTargetDetailAction,
  logNoteAction,
  logPhoneCallAction,
  updateTargetAction,
} from "./actions";

const CATEGORIES: OutreachCategory[] = ["rorbu", "hotell", "restaurant", "camping", "overnatting"];
const STATUSES: OutreachStatus[] = [
  "not_contacted",
  "queued",
  "contacted",
  "follow_up",
  "responded",
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
  const [filterCategory, setFilterCategory] = useState<OutreachCategory | "">("");
  const [filterStatus, setFilterStatus] = useState<OutreachStatus | "">("");
  const [search, setSearch] = useState("");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [hoveredId, setHoveredId] = useState<string | null>(null);
  const [contactLog, setContactLog] = useState<OutreachContactLogEntry[]>([]);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [discoverPending, startDiscover] = useTransition();
  const [discoverMessage, setDiscoverMessage] = useState<string | null>(null);
  const [showComposer, setShowComposer] = useState(false);
  const [showTemplates, setShowTemplates] = useState(false);

  const filtered = useMemo(() => {
    return targets.filter((t) => {
      if (filterCategory && t.category !== filterCategory) return false;
      if (filterStatus && t.status !== filterStatus) return false;
      if (search && !t.name.toLowerCase().includes(search.toLowerCase())) return false;
      return true;
    });
  }, [targets, filterCategory, filterStatus, search]);

  const selected = useMemo(() => targets.find((t) => t.id === selectedId) ?? null, [targets, selectedId]);

  const counts = useMemo(() => {
    const c: Record<OutreachStatus, number> = {
      not_contacted: 0, queued: 0, contacted: 0, follow_up: 0, responded: 0, declined: 0, onboarded: 0,
    };
    targets.forEach((t) => { c[t.status]++; });
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
        setDiscoverMessage(
          `Lagt til ${json.inserted}, oppdatert ${json.updated}, hoppet over ${json.skipped} (totalt ${json.totalFetched} fra Google)`,
        );
        await refresh();
      } catch (err) {
        setDiscoverMessage(`Feil: ${err instanceof Error ? err.message : "ukjent"}`);
      }
    });
  }

  async function changeStatus(target: OutreachTarget, status: OutreachStatus) {
    const res = await updateTargetAction(target.id, { status });
    if (res.target) {
      setTargets((prev) => prev.map((t) => (t.id === target.id ? res.target! : t)));
    }
  }

  async function saveNotes(target: OutreachTarget, notes: string) {
    const res = await updateTargetAction(target.id, { notes });
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

  async function downloadCSV() {
    const res = await exportTargetsCSVAction({
      area: "lofoten",
      category: filterCategory || undefined,
      status: filterStatus || undefined,
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

  async function logPhone(target: OutreachTarget, outcome: string, newStatus?: OutreachStatus) {
    const res = await logPhoneCallAction(target.id, outcome, newStatus);
    if (res.ok) {
      const detail = await loadTargetDetailAction(target.id);
      if (detail.log) setContactLog(detail.log);
      if (detail.target) setTargets((prev) => prev.map((t) => (t.id === target.id ? detail.target! : t)));
    }
  }

  async function logNote(target: OutreachTarget, note: string) {
    const res = await logNoteAction(target.id, note);
    if (res.ok) {
      const detail = await loadTargetDetailAction(target.id);
      if (detail.log) setContactLog(detail.log);
    }
  }

  return (
    <div className="mx-auto h-[calc(100vh-58px)] max-w-7xl">
      {/* Header */}
      <div className="border-b border-neutral-200 bg-white px-4 py-3 sm:px-6">
        <div className="flex items-center gap-3">
          <Link href="../" className="text-sm text-neutral-500 hover:text-neutral-700">
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
              onClick={() => setFilterStatus(filterStatus === s ? "" : s)}
              className={`flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs ${
                filterStatus === s ? "border-neutral-900 bg-neutral-900 text-white" : "border-neutral-200 bg-white text-neutral-700"
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
            onClick={() => setShowTemplates(true)}
            className="rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm hover:bg-neutral-50"
          >
            Mal-bibliotek
          </button>
          {discoverMessage && (
            <span className="text-xs text-neutral-600">{discoverMessage}</span>
          )}
        </div>
      </div>

      {/* List + Map */}
      <div className="grid h-[calc(100%-152px)] grid-cols-1 lg:grid-cols-[minmax(360px,40%)_1fr]">
        <div className="overflow-y-auto border-r border-neutral-200 bg-white">
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
                      <div className="flex items-center gap-2">
                        <span
                          className="inline-block h-2 w-2 rounded-full"
                          style={{ background: OUTREACH_STATUS_COLORS[t.status] }}
                        />
                        <p className="truncate text-sm font-medium text-neutral-900">{t.name}</p>
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
                      </div>
                    </div>
                    <span className="rounded bg-neutral-100 px-1.5 py-0.5 text-[10px] uppercase tracking-wide text-neutral-600">
                      {OUTREACH_STATUS_LABELS[t.status]}
                    </span>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="relative h-full">
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
          onChangeStatus={(s) => changeStatus(selected, s)}
          onSaveNotes={(n) => saveNotes(selected, n)}
          onSaveEmail={(e) => saveEmail(selected, e)}
          onLogPhone={(o, s) => logPhone(selected, o, s)}
          onLogNote={(n) => logNote(selected, n)}
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
  onChangeStatus: (s: OutreachStatus) => void;
  onSaveNotes: (n: string) => void;
  onSaveEmail: (e: string) => void;
  onLogPhone: (outcome: string, newStatus?: OutreachStatus) => void;
  onLogNote: (note: string) => void;
  onOpenComposer: () => void;
}

function DetailDrawer({
  target, contactLog, loading,
  onClose, onChangeStatus, onSaveNotes, onSaveEmail, onLogPhone, onLogNote, onOpenComposer,
}: DrawerProps) {
  const [notes, setNotes] = useState(target.notes ?? "");
  const [email, setEmail] = useState(target.email ?? "");
  const [phoneOutcome, setPhoneOutcome] = useState("");
  const [phoneStatus, setPhoneStatus] = useState<OutreachStatus | "">("");
  const [noteText, setNoteText] = useState("");

  // Resync when target changes
  useEffect(() => {
    setNotes(target.notes ?? "");
    setEmail(target.email ?? "");
    setPhoneOutcome("");
    setPhoneStatus("");
    setNoteText("");
  }, [target.id, target.notes, target.email]);

  // Debounced notes save
  useEffect(() => {
    if ((target.notes ?? "") === notes) return;
    const t = setTimeout(() => onSaveNotes(notes), 800);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [notes]);

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
        {/* Status */}
        <div>
          <label className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">Status</label>
          <select
            value={target.status}
            onChange={(e) => onChangeStatus(e.target.value as OutreachStatus)}
            className="mt-1 w-full rounded-md border border-neutral-200 px-2 py-2 text-sm"
          >
            {STATUSES.map((s) => (
              <option key={s} value={s}>{OUTREACH_STATUS_LABELS[s]}</option>
            ))}
          </select>
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
          {target.rating != null && (
            <p className="text-sm text-neutral-600">
              <Star className="inline h-3.5 w-3.5 text-amber-500" /> {target.rating.toFixed(1)} ({target.userRatingsTotal ?? 0} vurderinger)
            </p>
          )}
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

        {/* Notater */}
        <div>
          <label className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">
            Notater (auto-lagrer)
          </label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="Hva ble sagt? Plan for oppfølging..."
            className="mt-1 h-20 w-full rounded-md border border-neutral-200 px-2 py-2 text-sm"
          />
        </div>

        {/* Logg telefon */}
        <div className="rounded-lg border border-neutral-200 p-3">
          <p className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">Logg samtale</p>
          <input
            type="text"
            value={phoneOutcome}
            onChange={(e) => setPhoneOutcome(e.target.value)}
            placeholder="Hva ble sagt?"
            className="mt-2 w-full rounded-md border border-neutral-200 px-2 py-2 text-sm"
          />
          <div className="mt-2 flex gap-2">
            <select
              value={phoneStatus}
              onChange={(e) => setPhoneStatus(e.target.value as OutreachStatus | "")}
              className="flex-1 rounded-md border border-neutral-200 px-2 py-2 text-sm"
            >
              <option value="">Ingen status-endring</option>
              {STATUSES.map((s) => (
                <option key={s} value={s}>Sett til: {OUTREACH_STATUS_LABELS[s]}</option>
              ))}
            </select>
            <button
              onClick={() => {
                if (!phoneOutcome.trim()) return;
                onLogPhone(phoneOutcome, phoneStatus || undefined);
                setPhoneOutcome("");
                setPhoneStatus("");
              }}
              disabled={!phoneOutcome.trim()}
              className="rounded-md bg-neutral-900 px-3 py-2 text-sm font-medium text-white hover:bg-neutral-800 disabled:opacity-50"
            >
              Logg
            </button>
          </div>
        </div>

        {/* Logg note */}
        <div className="rounded-lg border border-neutral-200 p-3">
          <p className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">Legg til notat</p>
          <textarea
            value={noteText}
            onChange={(e) => setNoteText(e.target.value)}
            placeholder="Fri-tekst notat..."
            className="mt-2 h-16 w-full rounded-md border border-neutral-200 px-2 py-2 text-sm"
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

        {/* Historikk */}
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">Historikk</p>
          {loading ? (
            <p className="mt-2 text-xs text-neutral-500">Laster...</p>
          ) : contactLog.length === 0 ? (
            <p className="mt-2 text-xs text-neutral-500">Ingen kontakt-historikk enda.</p>
          ) : (
            <ul className="mt-2 space-y-3">
              {contactLog.map((e) => (
                <li key={e.id} className="rounded-md bg-neutral-50 p-2 text-xs">
                  <div className="flex justify-between text-neutral-500">
                    <span>
                      {e.contactType === "email" ? "E-post" : e.contactType === "phone" ? "Telefon" : "Notat"}
                      {e.contactedByName ? ` · ${e.contactedByName}` : ""}
                    </span>
                    <span>{new Date(e.createdAt).toLocaleString("nb-NO")}</span>
                  </div>
                  {e.subject && <p className="mt-1 font-medium text-neutral-700">{e.subject}</p>}
                  {e.recipient && <p className="text-neutral-500">Til: {e.recipient}</p>}
                  {e.body && (
                    <pre className="mt-1 whitespace-pre-wrap font-sans text-neutral-700">{e.body}</pre>
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
