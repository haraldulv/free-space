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
}
