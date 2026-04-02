import Link from "next/link";
import Container from "@/components/ui/Container";

export default function Footer() {
  return (
    <footer className="border-t border-neutral-200 bg-white">
      <Container className="py-12">
        <div className="grid grid-cols-1 gap-8 sm:grid-cols-2 lg:grid-cols-4">
          <div>
            <Link href="/">
              <span className="text-xl text-neutral-900 lowercase">
                <span className="font-extralight tracking-tighter">tu</span>
                <span className="font-bold italic tracking-tight">no</span>
              </span>
            </Link>
            <p className="mt-3 text-sm text-neutral-500">
              Finn og book parkeringsplasser og campingplasser over hele Norge.
            </p>
          </div>

          <div>
            <h3 className="text-sm font-semibold text-neutral-900">Utforsk</h3>
            <ul className="mt-3 space-y-2">
              <li>
                <Link
                  href="/?category=parking"
                  className="text-sm text-neutral-500 hover:text-neutral-700"
                >
                  Parkering
                </Link>
              </li>
              <li>
                <Link
                  href="/?category=camping"
                  className="text-sm text-neutral-500 hover:text-neutral-700"
                >
                  Campingplass
                </Link>
              </li>
            </ul>
          </div>

          <div>
            <h3 className="text-sm font-semibold text-neutral-900">Selskap</h3>
            <ul className="mt-3 space-y-2">
              <li>
                <span className="text-sm text-neutral-500">Om oss</span>
              </li>
              <li>
                <span className="text-sm text-neutral-500">Kontakt</span>
              </li>
            </ul>
          </div>

          <div>
            <h3 className="text-sm font-semibold text-neutral-900">Juridisk</h3>
            <ul className="mt-3 space-y-2">
              <li>
                <span className="text-sm text-neutral-500">Vilkår</span>
              </li>
              <li>
                <span className="text-sm text-neutral-500">Personvern</span>
              </li>
            </ul>
          </div>
        </div>

        <div className="mt-8 border-t border-neutral-200 pt-8 text-center text-sm text-neutral-400">
          &copy; {new Date().getFullYear()} Tuno. Alle rettigheter reservert.
        </div>
      </Container>
    </footer>
  );
}
