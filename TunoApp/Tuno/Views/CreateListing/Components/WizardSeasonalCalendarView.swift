import SwiftUI

/// Camping-versjon av bånd-kalenderen. Visuelt IDENTISK med
/// `WizardPricingCalendarView` (samme cellHeight, weekday-header, FAB,
/// color-picker, dag-celler med pris under) — kun bånd-meningen og editor-
/// sheet er ulike: bånd er sesongperioder med dato-range og per-natt-pris.
///
/// Brukes i camping-wizardens pris-variasjon-steg og i Profile-kalenderen for
/// camping-listings.
struct WizardSeasonalCalendarView: View {
    @ObservedObject var form: ListingFormModel
    let spotId: String

    @State private var editingBand: WizardPricingBand? = nil
    @State private var showCreateSheet: Bool = false
    @State private var hasScrolledToCurrent = false

    // Match parking-kalenderens konstanter eksakt.
    private let monthsAhead = 6
    private let cellHeight: CGFloat = 110
    private let cellSpacing: CGFloat = 6
    private let bandHeight: CGFloat = 22
    private let bandSpacing: CGFloat = 3

    private var availability: WizardSpotAvailability { form.availability(for: spotId) }
    private var bands: [WizardPricingBand] {
        availability.bands.filter { $0.isSeasonal }
    }

    private var basePerNight: Int {
        let spot = form.spotMarkers.first(where: { $0.id == spotId })
        return spot?.pricePerNight ?? spot?.price ?? 0
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
        return f
    }()

