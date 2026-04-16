"use client";

import { useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { useRouter, Link } from "@/i18n/navigation";
import { createClient } from "@/lib/supabase/client";
import { loginSchema } from "@/lib/utils/validation";
import AuthForm from "@/components/features/AuthForm";
import GoogleSignInButton from "@/components/features/GoogleSignInButton";
import AppleSignInButton from "@/components/features/AppleSignInButton";

export default function LoginPage() {
  const t = useTranslations("auth");
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirectTo = searchParams.get("redirectTo") || "/dashboard";
  const supabase = createClient();

  const handleLogin = async (values: Record<string, string>) => {
    const result = loginSchema.safeParse(values);
    if (!result.success) {
      throw new Error(result.error.issues[0].message);
    }

    const { error } = await supabase.auth.signInWithPassword({
      email: result.data.email,
      password: result.data.password,
    });

    if (error) throw new Error(error.message);
    router.push(redirectTo);
    router.refresh();
  };

  return (
    <div className="space-y-5">
      <div className="text-center">
        <h1 className="text-2xl font-bold text-neutral-900">{t("loginTitle")}</h1>
        <p className="mt-1 text-sm text-neutral-500">{t("loginSubtitle")}</p>
      </div>

      <AppleSignInButton redirectTo={redirectTo} />
      <GoogleSignInButton redirectTo={redirectTo} />

      <div className="relative">
        <div className="absolute inset-0 flex items-center">
          <div className="w-full border-t border-neutral-200" />
        </div>
        <div className="relative flex justify-center text-sm">
          <span className="bg-white px-3 text-neutral-400">{t("or")}</span>
        </div>
      </div>

      <AuthForm
        fields={[
          {
            name: "email",
            label: t("email"),
            type: "email",
            placeholder: t("emailPlaceholder"),
            autoComplete: "email",
          },
          {
            name: "password",
            label: t("password"),
            type: "password",
            placeholder: t("passwordDots"),
            autoComplete: "current-password",
          },
        ]}
        submitLabel={t("loginButton")}
        onSubmit={handleLogin}
        footer={
          <>
            <Link
              href="/forgot-password"
              className="text-primary-600 hover:text-primary-700"
            >
              {t("forgotPassword")}
            </Link>
            <span className="mx-2">&middot;</span>
            <Link
              href={{
                pathname: "/register",
                query: redirectTo !== "/dashboard" ? { redirectTo } : {},
              }}
              className="text-primary-600 hover:text-primary-700"
            >
              {t("createAccount")}
            </Link>
          </>
        }
      />
    </div>
  );
}
