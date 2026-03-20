import Link from "next/link";

export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-neutral-50 px-4">
      <Link href="/" className="mb-8">
        <span className="text-2xl font-bold text-primary-600">Free Space</span>
      </Link>
      <div className="w-full max-w-md rounded-xl bg-white p-8 shadow-sm">
        {children}
      </div>
    </div>
  );
}
