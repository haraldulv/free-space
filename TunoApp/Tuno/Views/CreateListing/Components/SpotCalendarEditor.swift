import SwiftUI

/// Forenklet kalender-editor for én plass. Erstatter den tidligere bånd-baserte
/// `WizardSeasonalCalendarView` / `WizardPricingCalendarView`. Modellen er
/// rett-fram: blokker datoer + sett egne priser per dato — ingen bånd, ingen
/// ukedags-mønster, ingen åpningstid.
///
/// Interaksjon:
/// - Tap én dato → bottom sheet med "Blokker" / "Sett egen pris"
/// - Tap dato + tap dato 2 → range — samme bottom sheet, men "rekkevidde"
/// - "Velg flere"-toggle → multi-select for ikke-sammenhengende datoer
struct SpotCalendarEditor: View {
    @Binding var blockedDates: [String]
    @Binding var datePriceOverrides: [String: Int]
    /// Standard pris (kr/dag eller kr/døgn) — brukes som referanse i UI og
    /// som default når host åpner pris-input. nil → vis ikke pris.
    let basePrice: Int

    @State private var rangeAnchor: String?
    @State private var multiSelectMode: Bool = false
    @State private var multiSelected: Set<String> = []
    @State private var actionTarget: ActionTarget?

    private let monthsAhead = 12
    private let cellHeight: CGFloat = 64
    private let cellSpacing: CGFloat = 4

    enum ActionTarget: Identifiable {
        case single(String)
        case range(start: String, end: String)
        case multi(Set<String>)

        var id: String {
            switch self {
            case .single(let d): return "single-\(d)"
            case .range(let a, let b): return "range-\(a)-\(b)"
            case .multi(let dates): return "multi-\(dates.sorted().joined(separator: ","))"
            }
        }

        var dates: [String] {
            switch self {
            case .single(let d): return [d]
            case .range(let a, let b): return SpotCalendarEditor.datesBetween(start: a, end: b)
            case .multi(let s): return s.sorted()
            }
        }
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
        f.dateFormat = "LLLL yyyy"
        f.locale = Locale(identifier: "nb_NO")
        return f
    }()

    private var blockedSet: Set<String> { Set(blockedDates) }

    var body: some View {
        VStack(spacing: 0) {
            actionBar
            ScrollView {
                LazyVStack(spacing: 18, pinnedViews: [.sectionHeaders]) {
                    Section {
                        weekdayHeader
                            .padding(.top, 8)
                    }
                    ForEach(visibleMonths, id: \.self) { month in
                        monthSection(month)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 32)
            }
        }
        .sheet(item: $actionTarget) { target in
            DateActionSheet(
                target: target,
                blockedDates: $blockedDates,
                datePriceOverrides: $datePriceOverrides,
                basePrice: basePrice,
                onClose: {
                    actionTarget = nil
                    rangeAnchor = nil
                    multiSelected.removeAll()
                }
            )
            .presentationDetents([.height(360), .medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Action bar (multi-select toggle + status)

    private var actionBar: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    multiSelectMode.toggle()
                    if !multiSelectMode { multiSelected.removeAll() }
                    rangeAnchor = nil
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: multiSelectMode ? "checkmark.circle.fill" : "checklist")
                        .font(.system(size: 13, weight: .semibold))
                    Text(multiSelectMode ? "Avslutt valg" : "Velg flere")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(multiSelectMode ? .white : Color.neutral900)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(multiSelectMode ? Color.primary600 : Color.neutral100)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            if multiSelectMode && !multiSelected.isEmpty {
                Button {
                    actionTarget = .multi(multiSelected)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("\(multiSelected.count) valgt")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.neutral900)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Weekday header (sticky)

    private var weekdayHeader: some View {
        HStack(spacing: cellSpacing) {
            ForEach(["Ma", "Ti", "On", "To", "Fr", "Lø", "Sø"], id: \.self) { day in
                Text(day)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.neutral500)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.95))
    }

    // MARK: - Month grid

    private var visibleMonths: [Date] {
        let cal = Self.osloCalendar
        let now = Date()
        guard let start = cal.dateInterval(of: .month, for: now)?.start else { return [] }
        return (0..<monthsAhead).compactMap { cal.date(byAdding: .month, value: $0, to: start) }
    }

    @ViewBuilder
    private func monthSection(_ month: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Self.monthNameFormatter.string(from: month).capitalized)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.neutral900)

            VStack(spacing: cellSpacing) {
                ForEach(weeksIn(month: month), id: \.first) { week in
                    HStack(spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { i in
                            if i < week.count, let date = week[i] {
                                dayCell(date: date)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, maxHeight: cellHeight)
                            }
                        }
                    }
                }
            }
        }
    }

