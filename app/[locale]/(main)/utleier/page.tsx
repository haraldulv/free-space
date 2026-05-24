import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import Link from "next/link";
import Image from "next/image";
import Container from "@/components/ui/Container";
import {
  Wallet,
  SlidersHorizontal,
  ShieldCheck,
  CreditCard,
  Clock,
  Sparkles,
  Download,
  CalendarCheck,
  Banknote,
} from "lucide-react";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslations("hostLanding");
  return {
    title: t("title"),
    description: t("description"),
  };
}

const APP_STORE_URL = "https://apps.apple.com/no/app/tuno/id6749316123";

const BENEFIT_ICONS = [Wallet, SlidersHorizontal, ShieldCheck, CreditCard, Clock, Sparkles];

export default async function UtleierPage() {
  const t = await getTranslations("hostLanding");

  const benefits = Array.from({ length: 6 }, (_, i) => ({
    icon: BENEFIT_ICONS[i],
    title: t(`benefit${i + 1}Title`),
    desc: t(`benefit${i + 1}Desc`),
  }));

  const steps = [
    { icon: Download, num: "1", title: t("step1Title"), desc: t("step1Desc") },
    { icon: CalendarCheck, num: "2", title: t("step2Title"), desc: t("step2Desc") },
    { icon: Banknote, num: "3", title: t("step3Title"), desc: t("step3Desc") },
  ];

  return (
    <div>
      {/* Hero */}
      <section className="bg-[#f0faf4] py-16 sm:py-24">
        <Container>
          <div className="mx-auto max-w-2xl text-center">
            <h1 className="text-3xl font-bold tracking-tight text-neutral-900 sm:text-5xl">
              {t("heroTitle")}
            </h1>
            <p className="mt-4 text-lg text-neutral-600 sm:text-xl">
              {t("heroSubtitle")}
            </p>
            <div className="mt-8 flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
              <Link
                href="/bli-utleier"
                className="rounded-full bg-[#46C185] px-8 py-3 text-base font-semibold text-white shadow-sm transition hover:bg-[#3baa73]"
              >
                {t("getStarted")}
              </Link>
              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
              >
                <Image
                  src="/app-store-badge-nb.svg"
                  alt={t("downloadApp")}
                  width={180}
                  height={60}
                  className="h-[52px] w-auto"
                />
              </a>
            </div>
          </div>
        </Container>
      </section>

      {/* Benefits */}
      <section className="py-16 sm:py-24">
        <Container>
          <h2 className="text-center text-2xl font-bold text-neutral-900 sm:text-3xl">
            {t("benefitsTitle")}
          </h2>
          <div className="mx-auto mt-12 grid max-w-5xl grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {benefits.map((b) => (
              <div
                key={b.title}
                className="rounded-xl border border-neutral-200 bg-white p-6 transition hover:shadow-md"
              >
                <b.icon className="h-7 w-7 text-[#46C185]" strokeWidth={1.8} />
                <h3 className="mt-3 text-base font-semibold text-neutral-900">{b.title}</h3>
                <p className="mt-1 text-sm text-neutral-600">{b.desc}</p>
              </div>
            ))}
          </div>
        </Container>
      </section>

      {/* How it works */}
      <section className="bg-neutral-50 py-16 sm:py-24">
        <Container>
          <h2 className="text-center text-2xl font-bold text-neutral-900 sm:text-3xl">
            {t("howItWorksTitle")}
          </h2>
          <div className="mx-auto mt-12 grid max-w-4xl grid-cols-1 gap-8 sm:grid-cols-3">
            {steps.map((s) => (
              <div key={s.num} className="text-center">
                <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-[#46C185]/10">
                  <s.icon className="h-6 w-6 text-[#46C185]" strokeWidth={1.8} />
                </div>
                <div className="mt-1 text-xs font-semibold text-[#46C185]">
                  {s.num}
                </div>
                <h3 className="mt-2 text-base font-semibold text-neutral-900">{s.title}</h3>
                <p className="mt-1 text-sm text-neutral-600">{s.desc}</p>
              </div>
            ))}
          </div>
        </Container>
      </section>

      {/* CTA */}
      <section className="bg-[#46C185] py-16 sm:py-20">
        <Container>
          <div className="mx-auto max-w-2xl text-center">
            <h2 className="text-2xl font-bold text-white sm:text-3xl">
              {t("ctaTitle")}
            </h2>
            <p className="mt-3 text-base text-white/90">
              {t("ctaSubtitle")}
            </p>
            <div className="mt-8 flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
              <Link
                href="/bli-utleier"
                className="rounded-full bg-white px-8 py-3 text-base font-semibold text-[#46C185] shadow-sm transition hover:bg-neutral-100"
              >
                {t("createListing")}
              </Link>
              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
              >
                <Image
                  src="/app-store-badge-nb.svg"
                  alt={t("downloadApp")}
                  width={180}
                  height={60}
                  className="h-[52px] w-auto"
                />
              </a>
            </div>
          </div>
        </Container>
      </section>
    </div>
  );
}
