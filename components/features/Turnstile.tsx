"use client";

import { useEffect, useRef } from "react";

/**
 * Cloudflare Turnstile-widget. Rendres kun når NEXT_PUBLIC_TURNSTILE_SITE_KEY
 * er satt; ellers kalles onToken(null) umiddelbart så skjemaet fungerer
 * uten captcha (lokalt/staging uten nøkkel).
 *
 * Supabase Auth verifiserer tokenet server-side (Dashboard → Auth →
 * Attack protection → Turnstile, med secret key). Web sender tokenet som
 * `options.captchaToken` på signUp / signInWithPassword /
 * resetPasswordForEmail / resend.
 */

declare global {
  interface Window {
    turnstile?: {
      render: (el: HTMLElement, opts: Record<string, unknown>) => string;
      reset: (id?: string) => void;
      remove: (id: string) => void;
    };
    __tunoTurnstileReady?: Promise<void>;
  }
}

export const TURNSTILE_SITE_KEY = process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY ?? "";
export const TURNSTILE_ENABLED = TURNSTILE_SITE_KEY.length > 0;

function loadScript(): Promise<void> {
  if (typeof window === "undefined") return Promise.resolve();
  if (window.turnstile) return Promise.resolve();
  if (window.__tunoTurnstileReady) return window.__tunoTurnstileReady;
  window.__tunoTurnstileReady = new Promise<void>((resolve, reject) => {
    const s = document.createElement("script");
    s.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
    s.async = true;
    s.defer = true;
    s.onload = () => resolve();
    s.onerror = () => reject(new Error("Turnstile script failed"));
    document.head.appendChild(s);
  });
  return window.__tunoTurnstileReady;
}

export interface TurnstileHandle {
  reset: () => void;
}

interface TurnstileProps {
  onToken: (token: string | null) => void;
  /** Kalles med reset-funksjon så forelder kan nullstille etter feilet innsending. */
  onReady?: (handle: TurnstileHandle) => void;
  className?: string;
}

export default function Turnstile({ onToken, onReady, className }: TurnstileProps) {
  const ref = useRef<HTMLDivElement>(null);
  const widgetId = useRef<string | null>(null);
  const onTokenRef = useRef(onToken);
  onTokenRef.current = onToken;

  useEffect(() => {
    if (!TURNSTILE_ENABLED) {
      onTokenRef.current(null);
      return;
    }
    let cancelled = false;
    loadScript()
      .then(() => {
        if (cancelled || !ref.current || !window.turnstile) return;
        widgetId.current = window.turnstile.render(ref.current, {
          sitekey: TURNSTILE_SITE_KEY,
          theme: "light",
          language: document.documentElement.lang || "auto",
          callback: (token: string) => onTokenRef.current(token),
          "expired-callback": () => onTokenRef.current(null),
          "error-callback": () => onTokenRef.current(null),
        });
        onReady?.({
          reset: () => {
            if (widgetId.current && window.turnstile) {
              window.turnstile.reset(widgetId.current);
              onTokenRef.current(null);
            }
          },
        });
      })
      .catch((err) => console.error(err));
    return () => {
      cancelled = true;
      if (widgetId.current && window.turnstile) {
        try { window.turnstile.remove(widgetId.current); } catch { /* noop */ }
        widgetId.current = null;
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (!TURNSTILE_ENABLED) return null;
  return <div ref={ref} className={className ?? "flex justify-center"} />;
}
