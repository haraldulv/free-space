import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import Container from "@/components/ui/Container";

export default function Footer() {
  const t = useTranslations("footer");
  const year = new Date().getFullYear();
  return (
    <footer className="border-t border-neutral-200 bg-white">
      <Container className="py-12">
        <div className="grid grid-cols-1 gap-8 sm:grid-cols-2 lg:grid-cols-4">
          <div>
            <Link href="/">
              <span className="text-xl text-neutral-900 lowercase">
                tuno
              </span>
            </Link>
            <p className="mt-3 text-sm text-neutral-500">
              {t("tagline")}
            </p>
          </div>

          <div>
            <h3 className="text-sm font-semibold text-neutral-900">{t("explore")}</h3>
            <ul className="mt-3 space-y-2">
              <li>
                <Link
                  href={{ pathname: "/", query: { category: "parking" } }}
                  className="text-sm text-neutral-500 hover:text-neutral-700"
                >
                  {t("parking")}
                </Link>
              </li>
              <li>
                <Link
                  href={{ pathname: "/", query: { category: "camping" } }}
                  className="text-sm text-neutral-500 hover:text-neutral-700"
                >
                  {t("camping")}
                </Link>
              </li>
            </ul>
          </div>

          <div>
            <h3 className="text-sm font-semibold text-neutral-900">{t("company")}</h3>
            <ul className="mt-3 space-y-2">
              <li>
                <span className="text-sm text-neutral-500">{t("about")}</span>
              </li>
              <li>
                <span className="text-sm text-neutral-500">{t("contact")}</span>
              </li>
            </ul>
          </div>

          <div>
            <h3 className="text-sm font-semibold text-neutral-900">{t("legal")}</h3>
            <ul className="mt-3 space-y-2">
              <li>
                <Link
                  href="/vilkar"
                  className="text-sm text-neutral-500 hover:text-neutral-700"
                >
                  {t("terms")}
                </Link>
              </li>
              <li>
                <Link
                  href="/personvern"
                  className="text-sm text-neutral-500 hover:text-neutral-700"
                >
                  {t("privacy")}
                </Link>
              </li>
              <li>
                <Link
                  href="/utleiervilkar"
                  className="text-sm text-neutral-500 hover:text-neutral-700"
                >
                  {t("hostTerms")}
                </Link>
              </li>
            </ul>
          </div>
        </div>

        <div className="mt-8 border-t border-neutral-200 pt-8 text-center text-sm text-neutral-400">
          {t("copyright", { year })}
        </div>
      </Container>
    </footer>
  );
}
