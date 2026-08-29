"use client";

import { useEffect, useState } from "react";
import Turnstile, { TURNSTILE_ENABLED } from "@/components/features/Turnstile";

/**
 * Minimal side for iOS-appen: rendrer Turnstile-widgeten på vårt eget
 * domene (Cloudflare krever domene-match) og poster tokenet til
 * WKWebView via `window.webkit.messageHandlers.turnstile`.
 * Åpnes som `/captcha?embed=ios`. Ikke lenket fra noe sted.
 */
export default function CaptchaPage() {
  const [state, setState] = useState<"idle" | "done" | "error">("idle");

  useEffect(() => {
    if (!TURNSTILE_ENABLED) {
      postToApp({ error: "turnstile_disabled" });
    }
  }, []);

  return (
    <div className="flex min-h-screen items-center justify-center bg-white p-4">
      <div className="text-center">
        <Turnstile
          onToken={(token) => {
            if (token) {
              setState("done");
              postToApp(token);
            }
          }}
        />
        {state === "done" && <p className="mt-3 text-sm text-neutral-500">Bekreftet</p>}
        {!TURNSTILE_ENABLED && <p className="text-sm text-neutral-400">Captcha er ikke konfigurert.</p>}
      </div>
    </div>
  );
}

function postToApp(payload: string | Record<string, string>) {
  const w = window as unknown as { webkit?: { messageHandlers?: { turnstile?: { postMessage: (m: unknown) => void } } } };
  w.webkit?.messageHandlers?.turnstile?.postMessage(payload);
}
