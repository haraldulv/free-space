"use client";

import { AlertTriangle } from "lucide-react";
import Button from "@/components/ui/Button";

export default function Error({
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center px-4 text-center">
      <AlertTriangle className="h-16 w-16 text-amber-400" />
      <h1 className="mt-6 text-3xl font-bold text-neutral-900">
        Noe gikk galt
      </h1>
      <p className="mt-2 text-neutral-500">
        En uventet feil oppstod. Vennligst prøv igjen.
      </p>
      <Button onClick={reset} className="mt-6">
        Prøv igjen
      </Button>
    </div>
  );
}
