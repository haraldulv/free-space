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
  title: "Free Space — Parkering og camping i Norge",
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
        <link href="https://api.mapbox.com/mapbox-gl-js/v3.9.4/mapbox-gl.css" rel="stylesheet" />
      </head>
      <body className="min-h-full flex flex-col font-sans">
        <PasswordGate>{children}</PasswordGate>
      </body>
    </html>
  );
}
