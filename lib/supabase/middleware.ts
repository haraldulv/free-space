import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { routing } from "@/i18n/routing";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || "https://placeholder.supabase.co";
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "placeholder-key";

function stripLocale(pathname: string): { locale: string | null; path: string } {
  for (const locale of routing.locales) {
    if (pathname === `/${locale}`) return { locale, path: "/" };
    if (pathname.startsWith(`/${locale}/`)) return { locale, path: pathname.slice(locale.length + 1) };
  }
  return { locale: null, path: pathname };
}

function localePrefix(locale: string | null): string {
  if (!locale || locale === routing.defaultLocale) return "";
  return `/${locale}`;
}

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  // Skip auth if Supabase is not configured
  if (supabaseUrl === "https://placeholder.supabase.co") {
    return supabaseResponse;
  }

  const supabase = createServerClient(supabaseUrl, supabaseKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) =>
          request.cookies.set(name, value)
        );
        supabaseResponse = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) =>
          supabaseResponse.cookies.set(name, value, options)
        );
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { locale, path } = stripLocale(request.nextUrl.pathname);
  const prefix = localePrefix(locale);

  // Auth guard for protected routes — redirect to login with return URL
  if (!user && (path.startsWith("/dashboard") || path.startsWith("/bli-utleier") || path.startsWith("/settings") || path.startsWith("/admin"))) {
    const url = request.nextUrl.clone();
    const returnTo = request.nextUrl.pathname + request.nextUrl.search;
    url.pathname = `${prefix}/login`;
    url.searchParams.set("redirectTo", returnTo);
    return NextResponse.redirect(url);
  }

  // Admin guard — check is_admin flag
  if (user && path.startsWith("/admin")) {
    const { data: profile } = await supabase
      .from("profiles")
      .select("is_admin")
      .eq("id", user.id)
      .single();

    if (!profile?.is_admin) {
      const url = request.nextUrl.clone();
      url.pathname = prefix || "/";
      return NextResponse.redirect(url);
    }
  }

  return supabaseResponse;
}
