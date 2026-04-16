"use client";

import { useState } from "react";
import { useSearchParams } from "next/navigation";
import { Mail } from "lucide-react";
import { useTranslations } from "next-intl";
import { createClient } from "@/lib/supabase/client";
import Button from "@/components/ui/Button";

export default function BekreftEpostPage() {
  const t = useTranslations("auth");
  const searchParams = useSearchParams();
  const email = searchParams.get("email") || "";
  const [resending, setResending] = useState(false);
  const [resent, setResent] = useState(false);

  const handleResend = async () => {
    if (!email || resending) return;
    setResending(true);
    const supabase = createClient();
    await supabase.auth.resend({ type: "signup", email });
    setResending(false);
    setResent(true);
    setTimeout(() => setResent(false), 5000);
  };

  return (
    <div className="space-y-6 text-center">
      <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-[#46C185]/10">
        <Mail className="h-8 w-8 text-[#46C185]" />
      </div>

      <div>
        <h1 className="text-2xl font-bold text-neutral-900">
          {t("resetSent")}
        </h1>
        <p className="mt-2 text-sm text-neutral-500">
          {email
            ? t("confirmEmailInstructions", { email })
            : t("confirmEmailInstructionsNoEmail")}
        </p>
      </div>

      <div className="space-y-3">
        <p className="text-xs text-neutral-400">
          {t("checkSpam")}
        </p>

        <Button
          variant="outline"
          size="sm"
          onClick={handleResend}
          disabled={resending || resent}
          className="mx-auto"
        >
          {resending
            ? t("sending")
            : resent
              ? t("sent")
              : t("resendConfirmation")}
        </Button>
      </div>
    </div>
  );
}
