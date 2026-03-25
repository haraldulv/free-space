"use client";

import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { registerSchema } from "@/lib/utils/validation";
import AuthForm from "@/components/features/AuthForm";
import GoogleSignInButton from "@/components/features/GoogleSignInButton";

export default function RegisterPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirectTo = searchParams.get("redirectTo") || "/dashboard";
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
    router.push(redirectTo);
    router.refresh();
  };

  return (
    <div className="space-y-5">
      <div className="text-center">
        <h1 className="text-2xl font-bold text-neutral-900">Opprett konto</h1>
        <p className="mt-1 text-sm text-neutral-500">Bli med på Free Space og begynn å booke</p>
      </div>

      <GoogleSignInButton redirectTo={redirectTo} />

      <div className="relative">
        <div className="absolute inset-0 flex items-center">
          <div className="w-full border-t border-neutral-200" />
        </div>
        <div className="relative flex justify-center text-sm">
          <span className="bg-white px-3 text-neutral-400">eller</span>
        </div>
      </div>

      <AuthForm
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
              href={`/login${redirectTo !== "/dashboard" ? `?redirectTo=${encodeURIComponent(redirectTo)}` : ""}`}
              className="text-primary-600 hover:text-primary-700"
            >
              Logg inn
            </Link>
          </>
        }
      />
    </div>
  );
}
