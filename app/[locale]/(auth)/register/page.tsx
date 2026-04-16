"use client";

import { useState } from "react";
import { useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import { createClient } from "@/lib/supabase/client";
import { registerSchema } from "@/lib/utils/validation";
import AuthForm from "@/components/features/AuthForm";
import GoogleSignInButton from "@/components/features/GoogleSignInButton";
import AppleSignInButton from "@/components/features/AppleSignInButton";

export default function RegisterPage() {
  const t = useTranslations("auth");
  const searchParams = useSearchParams();
  const redirectTo = searchParams.get("redirectTo") || "/dashboard";
  const supabase = createClient();
  const [termsAccepted, setTermsAccepted] = useState(false);
  const [termsError, setTermsError] = useState("");

  const handleRegister = async (values: Record<string, string>) => {
    setTermsError("");

    if (!termsAccepted) {
      setTermsError(t("mustAcceptTermsToCreate"));
      throw new Error(t("mustAcceptTermsToCreate"));
    }

    const result = registerSchema.safeParse(values);
    if (!result.success) {
      throw new Error(result.error.issues[0].message);
    }

    const { data: signUpData, error } = await supabase.auth.signUp({
      email: result.data.email,
      password: result.data.password,
      options: {
        data: { full_name: result.data.fullName },
      },
    });

    if (error) throw new Error(error.message);

    if (signUpData.user) {
      await supabase
        .from("profiles")
        .update({ terms_accepted_at: new Date().toISOString() })
        .eq("id", signUpData.user.id);
    }

    window.location.href = `/bekreft-epost?email=${encodeURIComponent(result.data.email)}`;
  };

  return (
    <div className="space-y-5">
      <div className="text-center">
        <h1 className="text-2xl font-bold text-neutral-900">{t("registerTitle")}</h1>
        <p className="mt-1 text-sm text-neutral-500">{t("registerSubtitle")}</p>
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
            name: "fullName",
            label: t("fullName"),
            type: "text",
            placeholder: t("fullNamePlaceholder"),
            autoComplete: "name",
          },
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
            autoComplete: "new-password",
          },
          {
            name: "confirmPassword",
            label: t("confirmPassword"),
            type: "password",
            placeholder: t("passwordDots"),
            autoComplete: "new-password",
          },
        ]}
        submitLabel={t("createAccount")}
        onSubmit={handleRegister}
        extraContent={
          <div>
            <label className="flex items-start gap-3 cursor-pointer">
              <input
                type="checkbox"
                checked={termsAccepted}
                onChange={(e) => {
                  setTermsAccepted(e.target.checked);
                  if (e.target.checked) setTermsError("");
                }}
                className="mt-0.5 h-4 w-4 rounded border-neutral-300 text-[#46C185] focus:ring-[#46C185]"
              />
              <span className="text-sm text-neutral-600">
                {t("acceptTermsIntro")}{" "}
                <Link
                  href="/vilkar"
                  target="_blank"
                  className="underline text-neutral-900 hover:text-[#46C185]"
                >
                  {t("userTerms")}
                </Link>{" "}
                {t("and")}{" "}
                <Link
                  href="/personvern"
                  target="_blank"
                  className="underline text-neutral-900 hover:text-[#46C185]"
                >
                  {t("privacyPolicy")}
                </Link>
              </span>
            </label>
            {termsError && (
              <p className="mt-1 text-sm text-red-600">{termsError}</p>
            )}
          </div>
        }
        footer={
          <>
            {t("haveAccount")}{" "}
            <Link
              href={{
                pathname: "/login",
                query: redirectTo !== "/dashboard" ? { redirectTo } : {},
              }}
              className="text-primary-600 hover:text-primary-700"
            >
              {t("loginButton")}
            </Link>
          </>
        }
      />
    </div>
  );
}
