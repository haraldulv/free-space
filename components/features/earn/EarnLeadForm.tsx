"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { submitEarnLeadAction } from "@/app/[locale]/tjen/actions";

export default function EarnLeadForm() {
  const t = useTranslations("tjen");
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [website, setWebsite] = useState(""); // honeypot, skal forbli tom
  const [state, setState] = useState<"idle" | "sending" | "done" | "error">("idle");

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (state === "sending") return;
    setState("sending");
    const result = await submitEarnLeadAction({ name, phone, website });
    setState(result.error ? "error" : "done");
  };

  if (state === "done") {
    return (
      <div className="rounded-3xl border border-[#37caa4]/40 bg-[#37caa4]/10 p-7 text-center">
        <p className="text-lg font-bold text-[#0f7a5f]">{t("leadThanks")}</p>
      </div>
    );
  }

  return (
    <form onSubmit={submit} className="rounded-3xl border border-[#e8e5dc] bg-[#fdfcf9] p-7">
      <h2 className="text-2xl font-bold text-neutral-900">{t("leadTitle")}</h2>
      <p className="mt-2 text-[15px] text-neutral-600">{t("leadBody")}</p>

      <div className="mt-5 grid gap-3 sm:grid-cols-2">
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder={t("leadName")}
          autoComplete="name"
          required
          minLength={2}
          maxLength={80}
          className="w-full rounded-2xl border border-neutral-200 px-4 py-3 text-[15px] focus:border-[#37caa4] focus:outline-none"
        />
        <input
          type="tel"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          placeholder={t("leadPhone")}
          autoComplete="tel"
          required
          minLength={8}
          maxLength={16}
          className="w-full rounded-2xl border border-neutral-200 px-4 py-3 text-[15px] focus:border-[#37caa4] focus:outline-none"
        />
        {/* Honeypot: skjult for mennesker, bots fyller den ut */}
        <input
          type="text"
          value={website}
          onChange={(e) => setWebsite(e.target.value)}
          tabIndex={-1}
          autoComplete="off"
          aria-hidden="true"
          className="hidden"
          name="website"
        />
      </div>

      {state === "error" && (
        <p className="mt-3 text-sm text-red-600">{t("leadError")}</p>
      )}

      <button
        type="submit"
        disabled={state === "sending"}
        className="mt-5 w-full rounded-full bg-[#121412] px-6 py-4 text-base font-bold text-white transition-transform hover:scale-[1.01] disabled:opacity-60 sm:w-auto sm:px-10"
      >
        {state === "sending" ? t("leadSending") : t("leadSend")}
      </button>
    </form>
  );
}
