"use client";

import { useEffect, useState } from "react";
import { Calendar, Tag } from "lucide-react";
import type { OfferMessageMetadata } from "@/types";

interface OfferMessageBubbleProps {
  metadata: OfferMessageMetadata;
  /** True hvis det er gjeldende bruker som la tilbudet (avsender-perspektiv). */
  isFromMe: boolean;
  /** True hvis dette er current_offer_id (siste aktive tilbud). */
  isActive: boolean;
  /** Hvilken rolle den innloggede har i denne samtalen. Brukes for accept-label. */
  viewerRole?: "host" | "guest" | null;
  /** True når booking har trigget PaymentIntent — skjuler accept/endre/avslå. */
  awaitingPayment?: boolean;
  /** True mens accept-API-kallet pågår — viser spinner i Godta-knappen. */
  accepting?: boolean;
  onAccept?: () => void;
  onCounter?: () => void;
  onDecline?: () => void;
}

export default function OfferMessageBubble({
  metadata,
  isFromMe,
  isActive,
  viewerRole,
  awaitingPayment = false,
  accepting = false,
  onAccept,
  onCounter,
  onDecline,
}: OfferMessageBubbleProps) {
  const countdown = useExpiryCountdown(metadata.expiresAt);
  const dateRange = formatDateRange(metadata.checkIn, metadata.checkOut);

  const roleLabel =
    metadata.proposedByRole === "host"
      ? isFromMe ? "Du foreslår" : "Utleier foreslår"
      : metadata.proposedByRole === "guest"
        ? isFromMe ? "Du foreslår" : "Gjest foreslår"
        : "Tilbud";

  const opposingPartyLabel = metadata.proposedByRole === "host" ? "gjest" : "utleier";
  // Host godtar uten å betale (gjest betaler etterpå); gjest betaler ved aksept.
  const acceptLabel = viewerRole === "host" ? "Godta forespørselen" : "Godta og betal";

  return (
    <div
      className={`max-w-[280px] rounded-2xl border bg-white p-3.5 ${
        isActive ? "border-primary-300 shadow-sm" : "border-neutral-200"
      }`}
    >
      <div className="flex items-center justify-between gap-2 mb-3">
        <div className="flex items-center gap-1.5">
          <Tag className="h-3 w-3 text-primary-600" />
          <span className="text-xs font-semibold text-neutral-700">{roleLabel}</span>
        </div>
        {countdown && (
          <span className="text-[10px] text-neutral-500">{countdown}</span>
        )}
      </div>

      <div className="flex items-baseline gap-1 mb-2">
        <span className="text-2xl font-bold text-neutral-900">
          {(metadata.totalPrice ?? 0).toLocaleString("nb-NO")}
        </span>
        <span className="text-sm font-semibold text-neutral-500">kr</span>
      </div>

      {dateRange && (
        <div className="flex items-center gap-1.5 text-xs text-neutral-600 mb-3">
          <Calendar className="h-3 w-3" />
          <span>{dateRange}</span>
        </div>
      )}

      {!isActive ? (
        <span className="inline-block rounded-full bg-neutral-100 px-2 py-0.5 text-[10px] font-medium text-neutral-500">
          Erstattet av nyere tilbud
        </span>
      ) : isFromMe ? (
        <p className="text-xs text-neutral-500">Venter på svar fra {opposingPartyLabel}</p>
      ) : awaitingPayment ? null : (
        <div className="flex flex-col gap-2">
          <button
            onClick={onAccept}
            disabled={accepting}
            className="w-full rounded-lg bg-primary-600 px-3 py-2 text-sm font-semibold text-white hover:bg-primary-700 disabled:opacity-70 transition-colors flex items-center justify-center"
          >
            {accepting ? (
              <span className="inline-block h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" aria-hidden="true" />
            ) : (
              acceptLabel
            )}
          </button>
          <div className="flex gap-2">
            <button
              onClick={onCounter}
              disabled={accepting}
              className="flex-1 rounded-lg border border-neutral-300 px-3 py-1.5 text-xs font-semibold text-neutral-900 hover:bg-neutral-50 disabled:opacity-50 transition-colors"
            >
              Endre pris
            </button>
            <button
              onClick={onDecline}
              disabled={accepting}
              className="flex-1 rounded-lg border border-red-200 px-3 py-1.5 text-xs font-semibold text-red-600 hover:bg-red-50 disabled:opacity-50 transition-colors"
            >
              Avslå
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function formatDateRange(start?: string, end?: string): string | null {
  if (!start || !end) return null;
  const s = new Date(start);
  const e = new Date(end);
  if (isNaN(s.getTime()) || isNaN(e.getTime())) return null;
  const sameMonth = s.getMonth() === e.getMonth() && s.getFullYear() === e.getFullYear();
  const dayFmt = new Intl.DateTimeFormat("nb-NO", { day: "numeric" });
  const fullFmt = new Intl.DateTimeFormat("nb-NO", { day: "numeric", month: "short" });
  if (sameMonth) {
    return `${dayFmt.format(s)}.–${fullFmt.format(e)}`;
  }
  return `${fullFmt.format(s)}–${fullFmt.format(e)}`;
}

function useExpiryCountdown(expiresAt?: string): string | null {
  const [now, setNow] = useState(Date.now());

  useEffect(() => {
    if (!expiresAt) return;
    const interval = setInterval(() => setNow(Date.now()), 60_000);
    return () => clearInterval(interval);
  }, [expiresAt]);

  if (!expiresAt) return null;
  const exp = new Date(expiresAt).getTime();
  if (isNaN(exp)) return null;
  const ms = exp - now;
  if (ms <= 0) return "Utløpt";
  const hours = Math.floor(ms / 3_600_000);
  if (hours >= 1) return `Utløper om ${hours}t`;
  const mins = Math.floor(ms / 60_000);
  return `Utløper om ${mins}m`;
}
