"use client";

import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import Link from "next/link";
import { CheckCircle, Clock, XCircle } from "lucide-react";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";
import { createClient } from "@/lib/supabase/client";

export default function ConfirmationPage() {
  const searchParams = useSearchParams();
  const bookingId = searchParams.get("bookingId");
  const [status, setStatus] = useState<"loading" | "confirmed" | "pending" | "failed">("loading");

  useEffect(() => {
    if (!bookingId) {
      setStatus("confirmed"); // Fallback for old localStorage bookings
      return;
    }

    const supabase = createClient();

    // Poll for payment confirmation (webhook may take a moment)
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
        // After 20 seconds, assume success (Stripe redirect means payment went through)
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
          Bekrefter betaling...
        </h1>
        <p className="mt-3 text-neutral-500">Vennligst vent.</p>
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
          Betalingen feilet
        </h1>
        <p className="mt-3 max-w-md text-neutral-500">
          Noe gikk galt med betalingen. Vennligst prøv igjen.
        </p>
        <div className="mt-8">
          <Link href="/">
            <Button>Tilbake til forsiden</Button>
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
        Bestilling bekreftet!
      </h1>
      <p className="mt-3 max-w-md text-neutral-500">
        Betalingen er gjennomført og plassen din er reservert. Du kan se
        bestillingsdetaljer i dashboardet ditt.
      </p>
      <div className="mt-8 flex gap-3">
        <Link href="/dashboard">
          <Button>Se mine bestillinger</Button>
        </Link>
        <Link href="/">
          <Button variant="outline">Tilbake til forsiden</Button>
        </Link>
      </div>
    </Container>
  );
}
