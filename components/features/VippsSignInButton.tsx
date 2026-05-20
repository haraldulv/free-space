"use client";

import { useState } from "react";

const ENABLED = process.env.NEXT_PUBLIC_VIPPS_ENABLED === "true";

export default function VippsSignInButton({
  redirectTo,
}: {
  redirectTo?: string;
}) {
  const [loading, setLoading] = useState(false);

  if (!ENABLED) return null;

  const handleVippsLogin = () => {
    setLoading(true);
    const url = new URL("/api/auth/vipps/start", window.location.origin);
    if (redirectTo) url.searchParams.set("return", redirectTo);
    // Full-page navigation — server-route håndterer 302 til Vipps.
    window.location.href = url.toString();
  };

  return (
    <button
      type="button"
      onClick={handleVippsLogin}
      disabled={loading}
      className="flex w-full items-center justify-center gap-3 rounded-lg bg-[#FF5B24] px-4 py-3 text-sm font-semibold text-white transition-colors hover:bg-[#E04E1E] disabled:cursor-not-allowed disabled:opacity-50"
    >
      <svg viewBox="0 0 32 32" className="h-5 w-5" aria-hidden="true">
        <path
          fill="white"
          d="M16 4C9.4 4 4 9.4 4 16s5.4 12 12 12 12-5.4 12-12S22.6 4 16 4zm6.5 9.8c.9 0 1.6.7 1.6 1.6 0 .9-.7 1.6-1.6 1.6-.9 0-1.6-.7-1.6-1.6 0-.9.7-1.6 1.6-1.6zm-13 0c.9 0 1.6.7 1.6 1.6 0 .9-.7 1.6-1.6 1.6-.9 0-1.6-.7-1.6-1.6 0-.9.7-1.6 1.6-1.6zM16 24c-3.4 0-6.4-2-7.8-5-.3-.6.1-1.3.8-1.3.4 0 .7.2.9.5 1 2.1 3.3 3.6 6.1 3.6 2.8 0 5.1-1.5 6.1-3.6.2-.3.5-.5.9-.5.7 0 1.1.7.8 1.3-1.4 3-4.4 5-7.8 5z"
        />
      </svg>
      {loading ? "Vennligst vent..." : "Fortsett med Vipps"}
    </button>
  );
}