    private static let monthNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        f.locale = Locale(identifier: "nb_NO")
        return f
    }()

    private var visibleMonths: [Date] {
        let cal = Self.osloCalendar
        let now = Date()
        guard let start = cal.dateInterval(of: .month, for: now)?.start else { return [] }
        return (0..<monthsAhead).compactMap {
            cal.date(byAdding: .month, value: $0, to: start)
        }
    }

    /// Lane-allokering for bånd: ikke-overlappende dato-ranger deler lane.
    private var bandLaneAssignment: [UUID: Int] {
        var laneRanges: [[(start: String, end: String)]] = []
        var assignment: [UUID: Int] = [:]
        for band in bands {
            guard let bStart = band.startDate, let bEnd = band.endDate else { continue }
            var lane = 0
            while lane < laneRanges.count {
                let conflict = laneRanges[lane].contains { range in
                    !(bEnd < range.start || bStart > range.end)
                }
                if !conflict { break }
                lane += 1
            }
            if lane >= laneRanges.count {
                laneRanges.append([])
            }
            laneRanges[lane].append((bStart, bEnd))
            assignment[band.id] = lane
        }
        return assignment
    }

    private var totalLanes: Int {
        (bandLaneAssignment.values.max() ?? -1) + 1
    }

    private var bandStartY: CGFloat {
        let stackHeight = CGFloat(totalLanes) * bandHeight + CGFloat(max(0, totalLanes - 1)) * bandSpacing
        return (cellHeight - stackHeight) / 2
    }

    var body: some View {
        VStack(spacing: 0) {
            stickyWeekdayHeader

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 18) {
                        ForEach(visibleMonths, id: \.self) { monthStart in
                            monthSection(monthStart)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
                .onAppear {
                    guard !hasScrolledToCurrent else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        if let first = visibleMonths.first {
                            proxy.scrollTo(first, anchor: .top)
                        }
                        hasScrolledToCurrent = true
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            fabAddBand
                .padding(.trailing, 16)
                .padding(.bottom, 16)
        }
        .sheet(isPresented: $showCreateSheet) {
            seasonBandEditorSheet(initial: defaultNewBand(), isEditing: false)
        }
        .sheet(item: $editingBand) { band in
            seasonBandEditorSheet(initial: band, isEditing: true)
        }
    }

    // MARK: - Sticky weekday header (matcher parking eksakt)

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
            Rectangle().fill(Color.neutral200).frame(height: 0.5)
        }
        .background(Color.white)
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

            if !bands.isEmpty {
                bandsOverlay(week: week).frame(height: cellHeight)
            }
        }
        .frame(height: cellHeight)
        .id(week.id)
    }

    // MARK: - Day cell (matcher parking-kalenderen eksakt visuelt)

    @ViewBuilder
    private func dayCell(date: Date) -> some View {
        let day = Self.osloCalendar.component(.day, from: date)
        let startOfToday = Self.osloCalendar.startOfDay(for: Date())
        let isPast = Self.osloCalendar.startOfDay(for: date) < startOfToday
        let priceForDay = priceForDate(date)
        let dayCovered = bandCoversDay(date)

        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isPast ? Color.neutral100 : Color.neutral200, lineWidth: 1)

            VStack(spacing: 0) {
                Text("\(day)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isPast ? Color.neutral300 : Color.neutral900)
                    .padding(.top, 8)

                Spacer(minLength: 0)

                // Skjul pris under hvis et bånd dekker dagen — prisen står
                // da på selve båndet (samme som parking).
                if !isPast && !dayCovered, priceForDay > 0 {
                    Text("\(priceForDay) kr")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.neutral500)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.bottom, 10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: cellHeight)
    }

    /// Effektiv per-natt-pris for en dato. Sjekker bånd som dekker datoen;
    /// hvis ingen, returnerer base.
    private func priceForDate(_ date: Date) -> Int {
        let iso = Self.isoFormatter.string(from: date)
        for band in bands {
            guard let bStart = band.startDate, let bEnd = band.endDate else { continue }
            if iso >= bStart && iso <= bEnd && bandDayMaskMatches(band, date: date) {
                return band.price
            }
        }
        return basePerNight
    }

    /// True hvis et bånd dekker dagen (basert på dato-range + dayMask).
    private func bandCoversDay(_ date: Date) -> Bool {
        let iso = Self.isoFormatter.string(from: date)
        return bands.contains { band in
            guard let bStart = band.startDate, let bEnd = band.endDate else { return false }
            return iso >= bStart && iso <= bEnd && bandDayMaskMatches(band, date: date)
        }
    }

    private func bandDayMaskMatches(_ band: WizardPricingBand, date: Date) -> Bool {
        if band.dayMask == 0 { return true }
        let weekday = Self.osloCalendar.component(.weekday, from: date)
        let bit = (weekday + 5) % 7  // ma=0 ... sø=6
        return (band.dayMask & (1 << bit)) != 0
    }

    // MARK: - Bånd-overlay (rendres over dag-celler i ZStack)

    @ViewBuilder
    private func bandsOverlay(week: WeekRow) -> some View {
        GeometryReader { g in
            let totalSpacing = cellSpacing * 6
            let cellWidth = max(0, (g.size.width - totalSpacing) / 7)

            ForEach(bands, id: \.id) { band in
                let segs = bandSegmentsInWeek(band, week: week)
                let lane = bandLaneAssignment[band.id] ?? 0
                ForEach(segs.indices, id: \.self) { i in
                    let seg = segs[i]
                    let palette = bandPalette(for: band)
                    let xOffset = CGFloat(seg.start) * (cellWidth + cellSpacing)
                    let width = CGFloat(seg.end - seg.start + 1) * cellWidth + CGFloat(seg.end - seg.start) * cellSpacing
                    let yOffset = bandStartY + CGFloat(lane) * (bandHeight + bandSpacing)

                    Button {
                        editingBand = band
                    } label: {
                        HStack(spacing: 4) {
                            Spacer(minLength: 0)
                            Text("\(band.price) kr")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(palette.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 6)
                        .frame(width: max(0, width - 4), height: bandHeight)
                        .background(Capsule().fill(palette.bgDefault))
                    }
                    .buttonStyle(.plain)
                    .offset(x: xOffset + 2, y: yOffset)
                }
            }
        }
    }

    /// Bestem hvilke kolonner i uken båndet dekker (kontinuerlige segmenter).
    private func bandSegmentsInWeek(_ band: WizardPricingBand, week: WeekRow) -> [(start: Int, end: Int)] {
        guard let bStart = band.startDate, let bEnd = band.endDate else { return [] }
        var segments: [(Int, Int)] = []
        var currentStart: Int? = nil

        for col in 0..<7 {
            guard let date = week.days[col] else {
                if let s = currentStart {
                    segments.append((s, col - 1))
                    currentStart = nil
                }
                continue
            }
            let iso = Self.isoFormatter.string(from: date)
            let included = iso >= bStart && iso <= bEnd && bandDayMaskMatches(band, date: date)
            if included {
                if currentStart == nil { currentStart = col }
            } else {
                if let s = currentStart {
                    segments.append((s, col - 1))
                    currentStart = nil
                }
            }
        }
        if let s = currentStart {
            segments.append((s, 6))
        }
        return segments
    }

    // MARK: - Palette (matcher parking eksakt)

    private func bandPalette(for band: WizardPricingBand) -> BandPalette {
        let palettes = WizardPricingCalendarView.bandPalettes
        if let chosen = band.colorIndex, palettes.indices.contains(chosen) {
            return palettes[chosen]
        }
        let idx = abs(band.id.hashValue) % palettes.count
        return palettes[idx]
    }

    // MARK: - Weeks-for-month helper (samme som parking)

    private struct WeekRow: Identifiable {
        let id: String
        let days: [Date?]
        let key: WeekKey
    }

    private func weeksFor(_ monthStart: Date) -> [WeekRow] {
        let cal = Self.osloCalendar
        guard let monthInterval = cal.dateInterval(of: .month, for: monthStart) else { return [] }
        let monthEnd = cal.date(byAdding: .day, value: -1, to: monthInterval.end) ?? monthInterval.start

        var rows: [WeekRow] = []
        guard let firstWeekStart = cal.dateInterval(of: .weekOfYear, for: monthInterval.start)?.start else { return [] }

        var weekStart = firstWeekStart
        while weekStart < monthInterval.end {
            var days: [Date?] = []
            for offset in 0..<7 {
                let d = cal.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
                let inMonth = d >= monthInterval.start && d <= monthEnd
                days.append(inMonth ? d : nil)
            }

            let yearWeek = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)
            let year = yearWeek.yearForWeekOfYear ?? 2026
            let week = yearWeek.weekOfYear ?? 1
            let key = WeekKey(year: year, weekNum: week)
            let id = "\(monthStart.timeIntervalSince1970)-\(year)-\(week)"
            rows.append(WeekRow(id: id, days: days, key: key))

            guard let next = cal.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = next
        }
        return rows
    }

    // MARK: - FAB (matcher parking eksakt)

    private var fabAddBand: some View {
        Button {
            showCreateSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("Nytt bånd")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.neutral900)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func defaultNewBand() -> WizardPricingBand {
        let cal = Self.osloCalendar
        let start = Date()
        let end = cal.date(byAdding: .day, value: 13, to: start) ?? start
        return WizardPricingBand(
            dayMask: 0,
            price: basePerNight > 0 ? basePerNight : 500,
            colorIndex: bands.count % WizardPricingCalendarView.bandPalettes.count,
            startDate: Self.isoFormatter.string(from: start),
            endDate: Self.isoFormatter.string(from: end)
        )
    }

    // MARK: - Editor sheet

    private func seasonBandEditorSheet(initial: WizardPricingBand, isEditing: Bool) -> some View {
        SeasonBandEditor(
            initial: initial,
            isEditing: isEditing,
            palette: WizardPricingCalendarView.bandPalettes,
            onSave: { saved in
                var avail = form.availability(for: spotId)
                if let idx = avail.bands.firstIndex(where: { $0.id == saved.id }) {
                    avail.bands[idx] = saved
                } else {
                    avail.bands.append(saved)
                }
                form.setAvailability(avail, for: spotId)
                showCreateSheet = false
                editingBand = nil
            },
            onDelete: isEditing ? { id in
                var avail = form.availability(for: spotId)
                avail.bands.removeAll { $0.id == id }
                avail.bandPriceOverrides.removeAll { $0.bandId == id }
                form.setAvailability(avail, for: spotId)
                editingBand = nil
            } : nil,
            onCancel: {
                showCreateSheet = false
                editingBand = nil
            }
        )
    }
}

