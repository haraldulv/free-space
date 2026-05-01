import SwiftUI

/// Camping-versjon av bånd-kalenderen. Visuelt IDENTISK med
/// `WizardPricingCalendarView` — samme cellHeight, weekday-header, FAB,
/// color-picker, dag-celler med pris under, og samme mørke glass-card-stil i
/// editor-action-baren. Eneste forskjell: bånd er sesongperioder med dato-
/// range (start_date / end_date) i stedet for time-range, og editor-baren
/// viser to dato-pillen i stedet for time-wheels.
struct WizardSeasonalCalendarView: View {
    @ObservedObject var form: ListingFormModel
    let spotId: String

    @State private var mode: SeasonalMode = .idle
    @State private var draft: WizardPricingBand? = nil
    @State private var draftPriceText: String = ""
    @FocusState private var draftPriceFocused: Bool
    @State private var showDeleteConfirm: Bool = false
    @State private var showColorPalette: Bool = false
    @State private var showStartPicker: Bool = false
    @State private var showEndPicker: Bool = false
    @State private var hasScrolledToCurrent = false

    enum SeasonalMode: Equatable {
        case idle
        case bandCreate
        case bandEdit(UUID)
    }

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

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d. MMM"
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
                    .padding(.bottom, 220)  // plass for action-bar
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
            if mode == .idle {
                fabAddBand
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom) {
            switch mode {
            case .idle:
                EmptyView()
            case .bandCreate, .bandEdit:
                bandEditorActionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: mode)
        .onChange(of: draftPriceFocused) { _, focused in
            if focused {
                draftPriceText = ""
            } else {
                commitDraftPrice()
            }
        }
        .confirmationDialog(
            "Slett bånd?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Slett bånd", role: .destructive) { deleteEditingBand() }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Båndet og pris-overstyringene som tilhører det fjernes.")
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
        let bit = (weekday + 5) % 7
        return (band.dayMask & (1 << bit)) != 0
    }

    // MARK: - Bånd-overlay

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
                        openBandEdit(band)
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

    private func bandPalette(for band: WizardPricingBand) -> BandPalette {
        let palettes = WizardPricingCalendarView.bandPalettes
        if let chosen = band.colorIndex, palettes.indices.contains(chosen) {
            return palettes[chosen]
        }
        let idx = abs(band.id.hashValue) % palettes.count
        return palettes[idx]
    }

    // MARK: - Weeks-for-month

    private struct WeekRow: Identifiable {
        let id: String
        let days: [Date?]
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
            let id = "\(monthStart.timeIntervalSince1970)-\(weekStart.timeIntervalSince1970)"
            rows.append(WeekRow(id: id, days: days))