    private func weeksIn(month: Date) -> [[Date?]] {
        let cal = Self.osloCalendar
        guard
            let interval = cal.dateInterval(of: .month, for: month),
            let firstDayWeekday = cal.dateComponents([.weekday], from: interval.start).weekday
        else { return [] }

        let firstWeekdayIndex = (firstDayWeekday + 5) % 7  // Mandag = 0
        let dayCount = cal.range(of: .day, in: .month, for: month)?.count ?? 30

        var cells: [Date?] = Array(repeating: nil, count: firstWeekdayIndex)
        for d in 0..<dayCount {
            if let date = cal.date(byAdding: .day, value: d, to: interval.start) {
                cells.append(date)
            }
        }
        while cells.count % 7 != 0 { cells.append(nil) }

        var weeks: [[Date?]] = []
        for chunk in stride(from: 0, to: cells.count, by: 7) {
            weeks.append(Array(cells[chunk..<min(chunk + 7, cells.count)]))
        }
        return weeks
    }

    // MARK: - Day cell

    @ViewBuilder
    private func dayCell(date: Date) -> some View {
        let iso = Self.isoFormatter.string(from: date)
        let day = Self.osloCalendar.component(.day, from: date)
        let startOfToday = Self.osloCalendar.startOfDay(for: Date())
        let isPast = Self.osloCalendar.startOfDay(for: date) < startOfToday
        let isAnchor = rangeAnchor == iso
        let isMulti = multiSelected.contains(iso)
        let isBlocked = blockedSet.contains(iso)
        let override = datePriceOverrides[iso]

        Button {
            handleTap(iso: iso, isPast: isPast)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(cellBackground(
                        isPast: isPast,
                        isAnchor: isAnchor,
                        isMulti: isMulti,
                        isBlocked: isBlocked,
                        hasOverride: override != nil
                    ))
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        cellBorder(isAnchor: isAnchor, isMulti: isMulti, isBlocked: isBlocked, isPast: isPast),
                        lineWidth: (isAnchor || isMulti) ? 2 : 1
                    )

                VStack(spacing: 1) {
                    Text("\(day)")
                        .font(.system(size: 14, weight: (isAnchor || isMulti) ? .bold : .semibold))
                        .foregroundStyle(cellTextColor(isPast: isPast, isBlocked: isBlocked))
                    if isBlocked {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.neutral500)
                    } else if let override, !isPast {
                        Text("\(override) kr")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.primary700)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .frame(height: cellHeight)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isPast)
    }

    private func cellBackground(isPast: Bool, isAnchor: Bool, isMulti: Bool, isBlocked: Bool, hasOverride: Bool) -> Color {
        if isAnchor { return Color.primary600.opacity(0.18) }
        if isMulti { return Color.primary600.opacity(0.12) }
        if isBlocked { return Color.neutral100 }
        if hasOverride { return Color(hex: "#ecfdf5") }
        return Color.white
    }

    private func cellBorder(isAnchor: Bool, isMulti: Bool, isBlocked: Bool, isPast: Bool) -> Color {
        if isAnchor { return Color.primary600 }
        if isMulti { return Color.primary500 }
        if isBlocked { return Color.neutral300 }
        if isPast { return Color.neutral100 }
        return Color.neutral200
    }

    private func cellTextColor(isPast: Bool, isBlocked: Bool) -> Color {
        if isPast { return Color.neutral300 }
        if isBlocked { return Color.neutral400 }
        return Color.neutral900
    }

    // MARK: - Tap handling

    private func handleTap(iso: String, isPast: Bool) {
        guard !isPast else { return }

        if multiSelectMode {
            if multiSelected.contains(iso) {
                multiSelected.remove(iso)
            } else {
                multiSelected.insert(iso)
            }
            return
        }

        if let anchor = rangeAnchor {
            if anchor == iso {
                // Tap samme dato igjen → bare action på den ene
                actionTarget = .single(iso)
            } else {
                let (start, end) = anchor < iso ? (anchor, iso) : (iso, anchor)
                actionTarget = .range(start: start, end: end)
            }
        } else {
            rangeAnchor = iso
            // Vis sheet umiddelbart for single-tap. Hvis bruker vil ha range,
            // tapper de ny dato før de lukker sheet → vi setter target på nytt.
            actionTarget = .single(iso)
        }
    }

    // MARK: - Helpers

    static func datesBetween(start: String, end: String) -> [String] {
        guard let s = isoFormatter.date(from: start),
              let e = isoFormatter.date(from: end) else { return [start] }
        let cal = osloCalendar
        var result: [String] = []
        var current = s
        while current <= e {
            result.append(isoFormatter.string(from: current))
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }
}

