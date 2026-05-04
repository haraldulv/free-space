import Foundation

/// Et åpningstid- eller pris-bånd redusert til det som trengs for overlap-sjekk:
/// 7-bits ukedags-maske + start/slutt i minutter siden midnatt (0…1440).
/// Brukes til å avvise nye bånd som krasjer med eksisterende — overlapp kan
/// forvirre prising og bookings.
struct BandRange: Hashable {
    let dayMask: Int
    let startMinutes: Int
    let endMinutes: Int
    /// Valgfri label vist i feilmelding ("Hverdager kveld", "Mandag 09:00–17:00").
    let label: String?

    init(dayMask: Int, startMinutes: Int, endMinutes: Int, label: String? = nil) {
        self.dayMask = dayMask
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.label = label
    }
}

enum BandOverlap {
    /// To bånd overlapper hvis de deler minst én ukedag OG tidsintervallene
    /// krysser hverandre (halvåpne intervaller [start, end)). Kryss-midnatt
    /// støttes ikke i dagens UI (sheet sikrer end > start).
    static func overlaps(_ a: BandRange, _ b: BandRange) -> Bool {
        if (a.dayMask & b.dayMask) == 0 { return false }
        return a.startMinutes < b.endMinutes && b.startMinutes < a.endMinutes
    }

    /// Returnerer første eksisterende bånd som krasjer med `candidate`, eller
    /// nil hvis ingen overlapp.
    static func firstConflict(for candidate: BandRange, in existing: [BandRange]) -> BandRange? {
        existing.first { overlaps(candidate, $0) }
    }
}
