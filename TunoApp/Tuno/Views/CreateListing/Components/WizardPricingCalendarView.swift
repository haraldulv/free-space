import SwiftUI

/// Pris-variasjon-kalender per plass — Airbnb-stil. Multi-måned grid med
/// store dato-celler som viser dato + effektiv pris per time. Tap-anker for
/// multi-select. Når dager er valgt, sticky bottom action-bar med:
///   - Date-range pille + lukke-X
///   - "Tilgjengelig"-toggle (blokker/avblokker)
///   - "Pris per time" stort tall + Tilpasset-knapp
struct WizardPricingCalendarView: View {
    @ObservedObject var form: ListingFormModel
    let spotId: String

    @State private var selectedDates: Set<String> = []
    @State private var rangeAnchor: String?
    @State private var showDatePriceSheet = false
    @State private var hasScrolledToCurrent = false

    private let monthsAhead = 6

    private var availability: WizardSpotAvailability {
        form.availability(for: spotId)
    }

    private var bands: [WizardPricingBand] { availability.bands }

    private var basePerHour: Int {
        form.spotMarkers.first(where: { $0.id == spotId })?.pricePerHour ?? 0
    }

    private var spot: SpotMarker? {
        form.spotMarkers.first(where: { $0.id == spotId })
    }

    private var spotIndex: Int? {
        form.spotMarkers.firstIndex(where: { $0.id == spotId })
    }

    private var blockedDates: Set<String> {
        Set(spot?.blockedDates ?? [])
    }

