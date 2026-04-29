import SwiftUI

/// Pris-variasjon-kalender per plass — Airbnb-inspirert fullskjerm-design.
/// Sticky ukedag-header øverst. Multi-måned grid med store dato-celler som
/// viser dato + bånd-bars (samme y-linje) + effektiv pris. Tap-anker for
/// multi-select. Glassmorphism action-bar i bunn med Tilgjengelig-toggle og
/// inline pris-editor.
struct WizardPricingCalendarView: View {
    @ObservedObject var form: ListingFormModel
    let spotId: String

    @State private var selectedDates: Set<String> = []
    @State private var rangeAnchor: String?
    @State private var hasScrolledToCurrent = false
    @State private var priceEditValue: Int = 0
    @FocusState private var priceEditFocused: Bool

    private let monthsAhead = 6
    private let cellHeight: CGFloat = 110
    private let cellSpacing: CGFloat = 6
    private let bandHeight: CGFloat = 22
    private let bandSpacing: CGFloat = 3
    private let bandStartY: CGFloat = 32

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
        VStack(spacing: 0) {
            stickyWeekdayHeader

            if bands.isEmpty {
                emptyHint
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 18) {
                            ForEach(visibleMonths, id: \.self) { monthStart in
                                monthSection(monthStart)
                            }
                        }
                        .padding(.top, 8)
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
        .safeAreaInset(edge: .bottom) {
            if !selectedDates.isEmpty {
                actionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: selectedDates.isEmpty)
        .onChange(of: priceEditFocused) { _, focused in
            if !focused {
                commitPriceEdit()
            }
        }
    }

    // MARK: - Sticky weekday header

    private var stickyWeekdayHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(["Ma", "Ti", "On", "To", "Fr", "Lø", "Sø"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.neutral500)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Rectangle()
                .fill(Color.neutral200)
                .frame(height: 0.5)
        }
        .background(Color.white)
    }

