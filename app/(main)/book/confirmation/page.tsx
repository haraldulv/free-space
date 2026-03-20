"use client";

import Link from "next/link";
import { CheckCircle } from "lucide-react";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";

export default function ConfirmationPage() {
  return (
    <Container className="flex flex-col items-center py-20 text-center">
      <div className="flex h-20 w-20 items-center justify-center rounded-full bg-primary-100">
        <CheckCircle className="h-10 w-10 text-primary-600" />
      </div>
      <h1 className="mt-6 text-3xl font-bold text-neutral-900">
        Bestilling bekreftet!
      </h1>
      <p className="mt-3 max-w-md text-neutral-500">
        Plassen din er reservert. Du kan se bestillingsdetaljer i
        kontrollpanelet ditt.
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
