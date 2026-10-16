import { redirect } from "@/i18n/navigation";

/** Den gamle camping-landingssiden for utleiere er pensjonert etter
    parkering-pivoten. /tjen er den nye utleier-landingen (QR-plakaten
    peker også dit). */
export default async function UtleierPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  redirect({ href: "/tjen", locale });
}
