"use client";

import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { resetPasswordSchema } from "@/lib/utils/validation";
import AuthForm from "@/components/features/AuthForm";

export default function ResetPasswordPage() {
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
      title="Sett nytt passord"
      subtitle="Skriv inn ditt nye passord nedenfor"
      fields={[
        {
          name: "password",
          label: "Nytt passord",
          type: "password",
          placeholder: "••••••••",
          autoComplete: "new-password",
        },
        {
          name: "confirmPassword",
          label: "Bekreft nytt passord",
          type: "password",
          placeholder: "••••••••",
          autoComplete: "new-password",
        },
      ]}
      submitLabel="Oppdater passord"
      onSubmit={handleReset}
    />
  );
}
