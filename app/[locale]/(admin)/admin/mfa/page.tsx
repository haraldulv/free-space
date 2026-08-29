"use client";

import { Suspense, useCallback, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { KeyRound, ShieldCheck } from "lucide-react";
import { createClient } from "@/lib/supabase/client";

/**
 * Tofaktor for admin (TOTP via Supabase MFA). Middleware sender hit når en
 * admin ikke er på AAL2. Første gang: sett opp (QR + kode). Senere: kode.
 */
function AdminMfaInner() {
  const supabase = createClient();
  const searchParams = useSearchParams();
  const returnTo = searchParams.get("returnTo") || "/admin";

  const [mode, setMode] = useState<"loading" | "enroll" | "verify" | "done">("loading");
  const [factorId, setFactorId] = useState<string | null>(null);
  const [qr, setQr] = useState<string | null>(null);
  const [secret, setSecret] = useState<string | null>(null);
  const [code, setCode] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const init = useCallback(async () => {
    const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (aal?.currentLevel === "aal2") {
      setMode("done");
      window.location.href = returnTo;
      return;
    }
    const { data: factors } = await supabase.auth.mfa.listFactors();
    const verified = factors?.totp?.find((f) => f.status === "verified");
    if (verified) {
      setFactorId(verified.id);
      setMode("verify");
      return;
    }
    // Rydd bort halvferdige (unverified) faktorer før ny enroll
    for (const f of factors?.totp ?? []) {
      if (f.status !== "verified") await supabase.auth.mfa.unenroll({ factorId: f.id });
    }
    const { data, error } = await supabase.auth.mfa.enroll({ factorType: "totp", friendlyName: "Tuno admin" });
    if (error || !data) {
      setError(error?.message ?? "Kunne ikke starte oppsett");
      setMode("enroll");
      return;
    }
    setFactorId(data.id);
    setQr(data.totp.qr_code);
    setSecret(data.totp.secret);
    setMode("enroll");
  }, [supabase, returnTo]);

  useEffect(() => {
    queueMicrotask(() => { void init(); });
  }, [init]);

  const submit = async () => {
    if (!factorId || code.length < 6) return;
    setBusy(true);
    setError("");
    const { data: challenge, error: cErr } = await supabase.auth.mfa.challenge({ factorId });
    if (cErr || !challenge) {
      setError(cErr?.message ?? "Kunne ikke starte verifisering");
      setBusy(false);
      return;
    }
    const { error: vErr } = await supabase.auth.mfa.verify({ factorId, challengeId: challenge.id, code: code.trim() });
    if (vErr) {
      setError("Feil kode. Prøv igjen.");
      setCode("");
      setBusy(false);
      return;
    }
    setMode("done");
    window.location.href = returnTo;
  };

  return (
    <div className="mx-auto flex min-h-[70vh] max-w-md flex-col justify-center px-4 py-10">
      <div className="rounded-2xl border border-neutral-200 bg-white p-6">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-full bg-primary-50 text-primary-600">
            {mode === "enroll" ? <KeyRound className="h-5 w-5" /> : <ShieldCheck className="h-5 w-5" />}
          </div>
          <div>
            <h1 className="text-lg font-semibold text-neutral-900">
              {mode === "enroll" ? "Sett opp tofaktor" : "Tofaktor"}
            </h1>
            <p className="text-sm text-neutral-500">Admin-området krever kode fra autentiserings-app.</p>
          </div>
        </div>

        {mode === "loading" && <p className="mt-6 text-sm text-neutral-500">Laster...</p>}

        {mode === "enroll" && (
          <div className="mt-6 space-y-4">
            <ol className="list-decimal space-y-1 pl-5 text-sm text-neutral-700">
              <li>Åpne Google Authenticator, 1Password eller Apple Passord.</li>
              <li>Skann QR-koden (eller lim inn nøkkelen manuelt).</li>
              <li>Skriv inn den 6-sifrede koden under.</li>
            </ol>
            {qr && (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={qr} alt="QR-kode for tofaktor" className="mx-auto h-48 w-48 rounded-lg border border-neutral-200 bg-white p-2" />
            )}
            {secret && (
              <p className="break-all rounded-lg bg-neutral-50 p-3 text-center font-mono text-xs text-neutral-600">{secret}</p>
            )}
          </div>
        )}

        {(mode === "enroll" || mode === "verify") && (
          <form
            className="mt-6 space-y-3"
            onSubmit={(e) => { e.preventDefault(); void submit(); }}
          >
            <input
              autoFocus
              inputMode="numeric"
              pattern="[0-9]*"
              maxLength={6}
              value={code}
              onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
              placeholder="123456"
              className="w-full rounded-lg border border-neutral-200 px-4 py-3 text-center text-2xl tracking-[0.4em] focus:border-primary-500 focus:outline-none"
            />
            {error && <p className="text-sm text-red-600">{error}</p>}
            <button
              type="submit"
              disabled={busy || code.length < 6}
              className="w-full rounded-lg bg-neutral-900 py-3 text-sm font-medium text-white disabled:opacity-50"
            >
              {busy ? "Sjekker..." : mode === "enroll" ? "Aktiver tofaktor" : "Fortsett"}
            </button>
          </form>
        )}

        {mode === "done" && <p className="mt-6 text-sm text-neutral-500">Sender deg videre...</p>}
      </div>
      <p className="mt-4 text-center text-xs text-neutral-400">
        Mistet autentiserings-appen? Faktoren kan nullstilles i databasen (auth.mfa_factors).
      </p>
    </div>
  );
}

export default function AdminMfaPage() {
  return (
    <Suspense>
      <AdminMfaInner />
    </Suspense>
  );
}
