import Foundation

/// Sentralisert kalender-helper med timezone-safe dato-strenger.
/// Tidligere kalender-implementasjoner brukte DateFormatter uten timeZone-config,
/// som ga off-by-one bugs (datoer kunne hoppe en dag i visse tidssoner).
/// All host-kalender-kode bør gå gjennom dette laget.
enum TunoCalendar {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    static func dateKey(_ date: Date) -> String { formatter.string(from: date) }
    static func date(from key: String) -> Date? { formatter.date(from: key) }
    static func todayKey() -> String { dateKey(Date()) }

    static func dateKey(daysAgo n: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: -n, to: Date()) ?? Date()
        return dateKey(d)
    }

    static func nightsBetween(_ a: String, _ b: String) -> Int? {
        guard let da = date(from: a), let db = date(from: b) else { return nil }
        let comps = Calendar.current.dateComponents([.day], from: da, to: db)
        return comps.day
    }

    /// Alle dagnøkler fra `from` til og med `through` (inklusiv begge).
    /// Parkering teller dager inklusivt: man-ons = 3 nøkler.
    static func dateKeys(from: String, through: String) -> [String] {
        guard var cursor = date(from: from), let end = date(from: through) else { return [] }
        var keys: [String] = []
        while cursor <= end {
            keys.append(dateKey(cursor))
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return keys
    }

    /// Komprimerer en (usortert) dagliste til sammenhengende perioder, for
    /// visning («3.–5. mar, 10.–12. mar») og kalenderpiller. Multi-velg-
    /// bookinger har hull; hver sammenhengende kjøring blir ett element.
    static func runs(_ keys: [String]) -> [(start: String, end: String)] {
        let sorted = Set(keys).sorted()
        guard !sorted.isEmpty else { return [] }
        var result: [(start: String, end: String)] = []
        var runStart = sorted[0]
        var prev = sorted[0]
        for key in sorted.dropFirst() {
            if let prevDate = date(from: prev),
               let next = Calendar.current.date(byAdding: .day, value: 1, to: prevDate),
               dateKey(next) == key {
                prev = key
            } else {
                result.append((start: runStart, end: prev))
                runStart = key
                prev = key
            }
        }
        result.append((start: runStart, end: prev))
        return result
    }
}
