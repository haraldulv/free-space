/** Avstand mellom to punkter i km (Haversine). */
export function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/** Formater avstand på en kompakt måte: "<100 m", "250 m", "2,3 km", "34 km". */
export function formatDistance(km: number, locale: string): string {
  const decimal = locale === "nb" || locale === "de" ? "," : ".";
  if (km < 0.1) return `<100 m`;
  if (km < 1) return `${Math.round(km * 1000)} m`;
  if (km < 10) return `${km.toFixed(1).replace(".", decimal)} km`;
  return `${Math.round(km)} km`;
}
