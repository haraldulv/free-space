"use client";

import { useCallback, useEffect, useState } from "react";
import { ShieldAlert, ShieldCheck } from "lucide-react";
import { loadSignupSettingAction, loadTurnstileSettingAction, setSignupsEnabledAction, setTurnstileEnabledAction } from "./actions";

export default function SignupSwitch() {
  const [state, setState] = useState<{ enabled: boolean; reason: string; lastSweepAt: string | null; sweepAgeMin: number | null } | null>(null);
  const [busy, setBusy] = useState(false);
  const [turnstile, setTurnstile] = useState<boolean | null>(null);

  const reload = useCallback(async () => {
    const [s, t] = await Promise.all([loadSignupSettingAction(), loadTurnstileSettingAction()]);
    setState(s);
    setTurnstile(t.enabled);
  }, []);

  useEffect(() => {
    queueMicrotask(() => { void reload(); });
  }, [reload]);

  if (!state) return null;

  const sweepAge = state.sweepAgeMin;
  const sweepOk = sweepAge !== null && sweepAge < 15;

  const toggle = async () => {
    const next = !state.enabled;
    if (!next && !confirm("Stenge registrering for alle nye brukere nå?")) return;
    setBusy(true);
    await setSignupsEnabledAction(next);
    await reload();
    setBusy(false);
  };

  const toggleTurnstile = async () => {
    const next = !turnstile;
    if (next && !confirm("Slå på captcha-krav i appen? Krever at Turnstile er aktivert i Supabase Dashboard (Attack Protection) og at app-versjonen med captcha-støtte er ute. Ellers feiler e-post-innlogging.")) return;
    setBusy(true);
    await setTurnstileEnabledAction(next);
    await reload();
    setBusy(false);
  };

  return (
    <>
    <div className="mt-4 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-neutral-200 bg-white px-4 py-3 text-sm">
      <div>
        <p className="font-medium text-neutral-900">Captcha i appen (Turnstile): {turnstile ? "på" : "av"}</p>
        <p className="text-xs text-neutral-400">Web styres av NEXT_PUBLIC_TURNSTILE_SITE_KEY. Supabase-siden må være på i Dashboard → Auth → Attack Protection.</p>
      </div>
      <button onClick={toggleTurnstile} disabled={busy || turnstile === null} className="rounded-lg border border-neutral-200 px-3 py-2 text-sm font-medium text-neutral-700 hover:bg-neutral-50 disabled:opacity-50">
        {turnstile ? "Slå av" : "Slå på"}
      </button>
    </div>
    <div className={`mt-4 flex flex-wrap items-center justify-between gap-3 rounded-xl border px-4 py-3 text-sm ${state.enabled ? "border-neutral-200 bg-white" : "border-red-300 bg-red-50"}`}>
      <div className="flex items-center gap-3">
        {state.enabled ? <ShieldCheck className="h-5 w-5 text-primary-600" /> : <ShieldAlert className="h-5 w-5 text-red-600" />}
        <div>
          <p className={`font-medium ${state.enabled ? "text-neutral-900" : "text-red-800"}`}>
            Registrering: {state.enabled ? "åpen" : "STENGT"}
          </p>
          {!state.enabled && state.reason && <p className="text-xs text-red-700">{state.reason}</p>}
          <p className="text-xs text-neutral-400">
            Vaktbikkje-sweep: {sweepAge === null ? "aldri kjørt" : sweepOk ? `OK, ${Math.round(sweepAge)} min siden` : `⚠️ sist for ${Math.round(sweepAge)} min siden`}
          </p>
        </div>
      </div>
      <button
        onClick={toggle}
        disabled={busy}
        className={`rounded-lg px-3 py-2 text-sm font-medium disabled:opacity-50 ${state.enabled ? "border border-neutral-200 text-neutral-700 hover:bg-neutral-50" : "bg-primary-600 text-white hover:bg-primary-700"}`}
      >
        {state.enabled ? "Steng registrering" : "Åpne registrering"}
      </button>
    </div>
    </>
  );
}