// MARK: - Season-bånd editor (sheet-content)

private struct SeasonBandEditor: View {
    let initial: WizardPricingBand
    let isEditing: Bool
    let palette: [BandPalette]
    let onSave: (WizardPricingBand) -> Void
    let onDelete: ((UUID) -> Void)?
    let onCancel: () -> Void

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var price: Int
    @State private var priceText: String
    @State private var dayMaskChoice: DayMaskChoice
    @State private var colorIndex: Int
    @State private var showDeleteConfirm = false

    enum DayMaskChoice: Int, CaseIterable {
        case all = 0
        case weekendsOnly = 1
        case weekdaysOnly = 2

        var label: String {
            switch self {
            case .all: return "Alle dager"
            case .weekendsOnly: return "Kun helger"
            case .weekdaysOnly: return "Kun ukedager"
            }
        }

        var dayMask: Int {
            switch self {
            case .all: return 0
            case .weekendsOnly: return (1 << 4) | (1 << 5) | (1 << 6)
            case .weekdaysOnly: return (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3)
            }
        }

        static func from(dayMask: Int) -> DayMaskChoice {
            if dayMask == 0 { return .all }
            if dayMask == (1 << 4) | (1 << 5) | (1 << 6) { return .weekendsOnly }
            if dayMask == (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) { return .weekdaysOnly }
            return .all
        }
    }