            guard let next = cal.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = next
        }
        return rows
    }

    // MARK: - FAB

    private var fabAddBand: some View {
        Button {
            openBandCreate()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("Nytt bånd")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.neutral900)
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Band editor action bar (mørk glass-stil — matcher parking)

    private var bandEditorActionBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                bandTitlePill
                Spacer()
                Button {
                    closeActionBar()
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

            bandEditorCard
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .padding(.top, 10)
    }

    private var bandTitlePill: some View {
        let label: String = {
            guard let d = draft, let s = d.startDate, let e = d.endDate,
                  let sd = Self.isoFormatter.date(from: s),
                  let ed = Self.isoFormatter.date(from: e) else {
                return "Nytt bånd"
            }
            return "\(weekdaysShortLabel(mask: d.dayMask)) · \(Self.shortDateFormatter.string(from: sd)) – \(Self.shortDateFormatter.string(from: ed))"
        }()
        return HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(glassPillBackground)
    }

    private var bandEditorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Rad 1: ukedager + farge-swatch
            HStack(spacing: 6) {
                weekdayStrip
                inlineColorSwatch
            }
            // Rad 2: Periode (to dato-knapper) + Pris
            HStack(alignment: .bottom, spacing: 10) {
                bandDateCard
                    .frame(maxWidth: .infinity)
                bandPriceCard
                    .frame(width: 130)
            }
            if case .bandEdit = mode {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Text("Slett bånd")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "#fca5a5"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(hex: "#fca5a5").opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(glassCardBackground)
    }

    // MARK: - Color swatch + palette

    private var inlineColorSwatch: some View {
        Button {
            showColorPalette = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(activePaletteColor)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 1.5))
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(activePaletteColor)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(Color.white))
                    .offset(x: 4, y: 4)
            }
            .frame(width: 40, height: 36)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showColorPalette) {
            colorPaletteSheet
                .presentationDetents([.height(160)])
                .presentationDragIndicator(.visible)
        }
    }

    private var activePaletteColor: Color {
        let palettes = WizardPricingCalendarView.bandPalettes
        guard let d = draft else { return palettes[0].bgDefault }
        if let idx = d.colorIndex, palettes.indices.contains(idx) {
            return palettes[idx].bgDefault
        }
        let idx = abs(d.id.hashValue) % palettes.count
        return palettes[idx].bgDefault
    }

    private var colorPaletteSheet: some View {
        let palettes = WizardPricingCalendarView.bandPalettes
        return VStack(spacing: 14) {
            Text("Farge")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.neutral900)
            HStack(spacing: 18) {
                ForEach(0..<palettes.count, id: \.self) { idx in
                    let palette = palettes[idx]
                    let selected = (draft?.colorIndex ?? -1) == idx
                    Button {
                        setDraftColor(idx)
                        showColorPalette = false
                    } label: {
                        ZStack {
                            Circle()
                                .fill(palette.bgDefault)
                                .frame(width: 44, height: 44)
                            if selected {
                                Circle()
                                    .stroke(Color.neutral900, lineWidth: 2.5)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.neutral900)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Weekday strip (matcher parking)

    private var weekdayStrip: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { bit in
                let mask = draft?.dayMask ?? 0
                // dayMask=0 betyr "alle dager" — vis alle som "på" visuelt.
                let isOn = mask == 0 || (mask & (1 << bit)) != 0
                Button {
                    toggleDraftDayBit(bit)
                } label: {
                    Text(weekdayLetter(bit))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isOn ? Color.neutral900 : Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(isOn ? Color.white : Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(isOn ? Color.white : Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func weekdayLetter(_ bit: Int) -> String {
        ["M", "T", "O", "T", "F", "L", "S"][bit]
    }

    private func weekdaysShortLabel(mask: Int) -> String {
        if mask == 0 { return "Alle dager" }
        var parts: [String] = []
        for bit in 0..<7 where (mask & (1 << bit)) != 0 {
            parts.append(["Ma", "Ti", "On", "To", "Fr", "Lø", "Sø"][bit])
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Date card (to dato-knapper i mørk-stil)

    private var bandDateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Periode")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                datePickerButton(
                    title: "Fra",
                    binding: bandStartDateBinding,
                    isPresented: $showStartPicker,
                    range: nil
                )
                datePickerButton(
                    title: "Til",
                    binding: bandEndDateBinding,
                    isPresented: $showEndPicker,
                    range: bandStartDateBinding.wrappedValue...
                )
            }
        }
    }

    @ViewBuilder
    private func datePickerButton(
        title: String,
        binding: Binding<Date>,
        isPresented: Binding<Bool>,
        range: PartialRangeFrom<Date>?
    ) -> some View {
        Button {
            isPresented.wrappedValue = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text(Self.shortDateFormatter.string(from: binding.wrappedValue))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .frame(height: 96)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: isPresented) {
            datePickerSheet(
                title: title,
                binding: binding,
                range: range,
                isPresented: isPresented
            )
        }
    }

    @ViewBuilder
    private func datePickerSheet(
        title: String,
        binding: Binding<Date>,
        range: PartialRangeFrom<Date>?,
        isPresented: Binding<Bool>
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Ferdig") { isPresented.wrappedValue = false }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary600)
            }
            .padding(20)
            Group {
                if let range = range {
                    DatePicker("", selection: binding, in: range, displayedComponents: .date)
                } else {
                    DatePicker("", selection: binding, displayedComponents: .date)
                }
            }
            .datePickerStyle(.graphical)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "nb_NO"))
            .environment(\.calendar, Self.osloCalendar)
            .padding(.horizontal, 16)
            Spacer(minLength: 0)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var bandStartDateBinding: Binding<Date> {
        Binding(
            get: {
                draft?.startDate.flatMap { Self.isoFormatter.date(from: $0) } ?? Date()
            },
            set: { newValue in
                let iso = Self.isoFormatter.string(from: newValue)
                if var d = draft {
                    d.startDate = iso
                    // Hold endDate >= startDate
                    if let endStr = d.endDate, let endDate = Self.isoFormatter.date(from: endStr), endDate < newValue {
                        d.endDate = iso
                    }
                    draft = d
                }
            }
        )
    }

    private var bandEndDateBinding: Binding<Date> {
        Binding(
            get: {
                draft?.endDate.flatMap { Self.isoFormatter.date(from: $0) } ?? Date()
            },
            set: { newValue in
                if var d = draft {
                    d.endDate = Self.isoFormatter.string(from: newValue)
                    draft = d
                }
            }
        )
    }

    // MARK: - Price card (matcher parking)

    private var bandPriceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pris per natt")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            HStack(spacing: 6) {
                Button {
                    stepDraftPrice(by: -50)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.5))
                }
                .buttonStyle(.plain)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    TextField("", text: $draftPriceText)
                        .focused($draftPriceFocused)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(minWidth: 28, maxWidth: 60)
                    Text("kr")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(maxWidth: .infinity)

                Button {
                    stepDraftPrice(by: 50)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .frame(height: 96)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
    }

    // MARK: - Glass backgrounds (kopi av parking)

    private var glassPillBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .overlay(Capsule().fill(Color.black.opacity(0.55)))
            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    private var glassCircleBackground: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .overlay(Circle().fill(Color.black.opacity(0.55)))
            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

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

    // MARK: - Mode helpers

    private func openBandCreate() {
        let cal = Self.osloCalendar
        let start = Date()
        let end = cal.date(byAdding: .day, value: 13, to: start) ?? start
        let newBand = WizardPricingBand(
            dayMask: 0,
            price: basePerNight > 0 ? basePerNight : 500,
            colorIndex: bands.count % WizardPricingCalendarView.bandPalettes.count,
            startDate: Self.isoFormatter.string(from: start),
            endDate: Self.isoFormatter.string(from: end)
        )
        draft = newBand
        draftPriceText = "\(newBand.price)"
        mode = .bandCreate
    }

    private func openBandEdit(_ band: WizardPricingBand) {
        draft = band
        draftPriceText = "\(band.price)"
        mode = .bandEdit(band.id)
    }

    private func closeActionBar() {
        // Lagre draft til availability
        if let d = draft {
            commitDraftPrice()
            var avail = form.availability(for: spotId)
            if let updated = draft, let idx = avail.bands.firstIndex(where: { $0.id == d.id }) {
                avail.bands[idx] = updated
            } else if let updated = draft {
                avail.bands.append(updated)
            }
            form.setAvailability(avail, for: spotId)
        }
        draft = nil
        draftPriceFocused = false
        mode = .idle
    }

    private func deleteEditingBand() {
        guard case .bandEdit(let id) = mode else { return }
        var avail = form.availability(for: spotId)
        avail.bands.removeAll { $0.id == id }
        avail.bandPriceOverrides.removeAll { $0.bandId == id }
        form.setAvailability(avail, for: spotId)
        draft = nil
        mode = .idle
    }

    private func toggleDraftDayBit(_ bit: Int) {
        guard var d = draft else { return }
        let mask = d.dayMask
        if mask == 0 {
            // "alle" → toggle: skru AV den ene biten (alle bortsett fra denne)
            d.dayMask = (~(1 << bit)) & 0b1111111  // 7 bits
        } else {
            let toggled = mask ^ (1 << bit)
            // Hvis alle 7 bits er på → tilbake til "alle dager" (0)
            d.dayMask = (toggled == 0b1111111) ? 0 : toggled
        }
        draft = d
    }

    private func setDraftColor(_ idx: Int) {
        guard var d = draft else { return }
        d.colorIndex = idx
        draft = d
    }

    private func stepDraftPrice(by delta: Int) {
        guard var d = draft else { return }
        d.price = max(0, d.price + delta)
        draft = d
        draftPriceText = "\(d.price)"
    }

    private func commitDraftPrice() {
        guard var d = draft else { return }
        let parsed = Int(draftPriceText.filter(\.isNumber)) ?? 0
        d.price = max(0, parsed)
        draft = d
        if !draftPriceFocused {
            draftPriceText = "\(d.price)"
        }
    }
}
