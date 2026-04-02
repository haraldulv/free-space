import { Suspense } from "react";
import Link from "next/link";

export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-neutral-50 px-4">
      <Link href="/" className="mb-8">
        <span className="text-2xl text-neutral-900 lowercase">
          <span className="font-extralight tracking-tighter">tu</span>
          <span className="font-bold italic tracking-tight">no</span>
        </span>
      </Link>
      <div className="w-full max-w-md rounded-xl bg-white p-8 shadow-sm">
        <Suspense>{children}</Suspense>
      </div>
    </div>
  );
}
