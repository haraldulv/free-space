import SwiftUI

/// Pris-variasjon-kalender per plass. Viser ekte multi-måned kalender (6
/// måneder fram) med dato-celler. Tilgjengelighets-båndene legges som
/// horisontale bars OVER dagene de matcher i hver uke (likt en booking
/// som strekker seg over flere dager). Tap på en bar → BandPriceOverrideSheet.
struct WizardPricingCalendarView: View {
    @ObservedObject var form: ListingFormModel
    let spotId: String

    @State private var sheetTarget: BandOverrideTarget?

    private let monthsAhead = 6

    private var availability: WizardSpotAvailability {
        form.availability(for: spotId)
    }

    private var bands: [WizardPricingBand] { availability.bands }

    private var basePerHour: Int {
        form.spotMarkers.first(where: { $0.id == spotId })?.pricePerHour ?? 0
    }

    private static var osloCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        return cal
    }

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let monthNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "nb_NO")
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        return f
    }()

    private var visibleMonths: [Date] {
        let cal = Self.osloCalendar
        let now = cal.startOfDay(for: Date())
        let comps = cal.dateComponents([.year, .month], from: now)
        guard let first = cal.date(from: comps) else { return [] }
        return (0..<monthsAhead).compactMap { offset in
            cal.date(byAdding: .month, value: offset, to: first)
        }
    }

    var body: some View {
        Group {
            if bands.isEmpty {
                emptyHint
            } else {
                ScrollView {
                    LazyVStack(spacing: 24) {
                        headerHint
                            .padding(.horizontal, 16)
                        ForEach(visibleMonths, id: \.self) { monthStart in
                            monthSection(monthStart)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .sheet(item: $sheetTarget) { target in
            BandPriceOverrideSheet(
                band: target.band,
                weekKey: target.weekKey,
                basePerHour: basePerHour,
                currentPrice: target.currentPrice,
                allWeeks: target.matchedScope == .allWeeks,
                onSave: { newPrice, newScope in
                    applyOverride(bandId: target.band.id, scope: newScope, price: newPrice)
                    sheetTarget = nil
                },
                onCancel: { sheetTarget = nil }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var headerHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.primary600)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text("Standardpris \(basePerHour) kr/time")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text("Tap på et bånd i kalenderen for å endre prisen for den uken, alle uker eller spesifikke uker.")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral600)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.primary50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 32))
                .foregroundStyle(.neutral400)
            Text("Ingen bånd å variere prisen på")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.neutral900)
            Text("Gå tilbake og legg til tilgjengelighets-bånd hvis du vil variere prisen.")
                .font(.system(size: 13))
                .foregroundStyle(.neutral500)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    // MARK: - Month section

    @ViewBuilder
    private func monthSection(_ monthStart: Date) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(Self.monthNameFormatter.string(from: monthStart).capitalized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.neutral900)
                Spacer()
            }
            .padding(.horizontal, 20)

            HStack(spacing: 0) {
                ForEach(["Ma", "Ti", "On", "To", "Fr", "Lø", "Sø"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.neutral500)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)

            VStack(spacing: 6) {
                ForEach(weeksFor(monthStart), id: \.id) { week in
                    weekRow(week)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private func weekRow(_ week: WeekRow) -> some View {
        let bandsInWeek = bands  // alle bånd vises i hver uke (de er ukentlige)
        let segCount = bandsInWeek.flatMap { bandSegments(mask: $0.dayMask) }.count
        let cellHeight: CGFloat = 64
        let bandsAreaHeight: CGFloat = CGFloat(segCount) * 22 + max(0, CGFloat(segCount - 1)) * 4
        let totalHeight = cellHeight + (segCount > 0 ? bandsAreaHeight + 8 : 0)

        ZStack(alignment: .topLeading) {
            // 7 dato-celler i en HStack — alltid lik bredde
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { col in
                    if let date = week.days[col] {
                        dayCell(date: date)
                            .frame(maxWidth: .infinity, minHeight: cellHeight, alignment: .top)
                    } else {
                        Color.clear.frame(maxWidth: .infinity, minHeight: cellHeight)
                    }
                }
            }
            .frame(height: cellHeight)

            // Bånd-bars-overlay under dato-tallet
            if segCount > 0 {
                bandsOverlay(week: week, bandsInWeek: bandsInWeek)
                    .padding(.top, cellHeight + 4)
            }
        }
        .frame(height: totalHeight)
    }

    @ViewBuilder
    private func bandsOverlay(week: WeekRow, bandsInWeek: [WizardPricingBand]) -> some View {
        GeometryReader { g in
            let cellSpacing: CGFloat = 3
            let totalSpacing = cellSpacing * 6
            let cellWidth = max(0, (g.size.width - totalSpacing) / 7)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(bandsInWeek) { band in
                    let segs = bandSegments(mask: band.dayMask)
                    ForEach(segs.indices, id: \.self) { i in
                        let seg = segs[i]
                        bandBar(
                            band: band,
                            week: week,
                            segment: seg,
                            cellWidth: cellWidth,
                            cellSpacing: cellSpacing
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bandBar(
        band: WizardPricingBand,
        week: WeekRow,
        segment seg: (start: Int, end: Int),
        cellWidth: CGFloat,
        cellSpacing: CGFloat
    ) -> some View {
        let resolved = priceForBand(band, weekKey: week.key)
        let isOverride = resolved.scope != nil
        let xOffset = CGFloat(seg.start) * (cellWidth + cellSpacing)
        let width = CGFloat(seg.end - seg.start + 1) * cellWidth + CGFloat(seg.end - seg.start) * cellSpacing

        Button {
            sheetTarget = BandOverrideTarget(
                band: band,
                weekKey: week.key,
                currentPrice: resolved.price,
                matchedScope: resolved.scope
            )
        } label: {
            HStack(spacing: 4) {
                Spacer(minLength: 0)
                Text("\(resolved.price) kr")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .frame(width: max(0, width - 4), height: 20)
            .background(barColor(isOverride: isOverride))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .offset(x: xOffset + 2)
    }

    private func barColor(isOverride: Bool) -> Color {
        // Override = mørkere primær (synlig forskjell)
        // Default = primary600 (samme grønn som logoen)
        isOverride ? Color.primary700 : Color.primary600
    }

    // MARK: - Day cell

    @ViewBuilder
    private func dayCell(date: Date) -> some View {
        let day = Self.osloCalendar.component(.day, from: date)
        let startOfToday = Self.osloCalendar.startOfDay(for: Date())
        let isPast = Self.osloCalendar.startOfDay(for: date) < startOfToday

        VStack(spacing: 0) {
            Text("\(day)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isPast ? .neutral300 : .neutral900)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Pris-oppslag (samme som tidligere implementering)

    private struct ResolvedPrice {
        let price: Int
        let scope: WeekScope?
    }

    private func priceForBand(_ band: WizardPricingBand, weekKey: WeekKey) -> ResolvedPrice {
        let overrides = availability.bandPriceOverrides.filter { $0.bandId == band.id }
        for o in overrides {
            if case .specificWeeks(let set) = o.weekScope, set.contains(weekKey) {
                return ResolvedPrice(price: o.price, scope: o.weekScope)
            }
        }
        for o in overrides {
            if case .allWeeks = o.weekScope {
                return ResolvedPrice(price: o.price, scope: .allWeeks)
            }
        }
        return ResolvedPrice(price: basePerHour, scope: nil)
    }

    // MARK: - Apply override

    private func applyOverride(bandId: UUID, scope: WeekScope, price: Int) {
        var avail = availability
        switch scope {
        case .allWeeks:
            avail.bandPriceOverrides.removeAll { o in
                guard o.bandId == bandId else { return false }
                if case .allWeeks = o.weekScope { return true }
                return false
            }
            if price != basePerHour {
                avail.bandPriceOverrides.append(WizardBandPriceOverride(
                    bandId: bandId, weekScope: .allWeeks, price: price
                ))
            }
        case .specificWeeks(let weeks):
            avail.bandPriceOverrides.removeAll { o in
                guard o.bandId == bandId else { return false }
                if case .specificWeeks(let existing) = o.weekScope {
                    return existing == weeks
                }
                return false
            }
            if price != basePerHour {
                avail.bandPriceOverrides.append(WizardBandPriceOverride(
                    bandId: bandId, weekScope: scope, price: price
                ))
            }
        }
        form.setAvailability(avail, for: spotId)
    }

    // MARK: - Helpers

    /// Splitter en dag-mask i sammenhengende segmenter (kolonne-rangen).
    /// "Hverdager" mask 0b0011111 → [(0, 4)]
    /// "Helg" mask 0b1100000 → [(5, 6)]
    /// "Man + Helg" mask 0b1100001 → [(0, 0), (5, 6)]
    private func bandSegments(mask: Int) -> [(start: Int, end: Int)] {
        var result: [(Int, Int)] = []
        var inSeg = false
        var segStart = 0
        for col in 0..<7 {
            let isSet = (mask & (1 << col)) != 0
            if isSet && !inSeg {
                segStart = col
                inSeg = true
            } else if !isSet && inSeg {
                result.append((segStart, col - 1))
                inSeg = false
            }
        }
        if inSeg { result.append((segStart, 6)) }
        return result
    }

    /// Beregner uker som ligger innenfor måneden (inkl. delvise uker — men
    /// dager utenfor måneden er nil i WeekRow.days).
    private func weeksFor(_ monthStart: Date) -> [WeekRow] {
        let cal = Self.osloCalendar
        guard let range = cal.range(of: .day, in: .month, for: monthStart) else { return [] }
        let daysInMonth = range.count

        // Finn første mandag før eller på den første i måneden
        let firstWeekday = cal.component(.weekday, from: monthStart)
        let daysFromMonday = (firstWeekday + 5) % 7
        guard let firstDisplayDay = cal.date(byAdding: .day, value: -daysFromMonday, to: monthStart) else { return [] }

        var weeks: [WeekRow] = []
        var cursor = firstDisplayDay
        let monthComps = cal.dateComponents([.year, .month], from: monthStart)

        // Iterér uke for uke til vi er forbi måneden
        while true {
            var days: [Date?] = []
            for col in 0..<7 {
                guard let d = cal.date(byAdding: .day, value: col, to: cursor) else {
                    days.append(nil); continue
                }
                let dComps = cal.dateComponents([.year, .month], from: d)
                if dComps.year == monthComps.year && dComps.month == monthComps.month {
                    days.append(d)
                } else {
                    days.append(nil)
                }
            }
            // Beregn weekKey fra første reelle dag i uken (eller fra cursor)
            let mondayOfWeek = days.compactMap { $0 }.first ?? cursor
            let year = cal.component(.yearForWeekOfYear, from: mondayOfWeek)
            let weekNum = cal.component(.weekOfYear, from: mondayOfWeek)
            let weekKey = WeekKey(year: year, weekNum: weekNum)

            // Avslutt hvis ingen dager i denne uken er i måneden
            let hasAnyMonthDay = days.contains(where: { $0 != nil })
            if !hasAnyMonthDay && !weeks.isEmpty { break }
            if hasAnyMonthDay {
                weeks.append(WeekRow(key: weekKey, days: days))
            }

            guard let next = cal.date(byAdding: .day, value: 7, to: cursor) else { break }
            cursor = next

            // Sikkerhetsbrekk
            if weeks.count > 6 { break }
            // (siste-uke-sjekk håndteres av hasAnyMonthDay-betingelsen)
            _ = daysInMonth
        }
        return weeks
    }
}

struct WeekRow: Identifiable {
    let key: WeekKey
    let days: [Date?]   // 7 entries, nil for dager utenfor måneden
    var id: String {
        let firstDay = days.compactMap { $0 }.first
        let suffix = firstDay.map { String($0.timeIntervalSince1970) } ?? ""
        return key.id + "-" + suffix
    }
}

extension WizardPricingCalendarView {
    /// ISO-yyyy-MM-dd for mandag/søndag i en gitt ISO-uke. Brukes ved
    /// publisering for å sette start_date/end_date på listing_pricing_rules.
    static func dateRangeForWeek(year: Int, week: Int) -> (start: String, end: String)? {
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
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return (f.string(from: monday), f.string(from: sunday))
    }
}

/// Target for BandPriceOverrideSheet.
struct BandOverrideTarget: Identifiable {
    let band: WizardPricingBand
    let weekKey: WeekKey
    let currentPrice: Int
    let matchedScope: WeekScope?
    var id: String { "\(band.id):\(weekKey.id)" }
}
