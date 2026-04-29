import SwiftUI

/// Pris-variasjon-kalender per plass. Speiler HostCalendarView fra Profil →
/// Kalender: multi-måned grid med kvadratiske dato-celler, tap-anker for
/// multi-select. Tilgjengelighets-båndene tegnes som horisontale bars
/// OVER cellene (likt en booking som strekker seg over flere dager), med
/// distinkte farger per bånd. Tap på bar → BandPriceOverrideSheet. Tap på
/// celle → multi-select med bunn-actionbar (Blokker / Sett pris / Fjern overst.).
struct WizardPricingCalendarView: View {
    @ObservedObject var form: ListingFormModel
    let spotId: String

    @State private var sheetTarget: BandOverrideTarget?
    @State private var selectedDates: Set<String> = []
    @State private var rangeAnchor: String?
    @State private var showDatePriceSheet = false

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
        ZStack(alignment: .bottom) {
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
                            // plass for bottom action-bar
                            Color.clear.frame(height: selectedDates.isEmpty ? 32 : 130)
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
        .sheet(isPresented: $showDatePriceSheet) {
            DatePriceSheet(
                basePerHour: basePerHour,
                selectedCount: selectedDates.count,
                onSave: { price in
                    applyDateOverride(price: price)
                    showDatePriceSheet = false
                },
                onCancel: { showDatePriceSheet = false }
            )
            .presentationDetents([.fraction(0.32)])
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
                Text("Tap på et bånd for å endre prisen for den uken eller spesifikke uker. Tap dato-celler for å blokkere eller sette pris per dag.")
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

    // MARK: - Bottom action bar

    private var actionBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(selectedDates.count) \(selectedDates.count == 1 ? "dag" : "dager") valgt")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.neutral900)
                Spacer()
                Button("Tøm") {
                    selectedDates.removeAll()
                    rangeAnchor = nil
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary600)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                actionButton(icon: "xmark.square.fill", title: "Blokker") {
                    blockSelectedDates()
                }
                actionButton(icon: "tag.fill", title: "Sett pris") {
                    showDatePriceSheet = true
                }
                actionButton(icon: "arrow.uturn.backward", title: "Fjern overst.") {
                    clearSelectedOverrides()
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay(Rectangle().fill(Color.neutral200).frame(height: 1), alignment: .top)
        .shadow(color: .black.opacity(0.06), radius: 10, y: -4)
    }

    private func actionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(.neutral800)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.neutral100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
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
        let segCount = bands.flatMap { bandSegments(mask: $0.dayMask) }.count
        let cellHeight: CGFloat = 64
        let bandLayerStart: CGFloat = 22  // y-pos under dato-tallet
        let totalHeight = cellHeight + 6  // litt margin under

        ZStack(alignment: .topLeading) {
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { col in
                    if let date = week.days[col] {
                        dayCell(date: date)
                            .frame(maxWidth: .infinity, minHeight: cellHeight)
                    } else {
                        Color.clear.frame(maxWidth: .infinity, minHeight: cellHeight)
                    }
                }
            }
            .frame(height: cellHeight)

            // Bånd-bars OVER cellene (overlapper midten/under tallet)
            if segCount > 0 {
                bandsOverlay(week: week)
                    .padding(.top, bandLayerStart)
                    .frame(height: cellHeight - bandLayerStart)
                    .allowsHitTesting(true)
            }
        }
        .frame(height: totalHeight)
    }

