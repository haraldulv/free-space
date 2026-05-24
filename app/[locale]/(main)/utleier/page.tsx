import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import Image from "next/image";
import Container from "@/components/ui/Container";
import {
  Wallet,
  SlidersHorizontal,
  ShieldCheck,
  CreditCard,
  Clock,
  Sparkles,
  QrCode,
  Smartphone,
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
  "https://images.unsplash.com/photo-1527542902003-a675625fb1eb?w=800&h=600&fit=crop&q=80";

const BENEFIT_ICONS = [
  Wallet,
  SlidersHorizontal,
  ShieldCheck,
  CreditCard,
  Clock,
  Sparkles,
];

const FEATURES = [
  { icon: QrCode, titleKey: "qrFeatureTitle", descKey: "qrFeatureDesc" },
  { icon: Smartphone, titleKey: "appFeatureTitle", descKey: "appFeatureDesc" },
  {
    icon: SlidersHorizontal,
    titleKey: "controlFeatureTitle",
    descKey: "controlFeatureDesc",
  },
] as const;

export default async function UtleierPage() {
  const t = await getTranslations("hostLanding");

  const benefits = Array.from({ length: 6 }, (_, i) => ({
    icon: BENEFIT_ICONS[i],
    title: t(`benefit${i + 1}Title`),
    desc: t(`benefit${i + 1}Desc`),
  }));

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
            <span className="inline-block rounded-full bg-[#46C185] px-4 py-1.5 text-xs font-semibold text-white">
              {t("heroBadge")}
            </span>
            <h1 className="mt-4 text-3xl font-bold tracking-tight text-white sm:text-5xl lg:text-6xl">
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
          </div>
        </Container>
      </section>

      {/* Feature highlight */}
      <section className="py-16 sm:py-24">
        <Container>
          <div className="mx-auto grid max-w-6xl grid-cols-1 items-center gap-12 lg:grid-cols-2">
            <div className="relative aspect-[4/3] overflow-hidden rounded-2xl">
              <Image
                src={FEATURE_IMAGE}
                alt="Bobil ved sjøen i Norge"
                fill
                className="object-cover"
                sizes="(min-width: 1024px) 50vw, 100vw"
              />
            </div>
            <div>
              <h2 className="text-2xl font-bold text-neutral-900 sm:text-3xl">
                {t("featureSectionTitle")}
              </h2>
              <p className="mt-4 text-base text-neutral-600 leading-relaxed">
                {t("featureSectionDesc")}
              </p>
              <div className="mt-8 space-y-6">
                {FEATURES.map((f) => (
                  <div key={f.titleKey} className="flex items-start gap-4">
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[#46C185]/10">
                      <f.icon
                        className="h-5 w-5 text-[#46C185]"
                        strokeWidth={1.8}
                      />
                    </div>
                    <div>
                      <h3 className="text-sm font-semibold text-neutral-900">
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
          <div className="mx-auto mt-12 grid max-w-4xl grid-cols-1 gap-8 sm:grid-cols-3">
            {[1, 2, 3].map((num) => (
              <div key={num} className="text-center">
                <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-[#46C185] text-lg font-bold text-white">
                  {num}
                </div>
                <h3 className="mt-4 text-base font-semibold text-neutral-900">
                  {t(`step${num}Title`)}
                </h3>
                <p className="mt-2 text-sm text-neutral-600">
                  {t(`step${num}Desc`)}
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
            {benefits.map((b) => (
              <div
                key={b.title}
                className="rounded-xl border border-neutral-100 bg-white p-5 shadow-sm"
              >
                <b.icon
                  className="h-6 w-6 text-[#46C185]"
                  strokeWidth={1.8}
                />
                <h3 className="mt-3 text-sm font-semibold text-neutral-900">
                  {b.title}
                </h3>
                <p className="mt-1 text-xs text-neutral-500">{b.desc}</p>
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
            <p className="mt-3 text-base text-white/90">{t("ctaSubtitle")}</p>
            <div className="mt-8 flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
              <Link
                href="/register"
                className="rounded-full bg-white px-8 py-3 text-base font-semibold text-[#46C185] shadow-sm transition hover:bg-neutral-100"
              >
                {t("registerButton")}
              </Link>
              <Link
                href="/bli-utleier"
                className="rounded-full border-2 border-white px-8 py-3 text-base font-semibold text-white transition hover:bg-white/10"
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
