import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import Image from "next/image";
import Container from "@/components/ui/Container";
import {
  Wallet,
  SlidersHorizontal,
  CreditCard,
  Clock,
  Sparkles,
  ShieldCheck,
  QrCode,
  Smartphone,
  Camera,
  Banknote,
} from "lucide-react";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslations("hostLanding");
  return {
    title: t("title"),
    description: t("description"),
  };
}

const APP_STORE_URL =
  "https://apps.apple.com/no/app/tuno-motorhome-and-parking/id6761529990";

const HERO_IMAGE =
  "https://images.unsplash.com/photo-1518124880777-cf8c82231ffb?w=1920&h=1080&fit=crop&q=80";
const FEATURE_IMAGE =
  "https://images.unsplash.com/photo-1527542902003-a675625fb1eb?w=1200&h=700&fit=crop&q=80";

const BENEFITS = [
  { icon: Wallet, titleKey: "benefit1Title", descKey: "benefit1Desc" },
  {
    icon: SlidersHorizontal,
    titleKey: "benefit2Title",
    descKey: "benefit2Desc",
  },
  { icon: CreditCard, titleKey: "benefit3Title", descKey: "benefit3Desc" },
  { icon: Clock, titleKey: "benefit4Title", descKey: "benefit4Desc" },
  { icon: Sparkles, titleKey: "benefit5Title", descKey: "benefit5Desc" },
  { icon: ShieldCheck, titleKey: "benefit6Title", descKey: "benefit6Desc" },
] as const;

const FEATURES = [
  { icon: QrCode, titleKey: "qrFeatureTitle", descKey: "qrFeatureDesc" },
  { icon: Smartphone, titleKey: "appFeatureTitle", descKey: "appFeatureDesc" },
  {
    icon: SlidersHorizontal,
    titleKey: "controlFeatureTitle",
    descKey: "controlFeatureDesc",
  },
] as const;

const STEPS = [
  { icon: Camera, titleKey: "step1Title", descKey: "step1Desc" },
  { icon: QrCode, titleKey: "step2Title", descKey: "step2Desc" },
  { icon: Banknote, titleKey: "step3Title", descKey: "step3Desc" },
] as const;

function NorwayBadge({ variant }: { variant: "light" | "dark" }) {
  const cls =
    variant === "light"
      ? "bg-white/15 text-white backdrop-blur-sm"
      : "bg-neutral-100 text-neutral-700";
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-4 py-1.5 text-sm font-medium ${cls}`}
    >
      <span className="text-base">🇳🇴</span>
      Utviklet i Norge
    </span>
  );
}

export default async function UtleierPage() {
  const t = await getTranslations("hostLanding");

  return (
    <div>
      {/* Hero */}
      <section className="relative flex min-h-[60vh] items-end sm:min-h-[70vh]">
        <Image
          src={HERO_IMAGE}
          alt="Lofoten, Norge"
          fill
          className="object-cover"
          priority
          sizes="100vw"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/40 to-transparent" />
        <Container>
          <div className="relative z-10 max-w-2xl pb-12 sm:pb-16">
            <h1 className="text-3xl font-bold tracking-tight text-white sm:text-5xl lg:text-6xl">
              {t("heroTitle")}
            </h1>
            <p className="mt-4 text-lg text-white/90 sm:text-xl">
              {t("heroSubtitle")}
            </p>
            <div className="mt-8 flex flex-col items-start gap-4 sm:flex-row sm:items-center">
              <Link
                href="/register"
                className="rounded-full bg-[#46C185] px-8 py-3.5 text-base font-semibold text-white shadow-lg transition hover:bg-[#3baa73]"
              >
                {t("registerButton")}
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
            <div className="mt-5">
              <NorwayBadge variant="light" />
            </div>
          </div>
        </Container>
      </section>

      {/* Feature highlight */}
      <section className="py-16 sm:py-24">
        <Container>
          <div className="mx-auto grid max-w-7xl grid-cols-1 items-center gap-12 lg:grid-cols-5">
            <div className="relative aspect-[16/10] overflow-hidden rounded-2xl lg:col-span-3">
              <Image
                src={FEATURE_IMAGE}
                alt="Bobil ved sjøen i Norge"
                fill
                className="object-cover"
                sizes="(min-width: 1024px) 60vw, 100vw"
              />
            </div>
            <div className="lg:col-span-2">
              <h2 className="text-2xl font-bold text-neutral-900 sm:text-3xl">
                {t("featureSectionTitle")}
              </h2>
              <p className="mt-4 text-base text-neutral-600 leading-relaxed sm:text-lg">
                {t("featureSectionDesc")}
              </p>
              <div className="mt-8 space-y-6">
                {FEATURES.map((f) => (
                  <div key={f.titleKey} className="flex items-start gap-4">
                    <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-[#46C185]/10">
                      <f.icon
                        className="h-5 w-5 text-[#46C185]"
                        strokeWidth={1.8}
                      />
                    </div>
                    <div>
                      <h3 className="text-base font-semibold text-neutral-900">
                        {t(f.titleKey)}
                      </h3>
                      <p className="mt-0.5 text-sm text-neutral-600">
                        {t(f.descKey)}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </Container>
      </section>

      {/* How it works */}
      <section className="bg-neutral-50 py-16 sm:py-24">
        <Container>
          <h2 className="text-center text-2xl font-bold text-neutral-900 sm:text-3xl">
            {t("howItWorksTitle")}
          </h2>
          <div className="mx-auto mt-12 grid max-w-5xl grid-cols-1 gap-6 sm:grid-cols-3">
            {STEPS.map((s) => (
              <div
                key={s.titleKey}
                className="rounded-xl border border-neutral-200 bg-white p-8 text-center shadow-sm"
              >
                <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-[#46C185]/10">
                  <s.icon
                    className="h-7 w-7 text-[#46C185]"
                    strokeWidth={1.8}
                  />
                </div>
                <h3 className="mt-5 text-lg font-semibold text-neutral-900">
                  {t(s.titleKey)}
                </h3>
                <p className="mt-2 text-base text-neutral-600">
                  {t(s.descKey)}
                </p>
              </div>
            ))}
          </div>
        </Container>
      </section>

      {/* Benefits */}
      <section className="py-16 sm:py-24">
        <Container>
          <h2 className="text-center text-2xl font-bold text-neutral-900 sm:text-3xl">
            {t("benefitsTitle")}
          </h2>
          <div className="mx-auto mt-12 grid max-w-5xl grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {BENEFITS.map((b) => (
              <div
                key={b.titleKey}
                className="rounded-xl border border-neutral-200 bg-white p-6 shadow-sm"
              >
                <b.icon
                  className="h-8 w-8 text-[#46C185]"
                  strokeWidth={1.6}
                />
                <h3 className="mt-3 text-base font-semibold text-neutral-900">
                  {t(b.titleKey)}
                </h3>
                <p className="mt-1 text-sm text-neutral-500">{t(b.descKey)}</p>
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
            <p className="mt-3 text-base text-white/90 sm:text-lg">
              {t("ctaSubtitle")}
            </p>
            <div className="mt-8 flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
              <Link
                href="/register"
                className="rounded-full bg-white px-8 py-3.5 text-base font-semibold text-[#46C185] shadow-sm transition hover:bg-neutral-100"
              >
                {t("registerButton")}
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
            <div className="mt-6">
              <NorwayBadge variant="light" />
            </div>
          </div>
        </Container>
      </section>
    </div>
  );
}
