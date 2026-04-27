"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

/**
 * E-post-verifiseringslanding. Brukeren havner her etter å ha klikket
 * lenken i Supabase verifiserings-mailen. Tre tilfeller:
 *
 * 1) iOS-bruker fra Mail.app/Safari + Tuno installert + Universal Links
 *    aktive: iOS åpner appen før denne siden lastes — siden rendres aldri.
 * 2) iOS-bruker fra Chrome eller Gmail-app: Chrome blokkerer ofte
 *    auto-redirect til custom scheme. Vi viser stor "Åpne Tuno-appen"-
 *    knapp øverst som primær handling.
 * 3) Desktop / Android: ser "Verifisert!" + Logg inn-knapp.
 *
 * Vi setter også Supabase-session fra hash-tokens så bruker er logget
 * inn på tuno.no (web-fallback hvis appen ikke er installert).
 */
export default function VerifiedClient() {
  const [hash, setHash] = useState<string>("");
  const [errorMessage, setErrorMessage] = useState<string>("");
  const [isError, setIsError] = useState<boolean>(false);

  useEffect(() => {
    const currentHash = window.location.hash.slice(1);
    setHash(currentHash);

    if (!currentHash) return;

    const params = new URLSearchParams(currentHash);
    const accessToken = params.get("access_token");
    const refreshToken = params.get("refresh_token");
    const errorDescription = params.get("error_description");

    if (errorDescription) {
      setErrorMessage(decodeURIComponent(errorDescription.replace(/\+/g, " ")));
      setIsError(true);
      return;
    }

    if (accessToken && refreshToken) {
      const supabase = createClient();
      supabase.auth
        .setSession({ access_token: accessToken, refresh_token: refreshToken })
        .catch(() => {
          /* Stille feil — siden viser ok-state uansett */
        });
    }
  }, []);

  const isIOS =
    typeof navigator !== "undefined" &&
    /iPad|iPhone|iPod/.test(navigator.userAgent);
  const appLink = hash ? `no.tuno.app://auth/verified#${hash}` : null;

  if (isError) {
    return <ErrorView message={errorMessage} />;
  }

  return (
    <main
      style={{
        minHeight: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: "#ffffff",
        padding: "0 24px",
        fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, sans-serif",
      }}
    >
      <div style={{ maxWidth: 420, width: "100%", textAlign: "center" }}>
        <div
          style={{
            width: 96,
            height: 96,
            borderRadius: "50%",
            backgroundColor: "#46c185",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            margin: "0 auto 24px",
            boxShadow: "0 4px 24px rgba(70, 193, 133, 0.3)",
          }}
        >
          <svg
            width="44"
            height="44"
            viewBox="0 0 24 24"
            fill="none"
            stroke="#ffffff"
            strokeWidth="3"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <polyline points="20 6 9 17 4 12" />
          </svg>
        </div>
        <h1
          style={{
            fontSize: 28,
            fontWeight: 700,
            color: "#0a0a0a",
            margin: "0 0 12px",
          }}
        >
          E-posten er bekreftet
        </h1>
        <p
          style={{
            fontSize: 16,
            color: "#525252",
            margin: "0 0 28px",
            lineHeight: 1.5,
          }}
        >
          Velkommen til Tuno! Klikk knappen under for å fortsette i appen.
        </p>

        {appLink && isIOS && (
          <a
            href={appLink}
            style={buttonPrimary}
          >
            Åpne Tuno-appen
          </a>
        )}

        <Link
          href="/"
          style={appLink && isIOS ? buttonSecondary : buttonPrimary}
        >
          {appLink && isIOS ? "Fortsett på nettsiden" : "Kom i gang"}
        </Link>
      </div>
    </main>
  );
}

function ErrorView({ message }: { message: string }) {
  return (
    <main
      style={{
        minHeight: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: "#ffffff",
        padding: "0 24px",
        fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, sans-serif",
      }}
    >
      <div style={{ maxWidth: 420, width: "100%", textAlign: "center" }}>
        <div
          style={{
            width: 96,
            height: 96,
            borderRadius: "50%",
            backgroundColor: "#fef2f2",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            margin: "0 auto 24px",
          }}
        >
          <span style={{ fontSize: 48, color: "#dc2626" }}>!</span>
        </div>
        <h1
          style={{
            fontSize: 28,
            fontWeight: 700,
            color: "#0a0a0a",
            margin: "0 0 12px",
          }}
        >
          Lenken har utløpt
        </h1>
        <p
          style={{
            fontSize: 16,
            color: "#525252",
            margin: "0 0 28px",
            lineHeight: 1.5,
          }}
        >
          {message || "Prøv å logge inn på nytt så sender vi en ny lenke."}
        </p>
        <Link href="/login" style={buttonPrimary}>
          Til innlogging
        </Link>
      </div>
    </main>
  );
}

const buttonPrimary: React.CSSProperties = {
  display: "block",
  width: "100%",
  padding: "18px 0",
  backgroundColor: "#46c185",
  color: "#ffffff",
  fontWeight: 600,
  fontSize: 17,
  borderRadius: 16,
  textDecoration: "none",
  marginBottom: 12,
  boxShadow: "0 2px 8px rgba(70, 193, 133, 0.25)",
};

const buttonSecondary: React.CSSProperties = {
  display: "block",
  width: "100%",
  padding: "16px 0",
  backgroundColor: "#f5f5f5",
  color: "#404040",
  fontWeight: 600,
  fontSize: 16,
  borderRadius: 16,
  textDecoration: "none",
};
