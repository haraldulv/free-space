"use client";

import { useState } from "react";
import { X } from "lucide-react";

interface CounterOfferModalProps {
  bookingId: string;
  currentOfferPrice: number;
  currentOfferLabel: string;
  onClose: () => void;
  onSent: () => void;
}

export default function CounterOfferModal({
  bookingId,
  currentOfferPrice,
  currentOfferLabel,
  onClose,
  onSent,
}: CounterOfferModalProps) {
  const [priceText, setPriceText] = useState("");
  const [note, setNote] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const priceValue = Number(priceText.replace(/[^0-9]/g, ""));
  const canSend = priceValue >= 3 && !sending;

  const send = async () => {
    if (!canSend) return;
    setSending(true);
    setError(null);
    try {
      const { createClient } = await import("@/lib/supabase/client");
      const supabase = createClient();
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        setError("Du må være innlogget");
        setSending(false);
        return;
      }
      const res = await fetch("/api/bookings/offer", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${session.access_token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          bookingId,
          totalPrice: priceValue,
          message: note.trim() || undefined,
        }),
      });
      const json = await res.json();
      if (!res.ok || json.error) {
        setError(json.error || "Kunne ikke sende motbud");
        setSending(false);
        return;
      }
      onSent();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Noe gikk galt");
      setSending(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-neutral-900">Send motbud</h2>
          <button onClick={onClose} className="text-neutral-500 hover:text-neutral-900">
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="rounded-xl bg-neutral-50 p-3 mb-5">
          <p className="text-xs font-medium text-neutral-500">Forrige tilbud</p>
          <p className="mt-1 text-sm font-semibold text-neutral-900">{currentOfferLabel}</p>
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-semibold text-neutral-700 mb-1.5">Ditt motbud</label>
            <div className="flex items-center gap-2">
              <input
                type="text"
                inputMode="numeric"
                value={priceText}
                onChange={(e) => setPriceText(e.target.value)}
                placeholder={`F.eks. ${currentOfferPrice}`}
                className="flex-1 rounded-lg bg-neutral-50 px-4 py-3 text-lg font-semibold text-neutral-900 focus:outline-none focus:ring-2 focus:ring-primary-500"
              />
              <span className="text-sm font-semibold text-neutral-500">kr</span>
            </div>
          </div>

          <div>
            <label className="block text-sm font-semibold text-neutral-700 mb-1.5">Begrunnelse (valgfritt)</label>
            <textarea
              value={note}
              onChange={(e) => setNote(e.target.value)}
              rows={3}
              placeholder="Forklar gjerne hvorfor"
              className="w-full resize-none rounded-lg bg-neutral-50 px-4 py-3 text-sm text-neutral-900 focus:outline-none focus:ring-2 focus:ring-primary-500"
            />
          </div>

          {error && <p className="text-sm text-red-600">{error}</p>}

          <button
            onClick={send}
            disabled={!canSend}
            className="w-full rounded-xl bg-primary-600 px-4 py-3 text-sm font-semibold text-white hover:bg-primary-700 disabled:opacity-50 transition-colors"
          >
            {sending ? "Sender…" : "Send motbud"}
          </button>
        </div>
      </div>
    </div>
  );
}
