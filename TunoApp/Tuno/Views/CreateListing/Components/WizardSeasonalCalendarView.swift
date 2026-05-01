import SwiftUI

/// Camping-versjon av wizardens kalender. Gjenbruker måneds-grid-stilen fra
/// `WizardPricingCalendarView`, men "bånd" er sesongperioder med dato-range
/// (start_date / end_date) i stedet for time-range. Brukes både i camping-
/// wizardens pris-variasjon-steg og i Profile-kalenderen for camping.
///
/// Bånd vises som streker som spenner over dagene innenfor [startDate, endDate]
/// (filtrert på dayMask hvis satt). Tap på et bånd åpner editor-sheet; FAB-
/// knappen lager nytt bånd.
struct WizardSeasonalCalendarView: View {
    @ObservedObject var form: ListingFormModel
    let spotId: String

    @State private var editingBand: WizardPricingBand? = nil
    @State private var showCreateSheet: Bool = false
    @State private var hasScrolledToCurrent = false

    private let monthsAhead = 11
    private let cellHeight: CGFloat = 64
    private let bandHeight: CGFloat = 18
    private let bandSpacing: CGFloat = 3

    private var availability: WizardSpotAvailability { form.availability(for: spotId) }
    private var bands: [WizardPricingBand] {
        availability.bands.filter { $0.isSeasonal }
    }

    private var basePerNight: Int {
        form.spotMarkers.first(where: { $0.id == spotId })?.pricePerNight
            ?? form.spotMarkers.first(where: { $0.id == spotId })?.price
            ?? 0
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

    /// Fargepalett (matcher parking-kalenderen).
    private static let bandPalette: [Color] = [
        Color(red: 0.20, green: 0.74, blue: 0.49),  // grønn (Tuno)
        Color(red: 0.62, green: 0.51, blue: 0.96),  // lavendel
        Color(red: 1.00, green: 0.65, blue: 0.20),  // oransje
        Color(red: 0.27, green: 0.58, blue: 0.96),  // blå
        Color(red: 0.95, green: 0.45, blue: 0.65),  // rosa
    ]

    private func colorFor(_ band: WizardPricingBand) -> Color {
        let idx = band.colorIndex ?? abs(band.id.hashValue) % Self.bandPalette.count
        return Self.bandPalette[idx % Self.bandPalette.count]
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

            monthGrid(monthStart)
        }
    }

