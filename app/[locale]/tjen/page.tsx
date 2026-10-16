import type { Metadata } from "next";
import Image from "next/image";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { APP_STORE_URL } from "@/lib/config";
import EarnCalculator from "@/components/features/earn/EarnCalculator";

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

/** Telefonmockup med ekte app-skjermbilde: iPhone-ramme med Dynamic Island,
    samme uttrykk som App Store-bildene. Kuttes av seksjonskanten i bunn så
    appen «stiger opp» av heroen. */
function PhoneMockup() {
  return (
    <div className="mx-auto w-[290px] sm:w-[330px]">
      <div className="rounded-t-[48px] bg-[#0a0b0a] p-[11px] pb-0 shadow-[0_30px_70px_rgba(10,12,10,0.35)] ring-[3px] ring-white/15">
        <div className="relative overflow-hidden rounded-t-[38px] bg-white">
          <Image
            src="/tjen-app-skjerm.jpg"
            alt="Tuno-appen med kart over ledige parkeringsplasser"
            width={720}
            height={1564}
            className="w-full"
            priority
          />
          <div className="absolute left-1/2 top-[10px] h-[24px] w-[84px] -translate-x-1/2 rounded-full bg-black" />
        </div>
      </div>
    </div>
  );
}

export default async function TjenPage({ params }: PageProps) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("tjen");

  // Offisiell Apple-badge per språk (nb er fallback).
  const badgeSrc = `/app-store-badge-${locale === "en" || locale === "de" ? locale : "nb"}.svg`;

  const steps = [
    { title: t("how1Title"), body: t("how1Body") },
    { title: t("how2Title"), body: t("how2Body") },
    { title: t("how3Title"), body: t("how3Body") },
  ];

  return (
    <main className="min-h-screen bg-[#f4f1ea]">
      {/* Hero i Tuno-grønn med telefonmockup som kuttes av bunnkanten */}
      <section className="bg-[#46C185] px-5 pt-8 text-white">
        <div className="mx-auto max-w-3xl">
          <div className="flex items-center justify-between">
            {/* Logo som på plakaten: hvit pin + tuno */}
            <Image
              src="/tuno-logo-pin-white.png"
              alt="Tuno"
              width={766}
              height={261}
              className="h-8 w-auto"
              priority
            />
            <span className="rounded-full bg-white/15 px-4 py-1.5 text-sm font-semibold text-white">
              {t("eyebrow")}
            </span>
          </div>

          <h1 className="mt-10 text-center text-4xl font-bold leading-tight sm:text-6xl">
            {t("title")}
          </h1>
          <p className="mx-auto mt-5 max-w-xl text-center text-lg font-medium leading-relaxed text-white/90 sm:text-xl">
            {t("subtitle")}
          </p>
          <p className="mt-2 text-center text-sm font-medium text-white/75">
            {t("youDecide")}
          </p>

          <div className="mt-8 flex flex-col items-center gap-3">
            <a
              href={APP_STORE_URL}
              className="inline-block transition-transform hover:scale-[1.03]"
            >
              <Image
                src={badgeSrc}
                alt={t("appStoreBadgeAlt")}
                width={156}
                height={52}
                className="h-[52px] w-auto"
                priority
              />
            </a>
            <p className="text-sm font-medium text-white/75">{t("androidSoon")}</p>
          </div>

          <div className="mt-12">
            <PhoneMockup />
          </div>
        </div>
      </section>

      {/* Kalkulator */}
      <section className="px-5 pt-12">
        <div className="mx-auto max-w-xl">
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
                <div className="mx-auto flex h-10 w-10 items-center justify-center rounded-full bg-[#46C185]/15 text-lg font-bold text-[#0f7a5f]">
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

      {/* App-CTA */}
      <section className="bg-[#46C185] px-5 py-16 text-center text-white">
        <div className="mx-auto max-w-xl">
          {/* Ekte app-ikon, samme som på hjemskjermen */}
          <Image
            src="/app-icon.png"
            alt=""
            aria-hidden="true"
            width={80}
            height={80}
            className="mx-auto h-20 w-20 rounded-[18px] shadow-[0_8px_24px_rgba(0,0,0,0.22)] ring-2 ring-white/40"
          />
          <h2 className="mt-6 text-3xl font-bold sm:text-4xl">{t("appTitle")}</h2>
          <p className="mx-auto mt-3 max-w-md text-base font-medium text-white/85">
            {t("appBody")}
          </p>
          <a
            href={APP_STORE_URL}
            className="mt-8 inline-block transition-transform hover:scale-[1.03]"
          >
            <Image
              src={badgeSrc}
              alt={t("appStoreBadgeAlt")}
              width={168}
              height={56}
              className="h-14 w-auto"
            />
          </a>
          <div className="mt-4 flex justify-center">
            <span className="rounded-full border border-white/40 px-4 py-1.5 text-sm font-semibold text-white/90">
              {t("androidSoonPill")}
            </span>
          </div>
        </div>
      </section>

      <footer className="px-5 py-8 text-center text-sm text-neutral-400">
        Tuno · <a href="https://tuno.no" className="hover:text-neutral-600">tuno.no</a> ·{" "}
        <a href="mailto:support@tuno.no" className="hover:text-neutral-600">support@tuno.no</a>
      </footer>
    </main>
  );
}
