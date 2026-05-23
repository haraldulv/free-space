"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

export default function AdminHeader() {
  const pathname = usePathname();
  // Outreach-siden trenger full bredde for liste+kart.
  const fullWidth = pathname?.includes("/admin/outreach");

  return (
    <header className="border-b border-neutral-200 bg-white">
      <div
        className={`flex items-center justify-between px-4 py-3 sm:px-6 ${
          fullWidth ? "w-full" : "mx-auto max-w-7xl"
        }`}
      >
        <div className="flex items-center gap-3">
          <Link href="/">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/tuno-logo.png" alt="Tuno" className="h-6" />
          </Link>
          <span className="rounded-md bg-red-100 px-2 py-0.5 text-xs font-semibold text-red-700">
            Admin
          </span>
        </div>
        <Link href="/dashboard" className="text-sm text-neutral-500 hover:text-neutral-700">
          Tilbake til appen
        </Link>
      </div>
    </header>
  );
}