    private var dateOverrides: [String: Int] {
        Dictionary(uniqueKeysWithValues: availability.dateOverrides.map { ($0.date, $0.price) })
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

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d. MMM"
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

    private var currentWeekRowId: String? {
        let cal = Self.osloCalendar
        let today = cal.startOfDay(for: Date())
        for monthStart in visibleMonths {
            for week in weeksFor(monthStart) {
                let year = cal.component(.yearForWeekOfYear, from: today)
                let weekNum = cal.component(.weekOfYear, from: today)
                if week.key.year == year && week.key.weekNum == weekNum {
                    return week.id
                }
            }
        }
        return nil
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if bands.isEmpty {
                    emptyHint
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                weekdayHeader
                                    .padding(.horizontal, 12)
                                    .padding(.top, 4)
                                ForEach(visibleMonths, id: \.self) { monthStart in
                                    monthSection(monthStart)
                                }
                                Color.clear.frame(height: selectedDates.isEmpty ? 24 : 220)
                            }
                        }
                        .onAppear {
                            guard !hasScrolledToCurrent else { return }
                            if let target = currentWeekRowId {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    proxy.scrollTo(target, anchor: .top)
                                    hasScrolledToCurrent = true
                                }
                            } else {
                                hasScrolledToCurrent = true
                            }
                        }
                    }
                }
            }

            if !selectedDates.isEmpty {
                actionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: selectedDates.isEmpty)
        .sheet(isPresented: $showDatePriceSheet) {
            DatePriceSheet(
                basePerHour: basePerHour,
                selectedCount: selectedDates.count,
                currentPrice: averageSelectedPrice() ?? basePerHour,
                onSave: { price in
                    applyDateOverride(price: price)
                    showDatePriceSheet = false
                },
                onCancel: { showDatePriceSheet = false }
            )
            .presentationDetents([.fraction(0.32)])
        }
    }

    // MARK: - Tom-tilstand

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

    // MARK: - Weekday header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(["Ma", "Ti", "On", "To", "Fr", "Lø", "Sø"], id: \.self) { day in
                Text(day)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.neutral500)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Month section

    @ViewBuilder
    private func monthSection(_ monthStart: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Self.monthNameFormatter.string(from: monthStart).capitalized)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.neutral900)
                .padding(.horizontal, 20)

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
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { col in
                if let date = week.days[col] {
                    dayCell(date: date)
                        .frame(maxWidth: .infinity)
                } else {
                    Color.clear.frame(maxWidth: .infinity, minHeight: 88)
                }
            }
        }
        .frame(minHeight: 88)
        .id(week.id)
    }

    // MARK: - Day cell (Airbnb-stil — stort kort med dato + pris)

    @ViewBuilder
    private func dayCell(date: Date) -> some View {
        let iso = Self.isoFormatter.string(from: date)
        let day = Self.osloCalendar.component(.day, from: date)
        let startOfToday = Self.osloCalendar.startOfDay(for: Date())
        let isPast = Self.osloCalendar.startOfDay(for: date) < startOfToday
        let isSelected = selectedDates.contains(iso)
        let isAnchor = rangeAnchor == iso
        let isBlocked = blockedDates.contains(iso)
        let hasOverride = dateOverrides[iso] != nil
        let priceInfo = priceForDate(date)

        Button {
            handleDayTap(iso: iso, isPast: isPast)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(cellBackground(
                        isPast: isPast,
                        isSelected: isSelected,
                        isAnchor: isAnchor,
                        isBlocked: isBlocked,
                        hasOverride: hasOverride
                    ))
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        cellBorder(isSelected: isSelected, isAnchor: isAnchor, isPast: isPast, isBlocked: isBlocked),
                        lineWidth: isAnchor ? 2 : (isSelected || isBlocked ? 1.5 : 1)
                    )

                VStack(spacing: 4) {
                    Text("\(day)")
                        .font(.system(size: 16, weight: (isSelected || isAnchor) ? .bold : .semibold))
                        .foregroundStyle(cellText(isPast: isPast, isBlocked: isBlocked, isSelected: isSelected, isAnchor: isAnchor))
                        .padding(.top, 10)

                    Spacer(minLength: 0)

                    if isBlocked {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.neutral500)
                            .padding(.bottom, 10)
                    } else if !isPast, let price = priceInfo {
                        Text("\(price.amount) kr")
                            .font(.system(size: 11, weight: hasOverride || price.isOverride ? .bold : .medium))
                            .foregroundStyle(priceTextColor(
                                isSelected: isSelected,
                                isAnchor: isAnchor,
                                isOverride: hasOverride || price.isOverride
                            ))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.bottom, 10)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 88)
        }
        .buttonStyle(.plain)
        .disabled(isPast)
    }

    // MARK: - Cell styling

    private func cellBackground(isPast: Bool, isSelected: Bool, isAnchor: Bool, isBlocked: Bool, hasOverride: Bool) -> Color {
        if isAnchor { return Color.primary600.opacity(0.18) }
        if isSelected { return Color.primary600.opacity(0.10) }
        if isBlocked { return Color.neutral100 }
        if hasOverride { return Color(hex: "#ecfdf5") }
        return Color.white
    }

    private func cellBorder(isSelected: Bool, isAnchor: Bool, isPast: Bool, isBlocked: Bool) -> Color {
        if isAnchor { return Color.primary600 }
        if isSelected { return Color.primary500 }
        if isBlocked { return Color.neutral300 }
        if isPast { return Color.neutral100 }
        return Color.neutral200
    }

    private func cellText(isPast: Bool, isBlocked: Bool, isSelected: Bool, isAnchor: Bool) -> Color {
        if isPast { return Color.neutral300 }
        if isBlocked { return Color.neutral400 }
        return Color.neutral900
    }

    private func priceTextColor(isSelected: Bool, isAnchor: Bool, isOverride: Bool) -> Color {
        if isOverride { return Color.primary700 }
        if isSelected || isAnchor { return Color.primary700 }
        return Color.neutral500
    }

    // MARK: - Bottom action bar (Airbnb-stil)

    private var actionBar: some View {
        VStack(spacing: 10) {
            // Topp-rad: dato-range pille + lukke-X
            HStack(spacing: 10) {
                dateRangePill
                Spacer()
                Button {
                    selectedDates.removeAll()
                    rangeAnchor = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.neutral900))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            // To-kort layout: Tilgjengelig + Pris/Tilpasset
            HStack(alignment: .top, spacing: 10) {
                availabilityCard
                priceCard
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .padding(.top, 10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.10), radius: 16, y: -4)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var dateRangePill: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Text(formatDateRange())
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.neutral900))
    }

    private var availabilityCard: some View {
        let allBlocked = !selectedDates.isEmpty && selectedDates.allSatisfy { blockedDates.contains($0) }
        let allOpen = !allBlocked

        return Button {
            toggleBlockSelected()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Text("Tilgjengelig")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Circle()
                        .fill(allOpen ? Color(hex: "#22c55e") : Color(hex: "#ef4444"))
                        .frame(width: 7, height: 7)
                }
                Spacer(minLength: 6)

                // Toggle-bryter Airbnb-stil: liten capsule med to states
                ZStack(alignment: allOpen ? .trailing : .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 76, height: 32)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 36, height: 28)
                        .padding(.horizontal, 2)
                        .overlay(
                            Image(systemName: allOpen ? "checkmark" : "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.neutral900)
                        )
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.85), value: allOpen)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .frame(height: 130)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.neutral900)
            )
        }
        .buttonStyle(.plain)
    }

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pris per time")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(currentSelectedPriceText)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            Button {
                showDatePriceSheet = true
            } label: {
                HStack(spacing: 6) {
                    Text("Tilpasset pris")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 130)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.neutral900)
        )
    }

    private var currentSelectedPriceText: String {
        let prices = selectedDates.compactMap { iso -> Int? in
            guard let date = Self.isoFormatter.date(from: iso) else { return nil }
            return priceForDate(date)?.amount
        }
        guard !prices.isEmpty else { return "\(basePerHour) kr" }
        let minP = prices.min() ?? basePerHour
        let maxP = prices.max() ?? basePerHour
        if minP == maxP { return "\(minP) kr" }
        return "\(minP)–\(maxP) kr"
    }

    private func formatDateRange() -> String {
        guard !selectedDates.isEmpty else { return "" }
        let sorted = selectedDates.sorted()
        guard let first = sorted.first.flatMap({ Self.isoFormatter.date(from: $0) }),
              let last = sorted.last.flatMap({ Self.isoFormatter.date(from: $0) }) else {
            return ""
        }
        if first == last {
            return Self.dayMonthFormatter.string(from: first)
        }
        return "\(Self.dayMonthFormatter.string(from: first)) – \(Self.dayMonthFormatter.string(from: last))"
    }

    // MARK: - Pris-oppslag per dato

    private struct ResolvedDayPrice {
        let amount: Int
        let isOverride: Bool
    }

    private func priceForDate(_ date: Date) -> ResolvedDayPrice? {
        let iso = Self.isoFormatter.string(from: date)
        if let dateOverride = dateOverrides[iso] {
            return ResolvedDayPrice(amount: dateOverride, isOverride: true)
        }
        let cal = Self.osloCalendar
        let weekday = cal.component(.weekday, from: date)
        let bit = (weekday + 5) % 7
        let year = cal.component(.yearForWeekOfYear, from: date)
        let weekNum = cal.component(.weekOfYear, from: date)
        let weekKey = WeekKey(year: year, weekNum: weekNum)

        // Finn første bånd som matcher dagen
        for band in bands {
            if (band.dayMask & (1 << bit)) != 0 {
                let resolved = priceForBand(band, weekKey: weekKey)
                return ResolvedDayPrice(amount: resolved.price, isOverride: resolved.scope != nil)
            }
        }
        // Ingen bånd matcher dagen — alltid ledig fallback til base
        return ResolvedDayPrice(amount: basePerHour, isOverride: false)
    }

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

    // MARK: - Tap-handling (multi-select tap-anker)

    private func handleDayTap(iso: String, isPast: Bool) {
        guard !isPast else { return }
        if let anchor = rangeAnchor {
            if anchor == iso {
                selectedDates.remove(iso)
                rangeAnchor = nil
                return
            }
            let range = isoRange(from: anchor, to: iso)
            for d in range { selectedDates.insert(d) }
            rangeAnchor = nil
            return
        }
        if selectedDates.contains(iso) {
            selectedDates.remove(iso)
            if selectedDates.isEmpty { rangeAnchor = nil }
        } else {
            selectedDates.insert(iso)
            rangeAnchor = iso
        }
    }

    private func isoRange(from start: String, to end: String) -> [String] {
        let lo = min(start, end)
        let hi = max(start, end)
        guard let loDate = Self.isoFormatter.date(from: lo),
              let hiDate = Self.isoFormatter.date(from: hi) else { return [start, end] }
        let cal = Self.osloCalendar
        var result: [String] = []
        var cursor = loDate
        while cursor <= hiDate {
            result.append(Self.isoFormatter.string(from: cursor))
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    // MARK: - Action handlers

    private func toggleBlockSelected() {
        guard let idx = spotIndex else { return }
        let existing = Set(form.spotMarkers[idx].blockedDates ?? [])
        let allBlocked = selectedDates.allSatisfy { existing.contains($0) }
        var updated = existing
        if allBlocked {
            // Avblokkér
            updated.subtract(selectedDates)
        } else {
            updated.formUnion(selectedDates)
        }
        form.spotMarkers[idx].blockedDates = updated.isEmpty ? nil : Array(updated).sorted()
    }

    private func applyDateOverride(price: Int) {
        var avail = availability
        for date in selectedDates {
            if let i = avail.dateOverrides.firstIndex(where: { $0.date == date }) {
                avail.dateOverrides[i].price = price
            } else {
                avail.dateOverrides.append(WizardDateOverride(date: date, price: price))
            }
        }
        form.setAvailability(avail, for: spotId)
    }

    private func averageSelectedPrice() -> Int? {
        let prices = selectedDates.compactMap { iso -> Int? in
            guard let date = Self.isoFormatter.date(from: iso) else { return nil }
            return priceForDate(date)?.amount
        }
        guard !prices.isEmpty else { return nil }
        return prices.reduce(0, +) / prices.count
    }

    // MARK: - Måned-uker-helper

    private func weeksFor(_ monthStart: Date) -> [WeekRow] {
        let cal = Self.osloCalendar
        let firstWeekday = cal.component(.weekday, from: monthStart)
        let daysFromMonday = (firstWeekday + 5) % 7
        guard let firstDisplayDay = cal.date(byAdding: .day, value: -daysFromMonday, to: monthStart) else { return [] }

        var weeks: [WeekRow] = []
        var cursor = firstDisplayDay
        let monthComps = cal.dateComponents([.year, .month], from: monthStart)

        while true {
            var days: [Date?] = []
            for col in 0..<7 {
                guard let d = cal.date(byAdding: .day, value: col, to: cursor) else { days.append(nil); continue }
                let dComps = cal.dateComponents([.year, .month], from: d)
                if dComps.year == monthComps.year && dComps.month == monthComps.month { days.append(d) }
                else { days.append(nil) }
            }
            let mondayOfWeek = days.compactMap { $0 }.first ?? cursor
            let year = cal.component(.yearForWeekOfYear, from: mondayOfWeek)
            let weekNum = cal.component(.weekOfYear, from: mondayOfWeek)
            let weekKey = WeekKey(year: year, weekNum: weekNum)

            let hasAnyMonthDay = days.contains(where: { $0 != nil })
            if !hasAnyMonthDay && !weeks.isEmpty { break }
            if hasAnyMonthDay {
                weeks.append(WeekRow(key: weekKey, days: days))
            }
            guard let next = cal.date(byAdding: .day, value: 7, to: cursor) else { break }
            cursor = next
            if weeks.count > 6 { break }
        }
        return weeks
    }
}

struct WeekRow: Identifiable {
    let key: WeekKey
    let days: [Date?]
    var id: String {
        let firstDay = days.compactMap { $0 }.first
        let suffix = firstDay.map { String($0.timeIntervalSince1970) } ?? ""
        return key.id + "-" + suffix
    }
}

extension WizardPricingCalendarView {
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

/// Sheet for å sette pris for valgte enkelt-datoer. Brukes fra "Tilpasset pris"-knappen
/// i bunn-actionbar.
private struct DatePriceSheet: View {
    let basePerHour: Int
    let selectedCount: Int
    let currentPrice: Int
    let onSave: (Int) -> Void
    let onCancel: () -> Void

    @State private var priceText: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tilpasset pris for \(selectedCount) \(selectedCount == 1 ? "dag" : "dager")")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.neutral900)
                    Text("Standardpris er \(basePerHour) kr/time. Sett en annen pris for valgte datoer.")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                }
                HStack(spacing: 10) {
                    TextField("\(basePerHour)", text: $priceText)
                        .focused($focused)
                        .keyboardType(.numberPad)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary600)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: 160)
                        .background(Color.primary50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("kr/time")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.neutral500)
                    Spacer()
                }
                Spacer()
            }
            .padding(20)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lagre") {
                        if let p = Int(priceText), p > 0 { onSave(p) }
                    }
                    .fontWeight(.semibold)
                    .disabled((Int(priceText) ?? 0) <= 0)
                }
            }
            .onAppear {
                priceText = "\(currentPrice)"
                focused = true
            }
        }
    }
}
