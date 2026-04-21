import Foundation

/// Klient-side pricing-engine som speiler server-logikken i lib/pricing.ts.
/// Presedens: override > sesong > helg > base.
/// Brukes i BookingView for korrekt preview før booking faktisk opprettes —
/// server rekalkulerer autoritativt og lagrer snapshot ved insert.
enum PricingService {
    struct Rule: Codable, Identifiable, Hashable {
        let id: String
        let listing_id: String
        let kind: String
        let day_mask: Int?
        let start_date: String?
        let end_date: String?
        let price: Int
    }

    struct Override: Codable, Identifiable, Hashable {
        var id: String { "\(listing_id):\(date)" }
        let listing_id: String
        let date: String
        let price: Int
    }

    private struct NewRule: Encodable {
        let listing_id: String
        let kind: String
        let day_mask: Int?
        let start_date: String?
        let end_date: String?
        let price: Int
    }

    // MARK: - CRUD mot regler

    /// Sett helg-pris (null sletter eksisterende regel).
    /// Kun én helg-regel per listing tillatt — eksisterende slettes først.
    static func setWeekendPrice(listingId: String, price: Int?) async throws {
        try await supabase
            .from("listing_pricing_rules")
            .delete()
            .eq("listing_id", value: listingId)
            .eq("kind", value: "weekend")
            .execute()

        if let price, price > 0 {
            let rule = NewRule(
                listing_id: listingId,
                kind: "weekend",
                day_mask: weekendDayMask,
                start_date: nil,
                end_date: nil,
                price: price,
            )
            try await supabase
                .from("listing_pricing_rules")
                .insert(rule)
                .execute()
        }
    }

    /// Legg til en sesong-regel.
    static func addSeasonRule(
        listingId: String,
        startDate: String,
        endDate: String,
        price: Int,
    ) async throws {
        let rule = NewRule(
            listing_id: listingId,
            kind: "season",
            day_mask: nil,
            start_date: startDate,
            end_date: endDate,
            price: price,
        )
        try await supabase
            .from("listing_pricing_rules")
            .insert(rule)
            .execute()
    }

    /// Slett en regel ved id.
    static func removeRule(ruleId: String) async throws {
        try await supabase
            .from("listing_pricing_rules")
            .delete()
            .eq("id", value: ruleId)
            .execute()
    }

    /// Hent alle regler for et listing.
    static func fetchRules(listingId: String) async -> [Rule] {
        do {
            let rules: [Rule] = try await supabase
                .from("listing_pricing_rules")
                .select()
                .eq("listing_id", value: listingId)
                .execute()
                .value
            return rules
        } catch {
            return []
        }
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
