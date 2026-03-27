import Link from "next/link";

export default function RegisterPage() {
  return (
    <div className="space-y-5">
      <div className="text-center">
        <h1 className="text-2xl font-bold text-neutral-900">Registrering kommer snart</h1>
        <p className="mt-1 text-sm text-neutral-500">SpotShare er ikke åpen for registrering ennå.</p>
      </div>

      <p className="text-center text-sm text-neutral-400">
        Har du allerede en konto?{" "}
        <Link
          href="/login"
          className="text-primary-600 hover:text-primary-700"
        >
          Logg inn
        </Link>
      </p>
    </div>
  );
}
