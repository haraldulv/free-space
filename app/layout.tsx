import type { Metadata } from "next";
import { DM_Sans } from "next/font/google";
import PasswordGate from "@/components/PasswordGate";
import "./globals.css";

const dmSans = DM_Sans({
  variable: "--font-dm-sans",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
});

export const metadata: Metadata = {
  title: "Tuno — Parkering og camping i Norge",
  description:
    "Finn og book parkeringsplasser og campingplasser over hele Norge. Pendlerparkering og bobilturisme gjort enkelt.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="nb" className={`${dmSans.variable} h-full antialiased`}>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
        <meta name="theme-color" content="#1a4fd6" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="default" />
        <link rel="manifest" href="/manifest.json" />
        <link rel="apple-touch-icon" href="/icons/icon-180.png" />
        <script dangerouslySetInnerHTML={{ __html: `
          window.addEventListener('load', function() {
            if (window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.SplashScreen) {
              window.Capacitor.Plugins.SplashScreen.hide();
            }
          });
        `}} />
      </head>
      <body className="min-h-full flex flex-col font-sans">
        <PasswordGate>{children}</PasswordGate>
      </body>
    </html>
  );
}
