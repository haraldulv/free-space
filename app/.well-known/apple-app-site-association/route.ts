import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

/**
 * Apple App Site Association — dynamisk per host.
 *
 * Vi serverer FORSKJELLIGE app-IDs for prod-domenet (tuno.no, www.tuno.no)
 * og staging-domenet (staging.tuno.no), så Universal Links åpner riktig
 * iOS-app uten kollisjon.
 *
 * Apple-krav:
 *  - HTTPS, Content-Type application/json, status 200, ingen redirects
 *  - Maks 128 KB
 *  - Apple cacher denne aggressivt — endringer kan ta tid å forplante
 */
const PROD_APP_IDS = ["3VD2DMBJ6M.no.tuno.app"];
const STAGING_APP_IDS = ["3VD2DMBJ6M.no.tuno.app.staging"];

const COMPONENTS = [
  { "/": "/listings/*", comment: "Annonse-detaljside" },
  { "/": "/auth/verified", comment: "E-post-verifisering eksakt" },
  { "/": "/auth/verified*", comment: "E-post-verifisering med query/hash" },
];

function appIdsForHost(host: string | null): string[] {
  if (!host) return PROD_APP_IDS;
  const lower = host.toLowerCase();
  if (lower.startsWith("staging.")) return STAGING_APP_IDS;
  return PROD_APP_IDS;
}

export async function GET(request: NextRequest) {
  const host = request.headers.get("host");
  const appIDs = appIdsForHost(host);

  const body = {
    applinks: {
      details: [
        {
          appIDs,
          components: COMPONENTS,
        },
      ],
    },
  };

  return NextResponse.json(body, {
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "public, max-age=3600",
    },
  });
}