    @ViewBuilder
    private func bandsOverlay(week: WeekRow) -> some View {
        GeometryReader { g in
            let cellSpacing: CGFloat = 3
            let totalSpacing = cellSpacing * 6
            let cellWidth = max(0, (g.size.width - totalSpacing) / 7)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(bands) { band in
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
        let width = CGFloat(seg.end - seg.start + 1) * cellWidth
                  + CGFloat(seg.end - seg.start) * cellSpacing
        let palette = bandPalette(for: band)

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
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .frame(width: max(0, width - 4), height: 22)
            .background(isOverride ? palette.bgOverride : palette.bgDefault)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(palette.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: palette.bgOverride.opacity(0.25), radius: isOverride ? 4 : 0, y: isOverride ? 2 : 0)
        }
        .buttonStyle(.plain)
        .offset(x: xOffset + 2)
    }

    /// Palett av bånd-farger basert på id-hash. Distinkte men begrensede sett.
    /// Override = mer mettet, default = pastell-versjon for å skille visuelt.
    private func bandPalette(for band: WizardPricingBand) -> BandPalette {
        let palettes: [BandPalette] = [
            BandPalette(  // Tuno-grønn
                bgDefault: Color(hex: "#5fcf96"),
                bgOverride: Color(hex: "#10b981"),
                border: Color(hex: "#10b981").opacity(0.6),
                text: .white
            ),
            BandPalette(  // Lavendel
                bgDefault: Color(hex: "#a78bfa"),
                bgOverride: Color(hex: "#7c3aed"),
                border: Color(hex: "#7c3aed").opacity(0.6),
                text: .white
            ),
            BandPalette(  // Korall
                bgDefault: Color(hex: "#fb923c"),
                bgOverride: Color(hex: "#ea580c"),
                border: Color(hex: "#ea580c").opacity(0.6),
                text: .white
            ),
            BandPalette(  // Sky
                bgDefault: Color(hex: "#60a5fa"),
                bgOverride: Color(hex: "#2563eb"),
                border: Color(hex: "#2563eb").opacity(0.6),
                text: .white
            ),
            BandPalette(  // Rose
                bgDefault: Color(hex: "#f472b6"),
                bgOverride: Color(hex: "#db2777"),
                border: Color(hex: "#db2777").opacity(0.6),
                text: .white
            ),
        ]
        let idx = abs(band.id.hashValue) % palettes.count
        return palettes[idx]
    }

    // MARK: - Day cell (samme stil som HostCalendarView)

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

        Button {
            handleDayTap(iso: iso, isPast: isPast)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(cellBackground(
                        isPast: isPast,
                        isSelected: isSelected,
                        isAnchor: isAnchor,
                        isBlocked: isBlocked,
                        hasOverride: hasOverride
                    ))
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        cellBorder(isSelected: isSelected, isAnchor: isAnchor, isPast: isPast),
                        lineWidth: isAnchor ? 2 : (isSelected ? 1.5 : 1)
                    )
                VStack(spacing: 0) {
                    Text("\(day)")
                        .font(.system(size: 13, weight: (isSelected || isAnchor) ? .bold : .medium))
                        .foregroundStyle(cellText(isPast: isPast, isBlocked: isBlocked))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 5)
                    Spacer()
                    if isBlocked {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.neutral500)
                            .padding(.bottom, 4)
                    } else if hasOverride, let p = dateOverrides[iso] {
                        Text("\(p) kr")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.primary700)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.bottom, 4)
                    }
                }
            }
            .frame(height: 64)
        }
        .buttonStyle(.plain)
        .disabled(isPast)
    }

    private func cellBackground(isPast: Bool, isSelected: Bool, isAnchor: Bool, isBlocked: Bool, hasOverride: Bool) -> Color {
        if isAnchor { return Color.primary600.opacity(0.18) }
        if isSelected { return Color.primary600.opacity(0.10) }
        if isBlocked { return Color.neutral100 }
        if hasOverride { return Color(hex: "#ecfdf5") }
        return Color.white
    }

    private func cellBorder(isSelected: Bool, isAnchor: Bool, isPast: Bool) -> Color {
        if isAnchor { return Color.primary600 }
        if isSelected { return Color.primary500 }
        if isPast { return Color.neutral100 }
        return Color.neutral200
    }

    private func cellText(isPast: Bool, isBlocked: Bool) -> Color {
        if isPast { return Color.neutral300 }
        if isBlocked { return Color.neutral500 }
        return Color.neutral900
    }

    // MARK: - Tap handling

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

    private func blockSelectedDates() {
        guard let idx = spotIndex else { return }
        let existing = Set(form.spotMarkers[idx].blockedDates ?? [])
        let merged = existing.union(selectedDates)
        form.spotMarkers[idx].blockedDates = Array(merged).sorted()
        selectedDates.removeAll()
        rangeAnchor = nil
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
        selectedDates.removeAll()
        rangeAnchor = nil
    }

    private func clearSelectedOverrides() {
        guard let idx = spotIndex else { return }
        // Fjern dato-overstyringer
        var avail = availability
        avail.dateOverrides.removeAll { selectedDates.contains($0.date) }
        form.setAvailability(avail, for: spotId)
        // Fjern blokkering
        let existing = Set(form.spotMarkers[idx].blockedDates ?? [])
        let updated = existing.subtracting(selectedDates)
        form.spotMarkers[idx].blockedDates = updated.isEmpty ? nil : Array(updated).sorted()
        selectedDates.removeAll()
        rangeAnchor = nil
    }

    // MARK: - Pris-oppslag

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

    private func bandSegments(mask: Int) -> [(start: Int, end: Int)] {
        var result: [(Int, Int)] = []
        var inSeg = false
        var segStart = 0
        for col in 0..<7 {
            let isSet = (mask & (1 << col)) != 0
            if isSet && !inSeg { segStart = col; inSeg = true }
            else if !isSet && inSeg { result.append((segStart, col - 1)); inSeg = false }
        }
        if inSeg { result.append((segStart, 6)) }
        return result
    }

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

struct BandPalette {
    let bgDefault: Color
    let bgOverride: Color
    let border: Color
    let text: Color
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

struct BandOverrideTarget: Identifiable {
    let band: WizardPricingBand
    let weekKey: WeekKey
    let currentPrice: Int
    let matchedScope: WeekScope?
    var id: String { "\(band.id):\(weekKey.id)" }
}

/// Sheet for å sette pris for valgte enkelt-datoer (multi-select via tap-anker).
private struct DatePriceSheet: View {
    let basePerHour: Int
    let selectedCount: Int
    let onSave: (Int) -> Void
    let onCancel: () -> Void

    @State private var priceText: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sett pris for \(selectedCount) \(selectedCount == 1 ? "dag" : "dager")")
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
            .onAppear { focused = true }
        }
    }
}
