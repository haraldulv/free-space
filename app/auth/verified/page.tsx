"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

/**
 * E-post-verifiseringslanding. Brukeren havner her etter å ha klikket
 * lenken i Supabase verifiserings-mailen. Tre tilfeller:
 *
 * 1) iOS-bruker med Tuno-appen installert: iOS åpner appen direkte via
 *    Universal Link før denne siden lastes — sider rendres aldri.
 * 2) iOS-bruker uten appen: ser "Verifisert!" + Last ned-knapp.
 * 3) Desktop / Android: ser "Verifisert!" + Logg inn-knapp som leder
 *    videre på web.
 *
 * Tokens kommer som hash-fragment (#access_token=...). Vi setter en
 * web-sesjon så bruker er logget inn på tuno.no umiddelbart.
 */
export default function VerifiedPage() {
  const [status, setStatus] = useState<"loading" | "ok" | "error">("loading");
  const [errorMessage, setErrorMessage] = useState<string>("");

  useEffect(() => {
    const hash = window.location.hash.slice(1);
    if (!hash) {
      setStatus("ok");
      return;
    }

    const params = new URLSearchParams(hash);
    const accessToken = params.get("access_token");
    const refreshToken = params.get("refresh_token");
    const errorDescription = params.get("error_description");

    if (errorDescription) {
      setErrorMessage(decodeURIComponent(errorDescription.replace(/\+/g, " ")));
      setStatus("error");
      return;
    }

    if (!accessToken || !refreshToken) {
      setStatus("ok");
      return;
    }

    const supabase = createClient();
    supabase.auth
      .setSession({ access_token: accessToken, refresh_token: refreshToken })
      .then(({ error }) => {
        setStatus(error ? "error" : "ok");
        if (error) setErrorMessage(error.message);
      });
  }, []);

  if (status === "loading") {
    return (
      <main className="min-h-screen flex items-center justify-center bg-white">
        <div className="size-10 rounded-full border-2 border-neutral-200 border-t-primary-600 animate-spin" />
      </main>
    );
  }

  return (
    <main className="min-h-screen flex items-center justify-center bg-white px-6">
      <div className="max-w-md w-full text-center space-y-6">
        {status === "ok" ? <SuccessHero /> : <ErrorHero message={errorMessage} />}

        <div className="space-y-3 pt-2">
          {status === "ok" ? (
            <>
              <Link
                href="/"
                className="block w-full rounded-2xl bg-primary-600 py-4 text-white font-semibold hover:bg-primary-700 transition"
              >
                Kom i gang
              </Link>
              <p className="text-sm text-neutral-500">
                Har du Tuno-appen? Den åpnes automatisk neste gang du klikker
                en Tuno-lenke fra mobilen.
              </p>
            </>
          ) : (
            <Link
              href="/login"
              className="block w-full rounded-2xl bg-primary-600 py-4 text-white font-semibold hover:bg-primary-700 transition"
            >
              Til innlogging
            </Link>
          )}
        </div>
      </div>
    </main>
  );
}

function SuccessHero() {
  return (
    <>
      <div className="mx-auto size-24 rounded-full bg-primary-50 flex items-center justify-center">
        <svg
          width="44"
          height="44"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="3"
          strokeLinecap="round"
          strokeLinejoin="round"
          className="text-primary-600"
        >
          <polyline points="20 6 9 17 4 12" />
        </svg>
      </div>
      <div className="space-y-2">
        <h1 className="text-3xl font-bold text-neutral-900">
          E-posten er bekreftet
        </h1>
        <p className="text-neutral-600">
          Velkommen til Tuno! Du er klar til å bestille parkerings- og
          campingplasser.
        </p>
      </div>
    </>
  );
}

function ErrorHero({ message }: { message: string }) {
  return (
    <>
      <div className="mx-auto size-24 rounded-full bg-red-50 flex items-center justify-center">
        <svg
          width="44"
          height="44"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="3"
          strokeLinecap="round"
          strokeLinejoin="round"
          className="text-red-600"
        >
          <circle cx="12" cy="12" r="10" />
          <line x1="12" y1="8" x2="12" y2="12" />
          <line x1="12" y1="16" x2="12.01" y2="16" />
        </svg>
      </div>
      <div className="space-y-2">
        <h1 className="text-3xl font-bold text-neutral-900">
          Lenken har utløpt
        </h1>
        <p className="text-neutral-600">
          {message || "Prøv å logge inn på nytt så sender vi en ny lenke."}
        </p>
      </div>
    </>
  );
}
