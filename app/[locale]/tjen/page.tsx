import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { APP_STORE_URL } from "@/lib/config";
import EarnCalculator from "@/components/features/earn/EarnCalculator";
import EarnLeadForm from "@/components/features/earn/EarnLeadForm";

interface PageProps {
  params: Promise<{ locale: string }>;
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "tjen" });
  return {
    title: t("metaTitle"),
    description: t("metaDescription"),
  };
}

/** Hvit strek-illustrasjon i plakatens stil: hus, oppkjørsel og bil. */
function DrivewayIllustration() {
  return (
    <svg viewBox="0 0 520 190" fill="none" aria-hidden="true" className="mx-auto h-36 w-full max-w-md sm:h-44">
      <g stroke="#ffffff" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
        {/* Bakkelinje */}
        <path d="M10 160 H510" />
        {/* Hus */}
        <path d="M330 160 V96 L395 58 L460 96 V160" />
        <path d="M418 160 V118 H443 V160" />
        <rect x="352" y="104" width="26" height="22" rx="2" />
        {/* Busker */}
        <path d="M300 160 c0-14 10-22 20-22 c8 0 14 6 15 22" />
        <path d="M472 160 c0-12 8-19 17-19 c7 0 12 5 13 19" />
        {/* Oppkjørsel */}
        <path d="M212 160 L244 118 H316 L296 160" />
        {/* Bil på plassen */}
        <path d="M60 160 v-6 a8 8 0 0 1 8-8 h8 l12-18 h52 l14 18 h10 a8 8 0 0 1 8 8 v6" />
        <circle cx="94" cy="160" r="10" />
        <circle cx="152" cy="160" r="10" />
        <path d="M96 146 l8-14 h34 l10 14" />
      </g>
    </svg>
  );
}

export default async function TjenPage({ params }: PageProps) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("tjen");

  const steps = [
    { title: t("how1Title"), body: t("how1Body") },
    { title: t("how2Title"), body: t("how2Body") },
    { title: t("how3Title"), body: t("how3Body") },
  ];

  return (
    <main className="min-h-screen bg-[#f4f1ea]">
      {/* Mørk hero-flate (palett C «Kontrast») */}
      <section className="bg-[#121412] px-5 pb-28 pt-8 text-[#f5f6f4] sm:pb-32">
        <div className="mx-auto max-w-3xl">
          <div className="flex items-center justify-between">
            <span className="text-2xl font-bold lowercase tracking-tight">tuno</span>
            <span className="rounded-full bg-[#37caa4]/15 px-4 py-1.5 text-sm font-semibold text-[#4fd6b2]">
              {t("eyebrow")}
            </span>
          </div>

          <h1 className="mt-10 text-center text-4xl font-bold leading-tight sm:text-6xl">
            {t("title")}
          </h1>
          <p className="mx-auto mt-5 max-w-xl text-center text-lg font-medium leading-relaxed text-[#cfd4d0] sm:text-xl">
            {t("subtitle")}
          </p>
          <p className="mt-2 text-center text-sm font-medium text-[#a8afaa]">
            {t("youDecide")}
          </p>

          <div className="mt-10">
            <DrivewayIllustration />
          </div>
        </div>
      </section>

      {/* Kalkulator-kort som overlapper flaten */}
      <section className="px-5">
        <div className="mx-auto -mt-20 max-w-xl">
          <EarnCalculator />
        </div>
      </section>

      {/* Du får hele prisen */}
      <section className="px-5 py-14">
        <div className="mx-auto max-w-xl rounded-3xl border border-[#e8e5dc] bg-[#fdfcf9] p-7 text-center">
          <h2 className="text-2xl font-bold text-neutral-900">{t("feeTitle")}</h2>
          <p className="mx-auto mt-3 max-w-md text-[15px] leading-relaxed text-neutral-600">
            {t("feeBody")}
          </p>
        </div>
      </section>

      {/* Slik fungerer det */}
      <section className="px-5 pb-14">
        <div className="mx-auto max-w-3xl">
          <h2 className="text-center text-2xl font-bold text-neutral-900 sm:text-3xl">
            {t("howTitle")}
          </h2>
          <div className="mt-8 grid gap-4 sm:grid-cols-3">
            {steps.map((step, i) => (
              <div key={step.title} className="rounded-3xl border border-[#e8e5dc] bg-[#fdfcf9] p-6 text-center">
                <div className="mx-auto flex h-10 w-10 items-center justify-center rounded-full bg-[#37caa4]/15 text-lg font-bold text-[#0f7a5f]">
                  {i + 1}
                </div>
                <h3 className="mt-4 text-lg font-bold text-neutral-900">{step.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-neutral-600">{step.body}</p>
              </div>
            ))}
          </div>
          <p className="mt-6 text-center text-sm text-neutral-500">{t("addressNote")}</p>
        </div>
      </section>

      {/* Vi ringer deg */}
      <section className="px-5 pb-14">
        <div className="mx-auto max-w-xl">
          <EarnLeadForm />
        </div>
      </section>

      {/* App-CTA */}
      <section className="bg-[#121412] px-5 py-14 text-center text-[#f5f6f4]">
        <div className="mx-auto max-w-xl">
          <h2 className="text-3xl font-bold">{t("appTitle")}</h2>
          <p className="mt-3 text-base font-medium text-[#a8afaa]">{t("appBody")}</p>
          <a
            href={APP_STORE_URL}
            className="mt-7 inline-block rounded-full bg-[#37caa4] px-9 py-4 text-base font-bold text-[#13201c] transition-transform hover:scale-[1.02]"
          >
            {t("appCta")}
          </a>
        </div>
      </section>

      <footer className="px-5 py-8 text-center text-sm text-neutral-400">
        Tuno · <a href="https://tuno.no" className="hover:text-neutral-600">tuno.no</a> ·{" "}
        <a href="mailto:support@tuno.no" className="hover:text-neutral-600">support@tuno.no</a>
      </footer>
    </main>
  );
}
