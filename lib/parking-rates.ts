/**
 * Satstabell for inntektskalkulatoren (tuno.no/tjen) og pris-forslag i appen.
 *
 * TALLENE ER STARTSATSER og skal justeres med Kim etter hvert som ekte
 * bookinger gir fasit. Estimatene kommuniseres alltid som spenn, aldri som
 * garanti. Alt annet i kalkulatoren (områder, faktorer) leser herfra, så
 * justering er én fil.
 */

export interface ParkingArea {
  id: string;
  /** i18n-nøkkel under tjen.areas.* */
  nameKey: string;
  /** Dagsleie, kroner per dag (lavt-høyt). */
  dayNokLow: number;
  dayNokHigh: number;
  /** Fast månedsplass, kroner per måned (lavt-høyt). */
  monthNokLow: number;
  monthNokHigh: number;
}

export const PARKING_AREAS: ParkingArea[] = [
  { id: "asker-sentrum", nameKey: "areaAskerSentrum", dayNokLow: 60, dayNokHigh: 100, monthNokLow: 1000, monthNokHigh: 1600 },
  { id: "hvalstad-vakas", nameKey: "areaHvalstadVakas", dayNokLow: 50, dayNokHigh: 80, monthNokLow: 800, monthNokHigh: 1300 },
  { id: "holmen-billingstad", nameKey: "areaHolmenBillingstad", dayNokLow: 50, dayNokHigh: 80, monthNokLow: 800, monthNokHigh: 1300 },
  { id: "heggedal", nameKey: "areaHeggedal", dayNokLow: 40, dayNokHigh: 70, monthNokLow: 600, monthNokHigh: 1000 },
  { id: "vollen", nameKey: "areaVollen", dayNokLow: 40, dayNokHigh: 70, monthNokLow: 600, monthNokHigh: 1000 },
  { id: "annet-asker", nameKey: "areaAnnetAsker", dayNokLow: 35, dayNokHigh: 60, monthNokLow: 500, monthNokHigh: 900 },
];

export type SpotKind = "outdoor" | "carport" | "garage";

/** Plasstype-faktor på månedsestimatet. Garasje/carport prises høyere. */
export const SPOT_KIND_FACTOR: Record<SpotKind, number> = {
  outdoor: 1.0,
  carport: 1.1,
  garage: 1.3,
};

export type AvailabilityKind = "always" | "weekdays" | "weekends";

/**
 * Tilgjengelighets-faktor. «Kun hverdager» treffer pendler-markedet godt og
 * koster lite i verdi; «kun helg» er et smalt marked.
 */
export const AVAILABILITY_FACTOR: Record<AvailabilityKind, number> = {
  always: 1.0,
  weekdays: 0.8,
  weekends: 0.35,
};

export interface EarnEstimate {
  monthLow: number;
  monthHigh: number;
  dayLow: number;
  dayHigh: number;
}

/** Rund til nærmeste 50 kr så estimatet ikke later som det er presist. */
function roundTo50(value: number): number {
  return Math.max(0, Math.round(value / 50) * 50);
}

export function estimateEarnings(
  areaId: string,
  kind: SpotKind,
  availability: AvailabilityKind,
): EarnEstimate {
  const area = PARKING_AREAS.find((a) => a.id === areaId) ?? PARKING_AREAS[PARKING_AREAS.length - 1];
  const factor = SPOT_KIND_FACTOR[kind] * AVAILABILITY_FACTOR[availability];
  return {
    monthLow: roundTo50(area.monthNokLow * factor),
    monthHigh: roundTo50(area.monthNokHigh * factor),
    dayLow: Math.round(area.dayNokLow * SPOT_KIND_FACTOR[kind]),
    dayHigh: Math.round(area.dayNokHigh * SPOT_KIND_FACTOR[kind]),
  };
}
