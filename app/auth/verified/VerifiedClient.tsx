"use client";

import { useEffect, useState, Suspense } from "react";
import { useSearchParams } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

type Status = "loading" | "ok" | "error";

/**
 * E-post-verifiseringslanding (PKCE/token_hash-flyt).
 *
 * Lenken i Supabase-mailen peker DIREKTE til denne siden:
 *   `https://www.tuno.no/auth/verified?token_hash=X&type=signup`
 *
 * Tre tilfeller:
 * 1) iOS med Tuno installert + Universal Links aktive: iOS åpner appen
 *    DIREKTE før denne siden lastes — siden rendres aldri.
 * 2) iOS uten appen / fra Chrome: vi viser "Verifisert!"-side med
 *    "Åpne Tuno-appen"-knapp som forsøker custom scheme.
 * 3) Desktop / Android: vi viser "Verifisert!" + "Logg inn"-knapp.
 *
 * Vi kaller `verifyOtp` selv så bruker er logget inn på web umiddelbart.
 */
export default function VerifiedClient() {
  return (
    <Suspense fallback={<LoadingShell />}>
      <VerifiedInner />
    </Suspense>
  );
}

function VerifiedInner() {
  const searchParams = useSearchParams();
  const [status, setStatus] = useState<Status>("loading");
  const [errorMessage, setErrorMessage] = useState<string>("");
  const [tokenHash, setTokenHash] = useState<string>("");
  const [otpType, setOtpType] = useState<string>("signup");

  useEffect(() => {
    const th = searchParams.get("token_hash");
    const ty = searchParams.get("type") ?? "signup";
    const errorDescription = searchParams.get("error_description");

    if (errorDescription) {
      setErrorMessage(decodeURIComponent(errorDescription));
      setStatus("error");
      return;
    }

    if (!th) {
      // Ingen token — antar bruker landet her direkte (uten lenke)
      setStatus("ok");
      return;
    }

    setTokenHash(th);
    setOtpType(ty);

    const supabase = createClient();
    supabase.auth
      .verifyOtp({ token_hash: th, type: ty as "signup" | "recovery" | "magiclink" | "email_change" | "invite" | "email" })
      .then(({ error }) => {
        if (error) {
          setErrorMessage(error.message);
          setStatus("error");
        } else {
          setStatus("ok");
        }
      });
  }, [searchParams]);

  if (status === "loading") {
    return <LoadingShell />;
  }

  if (status === "error") {
    return <ErrorView message={errorMessage} />;
  }

  // Bygg app-link som forsøker å åpne native-appen via custom scheme.
  // Inkluderer original token_hash så appen kan re-verifisere ved behov.
  const appLink = tokenHash
    ? `no.tuno.app://auth/verified?token_hash=${encodeURIComponent(tokenHash)}&type=${encodeURIComponent(otpType)}`
    : "no.tuno.app://auth/verified";

  return (
    <main style={pageStyle}>
      <div style={cardStyle}>
        <div style={iconCircle("#46c185")}>
          <svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="20 6 9 17 4 12" />
          </svg>
        </div>
        <h1 style={titleStyle}>E-posten er bekreftet</h1>
        <p style={paragraphStyle}>
          Velkommen til Tuno! Klikk knappen under for å fortsette i appen.
        </p>

        <a href={appLink} style={buttonPrimary}>
          Åpne Tuno-appen
        </a>

        <Link href="/" style={buttonSecondary}>
          Fortsett på nettsiden
        </Link>
      </div>
    </main>
  );
}

function LoadingShell() {
  return (
    <main style={pageStyle}>
      <div style={cardStyle}>
        <div
          style={{
            width: 48,
            height: 48,
            borderRadius: "50%",
            border: "3px solid #e5e5e5",
            borderTopColor: "#46c185",
            margin: "0 auto 24px",
            animation: "spin 0.9s linear infinite",
          }}
        />
        <h1 style={titleStyle}>Bekrefter e-posten...</h1>
        <p style={paragraphStyle}>Dette tar bare et øyeblikk.</p>
        <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
      </div>
    </main>
  );
}

function ErrorView({ message }: { message: string }) {
  return (
    <main style={pageStyle}>
      <div style={cardStyle}>
        <div style={iconCircle("#fef2f2")}>
          <span style={{ fontSize: 48, color: "#dc2626", fontWeight: 700 }}>!</span>
        </div>
        <h1 style={titleStyle}>Lenken har utløpt</h1>
        <p style={paragraphStyle}>
          {message || "Prøv å logge inn på nytt så sender vi en ny lenke."}
        </p>
        <Link href="/login" style={buttonPrimary}>
          Til innlogging
        </Link>
      </div>
    </main>
  );
}

// MARK: - Styles

const pageStyle: React.CSSProperties = {
  minHeight: "100vh",
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  backgroundColor: "#ffffff",
  padding: "0 24px",
  fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, sans-serif",
};

const cardStyle: React.CSSProperties = {
  maxWidth: 420,
  width: "100%",
  textAlign: "center",
};

const titleStyle: React.CSSProperties = {
  fontSize: 28,
  fontWeight: 700,
  color: "#0a0a0a",
  margin: "0 0 12px",
};

const paragraphStyle: React.CSSProperties = {
  fontSize: 16,
  color: "#525252",
  margin: "0 0 28px",
  lineHeight: 1.5,
};

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

function iconCircle(bg: string): React.CSSProperties {
  return {
    width: 96,
    height: 96,
    borderRadius: "50%",
    backgroundColor: bg,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    margin: "0 auto 24px",
    boxShadow: bg === "#46c185" ? "0 4px 24px rgba(70, 193, 133, 0.3)" : "none",
  };
}
