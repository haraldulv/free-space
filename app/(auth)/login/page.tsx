"use client";

import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { loginSchema } from "@/lib/utils/validation";
import AuthForm from "@/components/features/AuthForm";
import GoogleSignInButton from "@/components/features/GoogleSignInButton";

export default function LoginPage() {
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
        <h1 className="text-2xl font-bold text-neutral-900">Velkommen tilbake</h1>
        <p className="mt-1 text-sm text-neutral-500">Logg inn på din Free Space-konto</p>
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
              href={`/register${redirectTo !== "/dashboard" ? `?redirectTo=${encodeURIComponent(redirectTo)}` : ""}`}
              className="text-primary-600 hover:text-primary-700"
            >
              Opprett konto
            </Link>
          </>
        }
      />
    </div>
  );
}
