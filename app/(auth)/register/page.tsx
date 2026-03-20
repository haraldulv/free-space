"use client";

import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { registerSchema } from "@/lib/utils/validation";
import AuthForm from "@/components/features/AuthForm";

export default function RegisterPage() {
  const router = useRouter();
  const supabase = createClient();

  const handleRegister = async (values: Record<string, string>) => {
    const result = registerSchema.safeParse(values);
    if (!result.success) {
      throw new Error(result.error.issues[0].message);
    }

    const { error } = await supabase.auth.signUp({
      email: result.data.email,
      password: result.data.password,
      options: {
        data: { full_name: result.data.fullName },
      },
    });

    if (error) throw new Error(error.message);
    router.push("/dashboard");
    router.refresh();
  };

  return (
    <AuthForm
      title="Opprett konto"
      subtitle="Bli med på Free Space og begynn å booke"
      fields={[
        {
          name: "fullName",
          label: "Fullt navn",
          type: "text",
          placeholder: "Ola Nordmann",
          autoComplete: "name",
        },
        {
          name: "email",
          label: "E-post",
          type: "email",
          placeholder: "deg@eksempel.no",
          autoComplete: "email",
        },
        {
          name: "password",
          label: "Passord",
          type: "password",
          placeholder: "••••••••",
          autoComplete: "new-password",
        },
        {
          name: "confirmPassword",
          label: "Bekreft passord",
          type: "password",
          placeholder: "••••••••",
          autoComplete: "new-password",
        },
      ]}
      submitLabel="Opprett konto"
      onSubmit={handleRegister}
      footer={
        <>
          Har du allerede en konto?{" "}
          <Link
            href="/login"
            className="text-primary-600 hover:text-primary-700"
          >
            Logg inn
          </Link>
        </>
      }
    />
  );
}
