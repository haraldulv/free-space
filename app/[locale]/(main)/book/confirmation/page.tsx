"use client";

import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { CheckCircle, Clock, XCircle } from "lucide-react";
import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";
import { createClient } from "@/lib/supabase/client";

export default function ConfirmationPage() {
  const t = useTranslations("booking");
  const tCommon = useTranslations("common");
  const searchParams = useSearchParams();
  const bookingId = searchParams.get("bookingId");
  const [status, setStatus] = useState<"loading" | "confirmed" | "pending" | "failed">("loading");

  useEffect(() => {
    if (!bookingId) {
      setStatus("confirmed");
      return;
    }

    const supabase = createClient();

    let attempts = 0;
    const check = async () => {
      const { data } = await supabase
        .from("bookings")
        .select("status, payment_status")
        .eq("id", bookingId)
        .single();

      if (data?.payment_status === "paid" || data?.status === "confirmed") {
        setStatus("confirmed");
      } else if (data?.payment_status === "failed") {
        setStatus("failed");
      } else if (attempts < 10) {
        attempts++;
        setTimeout(check, 2000);
      } else {
        setStatus("confirmed");
      }
    };

    check();
  }, [bookingId]);

  if (status === "loading") {
    return (
      <Container className="flex flex-col items-center py-20 text-center">
        <div className="flex h-20 w-20 items-center justify-center rounded-full bg-primary-100">
          <Clock className="h-10 w-10 text-primary-600 animate-pulse" />
        </div>
        <h1 className="mt-6 text-2xl font-bold text-neutral-900">
          {t("confirmingPayment")}
        </h1>
        <p className="mt-3 text-neutral-500">{t("pleaseWait")}</p>
      </Container>
    );
  }

  if (status === "failed") {
    return (
      <Container className="flex flex-col items-center py-20 text-center">
        <div className="flex h-20 w-20 items-center justify-center rounded-full bg-red-100">
          <XCircle className="h-10 w-10 text-red-600" />
        </div>
        <h1 className="mt-6 text-2xl font-bold text-neutral-900">
          {t("paymentFailedTitle")}
        </h1>
        <p className="mt-3 max-w-md text-neutral-500">
          {t("paymentFailedDesc")}
        </p>
        <div className="mt-8">
          <Link href="/">
            <Button>{tCommon("backToHome")}</Button>
          </Link>
        </div>
      </Container>
    );
  }

  return (
    <Container className="flex flex-col items-center py-20 text-center">
      <div className="flex h-20 w-20 items-center justify-center rounded-full bg-primary-100">
        <CheckCircle className="h-10 w-10 text-primary-600" />
      </div>
      <h1 className="mt-6 text-3xl font-bold text-neutral-900">
        {t("bookingConfirmed")}
      </h1>
      <p className="mt-3 max-w-md text-neutral-500">
        {t("bookingConfirmedDesc")}
      </p>
      <div className="mt-8 flex gap-3">
        <Link href="/dashboard">
          <Button>{t("seeMyBookings")}</Button>
        </Link>
        <Link href="/">
          <Button variant="outline">{tCommon("backToHome")}</Button>
        </Link>
      </div>
    </Container>
  );
}
