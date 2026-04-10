import type { Metadata } from "next";
import LegalPageLayout, {
  Section,
} from "@/components/ui/LegalPageLayout";

export const metadata: Metadata = {
  title: "Brukervilkår | Tuno",
  description: "Brukervilkår for Tuno — markedsplass for parkering og camping i Norge.",
};

export default function VilkarPage() {
  return (
    <LegalPageLayout title="Brukervilkår" lastUpdated="10. april 2026">
      <Section title="1. Om Tuno og tjenesten">
        <p>
          Tuno er en norsk digital markedsplass som kobler utleiere av
          parkeringsplasser og campingplasser med personer som trenger et sted å
          parkere eller campe. Tjenesten drives av Tuno (org.nr. under
          registrering), heretter kalt &laquo;Tuno&raquo;, &laquo;vi&raquo;
          eller &laquo;oss&raquo;.
        </p>
        <p>
          Tuno er en formidlingsplattform. Vi er ikke part i avtalen mellom
          utleier og leietaker, og vi eier eller drifter ikke plassene som
          annonseres. Utleier er selv ansvarlig for at plassen oppfyller gjeldende
          lover og regler.
        </p>
      </Section>

      <Section title="2. Aksept av vilkår">
        <p>
          Ved å opprette en konto på Tuno godtar du disse brukervilkårene og vår{" "}
          <a href="/personvern" className="underline text-neutral-900 hover:text-[#46C185]">
            personvernerklæring
          </a>
          . Dersom du ikke godtar vilkårene, skal du ikke bruke tjenesten.
        </p>
        <p>
          For utleiere gjelder i tillegg egne{" "}
          <a href="/utleiervilkar" className="underline text-neutral-900 hover:text-[#46C185]">
            utleiervilkår
          </a>{" "}
          og{" "}
          <a href="/retningslinjer" className="underline text-neutral-900 hover:text-[#46C185]">
            retningslinjer for annonser
          </a>
          .
        </p>
      </Section>

      <Section title="3. Registrering og konto">
        <p>
          Du må være minst 18 år for å opprette konto. Du er ansvarlig for å
          oppgi korrekt informasjon og holde påloggingsdetaljene dine
          konfidensielle. All aktivitet på kontoen din er ditt ansvar.
        </p>
        <p>
          Vi forbeholder oss retten til å suspendere eller slette kontoer som
          bryter disse vilkårene, eller som brukes til svindel, trakassering eller
          annen uakseptabel oppførsel.
        </p>
      </Section>

      <Section title="4. Bruk av plattformen">
        <p>
          <strong>Som leietaker</strong> kan du søke etter og booke
          parkeringsplasser og campingplasser. En booking er en bindende avtale
          mellom deg og utleieren. Du forplikter deg til å bruke plassen i henhold
          til annonsebeskrivelsen og utleierens instruksjoner.
        </p>
        <p>
          <strong>Som utleier</strong> forplikter du deg til å gi korrekt
          informasjon om plassen, holde kalenderen oppdatert, og stille plassen
          til disposisjon som avtalt. Se{" "}
          <a href="/utleiervilkar" className="underline text-neutral-900 hover:text-[#46C185]">
            utleiervilkårene
          </a>{" "}
          for fullstendige betingelser.
        </p>
      </Section>

      <Section title="5. Betalinger og gebyrer">
        <p>
          Alle betalinger håndteres gjennom vår betalingspartner Stripe. Tuno
          tar et servicetillegg på leietakers betaling for å dekke
          plattformkostnader. Det nøyaktige beløpet vises alltid før du
          bekrefter en booking.
        </p>
        <p>
          Utbetalinger til utleiere skjer automatisk via Stripe Connect til den
          bankkontoen utleier har registrert. Tuno holder tilbake en
          plattformprovisjon fra utbetalingen.
        </p>
        <p>
          Alle priser på plattformen er oppgitt i norske kroner (NOK) og
          inkluderer merverdiavgift der dette er påkrevd.
        </p>
      </Section>

      <Section title="6. Avbestilling og refusjon">
        <p>
          Leietaker kan avbestille en booking. Dersom avbestillingen skjer mer enn
          24 timer før innsjekk, refunderes hele beløpet fratrukket
          servicetillegget. Ved avbestilling under 24 timer før innsjekk,
          refunderes 50 % av leiebeløpet.
        </p>
        <p>
          Utleier kan kansellere en booking ved ekstraordinære omstendigheter.
          Ved kansellering fra utleier refunderes leietaker fullt ut, inkludert
          servicetillegget.
        </p>
      </Section>

      <Section title="7. Brukerens ansvar">
        <p>Du forplikter deg til å:</p>
        <ul className="list-disc pl-5 space-y-1">
          <li>Oppgi korrekt og oppdatert informasjon</li>
          <li>Ikke bruke plattformen til ulovlige formål</li>
          <li>Respektere andres eiendom og følge utleierens regler</li>
          <li>Ikke omgå betalingssystemet ved å avtale betaling utenfor Tuno</li>
          <li>Ikke publisere støtende, diskriminerende eller villedende innhold</li>
        </ul>
      </Section>

      <Section title="8. Immaterielle rettigheter">
        <p>
          Alt innhold, design, logoer og programvare tilhørende Tuno er beskyttet
          av opphavsrett og andre immaterielle rettigheter. Du får en begrenset,
          ikke-eksklusiv rett til å bruke plattformen i henhold til disse
          vilkårene.
        </p>
        <p>
          Innhold du laster opp (bilder, tekst, beskrivelser) forblir ditt, men
          du gir Tuno en vederlagsfri lisens til å bruke det i forbindelse med
          driften av plattformen.
        </p>
      </Section>

      <Section title="9. Ansvarsbegrensning">
        <p>
          Tuno er en formidlingsplattform og er ikke ansvarlig for handlinger
          eller unnlatelser fra utleiere eller leietakere. Vi garanterer ikke
          kvaliteten, sikkerheten eller lovligheten til annonserte plasser.
        </p>
        <p>
          Tuno er ikke ansvarlig for indirekte tap, følgeskader eller tapt
          fortjeneste som oppstår ved bruk av plattformen. Vårt samlede ansvar er
          begrenset til beløpet du har betalt gjennom plattformen de siste 12
          månedene.
        </p>
      </Section>

      <Section title="10. Endringer i vilkårene">
        <p>
          Vi kan oppdatere disse vilkårene fra tid til annen. Ved vesentlige
          endringer vil vi varsle deg via e-post eller en melding i appen.
          Fortsatt bruk av tjenesten etter slike endringer utgjør aksept av de
          oppdaterte vilkårene.
        </p>
      </Section>

      <Section title="11. Tvister og lovvalg">
        <p>
          Disse vilkårene er underlagt norsk lov. Eventuelle tvister skal først
          forsøkes løst i minnelighet. Dersom dette ikke fører frem, kan tvisten
          bringes inn for de ordinære norske domstolene med Oslo tingrett som
          verneting.
        </p>
      </Section>

      <Section title="12. Kontakt">
        <p>
          Har du spørsmål om disse vilkårene, kan du kontakte oss på{" "}
          <a
            href="mailto:support@tuno.no"
            className="underline text-neutral-900 hover:text-[#46C185]"
          >
            support@tuno.no
          </a>
          .
        </p>
      </Section>
    </LegalPageLayout>
  );
}