    // MARK: - Tom-tilstand

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Spacer()
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
            Spacer()
        }
        .padding(24)
    }

    // MARK: - Month section

    @ViewBuilder
    private func monthSection(_ monthStart: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Self.monthNameFormatter.string(from: monthStart).capitalized)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.neutral900)
                .padding(.horizontal, 20)

            VStack(spacing: cellSpacing) {
                ForEach(weeksFor(monthStart), id: \.id) { week in
                    weekRow(week)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private func weekRow(_ week: WeekRow) -> some View {
        ZStack(alignment: .topLeading) {
            // 1. Dato-celler i bunn
            HStack(spacing: cellSpacing) {
                ForEach(0..<7, id: \.self) { col in
                    if let date = week.days[col] {
                        dayCell(date: date)
                            .frame(maxWidth: .infinity)
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: cellHeight)

            // 2. Bånd-bars i overlay (alltid samme y-koordinat innenfor uken)
            if !bands.isEmpty {
                bandsOverlay(week: week)
                    .frame(height: cellHeight)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: cellHeight)
        .id(week.id)
    }

    // MARK: - Day cell

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

                VStack(spacing: 0) {
                    Text("\(day)")
                        .font(.system(size: 16, weight: (isSelected || isAnchor) ? .bold : .semibold))
                        .foregroundStyle(cellText(isPast: isPast, isBlocked: isBlocked))
                        .padding(.top, 8)

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
            .frame(height: cellHeight)
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

    private func cellText(isPast: Bool, isBlocked: Bool) -> Color {
        if isPast { return Color.neutral300 }
        if isBlocked { return Color.neutral400 }
        return Color.neutral900
    }

    private func priceTextColor(isSelected: Bool, isAnchor: Bool, isOverride: Bool) -> Color {
        if isOverride { return Color.primary700 }
        if isSelected || isAnchor { return Color.primary700 }
        return Color.neutral500
    }

    // MARK: - Bånd-bars overlay (samme y-linje innenfor uken, alle bånd stables)

    @ViewBuilder
    private func bandsOverlay(week: WeekRow) -> some View {
        GeometryReader { g in
            let totalSpacing = cellSpacing * 6
            let cellWidth = max(0, (g.size.width - totalSpacing) / 7)

            ForEach(Array(bands.enumerated()), id: \.element.id) { bandIdx, band in
                let segs = bandSegments(mask: band.dayMask)
                ForEach(segs.indices, id: \.self) { i in
                    let seg = segs[i]
                    let resolved = priceForBand(band, weekKey: week.key)
                    let isOverride = resolved.scope != nil
                    let palette = bandPalette(for: band)
                    let xOffset = CGFloat(seg.start) * (cellWidth + cellSpacing)
                    let width = CGFloat(seg.end - seg.start + 1) * cellWidth + CGFloat(seg.end - seg.start) * cellSpacing
                    let yOffset = bandStartY + CGFloat(bandIdx) * (bandHeight + bandSpacing)

                    HStack(spacing: 4) {
                        Spacer(minLength: 0)
                        Text("\(resolved.price) kr")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(palette.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 6)
                    .frame(width: max(0, width - 4), height: bandHeight)
                    .background(
                        Capsule()
                            .fill(isOverride ? palette.bgOverride : palette.bgDefault)
                    )
                    .offset(x: xOffset + 2, y: yOffset)
                }
            }
        }
    }

    /// Dempede pastell-paletter basert på bånd-id-hash. Override = mettet for å skille seg ut.
    private func bandPalette(for band: WizardPricingBand) -> BandPalette {
        let palettes: [BandPalette] = [
            BandPalette(bgDefault: Color(hex: "#86d9b1").opacity(0.85), bgOverride: Color(hex: "#46c185"), border: .clear, text: .white),
            BandPalette(bgDefault: Color(hex: "#c4b5fd").opacity(0.85), bgOverride: Color(hex: "#8b5cf6"), border: .clear, text: .white),
            BandPalette(bgDefault: Color(hex: "#fdba74").opacity(0.85), bgOverride: Color(hex: "#f97316"), border: .clear, text: .white),
            BandPalette(bgDefault: Color(hex: "#93c5fd").opacity(0.85), bgOverride: Color(hex: "#3b82f6"), border: .clear, text: .white),
            BandPalette(bgDefault: Color(hex: "#f9a8d4").opacity(0.85), bgOverride: Color(hex: "#ec4899"), border: .clear, text: .white),
        ]
        let idx = abs(band.id.hashValue) % palettes.count
        return palettes[idx]
    }

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

    // MARK: - Bottom action bar (glassmorphism cards)

    private var actionBar: some View {
        VStack(spacing: 10) {
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
                        .frame(width: 38, height: 38)
                        .background(glassCircleBackground)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            HStack(alignment: .top, spacing: 10) {
                availabilityCard
                priceCard
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .padding(.top, 10)
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
        .background(glassPillBackground)
    }

    /// Glass-Capsule for dato-pillen (samme look som kortene).
    private var glassPillBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .overlay(
                Capsule().fill(Color.black.opacity(0.55))
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }

    /// Glass-sirkel for lukke-X.
    private var glassCircleBackground: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .overlay(Circle().fill(Color.black.opacity(0.55)))
            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    private var availabilityCard: some View {
        let allBlocked = !selectedDates.isEmpty && selectedDates.allSatisfy { blockedDates.contains($0) }
        let allOpen = !allBlocked

        return Button {
            toggleBlockSelected()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text("Tilgjengelig")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Circle()
                        .fill(allOpen ? Color(hex: "#22c55e") : Color(hex: "#ef4444"))
                        .frame(width: 7, height: 7)
                }
                Spacer(minLength: 0)
                ZStack(alignment: allOpen ? .trailing : .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.16))
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
            .background(glassCardBackground)
        }
        .buttonStyle(.plain)
    }

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pris per time")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            inlinePriceEditor

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 130)
        .background(glassCardBackground)
    }

    private var inlinePriceEditor: some View {
        HStack(spacing: 10) {
            Button {
                stepPrice(by: -10)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.5))
            }
            .buttonStyle(.plain)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                TextField("", value: $priceEditValue, formatter: NumberFormatter())
                    .focused($priceEditFocused)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize()
                    .frame(minWidth: 40)
                    .onAppear { syncPriceEditFromSelection() }
                    .onChange(of: selectedDates) { _, _ in syncPriceEditFromSelection() }
                Text("kr")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Button {
                stepPrice(by: 10)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.5))
            }
            .buttonStyle(.plain)
        }
    }

    /// Glassmorphism: mørk frosted glass med hairline-kant.
    private var glassCardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
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

        for band in bands {
            if (band.dayMask & (1 << bit)) != 0 {
                let resolved = priceForBand(band, weekKey: weekKey)
                return ResolvedDayPrice(amount: resolved.price, isOverride: resolved.scope != nil)
            }
        }
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
            updated.subtract(selectedDates)
        } else {
            updated.formUnion(selectedDates)
        }
        form.spotMarkers[idx].blockedDates = updated.isEmpty ? nil : Array(updated).sorted()
    }

    private func syncPriceEditFromSelection() {
        let prices = selectedDates.compactMap { iso -> Int? in
            guard let date = Self.isoFormatter.date(from: iso) else { return nil }
            return priceForDate(date)?.amount
        }
        if let first = prices.first {
            priceEditValue = first
        } else {
            priceEditValue = basePerHour
        }
    }

    private func stepPrice(by delta: Int) {
        let newValue = max(0, priceEditValue + delta)
        priceEditValue = newValue
        applyDateOverride(price: newValue)
    }

    private func commitPriceEdit() {
        applyDateOverride(price: priceEditValue)
    }

    private func applyDateOverride(price: Int) {
        var avail = availability
        if price <= 0 || price == basePerHour {
            // Fjern overstyring hvis prisen er null eller lik base
            avail.dateOverrides.removeAll { selectedDates.contains($0.date) }
        } else {
            for date in selectedDates {
                if let i = avail.dateOverrides.firstIndex(where: { $0.date == date }) {
                    avail.dateOverrides[i].price = price
                } else {
                    avail.dateOverrides.append(WizardDateOverride(date: date, price: price))
                }
            }
        }
        form.setAvailability(avail, for: spotId)
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
