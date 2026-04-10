import type { Metadata } from "next";
import LegalPageLayout, {
  Section,
} from "@/components/ui/LegalPageLayout";

export const metadata: Metadata = {
  title: "Retningslinjer | Tuno",
  description: "Retningslinjer for annonser på Tuno — krav til innhold, bilder og oppførsel.",
};

export default function RetningslinjerPage() {
  return (
    <LegalPageLayout
      title="Retningslinjer for annonser"
      lastUpdated="10. april 2026"
    >
      <p className="text-sm text-neutral-600 leading-relaxed">
        Disse retningslinjene gjelder for alle annonser på Tuno. Formålet er å
        sikre en trygg, ærlig og hyggelig opplevelse for både utleiere og
        leietakere.
      </p>

      <Section title="1. Tillatte kategorier">
        <p>Tuno er en markedsplass for utleie av:</p>
        <ul className="list-disc pl-5 space-y-1">
          <li>
            <strong>Parkeringsplasser:</strong> Private oppkjørsler, garasjer,
            gårdsplasser, næringsparkeringsplasser og andre egnede flater for
            personbiler.
          </li>
          <li>
            <strong>Campingplasser:</strong> Plasser egnet for bobiler,
            campingbiler eller telt, med eller uten fasiliteter som strøm, vann
            og tømming.
          </li>
        </ul>
        <p>
          Plasser som ikke faller inn under disse kategoriene, eller som ikke kan
          brukes trygt til parkering eller camping, vil bli fjernet.
        </p>
      </Section>

      <Section title="2. Bildekrav">
        <p>Gode bilder er viktig for å gi leietakere et riktig inntrykk.</p>
        <ul className="list-disc pl-5 space-y-1">
          <li>Last opp minst 1 bilde (anbefalt 3–5)</li>
          <li>Bildene skal vise den faktiske plassen, ikke stockfoto</li>
          <li>Bildene skal være tatt i dagslys og ha god oppløsning</li>
          <li>Vis innkjøring, selve plassen og eventuelle fasiliteter</li>
          <li>Ikke inkluder bilder med personer, bilskilt eller annet personlig innhold uten samtykke</li>
          <li>Maks 10 bilder per annonse, maks 5 MB per bilde</li>
          <li>Aksepterte formater: JPG, PNG</li>
        </ul>
      </Section>

      <Section title="3. Nøyaktig beskrivelse">
        <p>Annonsen skal gi et ærlig og fullstendig bilde av plassen:</p>
        <ul className="list-disc pl-5 space-y-1">
          <li>Beskriv plassens størrelse og hva slags kjøretøy den passer for</li>
          <li>Oppgi eventuell maks kjøretøylengde</li>
          <li>Beskriv tilgang (f.eks. bratt innkjøring, smal vei, port med kode)</li>
          <li>Nevn eventuelle begrensninger (tidspunkt, støy, osv.)</li>
          <li>Oppgi fasiliteter som faktisk er tilgjengelige</li>
        </ul>
        <p>
          Villedende annonser vil bli deaktivert og kan føre til suspensjon av
          kontoen.
        </p>
      </Section>

      <Section title="4. Prissetting">
        <p>
          Du bestemmer selv prisen for plassen din. Prisen skal oppgis i norske
          kroner (NOK) per natt eller per time. Vær oppmerksom på:
        </p>
        <ul className="list-disc pl-5 space-y-1">
          <li>Prisen som vises for leietaker inkluderer Tunos servicetillegg</li>
          <li>Sett en realistisk pris for området og plasstypen</li>
          <li>Ikke sett kunstig lave priser for å tiltrekke bookinger og deretter be om tilleggsbetaling utenfor plattformen</li>
        </ul>
      </Section>

      <Section title="5. Lokasjon og kart">
        <p>
          Annonsen skal ha korrekt lokasjon markert på kartet. Du kan velge å
          skjule den eksakte adressen — i så fall vises kun et omtrentlig område
          for leietaker frem til booking er bekreftet.
        </p>
        <p>
          Bruk plassmarkør-funksjonen for å vise hvor de individuelle plassene
          er. Dette hjelper leietakere med å finne riktig plass ved ankomst.
        </p>
      </Section>

      <Section title="6. Tilgjengelighet">
        <p>
          Hold tilgjengelighetskalenderen oppdatert. Blokker datoer når plassen
          ikke er tilgjengelig. Ikke la bookinger stå åpne for datoer du ikke
          kan tilby — dette fører til avbestillinger og dårlig opplevelse for
          leietakere.
        </p>
      </Section>

      <Section title="7. Forbudt innhold">
        <p>Følgende er ikke tillatt på Tuno:</p>
        <ul className="list-disc pl-5 space-y-1">
          <li>Annonser for plasser du ikke har rett til å leie ut</li>
          <li>Falsk eller villedende informasjon</li>
          <li>Diskriminerende innhold eller praksis</li>
          <li>Støtende, truende eller upassende bilder eller tekst</li>
          <li>Annonser for andre tjenester enn parkering/camping</li>
          <li>Duplikatannonser for samme plass</li>
          <li>Kontaktinformasjon i annonseteksten (for å omgå plattformen)</li>
        </ul>
      </Section>

      <Section title="8. Oppførsel og kommunikasjon">
        <p>
          Vi forventer at alle brukere behandler hverandre med respekt. Dette
          gjelder kommunikasjon via meldinger, ved ankomst og under oppholdet.
        </p>
        <p>
          Trakassering, trusler, diskriminering eller annen uakseptabel oppførsel
          fører til umiddelbar utestengelse fra plattformen.
        </p>
      </Section>

      <Section title="9. Moderering">
        <p>
          Tuno forbeholder seg retten til å gjennomgå, deaktivere eller fjerne
          annonser som bryter disse retningslinjene. Ved gjentatte brudd kan
          kontoen din suspenderes permanent.
        </p>
        <p>
          Dersom du mener en avgjørelse er feil, kan du kontakte oss på{" "}
          <a
            href="mailto:kontakt@tuno.no"
            className="underline text-neutral-900 hover:text-[#46C185]"
          >
            kontakt@tuno.no
          </a>
          .
        </p>
      </Section>
    </LegalPageLayout>
  );
}
