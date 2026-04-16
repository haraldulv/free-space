import { Suspense } from "react";
import { Link } from "@/i18n/navigation";

export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-neutral-50 px-4">
      <Link href="/" className="mb-8">
        <img src="/tuno-logo.png" alt="Tuno" className="h-8" />
      </Link>
      <div className="w-full max-w-md rounded-xl bg-white p-8 shadow-sm">
        <Suspense>{children}</Suspense>
      </div>
    </div>
  );
}
