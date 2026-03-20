"use client";

import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { loginSchema } from "@/lib/utils/validation";
import AuthForm from "@/components/features/AuthForm";

export default function LoginPage() {
  const router = useRouter();
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
    router.push("/dashboard");
    router.refresh();
  };

  return (
    <AuthForm
      title="Velkommen tilbake"
      subtitle="Logg inn på din Free Space-konto"
      fields={[
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
          autoComplete: "current-password",
        },
      ]}
      submitLabel="Logg inn"
      onSubmit={handleLogin}
      footer={
        <>
          <Link
            href="/forgot-password"
            className="text-primary-600 hover:text-primary-700"
          >
            Glemt passord?
          </Link>
          <span className="mx-2">&middot;</span>
          <Link
            href="/register"
            className="text-primary-600 hover:text-primary-700"
          >
            Opprett konto
          </Link>
        </>
      }
    />
  );
}
