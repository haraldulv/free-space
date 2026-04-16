"use client";

import { useState, useRef, useEffect, useTransition } from "react";
import { Languages, Check } from "lucide-react";
import { useLocale, useTranslations } from "next-intl";
import { usePathname, useRouter } from "@/i18n/navigation";
import { routing, type Locale } from "@/i18n/routing";
import { createClient } from "@/lib/supabase/client";

const LOCALE_LABELS: Record<Locale, { native: string; flag: string }> = {
  nb: { native: "Norsk", flag: "🇳🇴" },
  en: { native: "English", flag: "🇬🇧" },
};

export default function LocaleSwitcher() {
  const t = useTranslations("nav");
  const locale = useLocale() as Locale;
  const router = useRouter();
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const [isPending, startTransition] = useTransition();
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const onSelect = (next: Locale) => {
    setOpen(false);
    if (next === locale) return;
    startTransition(() => {
      router.replace(pathname, { locale: next });
    });
    // Lagre preferanse for innloggede brukere (best-effort, ignorer feil)
    void (async () => {
      try {
        const supabase = createClient();
        const { data } = await supabase.auth.getUser();
        if (data.user) {
          await supabase
            .from("profiles")
            .update({ preferred_language: next })
            .eq("id", data.user.id);
        }
      } catch {
        // Ignorer — kolonnen kan mangle lokalt
      }
    })();
  };

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen(!open)}
        disabled={isPending}
        className="flex items-center justify-center rounded-full border border-neutral-200 bg-white p-2 shadow-sm text-neutral-500 transition-all hover:shadow-md"
        aria-label={t("changeLanguage")}
      >
        <Languages className="h-4 w-4" />
      </button>

      {open && (
        <div className="animate-fade-in absolute right-0 mt-2 w-44 rounded-xl border border-neutral-100 bg-white py-1.5 shadow-xl z-50">
          {routing.locales.map((code) => (
            <button
              key={code}
              onClick={() => onSelect(code)}
              className="flex w-full items-center gap-3 px-4 py-2.5 min-h-[44px] text-sm text-neutral-700 hover:bg-neutral-50"
            >
              <span className="text-base">{LOCALE_LABELS[code].flag}</span>
              <span className="flex-1 text-left">{LOCALE_LABELS[code].native}</span>
              {code === locale && <Check className="h-4 w-4 text-[#46C185]" />}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
