import type { Metadata } from "next";
import LegalPageLayout, {
  Section,
} from "@/components/ui/LegalPageLayout";

export const metadata: Metadata = {
  title: "Personvern | Tuno",
  description: "Personvernerklæring for Tuno — slik behandler vi dine personopplysninger.",
};

export default function PersonvernPage() {
  return (
    <LegalPageLayout title="Personvernerklæring" lastUpdated="10. april 2026">
      <Section title="1. Behandlingsansvarlig">
        <p>
          Tuno (org.nr. under registrering) er behandlingsansvarlig for
          personopplysninger som samles inn gjennom tuno.no og Tuno-appen. Du kan
          kontakte oss på{" "}
          <a
            href="mailto:support@tuno.no"
            className="underline text-neutral-900 hover:text-[#46C185]"
          >
            support@tuno.no
          </a>{" "}
          med spørsmål om personvern.
        </p>
      </Section>

      <Section title="2. Personopplysninger vi samler inn">
        <p>Vi samler inn følgende kategorier av personopplysninger:</p>
        <ul className="list-disc pl-5 space-y-1">
          <li>
            <strong>Kontoinformasjon:</strong> Navn, e-postadresse, profilbilde og
            passord (kryptert). Ved innlogging via Google eller Apple mottar vi
            navn og e-post fra disse tjenestene.
          </li>
          <li>
            <strong>Utleierinformasjon:</strong> Fødselsdato, adresse,
            telefonnummer, bankkontonummer (IBAN) og personnummer — nødvendig for
            identitetsverifisering og utbetalinger via Stripe.
          </li>
          <li>
            <strong>Annonsedata:</strong> Bilder, beskrivelser, lokasjon og priser
            du publiserer.
          </li>
          <li>
            <strong>Bookingdata:</strong> Datoer, betalingsinformasjon og
            kommunikasjon mellom utleier og leietaker.
          </li>
          <li>
            <strong>Teknisk data:</strong> IP-adresse, nettlesertype,
            enhetstype og generelle bruksmønstre for feilsøking og forbedring av
            tjenesten.
          </li>
        </ul>
      </Section>

      <Section title="3. Formål og rettslig grunnlag">
        <p>Vi behandler personopplysningene dine for følgende formål:</p>
        <ul className="list-disc pl-5 space-y-2">
          <li>
            <strong>Levering av tjenesten</strong> (GDPR art. 6(1)(b) — oppfyllelse
            av avtale): Opprette og administrere kontoen din, behandle bookinger
            og betalinger, fasilitere kommunikasjon mellom brukere.
          </li>
          <li>
            <strong>Lovpålagte krav</strong> (GDPR art. 6(1)(c) — rettslig
            forpliktelse): Oppfylle regnskapskrav, rapportering til
            skattemyndigheter, og forebygging av hvitvasking via Stripe.
          </li>
          <li>
            <strong>Forbedring av tjenesten</strong> (GDPR art. 6(1)(f) — berettiget
            interesse): Analysere bruksmønstre for å forbedre funksjonalitet,
            feilsøking og sikkerhet.
          </li>
          <li>
            <strong>Markedsføring</strong> (GDPR art. 6(1)(a) — samtykke): Vi
            sender kun markedsføring dersom du har gitt uttrykkelig samtykke.
            Du kan trekke samtykket tilbake når som helst.
          </li>
        </ul>
      </Section>

      <Section title="4. Deling med tredjeparter">
        <p>Vi deler personopplysninger med følgende tredjeparter:</p>
        <ul className="list-disc pl-5 space-y-2">
          <li>
            <strong>Supabase (Hetzner, Frankfurt):</strong> Vår databaseleverandør.
            Lagrer kontoinformasjon, annonser og bookinger i EU.
          </li>
          <li>
            <strong>Stripe (Irland/USA):</strong> Betalingsbehandling og
            identitetsverifisering for utleiere. Stripe er selvstendig
            behandlingsansvarlig for data de mottar. Se{" "}
            <a
              href="https://stripe.com/no/privacy"
              target="_blank"
              rel="noopener noreferrer"
              className="underline text-neutral-900 hover:text-[#46C185]"
            >
              Stripes personvernerklæring
            </a>
            .
          </li>
          <li>
            <strong>Google (USA):</strong> Google Maps og Places API for
            kartvisning og adresseoppslag. Google mottar IP-adresse og
            søkestrenger. Se{" "}
            <a
              href="https://policies.google.com/privacy"
              target="_blank"
              rel="noopener noreferrer"
              className="underline text-neutral-900 hover:text-[#46C185]"
            >
              Googles personvernerklæring
            </a>
            .
          </li>
          <li>
            <strong>Vercel (USA):</strong> Hosting av nettsiden. Mottar
            IP-adresser og teknisk data.
          </li>
        </ul>
        <p>
          Overføring til USA skjer på grunnlag av EU-kommisjonens
          beslutning om tilstrekkelig beskyttelsesnivå (Data Privacy Framework)
          eller standard personvernbestemmelser (SCCs).
        </p>
      </Section>

      <Section title="5. Lagring og sletting">
        <p>
          Vi lagrer personopplysningene dine så lenge kontoen din er aktiv og
          du bruker tjenesten. Når du sletter kontoen din, slettes dine
          personopplysninger innen 30 dager, med unntak av data vi er lovpålagt
          å oppbevare (f.eks. regnskapsdata i 5 år).
        </p>
        <p>
          Bookinghistorikk og betalingsdata kan oppbevares i anonymisert form
          for regnskapsformål etter kontosletting.
        </p>
      </Section>

      <Section title="6. Dine rettigheter">
        <p>
          Etter personopplysningsloven og GDPR har du følgende rettigheter:
        </p>
        <ul className="list-disc pl-5 space-y-1">
          <li>
            <strong>Innsyn:</strong> Du kan be om en kopi av alle
            personopplysninger vi har om deg.
          </li>
          <li>
            <strong>Retting:</strong> Du kan be om at uriktige opplysninger
            korrigeres.
          </li>
          <li>
            <strong>Sletting:</strong> Du kan be om at opplysningene dine
            slettes. Du kan også slette kontoen din direkte i innstillingene.
          </li>
          <li>
            <strong>Dataportabilitet:</strong> Du kan be om å få utlevert
            opplysningene dine i et maskinlesbart format.
          </li>
          <li>
            <strong>Innsigelse:</strong> Du kan protestere mot behandling
            basert på berettiget interesse.
          </li>
          <li>
            <strong>Begrensning:</strong> Du kan be om at behandlingen begrenses
            i visse situasjoner.
          </li>
        </ul>
        <p>
          For å utøve dine rettigheter, kontakt oss på{" "}
          <a
            href="mailto:support@tuno.no"
            className="underline text-neutral-900 hover:text-[#46C185]"
          >
            support@tuno.no
          </a>
          . Vi svarer innen 30 dager.
        </p>
      </Section>

      <Section title="7. Informasjonskapsler (cookies)">
        <p>
          Tuno bruker kun nødvendige informasjonskapsler for autentisering og
          sesjonshåndtering. Vi bruker ikke analysecookies eller
          tredjepartscookies for sporing eller annonsering.
        </p>
        <p>
          Nødvendige cookies krever ikke samtykke i henhold til
          ekomloven § 2-7b.
        </p>
      </Section>

      <Section title="8. Sikkerhet">
        <p>
          Vi tar sikkerhet på alvor og bruker bransjestandarder for å beskytte
          dine data, inkludert kryptering i transit (TLS) og i ro, sikker
          autentisering, og tilgangskontroll med rad-nivå sikkerhet i databasen.
        </p>
      </Section>

      <Section title="9. Klage til Datatilsynet">
        <p>
          Dersom du mener at vi behandler personopplysningene dine i strid med
          regelverket, har du rett til å klage til Datatilsynet:
        </p>
        <p>
          Datatilsynet<br />
          Postboks 458 Sentrum, 0105 Oslo<br />
          Telefon: 22 39 69 00<br />
          E-post: postkasse@datatilsynet.no<br />
          Nettside:{" "}
          <a
            href="https://www.datatilsynet.no"
            target="_blank"
            rel="noopener noreferrer"
            className="underline text-neutral-900 hover:text-[#46C185]"
          >
            datatilsynet.no
          </a>
        </p>
      </Section>

      <Section title="10. Endringer">
        <p>
          Vi kan oppdatere denne personvernerklæringen ved behov. Ved vesentlige
          endringer vil vi varsle deg via e-post eller en melding i appen.
          Gjeldende versjon er alltid tilgjengelig på denne siden.
        </p>
      </Section>
    </LegalPageLayout>
  );
}
