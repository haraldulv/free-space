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
          <span className="font-extralight tracking-tighter">spot</span>
          <span className="font-bold italic tracking-tight">share</span>
        </span>
      </Link>
      <div className="w-full max-w-md rounded-xl bg-white p-8 shadow-sm">
        {children}
      </div>
    </div>
  );
}
