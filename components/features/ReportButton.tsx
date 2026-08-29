"use client";

import { useState } from "react";
import { Flag, X } from "lucide-react";
import { useTranslations } from "next-intl";

type TargetType = "listing" | "user" | "conversation" | "review";
type Reason = "scam" | "inappropriate" | "harassment" | "fake" | "spam" | "other";

const REASONS: Reason[] = ["scam", "inappropriate", "harassment", "fake", "spam", "other"];

interface ReportButtonProps {
  targetType: TargetType;
  targetId: string;
  /** "icon" = rund knapp som Share/Favoritt, "link" = liten tekstlenke, "menu" = rad i en meny */
  variant?: "icon" | "link" | "menu";
  className?: string;
}

export default function ReportButton({ targetType, targetId, variant = "link", className }: ReportButtonProps) {
  const t = useTranslations("report");
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState<Reason | null>(null);
  const [details, setDetails] = useState("");
  const [state, setState] = useState<"idle" | "sending" | "done" | "error">("idle");
  const [error, setError] = useState("");

  const submit = async () => {
    if (!reason) return;
    setState("sending");
    setError("");
    try {
      const res = await fetch("/api/reports", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ targetType, targetId, reason, details }),
      });
      const json = await res.json();
      if (!res.ok) {
        setError(res.status === 401 ? t("loginRequired") : json.error || t("failed"));
        setState("error");
        return;
      }
      setState("done");
    } catch {
      setError(t("failed"));
      setState("error");
    }
  };

  const trigger =
    variant === "icon" ? (
      <button
        type="button"
        onClick={() => setOpen(true)}
        title={t("title")}
        className={className ?? "p-2 rounded-full bg-neutral-100 transition-all hover:bg-neutral-200 active:scale-95"}
      >
        <Flag className="h-5 w-5 text-neutral-700" />
      </button>
    ) : variant === "menu" ? (
      <button type="button" onClick={() => setOpen(true)} className={className ?? "flex w-full items-center gap-3 px-4 py-2.5 min-h-[44px] text-sm text-neutral-700 hover:bg-neutral-50"}>
        <Flag className="h-4 w-4" />
        {t("title")}
      </button>
    ) : (
      <button type="button" onClick={() => setOpen(true)} className={className ?? "inline-flex items-center gap-1 text-xs text-neutral-500 underline hover:text-neutral-700"}>
        <Flag className="h-3 w-3" />
        {t(targetType === "user" ? "reportUser" : targetType === "listing" ? "reportListing" : "title")}
      </button>
    );

  return (
    <>
      {trigger}
      {open && (
        <div className="fixed inset-0 z-[100] flex items-end justify-center bg-black/40 p-0 sm:items-center sm:p-4" onClick={() => setOpen(false)}>
          <div className="w-full max-w-md rounded-t-2xl bg-white p-5 sm:rounded-2xl" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-semibold text-neutral-900">{t("title")}</h3>
              <button onClick={() => setOpen(false)} className="rounded-full p-1 hover:bg-neutral-100"><X className="h-5 w-5" /></button>
            </div>

            {state === "done" ? (
              <div className="mt-4">
                <p className="text-sm text-neutral-700">{t("thanks")}</p>
                <button onClick={() => setOpen(false)} className="mt-4 w-full rounded-lg bg-neutral-900 py-2.5 text-sm font-medium text-white">{t("close")}</button>
              </div>
            ) : (
              <>
                <p className="mt-1 text-sm text-neutral-500">{t("subtitle")}</p>
                <div className="mt-3 space-y-1.5">
                  {REASONS.map((r) => (
                    <label key={r} className={`flex cursor-pointer items-center gap-3 rounded-lg border px-3 py-2.5 text-sm ${reason === r ? "border-primary-500 bg-primary-50" : "border-neutral-200 hover:bg-neutral-50"}`}>
                      <input type="radio" name="reason" checked={reason === r} onChange={() => setReason(r)} className="accent-primary-600" />
                      {t(`reason_${r}`)}
                    </label>
                  ))}
                </div>
                <textarea
                  value={details}
                  onChange={(e) => setDetails(e.target.value)}
                  rows={3}
                  maxLength={2000}
                  placeholder={t("detailsPlaceholder")}
                  className="mt-3 w-full rounded-lg border border-neutral-200 p-3 text-sm focus:border-primary-500 focus:outline-none"
                />
                {error && <p className="mt-2 text-sm text-red-600">{error}</p>}
                <button
                  onClick={submit}
                  disabled={!reason || state === "sending"}
                  className="mt-3 w-full rounded-lg bg-neutral-900 py-2.5 text-sm font-medium text-white disabled:opacity-50"
                >
                  {state === "sending" ? t("sending") : t("send")}
                </button>
              </>
            )}
          </div>
        </div>
      )}
    </>
  );
}
