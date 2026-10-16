import type { NextConfig } from "next";
import createNextIntlPlugin from "next-intl/plugin";

const withNextIntl = createNextIntlPlugin("./i18n/request.ts");

const nextConfig: NextConfig = {
  experimental: {
    serverActions: {
      bodySizeLimit: "10mb",
    },
  },
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "images.unsplash.com",
      },
      {
        protocol: "https",
        hostname: "images.pexels.com",
      },
      {
        protocol: "https",
        hostname: "mqyeptwrfrhwxtysccnp.supabase.co",
      },
      {
        // Staging-storage: lokal dev og staging.tuno.no leser staging-DB-en,
        // der annonsebildene ligger på denne verten. Uten den krasjer
        // next/image hele sider i dev og gir knuste bilder ellers.
        protocol: "https",
        hostname: "qqtgmcxzyuquunsxoqog.supabase.co",
      },
      {
        protocol: "https",
        hostname: "lh3.googleusercontent.com",
      },
    ],
    formats: ["image/avif"],
  },
};

export default withNextIntl(nextConfig);
