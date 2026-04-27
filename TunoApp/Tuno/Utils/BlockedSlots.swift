import Foundation

/// Hjelper for å håndtere parkering- vs camping-blokkering i samme JSONB-felt.
///
/// `blocked_dates` lagrer to formater:
/// - `"yyyy-MM-dd"` — hele dag blokkert (camping + parkering hele dag)
/// - `"yyyy-MM-dd HH"` — én time blokkert (kun parkering)
///
/// Helper'en parser strenger til typed slots og tilbake.
enum BlockedSlot: Hashable {
    case fullDay(date: String)        // "yyyy-MM-dd"
    case hour(date: String, hour: Int) // "yyyy-MM-dd", 0-23

    /// Encoded tilbake til den strengen som lagres i blocked_dates.
    var encoded: String {
        switch self {
        case .fullDay(let date): return date
        case .hour(let date, let hour): return String(format: "%@ %02d", date, hour)
        }
    }

    /// Parse én streng. Format avgjøres av lengden:
    /// 10 tegn = "yyyy-MM-dd" (full dag), 13 tegn = "yyyy-MM-dd HH" (time).
    static func parse(_ raw: String) -> BlockedSlot? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.count == 10 {
            return .fullDay(date: trimmed)
        }
        if trimmed.count == 13 {
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2,
                  let hour = Int(parts[1]),
                  hour >= 0, hour <= 23 else { return nil }
            return .hour(date: String(parts[0]), hour: hour)
        }
        return nil
    }
}

extension Set where Element == String {
    /// Returner alle blokkerte timer for en gitt dato — både eksplisitt blokkerte
    /// timer OG implisitt (hvis hele dagen er blokkert, regnes alle 24 timer som blokkert).
    func blockedHours(on date: String) -> Set<Int> {
        if contains(date) { return Set<Int>(0..<24) }
        var hours: Set<Int> = []
        for raw in self {
            if case .hour(let d, let h) = BlockedSlot.parse(raw), d == date {
                hours.insert(h)
            }
        }
        return hours
    }

    /// Er denne dagen blokkert som en HEL dag (ikke bare timer)?
    func isFullDayBlocked(_ date: String) -> Bool { contains(date) }

    /// Toggle hele dagen blokkert/åpen. Hvis åpning, fjern også eventuelle time-blokker.
    mutating func toggleFullDay(_ date: String) {
        if contains(date) {
            remove(date)
        } else {
            insert(date)
            // Konsolider — fjern eventuelle time-blokker for samme dag siden hele dagen er blokk uansett
            self = filter { raw in
                if case .hour(let d, _) = BlockedSlot.parse(raw), d == date { return false }
                return true
            }
        }
    }

    /// Toggle én time blokkert/åpen. Hvis full-dag-blokk finnes, gjør først om til 23 time-blokker.
    mutating func toggleHour(date: String, hour: Int) {
        if contains(date) {
            // Konvertér full-dag → 24 time-blokker, deretter fjern den targetede
            remove(date)
            for h in 0..<24 where h != hour {
                insert(BlockedSlot.hour(date: date, hour: h).encoded)
            }
            return
        }
        let key = BlockedSlot.hour(date: date, hour: hour).encoded
        if contains(key) {
            remove(key)
        } else {
            insert(key)
        }
    }

    /// Blokkér en range av timer. Brukes av quick-actions ("Blokker arbeidstid 08-17").
    mutating func blockHourRange(date: String, from: Int, through: Int) {
        for h in from...through {
            insert(BlockedSlot.hour(date: date, hour: h).encoded)
        }
    }

    /// Fjern alle blokkeringer for en gitt dato (full dag + alle timer).
    mutating func clearDate(_ date: String) {
        remove(date)
        self = filter { raw in
            if case .hour(let d, _) = BlockedSlot.parse(raw), d == date { return false }
            return true
        }
    }
}