// MARK: - Action sheet

private struct DateActionSheet: View {
    let target: SpotCalendarEditor.ActionTarget
    @Binding var blockedDates: [String]
    @Binding var datePriceOverrides: [String: Int]
    let basePrice: Int
    let onClose: () -> Void

    @State private var showPriceEditor: Bool = false
    @State private var priceText: String = ""
    @FocusState private var priceFocused: Bool

    private var dates: [String] { target.dates }

    private var allBlocked: Bool {
        dates.allSatisfy { blockedDates.contains($0) }
    }

    private var headline: String {
        switch target {
        case .single(let d): return prettyDate(d)
        case .range(let a, let b): return "\(prettyDate(a)) – \(prettyDate(b))"
        case .multi(let s): return "\(s.count) datoer valgt"
        }
    }

    private var subline: String? {
        switch target {
        case .range:
            return "\(dates.count) dager"
        default:
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headline)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                if let subline {
                    Text(subline)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
            }
            .padding(.top, 4)

            if showPriceEditor {
                priceEditor
            } else {
                actions
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(0.85))
        .background(.ultraThinMaterial)
        .preferredColorScheme(.dark)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                if allBlocked {
                    blockedDates.removeAll { dates.contains($0) }
                } else {
                    var set = Set(blockedDates)
                    dates.forEach { set.insert($0) }
                    blockedDates = Array(set).sorted()
                }
                onClose()
            } label: {
                actionRow(
                    icon: allBlocked ? "lock.open.fill" : "lock.fill",
                    label: allBlocked ? "Frigi datoer" : "Blokker datoer",
                    description: allBlocked
                        ? "Datoene blir bookbare igjen"
                        : "Gjester kan ikke booke disse datoene"
                )
            }
            .buttonStyle(.plain)

            Button {
                let initial = firstOverride() ?? basePrice
                priceText = "\(initial)"
                showPriceEditor = true
                priceFocused = true
            } label: {
                actionRow(
                    icon: "tag.fill",
                    label: "Sett egen pris",
                    description: "Overstyr standardprisen for valgte datoer"
                )
            }
            .buttonStyle(.plain)

            if hasAnyOverride {
                Button {
                    dates.forEach { datePriceOverrides.removeValue(forKey: $0) }
                    onClose()
                } label: {
                    actionRow(
                        icon: "arrow.uturn.backward",
                        label: "Fjern egen pris",
                        description: "Tilbake til standardpris"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var priceEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pris per dag")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.7))

            HStack(spacing: 8) {
                TextField("0", text: $priceText)
                    .focused($priceFocused)
                    .keyboardType(.numberPad)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text("kr")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
            }

            if basePrice > 0 {
                Text("Standardpris: \(basePrice) kr")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            HStack(spacing: 10) {
                Button {
                    showPriceEditor = false
                } label: {
                    Text("Avbryt")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    let value = max(0, Int(priceText.filter(\.isNumber)) ?? 0)
                    if value > 0 {
                        for d in dates {
                            datePriceOverrides[d] = value
                        }
                    }
                    onClose()
                } label: {
                    Text("Lagre")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.primary600)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func actionRow(icon: String, label: String, description: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private var hasAnyOverride: Bool {
        dates.contains { datePriceOverrides[$0] != nil }
    }

    private func firstOverride() -> Int? {
        for d in dates {
            if let p = datePriceOverrides[d] { return p }
        }
        return nil
    }

    private func prettyDate(_ iso: String) -> String {
        let inFormatter = DateFormatter()
        inFormatter.dateFormat = "yyyy-MM-dd"
        inFormatter.locale = Locale(identifier: "en_US_POSIX")
        let outFormatter = DateFormatter()
        outFormatter.dateFormat = "d. MMM"
        outFormatter.locale = Locale(identifier: "nb_NO")
        guard let date = inFormatter.date(from: iso) else { return iso }
        return outFormatter.string(from: date)
    }
}
