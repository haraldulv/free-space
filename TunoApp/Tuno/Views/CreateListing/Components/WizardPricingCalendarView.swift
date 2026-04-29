import SwiftUI

/// Pris-variasjon-kalender per plass. Viser hver uke (12 uker fram) med en
/// klikkbar bar per tilgjengelighets-bånd. Tap → BandPriceOverrideSheet for å
/// sette pris (denne uken / alle uker / spesifikke uker).
struct WizardPricingCalendarView: View {
    @ObservedObject var form: ListingFormModel
    let spotId: String

    @State private var sheetTarget: BandOverrideTarget?

    private let weeksAhead = 12

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

    private static let weekRangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d. MMM"
        f.locale = Locale(identifier: "nb_NO")
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        return f
    }()

    /// 12 ISO-uker fra og med inneværende uke.
    private var weeks: [WeekRow] {
        let cal = Self.osloCalendar
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let mondayThisWeek = cal.date(byAdding: .day, value: -daysFromMonday, to: today) else { return [] }
        return (0..<weeksAhead).compactMap { offset in
            guard let monday = cal.date(byAdding: .day, value: offset * 7, to: mondayThisWeek),
                  let sunday = cal.date(byAdding: .day, value: 6, to: monday) else { return nil }
            let year = cal.component(.yearForWeekOfYear, from: monday)
            let weekNum = cal.component(.weekOfYear, from: monday)
            return WeekRow(
                key: WeekKey(year: year, weekNum: weekNum),
                monday: monday,
                sunday: sunday
            )
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if bands.isEmpty {
                    emptyHint
                } else {
                    headerHint
                    ForEach(weeks) { week in
                        weekSection(week)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
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

    // MARK: - Header

    private var headerHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.primary600)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text("Standardpris \(basePerHour) kr/time")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Text("Tap på et bånd for å endre prisen for den uken, alle uker, eller velge spesifikke uker.")
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

    // MARK: - Week section

    private func weekSection(_ week: WeekRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Uke \(week.key.weekNum)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.neutral900)
                Text("\(Self.weekRangeFormatter.string(from: week.monday)) – \(Self.weekRangeFormatter.string(from: week.sunday))")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
                Spacer()
            }
            VStack(spacing: 6) {
                ForEach(bands) { band in
                    bandBar(band: band, week: week)
                }
            }
        }
    }

    private func bandBar(band: WizardPricingBand, week: WeekRow) -> some View {
        let resolved = priceForBand(band, weekKey: week.key)
        let isOverride = resolved.price != basePerHour && (resolved.scope != nil)
        return Button {
            sheetTarget = BandOverrideTarget(
                band: band,
                weekKey: week.key,
                currentPrice: resolved.price,
                matchedScope: resolved.scope
            )
        } label: {
            HStack(spacing: 12) {
                dayMaskDots(mask: band.dayMask)
                VStack(alignment: .leading, spacing: 2) {
                    Text(daysLabel(mask: band.dayMask))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text("\(twoDigit(band.startHour)):00 – \(twoDigit(band.endHour)):00")
                        .font(.system(size: 11))
                        .foregroundStyle(.neutral500)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(resolved.price) kr")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isOverride ? .primary700 : .neutral900)
                    Text("per time")
                        .font(.system(size: 10))
                        .foregroundStyle(.neutral500)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.neutral400)
            }
            .padding(12)
            .background(isOverride ? Color.primary50 : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isOverride ? Color.primary600.opacity(0.4) : Color.neutral200, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func dayMaskDots(mask: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { i in
                Circle()
                    .fill((mask & (1 << i)) != 0 ? Color.primary600 : Color.neutral200)
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: - Pris-oppslag

    private struct ResolvedPrice {
        let price: Int
        let scope: WeekScope?  // nil = base-pris
    }

    private func priceForBand(_ band: WizardPricingBand, weekKey: WeekKey) -> ResolvedPrice {
        let overrides = availability.bandPriceOverrides.filter { $0.bandId == band.id }
        // Spesifikk uke vinner over allWeeks
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
        // Ved allWeeks: erstatt eksisterende allWeeks-rad for bandId
        // Ved specificWeeks: merge eller append
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

    private func daysLabel(mask: Int) -> String {
        let names = ["Man", "Tir", "Ons", "Tor", "Fre", "Lør", "Søn"]
        let selected = (0..<7).filter { (mask & (1 << $0)) != 0 }
        if selected == [0, 1, 2, 3, 4] { return "Hverdager" }
        if selected == [5, 6] { return "Helg" }
        if selected == [0, 1, 2, 3, 4, 5, 6] { return "Alle dager" }
        return selected.map { names[$0] }.joined(separator: ", ")
    }

    private func twoDigit(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
}

private struct WeekRow: Identifiable {
    let key: WeekKey
    let monday: Date
    let sunday: Date
    var id: String { key.id }
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
