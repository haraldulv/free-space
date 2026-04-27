import VerifiedClient from "./VerifiedClient";

/**
 * Server-rendret skjell for verifiseringssiden. Viser "E-posten er bekreftet"
 * som statisk HTML så brukeren får umiddelbar feedback selv om JS ikke kjører.
 *
 * Klient-komponenten over-rendrer med tokens fra hash-fragmentet og prøver
 * å åpne native-appen via custom scheme (siden Universal Links ikke trigges
 * pålitelig fra Chrome eller andre tredjeparts-browsere på iOS).
 */
export default function VerifiedPage() {
  return <VerifiedClient />;
}
