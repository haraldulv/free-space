"use client";

import { useState, useEffect } from "react";

const PASS = "kimharald";
const STORAGE_KEY = "fs_auth";
const GATE_DISABLED = process.env.NEXT_PUBLIC_DISABLE_PASSWORD_GATE === "true";

export default function PasswordGate({ children }: { children: React.ReactNode }) {
  const [authorized, setAuthorized] = useState(GATE_DISABLED);
  const [input, setInput] = useState("");
  const [error, setError] = useState(false);

  useEffect(() => {
    if (GATE_DISABLED || sessionStorage.getItem(STORAGE_KEY) === "1") {
      setAuthorized(true);
    }
  }, []);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (input === PASS) {
      sessionStorage.setItem(STORAGE_KEY, "1");
      setAuthorized(true);
    } else {
      setError(true);
      setTimeout(() => setError(false), 1500);
    }
  };

  if (authorized) return <>{children}</>;

  return (
    <div className="flex min-h-screen items-center justify-center bg-neutral-50">
      <form onSubmit={handleSubmit} className="w-full max-w-xs space-y-4 text-center">
        <div>
          <span className="text-2xl text-neutral-900 lowercase">
            <span className="font-extralight tracking-tighter">tu</span>
            <span className="font-bold italic tracking-tight">no</span>
          </span>
        </div>
        <p className="text-sm text-neutral-500">Skriv inn passord for å fortsette</p>
        <input
          type="password"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Passord"
          autoFocus
          className={`w-full rounded-lg border px-4 py-2.5 text-sm focus:outline-none focus:ring-2 transition-colors ${
            error
              ? "border-red-400 focus:ring-red-200"
              : "border-neutral-200 focus:ring-primary-200 focus:border-primary-400"
          }`}
        />
        <button
          type="submit"
          className="w-full rounded-lg bg-neutral-900 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-neutral-800"
        >
          Logg inn
        </button>
        {error && <p className="text-xs text-red-500">Feil passord</p>}
      </form>
    </div>
  );
}
