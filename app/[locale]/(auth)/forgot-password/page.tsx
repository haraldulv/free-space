"use client";

import { useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { forgotPasswordSchema } from "@/lib/utils/validation";
import AuthForm from "@/components/features/AuthForm";

export default function ForgotPasswordPage() {
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
        <h1 className="text-2xl font-bold text-neutral-900">Sjekk e-posten din</h1>
        <p className="mt-2 text-sm text-neutral-500">
          Vi har sendt en lenke for å tilbakestille passordet til e-postadressen din.
        </p>
        <Link
          href="/login"
          className="mt-4 inline-block text-sm text-primary-600 hover:text-primary-700"
        >
          Tilbake til innlogging
        </Link>
      </div>
    );
  }

  return (
    <AuthForm
      title="Tilbakestill passord"
      subtitle="Skriv inn e-posten din, så sender vi en tilbakestillingslenke"
      fields={[
        {
          name: "email",
          label: "E-post",
          type: "email",
          placeholder: "deg@eksempel.no",
          autoComplete: "email",
        },
      ]}
      submitLabel="Send tilbakestillingslenke"
      onSubmit={handleSubmit}
      footer={
        <Link
          href="/login"
          className="text-primary-600 hover:text-primary-700"
        >
          Tilbake til innlogging
        </Link>
      }
    />
  );
}