    private func monthGrid(_ monthStart: Date) -> some View {
        let cal = Self.osloCalendar
        let weeks = weeksInMonth(monthStart)
        return VStack(spacing: 6) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                weekRow(week, monthStart: monthStart, cal: cal)
            }
        }
        .padding(.horizontal, 12)
    }

    private func weekRow(_ week: [Date?], monthStart: Date, cal: Calendar) -> some View {
        // Lay-out: HStack med 7 celler. Bånd som dekker N påfølgende celler tegnes
        // som overlay over cellene.
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                    dayCell(date, monthStart: monthStart, cal: cal)
                }
            }
            // Bånd-overlay
            ForEach(bandsThatTouchWeek(week)) { band in
                bandStripeOverlay(band, week: week)
            }
        }
        .frame(height: cellHeight)
    }

    private func dayCell(_ date: Date?, monthStart: Date, cal: Calendar) -> some View {
        let inMonth = date.map { cal.isDate($0, equalTo: monthStart, toGranularity: .month) } ?? false
        let day = date.map { cal.component(.day, from: $0) } ?? 0
        return VStack {
            if let _ = date, inMonth {
                Text("\(day)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isToday(date) ? Color.primary600 : .neutral800)
                    .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: cellHeight)
    }

    private func isToday(_ date: Date?) -> Bool {
        guard let date else { return false }
        let cal = Self.osloCalendar
        return cal.isDateInToday(date)
    }

    /// Tegner en horisontal stripe for bånd over dagene som matcher i denne uken.
    /// Bånd som spenner over flere uker rendres separat i hver uke (med kantende
    /// rounding på den uken båndet starter/slutter).
    @ViewBuilder
    private func bandStripeOverlay(_ band: WizardPricingBand, week: [Date?]) -> some View {
        let segments = bandSegmentsInWeek(band, week: week)
        ForEach(Array(segments.enumerated()), id: \.offset) { idx, segment in
            let lane = laneFor(band: band)
            let yOffset = CGFloat(lane) * (bandHeight + bandSpacing) + 26
            GeometryReader { geo in
                let cellW = geo.size.width / 7
                let x = CGFloat(segment.startCol) * cellW
                let w = CGFloat(segment.endCol - segment.startCol + 1) * cellW

                Button {
                    editingBand = band
                } label: {
                    HStack(spacing: 4) {
                        Text("\(band.price) kr")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .frame(width: max(0, w - 4), height: bandHeight)
                    .background(colorFor(band))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .position(x: x + w / 2, y: yOffset + bandHeight / 2)
                }
                .buttonStyle(.plain)
                .id("\(band.id)-\(idx)")
            }
            .frame(height: cellHeight)
            .allowsHitTesting(true)
        }
    }

    /// Bestemmer en stabil "lane" per bånd så overlapper ikke kolliderer.
    private func laneFor(band: WizardPricingBand) -> Int {
        var laneMasks: [(start: String, end: String)] = []
        for b in bands {
            if b.id == band.id {
                return laneMasks.firstIndex { existing in
                    !rangesOverlap(existing, (b.startDate ?? "", b.endDate ?? ""))
                } ?? laneMasks.count
            }
            // Tildel midlertidig lane
            if let lane = laneMasks.firstIndex(where: { existing in
                !rangesOverlap(existing, (b.startDate ?? "", b.endDate ?? ""))
            }) {
                laneMasks[lane] = (b.startDate ?? "", b.endDate ?? "")
            } else {
                laneMasks.append((b.startDate ?? "", b.endDate ?? ""))
            }
        }
        return 0
    }

    private func rangesOverlap(_ a: (start: String, end: String), _ b: (start: String, end: String)) -> Bool {
        return !(a.end < b.start || b.end < a.start)
    }

    private struct WeekSegment {
        let startCol: Int
        let endCol: Int
    }

    private func bandSegmentsInWeek(_ band: WizardPricingBand, week: [Date?]) -> [WeekSegment] {
        guard let bStart = band.startDate, let bEnd = band.endDate else { return [] }
        var segments: [WeekSegment] = []
        var currentStart: Int? = nil

        for (col, dateOpt) in week.enumerated() {
            guard let date = dateOpt else {
                if let s = currentStart {
                    segments.append(WeekSegment(startCol: s, endCol: col - 1))
                    currentStart = nil
                }
                continue
            }
            let iso = Self.isoFormatter.string(from: date)
            let withinRange = iso >= bStart && iso <= bEnd
            let dayMatchesMask: Bool = {
                if band.dayMask == 0 { return true }  // 0 = alle dager
                let cal = Self.osloCalendar
                let wd = cal.component(.weekday, from: date)
                let bit = wd == 1 ? 6 : wd - 2  // ma=0 ... sø=6
                return (band.dayMask & (1 << bit)) != 0
            }()
            let included = withinRange && dayMatchesMask

            if included {
                if currentStart == nil { currentStart = col }
            } else {
                if let s = currentStart {
                    segments.append(WeekSegment(startCol: s, endCol: col - 1))
                    currentStart = nil
                }
            }
        }
        if let s = currentStart {
            segments.append(WeekSegment(startCol: s, endCol: 6))
        }
        return segments
    }

    private func bandsThatTouchWeek(_ week: [Date?]) -> [WizardPricingBand] {
        let dates = week.compactMap { $0 }
        guard let first = dates.first, let last = dates.last else { return [] }
        let firstISO = Self.isoFormatter.string(from: first)
        let lastISO = Self.isoFormatter.string(from: last)
        return bands.filter { band in
            guard let bStart = band.startDate, let bEnd = band.endDate else { return false }
            return !(bEnd < firstISO || bStart > lastISO)
        }
    }

    private func weeksInMonth(_ monthStart: Date) -> [[Date?]] {
        let cal = Self.osloCalendar
        guard let monthInterval = cal.dateInterval(of: .month, for: monthStart) else { return [] }
        let monthEnd = cal.date(byAdding: .day, value: -1, to: monthInterval.end) ?? monthInterval.start
        guard let firstWeek = cal.dateInterval(of: .weekOfMonth, for: monthInterval.start) else { return [] }

        var weeks: [[Date?]] = []
        var weekStart = firstWeek.start
        while weekStart < monthInterval.end {
            var week: [Date?] = []
            for offset in 0..<7 {
                let d = cal.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
                let inMonth = d >= monthInterval.start && d <= monthEnd
                week.append(inMonth ? d : nil)
            }
            weeks.append(week)
            guard let next = cal.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = next
        }
        return weeks
    }

    // MARK: - FAB

    private var fabAddBand: some View {
        Button {
            showCreateSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("Nytt sesong-bånd")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.primary600)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
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
            colorIndex: bands.count % Self.bandPalette.count,
            startDate: Self.isoFormatter.string(from: start),
            endDate: Self.isoFormatter.string(from: end)
        )
    }

    // MARK: - Editor sheet

    private func seasonBandEditorSheet(initial: WizardPricingBand, isEditing: Bool) -> some View {
        SeasonBandEditor(
            initial: initial,
            isEditing: isEditing,
            palette: Self.bandPalette,
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
    let palette: [Color]
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
            case .weekendsOnly: return (1 << 4) | (1 << 5) | (1 << 6)  // fr, lø, sø
            case .weekdaysOnly: return (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3)  // ma-to
            }
        }

        static func from(dayMask: Int) -> DayMaskChoice {
            if dayMask == 0 { return .all }
            if dayMask == (1 << 4) | (1 << 5) | (1 << 6) { return .weekendsOnly }
            if dayMask == (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) { return .weekdaysOnly }
            return .all  // fallback
        }
    }

    init(
        initial: WizardPricingBand,
        isEditing: Bool,
        palette: [Color],
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
                                    .fill(palette[idx])
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
        // Sett start/end-time til døgn-grenser så server-pricing skiller season fra hourly.
        band.startHour = 0
        band.startMinute = 0
        band.endHour = 24
        band.endMinute = 0
        onSave(band)
    }
}
