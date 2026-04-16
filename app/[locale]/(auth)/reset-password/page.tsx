"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "@/i18n/navigation";
import { createClient } from "@/lib/supabase/client";
import { resetPasswordSchema } from "@/lib/utils/validation";
import AuthForm from "@/components/features/AuthForm";

export default function ResetPasswordPage() {
  const t = useTranslations("auth");
  const router = useRouter();
  const supabase = createClient();

  const handleReset = async (values: Record<string, string>) => {
    const result = resetPasswordSchema.safeParse(values);
    if (!result.success) {
      throw new Error(result.error.issues[0].message);
    }

    const { error } = await supabase.auth.updateUser({
      password: result.data.password,
    });

    if (error) throw new Error(error.message);
    router.push("/login");
  };

  return (
    <AuthForm
      title={t("newPasswordTitle")}
      subtitle={t("newPasswordSubtitle")}
      fields={[
        {
          name: "password",
          label: t("newPassword"),
          type: "password",
          placeholder: t("passwordDots"),
          autoComplete: "new-password",
        },
        {
          name: "confirmPassword",
          label: t("confirmNewPassword"),
          type: "password",
          placeholder: t("passwordDots"),
          autoComplete: "new-password",
        },
      ]}
      submitLabel={t("updatePassword")}
      onSubmit={handleReset}
    />
  );
}
