import { type NextRequest, NextResponse } from "next/server";
import createIntlMiddleware from "next-intl/middleware";
import { routing } from "@/i18n/routing";
import { updateSession } from "@/lib/supabase/middleware";

const intlMiddleware = createIntlMiddleware(routing);

export async function middleware(request: NextRequest) {
  const intlResponse = intlMiddleware(request);

  // If intl middleware triggered a redirect/rewrite for locale, follow it
  // but still apply Supabase auth guards on the resolved pathname.
  if (intlResponse.status === 307 || intlResponse.status === 308) {
    return intlResponse;
  }

  const authResponse = await updateSession(request);
  if (authResponse.status >= 300 && authResponse.status < 400) {
    return authResponse;
  }

  // Merge headers from intl response into auth response
  intlResponse.headers.forEach((value, key) => {
    if (key.startsWith("x-") || key === "vary") {
      authResponse.headers.set(key, value);
    }
  });

  return authResponse;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|api/webhooks|api/cron|api/bookings|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
