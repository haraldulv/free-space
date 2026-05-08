import Foundation

/// Speil av lib/opening-hours.ts. Beregner effektive åpningstider og sjekker
/// overlap mot bookingsdatoer. Stateless utility — ingen dependencies utover
/// Models.swift.
enum OpeningHoursService {

    /// Returner effektiv åpningstid for én plass — spot.openingHours overstyrer listing-nivå.
    static func effective(listing: Listing, spot: SpotMarker?) -> OpeningHours? {
        if let spotHours = spot?.openingHours { return spotHours }
        return listing.openingHours
    }

    /// True hvis åpningstidene begrenser til mindre enn 24/7.
    static func hasLimitedHours(_ oh: OpeningHours?) -> Bool {
        guard let oh else { return false }
        for day in Weekday.allCases {
            let v = oh.value(for: day)
            if v == nil { return true } // stengt en dag
            if v != "00:00-23:59" && v != "00:00-24:00" { return true }
        }
        return false
    }

    /// True hvis listing/spot er åpen på datoen (helt eller delvis).
    /// `overrides` (per-dato) trumfer ukedags-åpningstider hvis satt for samme dato.
    static func isOpen(
        _ oh: OpeningHours?,
        on date: Date,
        overrides: [String: DayOpeningOverride]? = nil
    ) -> Bool {
        // 1) Per-dato overstyring trumfer alt annet
        if let overrides {
            let iso = isoDateString(date)
            if let ov = overrides[iso] {
                if ov.isClosed { return false }
                if let _ = ov.open { return true }
            }
        }
        // 2) Ukedags-default
        guard let oh else { return true } // ingen begrensning = døgnåpent
        let cal = Calendar(identifier: .iso8601)
        let comp = cal.component(.weekday, from: date)
        let day = Weekday.from(weekdayComponent: comp)
        return oh.value(for: day) != nil
    }

    /// Sjekk om alle dager i datoperioden (checkIn inklusiv, checkOut eksklusiv) er åpne.
    static func isOpenForRange(
        _ oh: OpeningHours?,
        checkIn: Date,
        checkOut: Date,
        overrides: [String: DayOpeningOverride]? = nil
    ) -> Bool {
        // Hvis ingen åpningstid OG ingen overrides → døgnåpent
        if oh == nil && (overrides?.isEmpty ?? true) { return true }
        var cursor = Calendar.current.startOfDay(for: checkIn)
        let end = Calendar.current.startOfDay(for: checkOut)
        while cursor < end {
            if !isOpen(oh, on: cursor, overrides: overrides) { return false }
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }
        return true
    }

    /// Returnerer effektiv åpningstid for en gitt dato — overstyringen tar
    /// presedens over ukedags-default.
    static func effectiveTime(
        _ oh: OpeningHours?,
        on date: Date,
        overrides: [String: DayOpeningOverride]? = nil
    ) -> String? {
        if let overrides {
            let iso = isoDateString(date)
            if let ov = overrides[iso] {
                if ov.isClosed { return nil }
                if let t = ov.open { return t }
            }
        }
        guard let oh else { return "00:00-24:00" } // døgnåpent
        let cal = Calendar(identifier: .iso8601)
        let comp = cal.component(.weekday, from: date)
        let day = Weekday.from(weekdayComponent: comp)
        return oh.value(for: day)
    }

    private static func isoDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        return f.string(from: date)
    }

    /// Parser "HH:MM-HH:MM" til (start, end) minutter siden midnatt.
    static func parseRange(_ s: String) -> (start: Int, end: Int)? {
        let parts = s.split(separator: "-")
        guard parts.count == 2 else { return nil }
        guard let start = parseTime(String(parts[0])), let end = parseTime(String(parts[1])) else { return nil }
        if end <= start { return nil }
        return (start, end)
    }

    static func parseTime(_ t: String) -> Int? {
        let parts = t.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), (0...23).contains(h),
              let m = Int(parts[1]), (0...59).contains(m) else { return nil }
        return h * 60 + m
    }

    static func formatTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%02d:%02d", h, m)
    }

    /// Kompakt label for søkekort/ikoner. Eks:
    /// - nil → "Hele dagen" (ingen åpningstid satt = ledig hele dagen)
    /// - alle åpne dager 9-17, helg stengt → "9-17"
    /// - 24/7 hver dag → "Hele dagen"
    /// - varierende tider → "Begrenset"
    /// - alle dager stengt → "Stengt"
    static func compactLabel(_ oh: OpeningHours?) -> String? {
        guard let oh else { return "Hele dagen" }
        var ranges: Set<String> = []
        var anyOpen = false
        for day in Weekday.allCases {
            if let raw = oh.value(for: day) {
                ranges.insert(raw)
                anyOpen = true
            }
        }
        guard anyOpen else { return "Stengt" }
        if ranges.count == 1, let only = ranges.first,
           let parsed = parseRange(only) {
            // 24/7 hver dag — vises som "Hele dagen" siden parkering er per dag
            if parsed.start == 0 && parsed.end >= 23 * 60 + 59 { return "Hele dagen" }
            let startH = parsed.start / 60
            let endH = parsed.end / 60
            return "\(startH)-\(endH)"
        }
        return "Begrenset"
    }
}
