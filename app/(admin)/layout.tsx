import Link from "next/link";

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-neutral-50">
      <header className="border-b border-neutral-200 bg-white">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-3 sm:px-6">
          <div className="flex items-center gap-3">
            <Link href="/">
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
      {children}
    </div>
  );
}
