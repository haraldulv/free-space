import type { Metadata } from "next";
import LegalPageLayout, { Section } from "@/components/ui/LegalPageLayout";

export const metadata: Metadata = {
  title: "Kontakt | Tuno",
  description:
    "Kontakt Tuno-support. Vi svarer på spørsmål om booking, utleie og betaling.",
};

export default function KontaktPage() {
  return (
    <LegalPageLayout title="Kontakt oss" lastUpdated="20. mai 2026">
      <Section title="Trenger du hjelp?">
        <p>
          Vi hjelper deg med booking, utleie, betaling og andre spørsmål om
          Tuno. Send oss en melding eller ring, så svarer vi så fort vi kan.
        </p>
      </Section>

      <Section title="E-post">
        <p>
          <a
            href="mailto:support@tuno.no"
            className="text-base font-medium text-neutral-900 underline hover:text-[#46C185]"
          >
            support@tuno.no
          </a>
        </p>
        <p className="text-sm text-neutral-500">
          Svar innen 24 timer på hverdager, lengre i helger og høytider.
        </p>
      </Section>

      <Section title="I appen">
        <p>
          Når du er logget inn i Tuno-appen kan du nå oss direkte fra
          Innstillinger → Kontakt support. Da chatter du med oss i Meldinger.
        </p>
      </Section>

      <Section title="Spørsmål om en konkret booking?">
        <p>
          Bruk meldingstråden med utleieren først — de fleste praktiske
          spørsmål (innsjekk, plassering, strøm) løses raskt der. Ta kontakt
          med oss hvis du ikke får svar eller det er noe vi må følge opp.
        </p>
      </Section>

      <Section title="Misbruk eller upassende innhold">
        <p>
          Hvis du opplever upassende oppførsel, mistenker svindel eller ser
          innhold som strider mot{" "}
          <a
            href="/retningslinjer"
            className="underline text-neutral-900 hover:text-[#46C185]"
          >
            retningslinjene
          </a>
          , kontakt oss umiddelbart på{" "}
          <a
            href="mailto:support@tuno.no"
            className="underline text-neutral-900 hover:text-[#46C185]"
          >
            support@tuno.no
          </a>
          . Vi behandler alle henvendelser konfidensielt.
        </p>
      </Section>
    </LegalPageLayout>
  );
}
