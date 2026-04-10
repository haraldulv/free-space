import type { Metadata } from "next";
import LegalPageLayout, {
  Section,
} from "@/components/ui/LegalPageLayout";

export const metadata: Metadata = {
  title: "Utleiervilkår | Tuno",
  description: "Handelsbetingelser for utleiere på Tuno — parkering og camping i Norge.",
};

export default function UtleiervilkarPage() {
  return (
    <LegalPageLayout title="Utleiervilkår" lastUpdated="10. april 2026">
      <p className="text-sm text-neutral-600 leading-relaxed">
        Disse vilkårene gjelder for deg som registrerer deg som utleier på Tuno.
        De kommer i tillegg til de generelle{" "}
        <a href="/vilkar" className="underline text-neutral-900 hover:text-[#46C185]">
          brukervilkårene
        </a>{" "}
        og{" "}
        <a href="/personvern" className="underline text-neutral-900 hover:text-[#46C185]">
          personvernerklæringen
        </a>
        .
      </p>

      <Section title="1. Krav til utleiere">
        <p>
          For å bli utleier på Tuno må du være minst 18 år og ha lovlig rett til
          å leie ut den aktuelle plassen (eier, leietaker med fremleierett, eller
          annen berettiget disposisjonsrett).
        </p>
        <p>
          Du må gjennomføre identitetsverifisering og registrere bankkonto for
          utbetalinger. Tuno forbeholder seg retten til å avvise utleiere som ikke
          oppfyller kravene.
        </p>
      </Section>

      <Section title="2. Stripe Connect og utbetalinger">
        <p>
          Tuno bruker Stripe som betalingspartner. Når du registrerer deg som
          utleier, opprettes en Stripe Connect-konto koblet til din
          Tuno-profil. Ved å fullføre registreringen godtar du også{" "}
          <a
            href="https://stripe.com/connect-account/legal/full"
            target="_blank"
            rel="noopener noreferrer"
            className="underline text-neutral-900 hover:text-[#46C185]"
          >
            Stripes tjenestevilkår for tilkoblede kontoer
          </a>
          .
        </p>
        <p>
          Utbetalinger skjer automatisk til din registrerte bankkonto etter at
          leietaker har sjekket inn. Tuno holder tilbake en plattformprovisjon
          før utbetaling.
        </p>
        <p>
          Ved avbestilling fra leietaker gjelder avbestillingsreglene i{" "}
          <a href="/vilkar" className="underline text-neutral-900 hover:text-[#46C185]">
            brukervilkårene
          </a>
          . Utbetaling som allerede er gjennomført kan bli reversert ved refusjon.
        </p>
      </Section>

      <Section title="3. Provisjon og gebyrer">
        <p>
          Tuno tar en plattformprovisjon fra utleiers inntekter for å dekke
          betalingsbehandling, plattformdrift og kundeservice. Provisjonen
          trekkes automatisk fra utbetalingen.
        </p>
        <p>
          Gjeldende provisjonssats vises i Tuno-appen under registrering som
          utleier. Tuno kan endre provisjonssatsen med 30 dagers varsel.
        </p>
      </Section>

      <Section title="4. Annonseinnhold og kvalitet">
        <p>
          Du er ansvarlig for at annonsene dine er nøyaktige, oppdaterte og
          følger våre{" "}
          <a href="/retningslinjer" className="underline text-neutral-900 hover:text-[#46C185]">
            retningslinjer for annonser
          </a>
          . Dette inkluderer:
        </p>
        <ul className="list-disc pl-5 space-y-1">
          <li>Korrekt beskrivelse av plassens egenskaper og begrensninger</li>
          <li>Oppdaterte og representative bilder</li>
          <li>Oppdatert tilgjengelighetskalender</li>
          <li>Korrekt prissetting</li>
        </ul>
        <p>
          Tuno kan deaktivere eller fjerne annonser som bryter retningslinjene
          eller mottar gjentatte negative tilbakemeldinger.
        </p>
      </Section>

      <Section title="5. Forsikring og ansvar">
        <p>
          Tuno tilbyr ikke forsikring for skade på eiendom eller kjøretøy.
          Utleier er selv ansvarlig for å ha tilstrekkelig forsikring for sin
          eiendom.
        </p>
        <p>
          Utleier er ansvarlig for at plassen er trygg å bruke og oppfyller
          gjeldende lover og forskrifter, inkludert plan- og bygningsloven,
          brannforskrifter og kommunale reguleringer.
        </p>
      </Section>

      <Section title="6. Kansellering fra utleier">
        <p>
          Du bør unngå å kansellere bekreftede bookinger. Gjentatte kanselleringer
          kan føre til at annonsen din rangeres lavere eller at kontoen din
          suspenderes.
        </p>
        <p>
          Ved kansellering fra deg refunderes leietaker fullt ut, inkludert
          servicetillegget.
        </p>
      </Section>

      <Section title="7. Skatt og avgifter">
        <p>
          Som utleier er du selv ansvarlig for å rapportere inntekter fra utleie
          til skattemyndighetene. Tuno rapporterer ikke automatisk til
          Skatteetaten på vegne av utleiere, men kan være forpliktet til å
          utlevere opplysninger ved forespørsel fra myndighetene.
        </p>
        <p>
          Utleieinntekter er skattepliktig inntekt. Vi anbefaler at du setter
          deg inn i gjeldende regler for beskatning av utleieinntekter, eller
          konsulterer en regnskapsfører.
        </p>
      </Section>

      <Section title="8. Oppsigelse">
        <p>
          Du kan når som helst avslutte som utleier ved å deaktivere eller slette
          annonsene dine. Eksisterende bookinger skal fullføres som avtalt.
        </p>
        <p>
          Tuno kan si opp avtalen med deg med umiddelbar virkning ved vesentlig
          brudd på disse vilkårene, svindel eller gjentatt dårlig oppførsel.
        </p>
      </Section>

      <Section title="9. Endringer">
        <p>
          Vi kan oppdatere utleiervilkårene med 30 dagers varsel. Fortsatt bruk
          av plattformen som utleier etter dette utgjør aksept av de oppdaterte
          vilkårene.
        </p>
      </Section>
    </LegalPageLayout>
  );
}
