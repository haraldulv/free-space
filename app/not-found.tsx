import Link from "next/link";
import { MapPinOff } from "lucide-react";
import Button from "@/components/ui/Button";

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center px-4 text-center">
      <MapPinOff className="h-16 w-16 text-neutral-300" />
      <h1 className="mt-6 text-3xl font-bold text-neutral-900">
        Siden ble ikke funnet
      </h1>
      <p className="mt-2 text-neutral-500">
        Siden du leter etter finnes ikke eller har blitt flyttet.
      </p>
      <Link href="/" className="mt-6">
        <Button>Tilbake til forsiden</Button>
      </Link>
    </div>
  );
}
