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
        /// Hourly-bånd: minutt 0 eller 30. Default 0.
        let start_minute: Int?
        /// Hourly-bånd: minutt 0 eller 30. Default 0.
        let end_minute: Int?
        let price: Int
        /// Hvilken plass (SpotMarker.id) regelen gjelder. NULL = listing-wide.
        let spot_id: String?
        /// Utleier-valgt farge-indeks (0-4). NULL = derives fra id-hash.
        let color_index: Int?
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
        let start_minute: Int
        let end_minute: Int
        let price: Int
        let spot_id: String?
        let color_index: Int?
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
                start_minute: 0,
                end_minute: 0,
                price: price,
                spot_id: nil,
                color_index: nil,
            )
            try await supabase
                .from("listing_pricing_rules")
                .insert(rule)
                .execute()
        }
    }

    /// Legg til en sesong-regel (legacy — behold for bakoverkompatibilitet).
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
            start_minute: 0,
            end_minute: 0,
            price: price,
            spot_id: nil,
            color_index: nil,
        )
        try await supabase
            .from("listing_pricing_rules")
            .insert(rule)
            .execute()
    }

    /// Legg til et camping-sesongbånd (per natt). Båndet treffer en natt hvis
    /// datoen er innenfor [startDate, endDate] OG ukedagen er i `dayMask`.
    /// `dayMask` = 0 betyr alle ukedager (server tolker 0 som "ingen filter").
    /// `spotId` = NULL er listing-wide; ellers per-plass.
    static func addSeasonBandRule(
        listingId: String,
        dayMask: Int,
        startDate: String,
        endDate: String,
        price: Int,
        spotId: String? = nil,
        colorIndex: Int? = nil
    ) async throws {
        let rule = NewRule(
            listing_id: listingId,
            kind: "season",
            day_mask: dayMask,
            start_date: startDate,
            end_date: endDate,
            start_hour: nil,
            end_hour: nil,
            start_minute: 0,
            end_minute: 0,
            price: price,
            spot_id: spotId,
            color_index: colorIndex,
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
        startMinute: Int = 0,
        endHour: Int,
        endMinute: Int = 0,
        price: Int,
        startDate: String? = nil,
        endDate: String? = nil,
        spotId: String? = nil,
        colorIndex: Int? = nil
    ) async throws {
        let rule = NewRule(
            listing_id: listingId,
            kind: "hourly",
            day_mask: dayMask,
            start_date: startDate,
            end_date: endDate,
            start_hour: startHour,
            end_hour: endHour,
            start_minute: startMinute,
            end_minute: endMinute,
            price: price,
            spot_id: spotId,
            color_index: colorIndex,
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

    // MARK: - Load/Save WizardSpotAvailability (per-spot)
    //
    // Brukes av Profile-kalenderen for å gjenbruke wizardens bånd-editor.
    // Lagring er delete-all-for-spot + reinsert. Det er enklere enn diff-
    // basert oppdatering og rules-volumet per spot er lite.

    /// Last alle bånd + overrides for én plass og oversett til
    /// WizardSpotAvailability slik wizardens bånd-editor forventer.
    static func loadAvailability(listingId: String, spotId: String) async -> WizardSpotAvailability {
        var avail = WizardSpotAvailability()
        avail.alwaysAvailable = false

        let hourlyRules = await fetchRulesForSpot(listingId: listingId, spotId: spotId, kind: "hourly")
        let seasonRules = await fetchRulesForSpot(listingId: listingId, spotId: spotId, kind: "season")
        let overrides = await fetchOverridesForSpot(listingId: listingId, spotId: spotId)

        var bands: [WizardPricingBand] = []
        var overridesPerBand: [UUID: [WizardBandPriceOverride]] = [:]

        // 1) Hourly default-bånd (start_date == nil)
        for rule in hourlyRules where rule.start_date == nil && rule.end_date == nil {
            guard let startHour = rule.start_hour, let endHour = rule.end_hour else { continue }
            let band = WizardPricingBand(
                dayMask: rule.day_mask ?? 0,
                startHour: startHour,
                startMinute: rule.start_minute ?? 0,
                endHour: endHour,
                endMinute: rule.end_minute ?? 0,
                price: rule.price,
                weekScope: .allWeeks,
                colorIndex: rule.color_index
            )
            bands.append(band)
        }

        // 2) Hourly override-rader (med start_date) → bandPriceOverrides
        for rule in hourlyRules where rule.start_date != nil || rule.end_date != nil {
            guard let startHour = rule.start_hour, let endHour = rule.end_hour else { continue }
            let dayMask = rule.day_mask ?? 0
            let startMinute = rule.start_minute ?? 0
            let endMinute = rule.end_minute ?? 0
            guard let band = bands.first(where: {
                $0.dayMask == dayMask
                && $0.startHour == startHour
                && $0.startMinute == startMinute
                && $0.endHour == endHour
                && $0.endMinute == endMinute
            }) else { continue }

            let scope: WeekScope
            if let s = rule.start_date, let _ = rule.end_date,
               let week = isoWeekFromRange(start: s) {
                scope = .specificWeeks([week])
            } else {
                scope = .allWeeks
            }

            let override = WizardBandPriceOverride(bandId: band.id, weekScope: scope, price: rule.price)
            overridesPerBand[band.id, default: []].append(override)
        }

        // 3) Sesong-bånd (camping) — én WizardPricingBand per season-rule
        for rule in seasonRules {
            guard let bStart = rule.start_date, let bEnd = rule.end_date else { continue }
            let band = WizardPricingBand(
                dayMask: rule.day_mask ?? 0,
                startHour: 0,
                startMinute: 0,
                endHour: 24,
                endMinute: 0,
                price: rule.price,
                weekScope: .allWeeks,
                colorIndex: rule.color_index,
                startDate: bStart,
                endDate: bEnd
            )
            bands.append(band)
        }

        avail.bands = bands
        avail.bandPriceOverrides = overridesPerBand.values.flatMap { $0 }

        avail.dateOverrides = overrides.map {
            WizardDateOverride(date: $0.date, price: $0.price)
        }
        return avail
    }

    /// Slett alle bånd + overrides for én plass, og persisterer det nye
    /// settet. Kalles fra Profile-kalenderen ved save.
    @MainActor
    static func saveAvailability(
        listingId: String,
        spotId: String,
        _ avail: WizardSpotAvailability,
        basePerHour: Int
    ) async throws {
        // 1) Slett eksisterende hourly + season rules for spotId.
        try await supabase
            .from("listing_pricing_rules")
            .delete()
            .eq("listing_id", value: listingId)
            .eq("spot_id", value: spotId)
            .in("kind", values: ["hourly", "season"])
            .execute()

        // 2) Slett eksisterende overrides for spotId.
        try await supabase
            .from("listing_pricing_overrides")
            .delete()
            .eq("listing_id", value: listingId)
            .eq("spot_id", value: spotId)
            .execute()

        // 3) Re-insert: default-bånd-rader (hourly OG seasonal).
        for band in avail.bands {
            let bandBasePrice = band.price > 0 ? band.price : basePerHour
            if band.isSeasonal, let bStart = band.startDate, let bEnd = band.endDate {
                // Send dayMask=0 (alle dager) i stedet for NULL — unngår
                // avhengighet til migration-pricing-rules-seasonal.sql.
                try? await addSeasonBandRule(
                    listingId: listingId,
                    dayMask: band.dayMask,
                    startDate: bStart,
                    endDate: bEnd,
                    price: bandBasePrice,
                    spotId: spotId,
                    colorIndex: band.colorIndex
                )
            } else {
                try? await addHourlyBandRule(
                    listingId: listingId,
                    dayMask: band.dayMask,
                    startHour: band.startHour,
                    startMinute: band.startMinute,
                    endHour: band.endHour,
                    endMinute: band.endMinute,
                    price: bandBasePrice,
                    startDate: nil,
                    endDate: nil,
                    spotId: spotId,
                    colorIndex: band.colorIndex
                )
            }
        }

        // 4) Override-bånd-rader (per uke i scope).
        for override in avail.bandPriceOverrides {
            guard let band = avail.bands.first(where: { $0.id == override.bandId }) else { continue }
            switch override.weekScope {
            case .allWeeks:
                try? await addHourlyBandRule(
                    listingId: listingId,
                    dayMask: band.dayMask,
                    startHour: band.startHour,
                    startMinute: band.startMinute,
                    endHour: band.endHour,
                    endMinute: band.endMinute,
                    price: override.price,
                    startDate: nil,
                    endDate: nil,
                    spotId: spotId
                )
            case .specificWeeks(let weeks):
                for week in weeks {
                    guard let range = isoWeekDateRange(year: week.year, week: week.weekNum) else { continue }
                    try? await addHourlyBandRule(
                        listingId: listingId,
                        dayMask: band.dayMask,
                        startHour: band.startHour,
                        startMinute: band.startMinute,
                        endHour: band.endHour,
                        endMinute: band.endMinute,
                        price: override.price,
                        startDate: range.start,
                        endDate: range.end,
                        spotId: spotId
                    )
                }
            }
        }

        // 5) Date-overrides.
        for dateOverride in avail.dateOverrides {
            try? await setOverride(
                listingId: listingId,
                date: dateOverride.date,
                price: dateOverride.price,
                spotId: spotId
            )
        }
    }

    /// Hent rules filtrert på spot_id (NULL ⇒ listing-wide).
    private static func fetchRulesForSpot(listingId: String, spotId: String?, kind: String?) async -> [Rule] {
        do {
            var query = supabase
                .from("listing_pricing_rules")
                .select()
                .eq("listing_id", value: listingId)
            if let spotId {
                query = query.eq("spot_id", value: spotId)
            } else {
                query = query.is("spot_id", value: nil as Bool?)
            }
            if let kind {
                query = query.eq("kind", value: kind)
            }
            let rules: [Rule] = try await query.execute().value
            return rules
        } catch {
            return []
        }
    }

    /// Hent overrides filtrert på spot_id.
    private static func fetchOverridesForSpot(listingId: String, spotId: String?) async -> [Override] {
        do {
            var query = supabase
                .from("listing_pricing_overrides")
                .select()
                .eq("listing_id", value: listingId)
            if let spotId {
                query = query.eq("spot_id", value: spotId)
            } else {
                query = query.is("spot_id", value: nil as Bool?)
            }
            let overrides: [Override] = try await query.execute().value
            return overrides
        } catch {
            return []
        }
    }

    /// Forsøk å gjenfinne ISO-uke fra en startdato. Returnerer nil hvis dato-
    /// strengen ikke kan parses.
    private static func isoWeekFromRange(start: String) -> WeekKey? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let startDate = f.date(from: start) else { return nil }
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDate)
        guard let year = comps.yearForWeekOfYear, let week = comps.weekOfYear else { return nil }
        return WeekKey(year: year, weekNum: week)
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

    /// Returner dato-range (start, slutt) for en gitt ISO-uke.
    /// Erstatter den tidligere `WizardPricingCalendarView.dateRangeForWeek`.
    private static func isoWeekDateRange(year: Int, week: Int) -> (start: String, end: String)? {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        var comps = DateComponents()
        comps.weekday = 2
        comps.weekOfYear = week
        comps.yearForWeekOfYear = year
        guard let monday = cal.date(from: comps),
              let sunday = cal.date(byAdding: .day, value: 6, to: monday) else { return nil }
        return (start: format(monday), end: format(sunday))
    }

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
            // Booking-time tikker i hele timer; båndet kan være finere (halvtimer).
            // Time h dekkes hvis hele [h*60, (h+1)*60) ligger innenfor båndet.
            let bandStartMin = sh * 60 + (r.start_minute ?? 0)
            let bandEndMin = eh * 60 + (r.end_minute ?? 0)
            let hourStartMin = hour * 60
            let hourEndMin = hourStartMin + 60
            let hourMatches = hourStartMin >= bandStartMin && hourEndMin <= bandEndMin
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

    // MARK: - Lengre opphold (parkering)
    //
    // Speiler lib/pricing.ts:applyLongerStayPricing. Bruk i BookingView for å
    // gi gjesten en pris-preview som matcher det server lander på.

    struct DurationDiscount {
        let total: Int
        let baseTotal: Int
        let savings: Int
        let fullDays: Int
        let years: Int
        let sixMonths: Int
        let threeMonths: Int
        let months: Int
        let weeks: Int
        let days: Int
    }

    /// Tier-prisene som verten kan tilby. Stables greedy 365 → 180 → 90 → 30 → 7.
    struct LongerStayTiers {
        let weeklyPrice: Int
        let monthlyPrice: Int
        let threeMonthPrice: Int
        let sixMonthPrice: Int
        let yearPrice: Int

        var hasAny: Bool {
            weeklyPrice > 0 || monthlyPrice > 0
                || threeMonthPrice > 0 || sixMonthPrice > 0 || yearPrice > 0
        }
    }

    /// Anvender "lengre opphold"-priser på en per-dag-breakdown. Speiler
    /// lib/pricing.ts:applyLongerStayPricing.
    static func applyLongerStayPricing(
        breakdown: [NightlyPriceEntry],
        tiers: LongerStayTiers
    ) -> DurationDiscount {
        let baseTotal = breakdown.reduce(0) { $0 + $1.price }
        let totalDays = breakdown.count

        if !tiers.hasAny {
            return DurationDiscount(
                total: baseTotal, baseTotal: baseTotal, savings: 0, fullDays: 0,
                years: 0, sixMonths: 0, threeMonths: 0, months: 0, weeks: 0, days: 0
            )
        }

        var cursor = 0
        var remaining = totalDays
        var savings = 0
        var years = 0, sixMonths = 0, threeMonths = 0, months = 0, weeks = 0

        func tierSavings(_ baseSum: Int, _ tierPrice: Int) -> Int {
            if tierPrice <= 0 || tierPrice >= baseSum { return 0 }
            return baseSum - tierPrice
        }

        func sumRange(_ start: Int, _ length: Int) -> Int {
            var s = 0
            for i in 0..<length { s += breakdown[start + i].price }
            return s
        }

        while tiers.yearPrice > 0 && remaining >= 365 {
            savings += tierSavings(sumRange(cursor, 365), tiers.yearPrice)
            years += 1; cursor += 365; remaining -= 365
        }
        while tiers.sixMonthPrice > 0 && remaining >= 180 {
            savings += tierSavings(sumRange(cursor, 180), tiers.sixMonthPrice)
            sixMonths += 1; cursor += 180; remaining -= 180
        }
        while tiers.threeMonthPrice > 0 && remaining >= 90 {
            savings += tierSavings(sumRange(cursor, 90), tiers.threeMonthPrice)
            threeMonths += 1; cursor += 90; remaining -= 90
        }
        while tiers.monthlyPrice > 0 && remaining >= 30 {
            savings += tierSavings(sumRange(cursor, 30), tiers.monthlyPrice)
            months += 1; cursor += 30; remaining -= 30
        }
        while tiers.weeklyPrice > 0 && remaining >= 7 {
            savings += tierSavings(sumRange(cursor, 7), tiers.weeklyPrice)
            weeks += 1; cursor += 7; remaining -= 7
        }

        return DurationDiscount(
            total: baseTotal - savings,
            baseTotal: baseTotal,
            savings: savings,
            fullDays: totalDays,
            years: years,
            sixMonths: sixMonths,
            threeMonths: threeMonths,
            months: months,
            weeks: weeks,
            days: 0
        )
    }

    /// Beregn "lengre opphold"-pris for hourly booking. Inputs er rules brukt
    /// for breakdown (samme spot-filter), den ferdige breakdownen, og kr-priser
    /// per tier. `spotId` brukes til å re-anvende spot-filter på rules (matcher
    /// server). Speil av lib/pricing.ts:applyLongerStayPricing.
    static func applyLongerStayPricing(
        rules: [Rule],
        breakdown: [HourlyPriceEntry],
        dailyPrice: Int,
        weeklyPrice: Int,
        monthlyPrice: Int,
        spotId: String?
    ) -> DurationDiscount {
        let baseTotal = breakdown.reduce(0) { $0 + $1.price }

        if dailyPrice <= 0 && weeklyPrice <= 0 && monthlyPrice <= 0 {
            return DurationDiscount(total: baseTotal, baseTotal: baseTotal, savings: 0, fullDays: 0, years: 0, sixMonths: 0, threeMonths: 0, months: 0, weeks: 0, days: 0)
        }

        // Filtrer regler likt som server (spot_id IS NULL OR spot_id = target).
        let filteredRules: [Rule]
        if let target = spotId {
            filteredRules = rules.filter { $0.spot_id == nil || $0.spot_id == target }
        } else {
            filteredRules = rules.filter { $0.spot_id == nil }
        }
        let hourlyRules = filteredRules.filter { $0.kind == "hourly" }

        // Alltid-ledig: et døgn = 24 sammenhengende timer.
        if hourlyRules.isEmpty {
            return apply24HourBlock(
                breakdown: breakdown,
                dailyPrice: dailyPrice,
                weeklyPrice: weeklyPrice,
                monthlyPrice: monthlyPrice
            )
        }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current

        let isoFmt = ISO8601DateFormatter()
        isoFmt.timeZone = TimeZone(identifier: "Europe/Oslo")
        isoFmt.formatOptions = [.withInternetDateTime]

        // Grupper timer etter Oslo-dato.
        var hoursByDate: [String: [(hour: Int, price: Int)]] = [:]
        for entry in breakdown where entry.source != "unavailable" {
            guard let date = isoFmt.date(from: entry.hourAt) else { continue }
            let dayKey = format(date)
            let h = cal.component(.hour, from: date)
            hoursByDate[dayKey, default: []].append((hour: h, price: entry.price))
        }

        let dates = hoursByDate.keys.sorted()
        var fullDayFlags: [Bool] = []

        for dateIso in dates {
            let bookedHours = Set((hoursByDate[dateIso] ?? []).map { $0.hour })
            guard let date = parse(dateIso) else {
                fullDayFlags.append(false)
                continue
            }
            let bit = weekdayBit(date)

            let bandsForDay = hourlyRules.filter { r in
                guard let mask = r.day_mask, r.start_hour != nil, r.end_hour != nil else { return false }
                if let sd = r.start_date, dateIso < sd { return false }
                if let ed = r.end_date, dateIso > ed { return false }
                return (mask & (1 << bit)) != 0
            }

            if bandsForDay.isEmpty {
                fullDayFlags.append(false)
                continue
            }

            var requiredHours: Set<Int> = []
            for band in bandsForDay {
                let startMin = (band.start_hour ?? 0) * 60 + (band.start_minute ?? 0)
                let endMin = (band.end_hour ?? 0) * 60 + (band.end_minute ?? 0)
                for h in 0..<24 {
                    let hStart = h * 60
                    let hEnd = hStart + 60
                    if hStart >= startMin && hEnd <= endMin {
                        requiredHours.insert(h)
                    }
                }
            }

            let isFull = !requiredHours.isEmpty && requiredHours.allSatisfy { bookedHours.contains($0) }
            fullDayFlags.append(isFull)
        }

        // Stable rabatt over påfølgende strekninger.
        var totalSavings: Double = 0
        var totalFullDays = 0
        var totalMonths = 0, totalWeeks = 0, totalDayCount = 0

        let sumDay: (Int) -> Int = { idx in
            (hoursByDate[dates[idx]] ?? []).reduce(0) { $0 + $1.price }
        }

        var runStart = -1
        for i in 0...fullDayFlags.count {
            let isFull = i < fullDayFlags.count && fullDayFlags[i]
            if isFull && runStart == -1 {
                runStart = i
            } else if !isFull && runStart != -1 {
                let runEnd = i - 1
                let length = runEnd - runStart + 1
                var cursor = runStart
                var remaining = length

                func tierSavings(_ baseHours: Int, _ tierPrice: Int) -> Double {
                    if tierPrice <= 0 || tierPrice >= baseHours { return 0 }
                    return Double(baseHours - tierPrice)
                }

                while monthlyPrice > 0 && remaining >= 30 {
                    var monthBase = 0
                    for j in 0..<30 { monthBase += sumDay(cursor + j) }
                    totalSavings += tierSavings(monthBase, monthlyPrice)
                    totalMonths += 1
                    cursor += 30
                    remaining -= 30
                }
                while weeklyPrice > 0 && remaining >= 7 {
                    var weekBase = 0
                    for j in 0..<7 { weekBase += sumDay(cursor + j) }
                    totalSavings += tierSavings(weekBase, weeklyPrice)
                    totalWeeks += 1
                    cursor += 7
                    remaining -= 7
                }
                while dailyPrice > 0 && remaining > 0 {
                    totalSavings += tierSavings(sumDay(cursor), dailyPrice)
                    totalDayCount += 1
                    cursor += 1
                    remaining -= 1
                }
                totalFullDays += length
                runStart = -1
            }
        }

        let savings = Int(totalSavings.rounded())
        return DurationDiscount(
            total: baseTotal - savings,
            baseTotal: baseTotal,
            savings: savings,
            fullDays: totalFullDays,
            years: 0,
            sixMonths: 0,
            threeMonths: 0,
            months: totalMonths,
            weeks: totalWeeks,
            days: totalDayCount
        )
    }

    /// 24-timers-blokk for plasser uten bånd. Et "døgn" = 24 sammenhengende
    /// timer fra start av booking. Resten (siste < 24t) betales full pris.
    private static func apply24HourBlock(
        breakdown: [HourlyPriceEntry],
        dailyPrice: Int,
        weeklyPrice: Int,
        monthlyPrice: Int
    ) -> DurationDiscount {
        let usable = breakdown.filter { $0.source != "unavailable" }
        let baseTotal = usable.reduce(0) { $0 + $1.price }
        let totalDays = usable.count / 24

        var cursor = 0
        var remaining = totalDays
        var savings: Double = 0
        var months = 0, weeks = 0, days = 0

        func tierSavings(_ baseHours: Int, _ tierPrice: Int) -> Double {
            if tierPrice <= 0 || tierPrice >= baseHours { return 0 }
            return Double(baseHours - tierPrice)
        }

        while monthlyPrice > 0 && remaining >= 30 {
            var monthBase = 0
            for i in 0..<(30 * 24) { monthBase += usable[cursor + i].price }
            savings += tierSavings(monthBase, monthlyPrice)
            months += 1
            cursor += 30 * 24
            remaining -= 30
        }
        while weeklyPrice > 0 && remaining >= 7 {
            var weekBase = 0
            for i in 0..<(7 * 24) { weekBase += usable[cursor + i].price }
            savings += tierSavings(weekBase, weeklyPrice)
            weeks += 1
            cursor += 7 * 24
            remaining -= 7
        }
        while dailyPrice > 0 && remaining > 0 {
            var dayBase = 0
            for i in 0..<24 { dayBase += usable[cursor + i].price }
            savings += tierSavings(dayBase, dailyPrice)
            days += 1
            cursor += 24
            remaining -= 1
        }

        let rounded = Int(savings.rounded())
        return DurationDiscount(
            total: baseTotal - rounded,
            baseTotal: baseTotal,
            savings: rounded,
            fullDays: totalDays,
            years: 0,
            sixMonths: 0,
            threeMonths: 0,
            months: months,
            weeks: weeks,
            days: days
        )
    }

    // MARK: - Service-fee split (speiler lib/config.ts)
    //
    // Tunos plattform-gebyr legges på TOPPEN av host-prisen. Når host setter
    // 1000 kr per natt → gjest betaler 1100 kr → host får 1000 kr → Tuno får 100 kr.

    static let serviceFeeRate: Double = 0.10

    /// Gebyret når brukeren har satt en host-pris (subtotal). Avrundet heltall NOK.
    static func feeFromSubtotal(_ subtotal: Int) -> Int {
        Int((Double(subtotal) * serviceFeeRate).rounded())
    }

    /// Gjestens totalpris gitt host-prisen.
    static func guestPriceFromSubtotal(_ subtotal: Int) -> Int {
        subtotal + feeFromSubtotal(subtotal)
    }

    /// Splitter en gjeste-totalpris til (hostShare, fee). Brukes når vi
    /// allerede har totalen og må vise ut gebyret. Speiler `splitHostAndFee`
    /// i `lib/config.ts`.
    static func splitHostAndFee(totalPriceNok: Int) -> (hostShare: Int, fee: Int) {
        let fee = Int((Double(totalPriceNok) * serviceFeeRate / (1 + serviceFeeRate)).rounded())
        return (hostShare: totalPriceNok - fee, fee: fee)
    }
}