    init(
        initial: WizardPricingBand,
        isEditing: Bool,
        palette: [BandPalette],
        onSave: @escaping (WizardPricingBand) -> Void,
        onDelete: ((UUID) -> Void)?,
        onCancel: @escaping () -> Void
    ) {
        self.initial = initial
        self.isEditing = isEditing
        self.palette = palette
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let start = (initial.startDate.flatMap { f.date(from: $0) }) ?? Date()
        let end = (initial.endDate.flatMap { f.date(from: $0) }) ?? Date()
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end)
        _price = State(initialValue: initial.price)
        _priceText = State(initialValue: "\(initial.price)")
        _dayMaskChoice = State(initialValue: DayMaskChoice.from(dayMask: initial.dayMask))
        _colorIndex = State(initialValue: initial.colorIndex ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Periode") {
                    DatePicker("Fra", selection: $startDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "nb_NO"))
                    DatePicker("Til", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "nb_NO"))
                }

                Section("Hvilke dager?") {
                    Picker("Dager", selection: $dayMaskChoice) {
                        ForEach(DayMaskChoice.allCases, id: \.self) { choice in
                            Text(choice.label).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Pris per natt") {
                    HStack {
                        TextField("0", text: $priceText)
                            .keyboardType(.numberPad)
                            .font(.system(size: 22, weight: .bold))
                            .onChange(of: priceText) { _, new in
                                let cleaned = new.filter(\.isNumber)
                                if cleaned != new { priceText = cleaned }
                                price = Int(cleaned) ?? 0
                            }
                        Text("kr")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.neutral500)
                    }
                }

                Section("Farge") {
                    HStack(spacing: 12) {
                        ForEach(0..<palette.count, id: \.self) { idx in
                            Button {
                                colorIndex = idx
                            } label: {
                                Circle()
                                    .fill(palette[idx].bgDefault)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if colorIndex == idx {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .overlay(
                                        Circle().stroke(colorIndex == idx ? Color.neutral900 : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if isEditing, let onDelete {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Slett bånd")
                            }
                        }
                        .confirmationDialog("Slett bånd?", isPresented: $showDeleteConfirm) {
                            Button("Slett", role: .destructive) {
                                onDelete(initial.id)
                            }
                            Button("Avbryt", role: .cancel) {}
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Rediger bånd" : "Nytt bånd")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lagre") {
                        save()
                    }
                    .disabled(price <= 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        var band = initial
        band.startDate = f.string(from: startDate)
        band.endDate = f.string(from: endDate)
        band.price = price
        band.dayMask = dayMaskChoice.dayMask
        band.colorIndex = colorIndex
        band.startHour = 0
        band.startMinute = 0
        band.endHour = 24
        band.endMinute = 0
        onSave(band)
    }
}
