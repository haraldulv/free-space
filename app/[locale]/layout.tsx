import type { Metadata } from "next";
import { DM_Sans } from "next/font/google";
import { notFound } from "next/navigation";
import { NextIntlClientProvider, hasLocale } from "next-intl";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { Analytics } from "@vercel/analytics/next";
import PasswordGate from "@/components/PasswordGate";
import { routing } from "@/i18n/routing";
import "../globals.css";

const dmSans = DM_Sans({
  variable: "--font-dm-sans",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
});

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "metadata" });
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || "https://tuno.no";
  const localeMap: Record<string, string> = { nb: "nb_NO", en: "en_US", de: "de_DE" };
  return {
    metadataBase: new URL(siteUrl),
    title: {
      default: t("title"),
      template: `%s — Tuno`,
    },
    description: t("description"),
    openGraph: {
      siteName: "Tuno",
      type: "website",
      url: siteUrl,
      title: t("title"),
      description: t("description"),
      locale: localeMap[locale] ?? "nb_NO",
      images: ["/tuno-logo.png"],
    },
    twitter: {
      card: "summary_large_image",
      title: t("title"),
      description: t("description"),
      images: ["/tuno-logo.png"],
    },
    icons: {
      icon: "/favicon.ico",
      apple: "/icons/icon-180.png",
    },
  };
}

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export default async function LocaleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!hasLocale(routing.locales, locale)) {
    notFound();
  }
  setRequestLocale(locale);

  return (
    <html lang={locale} className={`${dmSans.variable} h-full antialiased`}>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
        <meta name="theme-color" content="#46C185" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="default" />
        <link rel="manifest" href="/manifest.json" />
        <link rel="apple-touch-icon" href="/icons/icon-180.png" />
        <script dangerouslySetInnerHTML={{ __html: `
          window.addEventListener('load', function() {
            if (window.Capacitor && window.Capacitor.isNativePlatform && window.Capacitor.isNativePlatform()) {
              if (window.Capacitor.Plugins.SplashScreen) {
                window.Capacitor.Plugins.SplashScreen.hide();
              }
              if (window.Capacitor.Plugins.Keyboard) {
                window.Capacitor.Plugins.Keyboard.setAccessoryBarVisible({ isVisible: true });
              }
              if (window.Capacitor.Plugins.App) {
                window.Capacitor.Plugins.App.addListener('appUrlOpen', function(event) {
                  var url = event.url;
                  if (url && url.indexOf('/auth/callback') !== -1) {
                    var path = url.replace(/^https?:\\/\\/[^/]+/, '');
                    window.location.href = path;
                  }
                });
              }
            }
          });
        `}} />
      </head>
      <body className="min-h-full flex flex-col font-sans">
        <NextIntlClientProvider>
          <PasswordGate>{children}</PasswordGate>
        </NextIntlClientProvider>
        <Analytics />
      </body>
    </html>
  );
}
