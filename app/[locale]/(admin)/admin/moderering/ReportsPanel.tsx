"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { Check, ExternalLink, Flag, MessageSquareWarning, Trash2, X } from "lucide-react";
import {
  deleteFlaggedContentAction,
  loadReportsAction,
  resolveFlagAction,
  resolveReportAction,
  type AdminContentFlag,
  type AdminReport,
} from "./actions";

const REASON_LABELS: Record<string, string> = {
  scam: "Svindel / betaling utenom Tuno",
  inappropriate: "Upassende innhold",
  harassment: "Trakassering / trusler",
  fake: "Falsk annonse / profil",
  spam: "Spam",
  other: "Annet",
};

function fmt(iso: string | null) {
  if (!iso) return "";
  return new Date(iso).toLocaleString("nb-NO", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" });
}

export default function ReportsPanel({ mode, focusReportId }: { mode: "reports" | "content"; focusReportId: string | null }) {
  const [reports, setReports] = useState<AdminReport[]>([]);
  const [flags, setFlags] = useState<AdminContentFlag[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [showHandled, setShowHandled] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);

  const reload = useCallback(async () => {
    const res = await loadReportsAction();
    if (res.error) setError(res.error);
    else {
      setReports(res.reports ?? []);
      setFlags(res.flags ?? []);
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    queueMicrotask(() => { void reload(); });
  }, [reload]);

  const run = async (id: string, fn: () => Promise<{ error?: string }>) => {
    setBusy(id);
    const res = await fn();
    if (res.error) setError(res.error);
    await reload();
    setBusy(null);
  };

  const visibleReports = useMemo(() => reports.filter((r) => showHandled || r.status === "open"), [reports, showHandled]);
  const visibleFlags = useMemo(() => flags.filter((f) => showHandled || f.status === "open"), [flags, showHandled]);

  if (loading) return <p className="mt-8 text-sm text-neutral-500">Laster...</p>;

  return (
    <div className="mt-4">
      {error && <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>}
      <label className="flex items-center gap-2 text-sm text-neutral-600">
        <input type="checkbox" checked={showHandled} onChange={(e) => setShowHandled(e.target.checked)} />
        Vis behandlede
      </label>

      {mode === "reports" ? (
        visibleReports.length === 0 ? (
          <div className="mt-6 rounded-xl border border-dashed border-neutral-200 p-10 text-center text-sm text-neutral-500">Ingen rapporter.</div>
        ) : (
          <div className="mt-4 space-y-3">
            {visibleReports.map((r) => (
              <div key={r.id} className={`rounded-xl border bg-white p-4 ${r.status === "open" ? "border-amber-200" : "border-neutral-200 opacity-70"} ${focusReportId === r.id ? "ring-2 ring-primary-500" : ""}`}>
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-800"><Flag className="h-3 w-3" />{REASON_LABELS[r.reason] ?? r.reason}</span>
                      <span className="rounded-full bg-neutral-100 px-2 py-0.5 text-xs text-neutral-600">{r.target_type}</span>
                      <span className="text-xs text-neutral-400">{fmt(r.created_at)}</span>
                      {r.status !== "open" && <span className="rounded-full bg-neutral-800 px-2 py-0.5 text-xs text-white">{r.status}</span>}
                    </div>
                    <p className="mt-2 text-sm text-neutral-900">
                      <span className="font-semibold">{r.target_label}</span>
                      {r.target_type === "listing" && (
                        <Link href={`/admin/moderering?listing=${r.target_id}`} className="ml-2 inline-flex align-middle text-neutral-400 hover:text-neutral-700"><ExternalLink className="h-4 w-4" /></Link>
                      )}
                    </p>
                    <p className="text-xs text-neutral-500">Rapportert av {r.reporter?.full_name ?? "ukjent"}</p>
                    {r.details && <p className="mt-2 whitespace-pre-line rounded-lg bg-neutral-50 p-3 text-sm text-neutral-700">{r.details}</p>}
                    {r.admin_note && <p className="mt-2 text-xs text-neutral-500">Notat: {r.admin_note}</p>}
                  </div>
                  {r.status === "open" && (
                    <div className="flex gap-2">
                      <button disabled={busy === r.id} onClick={() => run(r.id, () => resolveReportAction(r.id, "reviewed"))} className="flex items-center gap-1.5 rounded-lg bg-primary-600 px-3 py-2 text-sm font-medium text-white hover:bg-primary-700 disabled:opacity-50"><Check className="h-4 w-4" /> Behandlet</button>
                      <button disabled={busy === r.id} onClick={() => run(r.id, () => resolveReportAction(r.id, "dismissed"))} className="flex items-center gap-1.5 rounded-lg border border-neutral-200 px-3 py-2 text-sm text-neutral-700 hover:bg-neutral-50 disabled:opacity-50"><X className="h-4 w-4" /> Avvis</button>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        )
      ) : visibleFlags.length === 0 ? (
        <div className="mt-6 rounded-xl border border-dashed border-neutral-200 p-10 text-center text-sm text-neutral-500">Ingen flagget innhold.</div>
      ) : (
        <div className="mt-4 space-y-3">
          {visibleFlags.map((f) => (
            <div key={f.id} className={`rounded-xl border bg-white p-4 ${f.status === "open" ? (f.severity === "high" ? "border-red-300" : "border-amber-200") : "border-neutral-200 opacity-70"}`}>
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-semibold ${f.severity === "high" ? "bg-red-100 text-red-700" : f.severity === "medium" ? "bg-amber-100 text-amber-800" : "bg-neutral-100 text-neutral-700"}`}><MessageSquareWarning className="h-3 w-3" />{f.category} · {f.severity}</span>
                    <span className="rounded-full bg-neutral-100 px-2 py-0.5 text-xs text-neutral-600">{f.content_type}</span>
                    <span className="text-xs text-neutral-400">{fmt(f.created_at)}</span>
                    {!f.content_exists && <span className="text-xs text-neutral-400">(innholdet er slettet)</span>}
                    {f.status !== "open" && <span className="rounded-full bg-neutral-800 px-2 py-0.5 text-xs text-white">{f.status}</span>}
                  </div>
                  <p className="mt-2 text-xs text-neutral-500">{f.author?.full_name ?? "ukjent"}</p>
                  {f.content_type === "avatar" && f.excerpt ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={f.excerpt} alt="" className="mt-2 h-24 w-24 rounded-lg object-cover" />
                  ) : (
                    <p className="mt-2 whitespace-pre-line rounded-lg bg-neutral-50 p-3 text-sm text-neutral-800">{f.excerpt}</p>
                  )}
                  {f.reason && <p className="mt-2 text-sm text-neutral-600">AI: {f.reason}</p>}
                </div>
                {f.status === "open" && (
                  <div className="flex gap-2">
                    {f.content_type !== "avatar" && f.content_exists && (
                      <button disabled={busy === f.id} onClick={() => { if (confirm("Fjerne innholdet permanent?")) run(f.id, () => deleteFlaggedContentAction(f.id)); }} className="flex items-center gap-1.5 rounded-lg bg-red-600 px-3 py-2 text-sm font-medium text-white hover:bg-red-700 disabled:opacity-50"><Trash2 className="h-4 w-4" /> Fjern innhold</button>
                    )}
                    <button disabled={busy === f.id} onClick={() => run(f.id, () => resolveFlagAction(f.id, "reviewed"))} className="flex items-center gap-1.5 rounded-lg bg-primary-600 px-3 py-2 text-sm font-medium text-white hover:bg-primary-700 disabled:opacity-50"><Check className="h-4 w-4" /> Behandlet</button>
                    <button disabled={busy === f.id} onClick={() => run(f.id, () => resolveFlagAction(f.id, "dismissed"))} className="flex items-center gap-1.5 rounded-lg border border-neutral-200 px-3 py-2 text-sm text-neutral-700 hover:bg-neutral-50 disabled:opacity-50"><X className="h-4 w-4" /> Falsk alarm</button>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
