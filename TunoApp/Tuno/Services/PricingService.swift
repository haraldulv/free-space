import Foundation

/// Klient-side pricing-engine som speiler server-logikken i lib/pricing.ts.
/// Presedens: override > sesong > helg > base.
/// Brukes i BookingView for korrekt preview før booking faktisk opprettes —
/// server rekalkulerer autoritativt og lagrer snapshot ved insert.
enum PricingService {
    struct Rule: Decodable {
        let id: String
        let listing_id: String
        let kind: String
        let day_mask: Int?
        let start_date: String?
        let end_date: String?
        let price: Int
    }

    struct Override: Decodable {
        let listing_id: String
        let date: String
        let price: Int
    }

    /// Helg-maske: fredag (bit 4), lørdag (bit 5), søndag (bit 6).
    static let weekendDayMask = (1 << 4) | (1 << 5) | (1 << 6)

    /// ISO weekday bit-index (Mandag=0 ... Søndag=6).
    private static func weekdayBit(_ date: Date) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        let wd = cal.component(.weekday, from: date)  // søn=1 ... lør=7
        return wd == 1 ? 6 : wd - 2
    }

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func parse(_ s: String) -> Date? {
        isoFormatter.date(from: s)
    }

    private static func format(_ d: Date) -> String {
        isoFormatter.string(from: d)
    }

    /// Beregn per-natt pris-breakdown. Kaller Supabase for regler + overrides.
    static func nightlyPrices(
        listingId: String,
        basePrice: Int,
        checkIn: Date,
        checkOut: Date,
    ) async -> [NightlyPriceEntry] {
        let rules: [Rule]
        let overrides: [Override]
        do {
            rules = try await supabase
                .from("listing_pricing_rules")
                .select()
                .eq("listing_id", value: listingId)
                .execute()
                .value
        } catch {
            rules = []
        }
        do {
            overrides = try await supabase
                .from("listing_pricing_overrides")
                .select()
                .eq("listing_id", value: listingId)
                .gte("date", value: format(checkIn))
                .lt("date", value: format(checkOut))
                .execute()
                .value
        } catch {
            overrides = []
        }

        return buildBreakdown(
            from: checkIn,
            to: checkOut,
            basePrice: basePrice,
            rules: rules,
            overrides: overrides,
        )
    }

    static func buildBreakdown(
        from checkIn: Date,
        to checkOut: Date,
        basePrice: Int,
        rules: [Rule],
        overrides: [Override],
    ) -> [NightlyPriceEntry] {
        var result: [NightlyPriceEntry] = []
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        var cursor = cal.startOfDay(for: checkIn)
        let end = cal.startOfDay(for: checkOut)

        while cursor < end {
            let iso = format(cursor)
            result.append(resolve(
                date: cursor,
                iso: iso,
                basePrice: basePrice,
                rules: rules,
                overrides: overrides,
            ))
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private static func resolve(
        date: Date,
        iso: String,
        basePrice: Int,
        rules: [Rule],
        overrides: [Override],
    ) -> NightlyPriceEntry {
        // 1) Override
        if let o = overrides.first(where: { $0.date == iso }) {
            return NightlyPriceEntry(date: iso, price: o.price, source: "override")
        }
        // 2) Sesong
        if let s = rules.first(where: { r in
            guard r.kind == "season",
                  let start = r.start_date, let end = r.end_date else { return false }
            return iso >= start && iso <= end
        }) {
            return NightlyPriceEntry(date: iso, price: s.price, source: "season")
        }
        // 3) Helg (dag-maske)
        let bit = weekdayBit(date)
        if let w = rules.first(where: { r in
            r.kind == "weekend" && ((r.day_mask ?? 0) & (1 << bit)) != 0
        }) {
            return NightlyPriceEntry(date: iso, price: w.price, source: "weekend")
        }
        // 4) Base
        return NightlyPriceEntry(date: iso, price: basePrice, source: "base")
    }
}
