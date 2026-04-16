"use client";

import { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { registerSchema } from "@/lib/utils/validation";
import AuthForm from "@/components/features/AuthForm";
import GoogleSignInButton from "@/components/features/GoogleSignInButton";
import AppleSignInButton from "@/components/features/AppleSignInButton";

export default function RegisterPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirectTo = searchParams.get("redirectTo") || "/dashboard";
  const supabase = createClient();
  const [termsAccepted, setTermsAccepted] = useState(false);
  const [termsError, setTermsError] = useState("");

  const handleRegister = async (values: Record<string, string>) => {
    setTermsError("");

    if (!termsAccepted) {
      setTermsError("Du må godta vilkårene for å opprette konto");
      throw new Error("Du må godta vilkårene for å opprette konto");
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
        <h1 className="text-2xl font-bold text-neutral-900">Opprett konto</h1>
        <p className="mt-1 text-sm text-neutral-500">Bli med på Tuno og begynn å booke</p>
      </div>

      <AppleSignInButton redirectTo={redirectTo} />
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
                Jeg godtar Tunos{" "}
                <Link
                  href="/vilkar"
                  target="_blank"
                  className="underline text-neutral-900 hover:text-[#46C185]"
                >
                  brukervilkår
                </Link>{" "}
                og{" "}
                <Link
                  href="/personvern"
                  target="_blank"
                  className="underline text-neutral-900 hover:text-[#46C185]"
                >
                  personvernerklæring
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
