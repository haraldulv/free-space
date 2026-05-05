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
    static func isOpen(_ oh: OpeningHours?, on date: Date) -> Bool {
        guard let oh else { return true } // ingen begrensning = døgnåpent
        let cal = Calendar(identifier: .iso8601)
        let comp = cal.component(.weekday, from: date)
        let day = Weekday.from(weekdayComponent: comp)
        return oh.value(for: day) != nil
    }

    /// Sjekk om alle dager i datoperioden (checkIn inklusiv, checkOut eksklusiv) er åpne.
    static func isOpenForRange(_ oh: OpeningHours?, checkIn: Date, checkOut: Date) -> Bool {
        guard let oh else { return true }
        var cursor = Calendar.current.startOfDay(for: checkIn)
        let end = Calendar.current.startOfDay(for: checkOut)
        while cursor < end {
            if !isOpen(oh, on: cursor) { return false }
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }
        return true
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
}
