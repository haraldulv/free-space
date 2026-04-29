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
        /// Hourly-bånd: time 0..23 (inklusiv). NULL for weekend/season.
        let start_hour: Int?
        /// Hourly-bånd: time 1..24 (eksklusiv). NULL for weekend/season.
        let end_hour: Int?
        let price: Int
        /// Hvilken plass (SpotMarker.id) regelen gjelder. NULL = listing-wide.
        let spot_id: String?
    }

    struct Override: Codable, Identifiable, Hashable {
        var id: String { "\(listing_id):\(date):\(spot_id ?? "")" }
        let listing_id: String
        let date: String
        let price: Int
        /// Hvilken plass (SpotMarker.id) overstyringen gjelder. NULL = listing-wide.
        let spot_id: String?
    }

    private struct NewRule: Encodable {
        let listing_id: String
        let kind: String
        let day_mask: Int?
        let start_date: String?
        let end_date: String?
        let start_hour: Int?
        let end_hour: Int?
        let price: Int
        let spot_id: String?
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
                start_hour: nil,
                end_hour: nil,
                price: price,
                spot_id: nil,
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
            start_hour: nil,
            end_hour: nil,
            price: price,
            spot_id: nil,
        )
        try await supabase
            .from("listing_pricing_rules")
            .insert(rule)
            .execute()
    }

    /// Legg til et time-bånd for parkering per time.
    /// Et bånd treffer en booking-time hvis dagen er i `dayMask` OG `startHour <= time < endHour`.
    /// `startDate`/`endDate` (yyyy-MM-dd) avgrenser regelen til en spesifikk
    /// dato-rangen (typisk én ISO-uke). NIL = gjelder alle uker.
    /// `spotId` setter regelen som per-plass; NULL = listing-wide.
    static func addHourlyBandRule(
        listingId: String,
        dayMask: Int,
        startHour: Int,
        endHour: Int,
        price: Int,
        startDate: String? = nil,
        endDate: String? = nil,
        spotId: String? = nil
    ) async throws {
        let rule = NewRule(
            listing_id: listingId,
            kind: "hourly",
            day_mask: dayMask,
            start_date: startDate,
            end_date: endDate,
            start_hour: startHour,
            end_hour: endHour,
            price: price,
            spot_id: spotId,
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

    /// Sett override-pris for én dato. Nil/0 sletter eksisterende.
    /// `spotId` scoper override til en plass; NULL = listing-wide.
    static func setOverride(listingId: String, date: String, price: Int?, spotId: String? = nil) async throws {
        var deleteQuery = supabase
            .from("listing_pricing_overrides")
            .delete()
            .eq("listing_id", value: listingId)
            .eq("date", value: date)
        if let spotId {
            deleteQuery = deleteQuery.eq("spot_id", value: spotId)
        } else {
            deleteQuery = deleteQuery.is("spot_id", value: nil as Bool?)
        }
        try await deleteQuery.execute()

        if let price, price > 0 {
            struct NewOverride: Encodable {
                let listing_id: String
                let date: String
                let price: Int
                let spot_id: String?
            }
            try await supabase
                .from("listing_pricing_overrides")
                .insert(NewOverride(listing_id: listingId, date: date, price: price, spot_id: spotId))
                .execute()
        }
    }

    /// Sett override for mange datoer samtidig (upsert pattern — slett alle først, insert så).
    static func setOverrides(listingId: String, dates: [String], price: Int, spotId: String? = nil) async throws {
        guard !dates.isEmpty, price > 0 else { return }
        var deleteQuery = supabase
            .from("listing_pricing_overrides")
            .delete()
            .eq("listing_id", value: listingId)
            .in("date", values: dates)
        if let spotId {
            deleteQuery = deleteQuery.eq("spot_id", value: spotId)
        } else {
            deleteQuery = deleteQuery.is("spot_id", value: nil as Bool?)
        }
        try await deleteQuery.execute()

        struct NewOverride: Encodable {
            let listing_id: String
            let date: String
            let price: Int
            let spot_id: String?
        }
        let rows = dates.map { NewOverride(listing_id: listingId, date: $0, price: price, spot_id: spotId) }
        try await supabase
            .from("listing_pricing_overrides")
            .insert(rows)
            .execute()
    }

    /// Slett flere override på én gang.
    static func clearOverrides(listingId: String, dates: [String]) async throws {
        guard !dates.isEmpty else { return }
        try await supabase
            .from("listing_pricing_overrides")
            .delete()
            .eq("listing_id", value: listingId)
            .in("date", values: dates)
            .execute()
    }

    /// Hent alle overrides for et listing.
    static func fetchOverrides(listingId: String) async -> [Override] {
        do {
            let overrides: [Override] = try await supabase
                .from("listing_pricing_overrides")
                .select()
                .eq("listing_id", value: listingId)
                .execute()
                .value
            return overrides
        } catch {
            return []
        }
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

    // MARK: - Hourly pricing (parkering per time)

    /// Beregn per-time pris-breakdown for hourly bookings.
    /// Presedens: override (per dato) > hourly-bånd (matchende dag+time) > base hourly-pris.
    /// `start`/`end` tolkes som timestamps (samme dag forventes — multi-dags hourly er ikke i v1).
    static func hourlyPriceBreakdown(
        listingId: String,
        baseHourlyPrice: Int,
        start: Date,
        end: Date,
    ) async -> [HourlyPriceEntry] {
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
                .gte("date", value: format(start))
                .lte("date", value: format(end))
                .execute()
                .value
        } catch {
            overrides = []
        }

        return buildHourlyBreakdown(
            from: start,
            to: end,
            baseHourlyPrice: baseHourlyPrice,
            rules: rules,
            overrides: overrides,
        )
    }

    static func buildHourlyBreakdown(
        from start: Date,
        to end: Date,
        baseHourlyPrice: Int,
        rules: [Rule],
        overrides: [Override],
    ) -> [HourlyPriceEntry] {
        var result: [HourlyPriceEntry] = []
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current

        let isoTimestamp = ISO8601DateFormatter()
        isoTimestamp.timeZone = TimeZone(identifier: "Europe/Oslo")
        isoTimestamp.formatOptions = [.withInternetDateTime]

        var cursor = start
        while cursor < end {
            let dayKey = format(cursor)
            let hour = cal.component(.hour, from: cursor)
            let bit = weekdayBit(cursor)

            let entry = resolveHourly(
                cursor: cursor,
                hour: hour,
                bit: bit,
                dayKey: dayKey,
                baseHourlyPrice: baseHourlyPrice,
                rules: rules,
                overrides: overrides,
                isoTimestamp: isoTimestamp,
            )
            result.append(entry)

            guard let next = cal.date(byAdding: .hour, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private static func resolveHourly(
        cursor: Date,
        hour: Int,
        bit: Int,
        dayKey: String,
        baseHourlyPrice: Int,
        rules: [Rule],
        overrides: [Override],
        isoTimestamp: ISO8601DateFormatter,
    ) -> HourlyPriceEntry {
        let stamp = isoTimestamp.string(from: cursor)

        // 1) Override (per dato — gjelder hele dagen)
        if let o = overrides.first(where: { $0.date == dayKey }) {
            return HourlyPriceEntry(hourAt: stamp, price: o.price, source: "override")
        }

        // 2) Hourly-bånd: matchende dag-bit OG time i [start_hour, end_hour).
        // Uke-spesifikke regler (har start_date/end_date) vinner over default
        // når begge matcher samme tidspunkt — så drag-til-uke-overstyringer
        // virker som forventet.
        let matching = rules.filter { r in
            guard r.kind == "hourly",
                  let mask = r.day_mask,
                  let sh = r.start_hour,
                  let eh = r.end_hour else { return false }
            if let sd = r.start_date, dayKey < sd { return false }
            if let ed = r.end_date, dayKey > ed { return false }
            let dayMatches = (mask & (1 << bit)) != 0
            let hourMatches = hour >= sh && hour < eh
            return dayMatches && hourMatches
        }
        let sorted = matching.sorted { a, b in
            let aSpecific = (a.start_date != nil) || (a.end_date != nil)
            let bSpecific = (b.start_date != nil) || (b.end_date != nil)
            return aSpecific && !bSpecific
        }
        if let band = sorted.first {
            return HourlyPriceEntry(hourAt: stamp, price: band.price, source: "hourly")
        }

        // 3) Base
        return HourlyPriceEntry(hourAt: stamp, price: baseHourlyPrice, source: "base")
    }
}
