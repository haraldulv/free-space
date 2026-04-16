"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import { createClient } from "@/lib/supabase/client";
import { forgotPasswordSchema } from "@/lib/utils/validation";
import AuthForm from "@/components/features/AuthForm";

export default function ForgotPasswordPage() {
  const t = useTranslations("auth");
  const [sent, setSent] = useState(false);
  const supabase = createClient();

  const handleSubmit = async (values: Record<string, string>) => {
    const result = forgotPasswordSchema.safeParse(values);
    if (!result.success) {
      throw new Error(result.error.issues[0].message);
    }

    const { error } = await supabase.auth.resetPasswordForEmail(
      result.data.email,
      { redirectTo: `${window.location.origin}/reset-password` }
    );

    if (error) throw new Error(error.message);
    setSent(true);
  };

  if (sent) {
    return (
      <div className="text-center">
        <h1 className="text-2xl font-bold text-neutral-900">{t("resetSent")}</h1>
        <p className="mt-2 text-sm text-neutral-500">
          {t("resetLinkSent")}
        </p>
        <Link
          href="/login"
          className="mt-4 inline-block text-sm text-primary-600 hover:text-primary-700"
        >
          {t("backToLogin")}
        </Link>
      </div>
    );
  }

  return (
    <AuthForm
      title={t("forgotPasswordTitle")}
      subtitle={t("resetPasswordSubtitle")}
      fields={[
        {
          name: "email",
          label: t("email"),
          type: "email",
          placeholder: t("emailPlaceholder"),
          autoComplete: "email",
        },
      ]}
      submitLabel={t("sendResetLink")}
      onSubmit={handleSubmit}
      footer={
        <Link
          href="/login"
          className="text-primary-600 hover:text-primary-700"
        >
          {t("backToLogin")}
        </Link>
      }
    />
  );
}
