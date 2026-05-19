import SwiftUI
import UIKit

/// Pris-variasjon-kalender per plass — Airbnb-inspirert fullskjerm-design.
/// Sticky ukedag-header øverst. Multi-måned grid med store dato-celler som
/// viser dato + bånd-bars (samme y-linje) + effektiv pris. Tap-anker for
/// multi-select. Glassmorphism action-bar i bunn med Tilgjengelig-toggle og
/// inline pris-editor.
enum CalendarMode: Equatable {
    case idle
    case dateOverride
    case bandEdit(UUID)
    case bandCreate
}

/// Aggregerer cell-frames fra alle dayCells slik at DragGesture kan slå opp
/// hvilken dato finger-koordinatet treffer i `named("calendarGrid")`-rommet.
/// Merge bevarer nyeste verdi pr iso-key (under-scrolling kan re-rapportere).
struct CellFramesPreference: PreferenceKey {
    // Swift 6 strict-concurrency: PreferenceKey-protokollen krever `var` på
    // defaultValue, men kompilatoren tolker det som global mutable state.
    // nonisolated(unsafe) er standardpatternet for å si "vi vet hva vi gjør".
    nonisolated(unsafe) static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct WizardPricingCalendarView: View {
    @ObservedObject var form: ListingFormModel
    let spotId: String

    @State private var mode: CalendarMode = .idle
    @State private var selectedDates: Set<String> = []
    @State private var hasScrolledToCurrent = false

    // MARK: - Drag-select state (iOS 18)
    /// True mens fingeren er nede og DragGesture er aktiv. Brukes til å låse
    /// ScrollView så drag-bevegelse ikke trigger scroll.
    @State private var isDragging: Bool = false
    /// Bestemmer toggle-retning: hvis drag startet på en valgt celle, fjerner
    /// vi datoer; ellers legger vi til. Mimicker Apple sin Reminders-app.
    @State private var dragStartedOnSelected: Bool = false
    /// Datoer drag-en har besøkt i denne gestus-sesjonen — brukes for å
    /// unngå dobbel-toggling samme celle.
    @State private var dragVisited: Set<String> = []
    /// Cell-frame lookup i navngitt coordinate space "calendarGrid".
    /// Aggregert via PreferenceKey fra hver dayCell.
    @State private var cellFrames: [String: CGRect] = [:]

    // MARK: - Panel-minimer state
    /// True når bunn-panelet er kollapset til kun pille + reset + maks-knapp.
    /// Auto-trigges på scroll ned, manuelt toggles via X / chevron.up.
    @State private var panelMinimized: Bool = false
    /// Seneste scroll-offset for delta-beregning i onScrollGeometryChange.
    @State private var lastScrollY: CGFloat = 0
    @State private var priceEditValue: Int = 0
    @FocusState private var priceEditFocused: Bool

    /// Sub-modus for action-baren: vis tilgjengelighet+pris (default) eller
    /// inline åpningstid-editor.
    private enum ActionBarSubMode { case availability, openingHours }
    @State private var actionBarSubMode: ActionBarSubMode = .availability

    /// State for inline åpningstid-editor. Stenging skjer via
    /// Tilgjengelig-toggle (blockedDates), IKKE via åpningstid — derfor kun
    /// to valg: Døgnåpent eller Egne tider.
    private enum OHEditorMode { case allDay, otherTime }
    @State private var ohEditorMode: OHEditorMode = .otherTime
    @State private var ohStartTime: Date = Self.defaultStartTime()
    @State private var ohEndTime: Date = Self.defaultEndTime()

    // Band-editor draft state
    @State private var draft: WizardPricingBand? = nil
    @State private var draftPriceValue: Int = 0
    @State private var draftPriceText: String = ""
    @FocusState private var draftPriceFocused: Bool
    @State private var showDeleteConfirm: Bool = false
    /// Når true vises hele palett-raden i stedet for kompakt single-swatch.
    @State private var showColorPalette: Bool = false
    /// Tikker som bumpes når en wheel-endring rejectes (overlap). Trigger
    /// SwiftUI re-render slik at DarkWheelPicker.updateUIView reverterer
    /// visuelt til den gyldige verdien fra draft.
    @State private var wheelRevertTick: Int = 0

    private let monthsAhead = 6
    private let cellHeight: CGFloat = 95
    private let cellSpacing: CGFloat = 6
    /// Default-høyde per bånd. Skaleres ned dynamisk om mange lanes finnes
    /// slik at stacken aldri sprenger cellHeight.
    private let bandHeight: CGFloat = 22
    private let bandSpacing: CGFloat = 3
    private let bandMinHeight: CGFloat = 14

    /// Antall lanes som faktisk er i bruk (= max lane + 1).
    private var totalLanes: Int {
        (bandLaneAssignment.values.max() ?? -1) + 1
    }

    /// Effektiv bånd-høyde. Krymper fra 22 ned mot bandMinHeight (14) når
    /// totalLanes >= 5, slik at hele stacken får plass innenfor cellHeight.
    /// Forhindrer "kalender forstrekkes med flere bånd"-buggen.
    private var effectiveBandHeight: CGFloat {
        guard totalLanes > 0 else { return bandHeight }
        let availableHeight = cellHeight - 16 // 8 top + 8 bottom padding
        let totalSpacing = CGFloat(max(0, totalLanes - 1)) * bandSpacing
        let computed = (availableHeight - totalSpacing) / CGFloat(totalLanes)
        return max(bandMinHeight, min(bandHeight, computed))
    }

    /// Y-koordinat for bånd-stacken slik at den er vertikalt sentrert
    /// på dag-cellen.
    private var bandStartY: CGFloat {
        let h = effectiveBandHeight
        let stackHeight = CGFloat(totalLanes) * h + CGFloat(max(0, totalLanes - 1)) * bandSpacing
        return (cellHeight - stackHeight) / 2
    }

    private var availability: WizardSpotAvailability {
        form.availability(for: spotId)
    }

    private var bands: [WizardPricingBand] { availability.bands }

    /// Tildeler hvert bånd en "lane" (vertikalt nivå) basert på faktisk
    /// dag-overlap. Bånd som ikke deler noen dag får samme lane → samme Y,
    /// så de fortsetter visuelt på samme linje istedenfor å stables unødig.
    private var bandLaneAssignment: [UUID: Int] {
        var laneMasks: [Int] = []
        var assignment: [UUID: Int] = [:]
        for band in bands {
            var lane = 0
            while lane < laneMasks.count && (laneMasks[lane] & band.dayMask) != 0 {
                lane += 1
            }
            if lane >= laneMasks.count {
                laneMasks.append(0)
            }
            laneMasks[lane] |= band.dayMask
            assignment[band.id] = lane
        }
        return assignment
    }

    /// Standardpris for plassen (kr/dag). Faller tilbake til legacy-felter
    /// (pricePerNight, pricePerHour) for å støtte eldre annonser.
    /// Brukes som referanse for å vite om en pris-overstyring faktisk
    /// avviker fra standard.
    private var basePerHour: Int {
        let s = spot
        return s?.price ?? s?.pricePerNight ?? s?.pricePerHour ?? 0
    }

    // ÅPNINGSTIDER PAUSET pre-launch — re-aktiver alle tre helpers
    // post-launch. Stubbene returnerer "ingen begrensning" så all
    // kallesteder (cell-rendering, filtre) oppfører seg som om
    // ingen åpningstid er satt.
    private var effectiveOpeningHours: OpeningHours? { nil }

    private func closedByOpeningHours(_ date: Date) -> Bool { false }

    enum CellOpeningDisplay: Equatable {
        case none
        case alwaysOpen
        case limited(String)
    }

    private func openingHoursDisplay(for date: Date) -> CellOpeningDisplay { .none }

    /* ORIGINAL — re-aktiver post-launch
    private var effectiveOpeningHours: OpeningHours? {
        spot?.openingHours ?? form.openingHours
    }

    private func closedByOpeningHours(_ date: Date) -> Bool {
        let oh = effectiveOpeningHours
        let overrides = spot?.openingHoursOverrides
        if oh == nil && (overrides?.isEmpty ?? true) { return false }
        return !OpeningHoursService.isOpen(oh, on: date, overrides: overrides)
    }

    private func openingHoursDisplay(for date: Date) -> CellOpeningDisplay {
        let oh = effectiveOpeningHours
        let overrides = spot?.openingHoursOverrides
        if oh == nil && (overrides?.isEmpty ?? true) { return .none }
        guard let raw = OpeningHoursService.effectiveTime(oh, on: date, overrides: overrides) else {
            return .none
        }
        if raw == "00:00-24:00" || raw == "00:00-23:59" { return .alwaysOpen }
        guard let parsed = OpeningHoursService.parseRange(raw) else { return .none }
        if parsed.start == 0 && parsed.end >= 23 * 60 + 59 { return .alwaysOpen }
        let startH = parsed.start / 60
        let endH = parsed.end / 60
        return .limited("\(startH)–\(endH)")
    }
    */

    private var spot: SpotMarker? {
        form.spotMarkers.first(where: { $0.id == spotId })
    }

    private var spotIndex: Int? {
        form.spotMarkers.firstIndex(where: { $0.id == spotId })
    }

    private var blockedDates: Set<String> {
        Set(spot?.blockedDates ?? [])
    }

    /// Per-dato pris-overstyringer — leses direkte fra spot.datePriceOverrides
    /// (ikke fra availability.dateOverrides, som er den utgående bånd-modellen).
    private var dateOverrides: [String: Int] {
        spot?.datePriceOverrides ?? [:]
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
        // Touch wheelRevertTick så body re-evalueres når en wheel-endring
        // rejectes — det får DarkWheelPicker til å reverter visuelt.
        let _ = wheelRevertTick
        return VStack(spacing: 0) {
            stickyWeekdayHeader

            // Kalender-grid vises alltid — også når det ikke er bånd, så vert
            // kan legge til via "+ Nytt bånd"-FAB-en.
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 18) {
                        ForEach(visibleMonths, id: \.self) { monthStart in
                            monthSection(monthStart)
                        }
                    }
                    .padding(.top, 8)
                }
                .background(Color(.systemGroupedBackground))
                .coordinateSpace(name: "calendarGrid")
                // Aggregere cell-frames fra alle dayCells i drag-mappingen.
                .onPreferenceChange(CellFramesPreference.self) { frames in
                    cellFrames = frames
                }
                // Drag-select: hold + slide trigger range-mark. simultaneousGesture
                // lar ScrollView fortsatt scrolle vertikalt når brukeren ikke
                // beveger fingeren fort nok til å trigge dragen. Når dragen
                // begynner låser vi scroll via `.scrollDisabled(isDragging)`.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12, coordinateSpace: .named("calendarGrid"))
                        .onChanged { value in
                            handleDragChanged(at: value.location, startLocation: value.startLocation)
                        }
                        .onEnded { _ in
                            commitDrag()
                        }
                )
                .scrollDisabled(isDragging)
                // Auto-minimer panel ved scroll ned. Sjekker delta >30pt slik
                // at små bevegelser (overscroll-bounce) ikke trigger.
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y
                } action: { _, newY in
                    let delta = newY - lastScrollY
                    lastScrollY = newY
                    if delta > 30, !panelMinimized, !selectedDates.isEmpty {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            panelMinimized = true
                        }
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
        // FAB "+ Nytt bånd" fjernet — bånd-modellen er erstattet med per-dato
        // pris-overstyringer + blokkering. Tap på dato → action sheet.
        .safeAreaInset(edge: .bottom) {
            switch mode {
            case .idle:
                EmptyView()
            case .dateOverride:
                dateOverrideActionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .bandEdit, .bandCreate:
                bandEditorActionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: mode)
        .onChange(of: priceEditFocused) { _, focused in
            if !focused {
                commitPriceEdit()
            }
        }
        .onChange(of: draftPriceFocused) { _, focused in
            if focused {
                // Tøm feltet ved tap så bruker kan skrive ny pris direkte.
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

            // 2. Bånd-bars i overlay (alltid samme y-koordinat innenfor uken).
            // Capsule-button konsumerer tap → åpner band-editor. Tomt område
            // utenfor capsule lar dayCell-knappen under fortsatt motta tap.
            if !bands.isEmpty {
                bandsOverlay(week: week)
                    .frame(height: cellHeight)
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
        // isAnchor fjernet — single-tap = toggle, ingen anker-konsept lenger.
        // Behold lokalvariabelen som `false` for å minimere downstream-endringer.
        let isAnchor = false
        let isBlocked = blockedDates.contains(iso)
        // hasOverride er kun true når overstyringen FAKTISK avviker fra
        // base — defensiv mot stale data der dict'en kan ha verdier lik base.
        let overrideValue = dateOverrides[iso]
        let hasOverride = overrideValue != nil && overrideValue != basePerHour
        let priceInfo = priceForDate(date)
        // Stengt etter åpningstid (f.eks. lør/søn når host har 9-17 man-fre).
        // Visuelt: samme dimming som blokkerte dager, men viser "Stengt" i
        // stedet for X — så bruker skjønner at det ikke er en manuell blokk.
        let isClosedByHours = !isPast && !isBlocked && closedByOpeningHours(date)
        let dimAsBlocked = isBlocked || isClosedByHours
        let showPrice = !isPast && !dimAsBlocked && priceInfo != nil &&
            !(dayCoveredByBand(date) && !hasOverride)
        let ohDisplay: CellOpeningDisplay = (!isPast && !dimAsBlocked)
            ? openingHoursDisplay(for: date)
            : .none

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
                        isClosedByHours: isClosedByHours,
                        hasOverride: hasOverride
                    ))
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        cellBorder(isSelected: isSelected, isAnchor: isAnchor, isPast: isPast, isBlocked: isBlocked, isClosedByHours: isClosedByHours),
                        lineWidth: isAnchor ? 2 : (isSelected || dimAsBlocked ? 1.5 : 1)
                    )

                VStack(spacing: 0) {
                    Text("\(day)")
                        .font(.system(size: 16, weight: (isSelected || isAnchor) ? .bold : .semibold))
                        .foregroundStyle(cellText(isPast: isPast, isBlocked: dimAsBlocked))
                        .padding(.top, 8)

                    Spacer(minLength: 0)

                    // Faste linjer: pris og status alltid på samme y-koordinat
                    // — uavhengig av dag-state. Tomme rader er Color.clear med
                    // samme høyde som teksten ville hatt.
                    VStack(spacing: 5) {
                        priceLine(
                            priceInfo: priceInfo,
                            show: showPrice,
                            isSelected: isSelected,
                            isAnchor: isAnchor,
                            hasOverride: hasOverride
                        )
                        statusLine(
                            isBlocked: isBlocked,
                            isClosedByHours: isClosedByHours,
                            ohDisplay: ohDisplay
                        )
                    }
                    .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: cellHeight)
        }
        .buttonStyle(.plain)
        .disabled(isPast)
        .background(
            // Rapporter cellens frame i navngitt coordinate space slik at
            // DragGesture kan mappe finger-koordinat → dato. PreferenceKey
            // aggregeres i ScrollView'en (onPreferenceChange).
            GeometryReader { geo in
                Color.clear.preference(
                    key: CellFramesPreference.self,
                    value: [iso: geo.frame(in: .named("calendarGrid"))]
                )
            }
        )
    }

    /// Pris-linje med fast høyde. Tom plassholder hvis pris ikke skal vises,
    /// slik at status-linja under blir på samme y-koordinat for alle celler.
    @ViewBuilder
    private func priceLine(
        priceInfo: ResolvedDayPrice?,
        show: Bool,
        isSelected: Bool,
        isAnchor: Bool,
        hasOverride: Bool
    ) -> some View {
        if show, let price = priceInfo {
            Text("\(price.amount) kr")
                .font(.system(size: 12, weight: hasOverride || price.isOverride ? .bold : .semibold))
                .foregroundStyle(priceTextColor(
                    isSelected: isSelected,
                    isAnchor: isAnchor,
                    isOverride: hasOverride || price.isOverride
                ))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 15)
        } else {
            Color.clear.frame(height: 15)
        }
    }

    /// Status-linje: blokkert (X), stengt-av-åpningstid ("Stengt"),
    /// døgnåpent ("24t" tekst), åpen med tider ("9–17"). Fast høyde for
    /// konsistens på tvers av celler.
    @ViewBuilder
    private func statusLine(
        isBlocked: Bool,
        isClosedByHours: Bool,
        ohDisplay: CellOpeningDisplay
    ) -> some View {
        if isBlocked || isClosedByHours {
            Text("Stengt")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 185/255, green: 28/255, blue: 28/255))
                .frame(height: 14)
        } else {
            switch ohDisplay {
            case .none:
                Color.clear.frame(height: 14)
            case .alwaysOpen:
                Text("24t")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.neutral500)
                    .frame(height: 14)
            case .limited(let label):
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.neutral500)
                    .lineLimit(1)
                    .frame(height: 14)
            }
        }
    }

    // MARK: - Cell styling

    private func cellBackground(isPast: Bool, isSelected: Bool, isAnchor: Bool, isBlocked: Bool, isClosedByHours: Bool, hasOverride: Bool) -> Color {
        if isAnchor { return Color.primary600.opacity(0.18) }
        if isSelected { return Color.primary600.opacity(0.10) }
        // Stengt = stengt: både manuelt blokkert OG av åpningstid har samme
        // visuelle stil — svak rødtone. Bruker skal ikke trenge å huske
        // hvilken kilde stengningen kommer fra.
        if isBlocked || isClosedByHours {
            return Color(red: 254/255, green: 226/255, blue: 226/255)
        }
        return Color.white
    }

    private func cellBorder(isSelected: Bool, isAnchor: Bool, isPast: Bool, isBlocked: Bool, isClosedByHours: Bool) -> Color {
        if isAnchor { return Color.primary600 }
        if isSelected { return Color.primary500 }
        if isBlocked || isClosedByHours {
            return Color(red: 252/255, green: 165/255, blue: 165/255)
        }
        if isPast { return Color.neutral100 }
        return Color.neutral200
    }

    private func cellText(isPast: Bool, isBlocked: Bool) -> Color {
        if isPast { return Color.neutral300 }
        // Stengt-tall: dempet rødtone for konsistens med "Stengt"-teksten
        if isBlocked { return Color(red: 185/255, green: 28/255, blue: 28/255).opacity(0.55) }
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

            // Maske som bare har bits satt for celler som faktisk tilhører
            // måneden (delvise uker har nil-celler i forrige/neste måned).
            let validMask = (0..<7).reduce(0) { acc, col in
                week.days[col] != nil ? acc | (1 << col) : acc
            }

            ForEach(bands, id: \.id) { band in
                let effectiveMask = band.dayMask & validMask
                let segs = bandSegments(mask: effectiveMask)
                let lane = bandLaneAssignment[band.id] ?? 0
                ForEach(segs.indices, id: \.self) { i in
                    let seg = segs[i]
                    let resolved = priceForBand(band, weekKey: week.key)
                    let isOverride = resolved.scope != nil
                    let palette = bandPalette(for: band)
                    let xOffset = CGFloat(seg.start) * (cellWidth + cellSpacing)
                    let width = CGFloat(seg.end - seg.start + 1) * cellWidth + CGFloat(seg.end - seg.start) * cellSpacing
                    let yOffset = bandStartY + CGFloat(lane) * (effectiveBandHeight + bandSpacing)

                    Button {
                        openBandEditor(band)
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
                        .padding(.horizontal, 6)
                        .frame(width: max(0, width - 4), height: effectiveBandHeight)
                        .background(
                            Capsule()
                                .fill(isOverride ? palette.bgOverride : palette.bgDefault)
                        )
                    }
                    .buttonStyle(.plain)
                    .offset(x: xOffset + 2, y: yOffset)
                }
            }
        }
    }

    /// 5 pastell-paletter. Indeks 0-4 brukes både i bandColorPicker og bandPalette.
    static let bandPalettes: [BandPalette] = [
        BandPalette(bgDefault: Color(hex: "#86d9b1").opacity(0.85), bgOverride: Color(hex: "#46c185"), border: .clear, text: .white),
        BandPalette(bgDefault: Color(hex: "#c4b5fd").opacity(0.85), bgOverride: Color(hex: "#8b5cf6"), border: .clear, text: .white),
        BandPalette(bgDefault: Color(hex: "#fdba74").opacity(0.85), bgOverride: Color(hex: "#f97316"), border: .clear, text: .white),
        BandPalette(bgDefault: Color(hex: "#93c5fd").opacity(0.85), bgOverride: Color(hex: "#3b82f6"), border: .clear, text: .white),
        BandPalette(bgDefault: Color(hex: "#f9a8d4").opacity(0.85), bgOverride: Color(hex: "#ec4899"), border: .clear, text: .white),
    ]

    /// Returner palett for et bånd. Bruker utleier-valgt colorIndex hvis satt,
    /// ellers derives fra id-hash som fallback.
    private func bandPalette(for band: WizardPricingBand) -> BandPalette {
        let palettes = Self.bandPalettes
        if let chosen = band.colorIndex, palettes.indices.contains(chosen) {
            return palettes[chosen]
        }
        let idx = abs(band.id.hashValue) % palettes.count
        return palettes[idx]
    }

    /// Sjekker om noen bånd dekker den gitte datoen (basert på ukedag-bit).
    private func dayCoveredByBand(_ date: Date) -> Bool {
        let weekday = Self.osloCalendar.component(.weekday, from: date)
        let bit = (weekday + 5) % 7
        for band in bands where (band.dayMask & (1 << bit)) != 0 {
            return true
        }
        return false
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

    private var dateOverrideActionBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                dateRangePill
                Spacer()
                // Pil = nullstill seleksjon (close action bar helt).
                // Vises bare når noe er valgt.
                if !selectedDates.isEmpty {
                    Button {
                        closeActionBar()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(glassCircleBackground)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tøm valg")
                }
                // X = minimer panel (skjul kortene, behold pill + pil).
                // Når minimert: ikonet byttes til chevron.up = maksimer-knapp.
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        panelMinimized.toggle()
                    }
                } label: {
                    Image(systemName: panelMinimized ? "chevron.up" : "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(glassCircleBackground)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(panelMinimized ? "Maksimer panel" : "Minimer panel")
            }
            .padding(.horizontal, 16)

            // Innhold bytter basert på sub-modus. Skjul ved minimer.
            if !panelMinimized {
                Group {
                    switch actionBarSubMode {
                    case .availability:
                        HStack(alignment: .top, spacing: 10) {
                            availabilityCard
                            priceCard
                        }
                    case .openingHours:
                        openingHoursInlineEditor
                    }
                }
                .padding(.horizontal, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))

                // Bunn-rad bytter også basert på modus.
                // ÅPNINGSTIDER PAUSET pre-launch — re-aktiver toggle-knappen post-launch
                Group {
                    switch actionBarSubMode {
                    case .availability:
                        EmptyView()
                        // if effectiveOpeningHours != nil {
                        //     openingHoursToggleButton
                        // }
                    case .openingHours:
                        backToAvailabilityButton
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.top, 10)
        .padding(.bottom, panelMinimized ? 12 : 0)
        .animation(.easeInOut(duration: 0.22), value: actionBarSubMode)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: panelMinimized)
    }

    /// Bunn-rad i .availability-modus: bytter til åpningstid-editor.
    private var openingHoursToggleButton: some View {
        Button {
            primeOHEditorFromSelection()
            actionBarSubMode = .openingHours
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .semibold))
                Text("Åpningstid for valgte datoer")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .background(glassCardBackground)
        }
        .buttonStyle(.plain)
    }

    /// Bunn-rad i .openingHours-modus: tilbake til tilgjengelighet/pris.
    private var backToAvailabilityButton: some View {
        Button {
            actionBarSubMode = .availability
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                Text("Tilbake til tilgjengelighet")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .background(glassCardBackground)
        }
        .buttonStyle(.plain)
    }

    /// Inline åpningstid-editor som erstatter availabilityCard+priceCard
    /// når subMode == .openingHours. Tre valg + "Egne tider"-pickere +
    /// Lagre/Fjern-knapper. Full bredde, glass-stil.
    private var openingHoursInlineEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Åpningstid for valgte datoer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                ohModeChip(label: "Døgnåpent", value: .allDay)
                ohModeChip(label: "Egne tider", value: .otherTime)
            }

            if ohEditorMode == .otherTime {
                HStack(spacing: 12) {
                    ohTimeColumn(title: "Fra", date: $ohStartTime)
                    ohTimeColumn(title: "Til", date: $ohEndTime)
                }
            }

            HStack(spacing: 8) {
                if selectionHasExistingOpeningOverride {
                    Button {
                        removeOpeningHoursOverride()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Fjern åpningstid")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(Capsule().fill(Color.white.opacity(0.14)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    applyOpeningHoursOverride()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text("Lagre")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.neutral900)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(glassCardBackground)
    }

    /// Chip-knapp i åpningstid-editoren. Valgt = hvit bg + svart tekst.
    private func ohModeChip(label: String, value: OHEditorMode) -> some View {
        let active = ohEditorMode == value
        return Button {
            ohEditorMode = value
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(active ? Color.neutral900 : .white)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(active ? Color.white : Color.white.opacity(0.12)))
                .overlay(Capsule().stroke(Color.white.opacity(active ? 0.0 : 0.20), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// Kompakt time-picker-kolonne for "Egne tider"-modus.
    private func ohTimeColumn(title: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
            DatePicker("", selection: date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .environment(\.colorScheme, .dark)
                .environment(\.locale, Locale(identifier: "nb_NO"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // ÅPNINGSTIDER PAUSET pre-launch — alle per-date override-helpers
    // er no-op-stubbet. Logikken er uberørt under kommentaren slik at vi
    // bare kan reverse-uncommente for å re-aktivere post-launch.
    private var selectionHasExistingOpeningOverride: Bool { false }
    private func primeOHEditorFromSelection() { /* paused */ }
    private func applyOpeningHoursOverride() { /* paused */ }
    private func removeOpeningHoursOverride() { /* paused */ }

    /* ORIGINAL — re-aktiver post-launch
    private var selectionHasExistingOpeningOverride: Bool {
        guard let idx = spotIndex,
              let dict = form.spotMarkers[idx].openingHoursOverrides else { return false }
        return selectedDates.contains { dict[$0] != nil }
    }

    private func primeOHEditorFromSelection() {
        guard let idx = spotIndex,
              let dict = form.spotMarkers[idx].openingHoursOverrides else {
            ohEditorMode = .otherTime
            ohStartTime = Self.defaultStartTime()
            ohEndTime = Self.defaultEndTime()
            return
        }
        let firstWithOverride = selectedDates.sorted().first { dict[$0] != nil }
        guard let iso = firstWithOverride, let ov = dict[iso] else {
            ohEditorMode = .otherTime
            ohStartTime = Self.defaultStartTime()
            ohEndTime = Self.defaultEndTime()
            return
        }
        if ov.open == "00:00-24:00" {
            ohEditorMode = .allDay
        } else if let s = ov.open, let dash = s.firstIndex(of: "-") {
            ohEditorMode = .otherTime
            let from = String(s[..<dash])
            let to = String(s[s.index(after: dash)...])
            ohStartTime = Self.parseHM(from) ?? Self.defaultStartTime()
            ohEndTime = Self.parseHM(to) ?? Self.defaultEndTime()
        } else {
            ohEditorMode = .otherTime
            ohStartTime = Self.defaultStartTime()
            ohEndTime = Self.defaultEndTime()
        }
    }

    private func applyOpeningHoursOverride() {
        guard let idx = spotIndex else { return }
        let value: DayOpeningOverride
        switch ohEditorMode {
        case .allDay:
            value = .openTimes("00:00-24:00")
        case .otherTime:
            let s = Self.formatHM(ohStartTime)
            let e = Self.formatHM(ohEndTime)
            value = .openTimes("\(s)-\(e)")
        }
        var dict = form.spotMarkers[idx].openingHoursOverrides ?? [:]
        for iso in selectedDates { dict[iso] = value }
        form.spotMarkers[idx].openingHoursOverrides = dict.isEmpty ? nil : dict
        actionBarSubMode = .availability
        clearSelectionState()
    }

    private func removeOpeningHoursOverride() {
        guard let idx = spotIndex else { return }
        var dict = form.spotMarkers[idx].openingHoursOverrides ?? [:]
        for iso in selectedDates { dict.removeValue(forKey: iso) }
        form.spotMarkers[idx].openingHoursOverrides = dict.isEmpty ? nil : dict
        actionBarSubMode = .availability
        clearSelectionState()
    }
    */

    private static func defaultStartTime() -> Date {
        var c = DateComponents(); c.hour = 9; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }
    private static func defaultEndTime() -> Date {
        var c = DateComponents(); c.hour = 17; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }
    private static func formatHM(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
    private static func parseHM(_ s: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.date(from: s)
    }

    /// Lukker den aktive action-baren og rydder draft/selection.
    /// Force-committer evt. pending pris-tekst før draft fjernes så ingen
    /// endringer går tapt når vert tapper X eller utenfor.
    private func closeActionBar() {
        if draft != nil {
            commitDraftPrice()
        }
        if priceEditFocused {
            commitPriceEdit()
        }
        selectedDates.removeAll()
        draft = nil
        mode = .idle
        actionBarSubMode = .availability
        priceEditFocused = false
        draftPriceFocused = false
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
        // Ignorer stengt-av-åpningstid i toggle-state: den behandles
        // separat via åpningstid-editor. Tilgjengelig-toggle gjelder kun
        // dager som faktisk kan blokkeres/åpnes manuelt.
        let togglable = selectedDates.filter { iso -> Bool in
            guard let d = Self.isoFormatter.date(from: iso) else { return false }
            return !closedByOpeningHours(d)
        }
        let allBlocked = !togglable.isEmpty && togglable.allSatisfy { blockedDates.contains($0) }
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
                stepPrice(by: -50)
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
                stepPrice(by: 50)
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
        // Bånd-egen pris vinner over spot-base. Hvis båndet ikke har eksplisitt
        // pris (0/unset), fall tilbake til spot.basePerHour.
        let bandPrice = band.price > 0 ? band.price : basePerHour
        return ResolvedPrice(price: bandPrice, scope: nil)
    }

    // MARK: - Tap-handling (single-tap toggle)
    //
    // Ny modell per Kim/Harald-feedback: tap legger til ELLER fjerner en
    // dato — aldri range-fyll. Range gjøres via DragGesture (under).

    private func handleDayTap(iso: String, isPast: Bool) {
        guard !isPast else { return }
        if case .bandEdit = mode { return }
        if case .bandCreate = mode { return }

        if selectedDates.contains(iso) {
            selectedDates.remove(iso)
        } else {
            selectedDates.insert(iso)
        }
        mode = selectedDates.isEmpty ? .idle : .dateOverride
        if selectedDates.isEmpty {
            panelMinimized = false  // reset minimer-tilstand når seleksjonen tømmes
        }
    }

    // MARK: - Drag-select (iOS 18 simultaneousGesture)

    /// Kalles fra `.simultaneousGesture(DragGesture...)` på ScrollView.
    /// Mapper finger-koordinat til celle via `cellFrames` og legger til/fjerner
    /// datoen i seleksjonen avhengig av drag-start-cellens initial-tilstand.
    private func handleDragChanged(at location: CGPoint, startLocation: CGPoint) {
        if !isDragging {
            // Drag-en starter nå. Bestem toggle-retning ut fra første celle.
            guard let startIso = cellAt(point: startLocation) else { return }
            isDragging = true
            dragStartedOnSelected = selectedDates.contains(startIso)
            dragVisited = [startIso]
            applyDragVisit(startIso)
            return
        }
        if let iso = cellAt(point: location), !dragVisited.contains(iso) {
            dragVisited.insert(iso)
            applyDragVisit(iso)
        }
    }

    private func applyDragVisit(_ iso: String) {
        if dragStartedOnSelected {
            selectedDates.remove(iso)
        } else {
            selectedDates.insert(iso)
        }
    }

    private func commitDrag() {
        isDragging = false
        dragVisited.removeAll()
        mode = selectedDates.isEmpty ? .idle : .dateOverride
        if selectedDates.isEmpty {
            panelMinimized = false
        }
    }

    /// Slå opp hvilken dag-celle som inneholder gitt punkt i "calendarGrid"-
    /// coordinate space. Filtrerer bort past-celler så drag hopper over fortiden.
    private func cellAt(point: CGPoint) -> String? {
        for (iso, frame) in cellFrames where frame.contains(point) {
            if let date = Self.isoFormatter.date(from: iso),
               !Calendar.current.isDate(date, inSameDayAs: Date()),
               date < Calendar.current.startOfDay(for: Date()) {
                return nil
            }
            return iso
        }
        return nil
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
        // Stengt-av-åpningstid trumfer manuell blokk — vi blokkerer/åpner kun
        // dager som faktisk er booking-bare. Ellers blir det inkonsistent at
        // bruker "blokkerer" en stengt søndag og taper den røde stengt-stil.
        let togglable = selectedDates.filter { iso in
            guard let date = Self.isoFormatter.date(from: iso) else { return false }
            return !closedByOpeningHours(date)
        }
        guard !togglable.isEmpty else {
            clearSelectionState()
            return
        }
        let allBlocked = togglable.allSatisfy { existing.contains($0) }
        var updated = existing
        if allBlocked {
            updated.subtract(togglable)
        } else {
            updated.formUnion(togglable)
        }
        form.spotMarkers[idx].blockedDates = updated.isEmpty ? nil : Array(updated).sorted()
        clearSelectionState()
    }

    /// Felles helper for å rydde markering + anker + modus etter en utført
    /// handling i kalenderen (blokker/åpne dager, bekreft pris-override osv).
    private func clearSelectionState() {
        selectedDates.removeAll()
        mode = .idle
        actionBarSubMode = .availability
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
        clearSelectionState()
    }

    private func applyDateOverride(price: Int) {
        guard let idx = spotIndex else { return }
        var current = form.spotMarkers[idx].datePriceOverrides ?? [:]
        if price <= 0 || price == basePerHour {
            // Fjern overstyring hvis prisen er null eller lik base
            for date in selectedDates {
                current.removeValue(forKey: date)
            }
        } else {
            for date in selectedDates {
                current[date] = price
            }
        }
        form.spotMarkers[idx].datePriceOverrides = current.isEmpty ? nil : current
    }

    // MARK: - Band-editor: state + handlers

    private func openBandEditor(_ band: WizardPricingBand) {
        draft = band
        draftPriceValue = band.price > 0 ? band.price : basePerHour
        draftPriceText = "\(draftPriceValue)"
        // Rydd date-override-state for å unngå at den vises bak editoren.
        selectedDates.removeAll()
        mode = .bandEdit(band.id)
    }

    private func openBandCreate() {
        // Default-bånd: hverdager 09:00-17:00, basePerHour
        let new = WizardPricingBand(
            dayMask: 0b0011111,
            startHour: 9,
            startMinute: 0,
            endHour: 17,
            endMinute: 0,
            price: basePerHour,
            weekScope: .allWeeks
        )
        draft = new
        draftPriceValue = basePerHour
        draftPriceText = "\(draftPriceValue)"
        selectedDates.removeAll()
        mode = .bandCreate
    }

    private func commitDraftPrice() {
        guard var d = draft else { return }
        // Parse fra tekst-feltet i tilfelle bruker har skrevet noe nytt
        let parsed = Int(draftPriceText) ?? draftPriceValue
        let clamped = max(0, parsed)
        draftPriceValue = clamped
        draftPriceText = "\(clamped)"
        d.price = clamped
        draft = d
        persistDraft()
    }

    private func stepDraftPrice(by delta: Int) {
        let v = max(0, draftPriceValue + delta)
        draftPriceValue = v
        draftPriceText = "\(v)"
        commitDraftPrice()
    }

    /// Skriver draft til availability.bands (oppdaterer eksisterende eller appender ny).
    private func persistDraft() {
        guard let d = draft else { return }
        var avail = availability
        if let idx = avail.bands.firstIndex(where: { $0.id == d.id }) {
            avail.bands[idx] = d
        } else {
            avail.bands.append(d)
        }
        form.setAvailability(avail, for: spotId)
    }

    private func deleteEditingBand() {
        guard let d = draft else { return }
        var avail = availability
        avail.bands.removeAll { $0.id == d.id }
        avail.bandPriceOverrides.removeAll { $0.bandId == d.id }
        form.setAvailability(avail, for: spotId)
        draft = nil
        mode = .idle
    }

    /// Ukedags-bit toggle — blokkerer hvis det ville skapt overlap mot annet bånd.
    private func toggleDraftDayBit(_ bit: Int) {
        guard var d = draft else { return }
        let mask = 1 << bit
        let isOn = (d.dayMask & mask) != 0
        if isOn {
            // Ikke tillat null-mask (bånd må ha minst 1 dag).
            let newMask = d.dayMask & ~mask
            guard newMask != 0 else { return }
            d.dayMask = newMask
        } else {
            d.dayMask |= mask
            if wouldOverlap(d) {
                wheelRevertTick &+= 1
                return
            }
        }
        draft = d
        persistDraft()
    }

    private func setDraftStart(minutes: Int) {
        guard var d = draft else { return }
        let h = minutes / 60
        let m = minutes % 60
        let snapped = (m == 30) ? 30 : 0
        d.startHour = h
        d.startMinute = snapped
        // Sikre start < end
        if d.startMinutes >= d.endMinutes {
            // Skyv slutt til neste hele time etter start
            let candidate = d.startMinutes + 60
            d.endHour = min(24, candidate / 60)
            d.endMinute = 0
        }
        if wouldOverlap(d) {
            wheelRevertTick &+= 1
            return
        }
        draft = d
        persistDraft()
    }

    private func setDraftColor(_ index: Int) {
        guard var d = draft else { return }
        d.colorIndex = index
        draft = d
        persistDraft()
    }

    private func setDraftEnd(minutes: Int) {
        guard var d = draft else { return }
        let h = minutes / 60
        let m = minutes % 60
        let snapped = (m == 30) ? 30 : 0
        d.endHour = h
        d.endMinute = snapped
        if d.endMinutes <= d.startMinutes {
            // Skyv start til 60 min før slutt
            let candidate = max(0, d.endMinutes - 60)
            d.startHour = candidate / 60
            d.startMinute = (candidate % 60 == 30) ? 30 : 0
        }
        if wouldOverlap(d) {
            wheelRevertTick &+= 1
            return
        }
        draft = d
        persistDraft()
    }

    /// Returnerer true hvis kandidat-båndet overlapper med et eksisterende bånd
    /// (samme spot, ulik id, deler ukedag, og tidsintervaller krysser hverandre).
    private func wouldOverlap(_ candidate: WizardPricingBand) -> Bool {
        for other in availability.bands where other.id != candidate.id {
            if bandsOverlap(candidate, other) { return true }
        }
        return false
    }

    private func bandsOverlap(_ a: WizardPricingBand, _ b: WizardPricingBand) -> Bool {
        if (a.dayMask & b.dayMask) == 0 { return false }
        return a.startMinutes < b.endMinutes && b.startMinutes < a.endMinutes
    }

    /// Hvis user toggler en ukedag PÅ — vil det skape overlap?
    private func dayBitWouldOverlap(_ bit: Int) -> Bool {
        guard var d = draft else { return false }
        let mask = 1 << bit
        if (d.dayMask & mask) != 0 { return false }   // allerede på, irrelevant
        d.dayMask |= mask
        return wouldOverlap(d)
    }

    // MARK: - Band-editor: UI

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
        HStack(spacing: 6) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Text(draft.map { "\(weekdaysShortLabel(mask: $0.dayMask)) · \($0.timeDisplayLabel)" } ?? "Nytt bånd")
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
            // Rad 1: ukedager + farge-swatch (uten "Farge"-label).
            HStack(spacing: 6) {
                weekdayStrip
                inlineColorSwatch
            }
            // Rad 2: Tidspunkt (full-bredde wheels) + Pris.
            HStack(alignment: .bottom, spacing: 10) {
                bandTimeCard
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

    /// Lite farge-swatch som ligger ved siden av ukedags-knappene. Tap åpner
    /// fargepalett-sheet. Subtil hvit checkmark i bunn-høyre indikerer valgt.
    private var inlineColorSwatch: some View {
        Button {
            showColorPalette = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(activePaletteColor)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.55), lineWidth: 1.5)
                    )
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

    /// Aktiv palette-farge for swatch. Bruker samme `bgDefault` som båndet
    /// rendrer med (pastell-tonen) så swatch matcher visuelt. Override-tonen
    /// (bgOverride) brukes bare på selve båndet når det er en uke-override.
    private var activePaletteColor: Color {
        guard let d = draft else { return Self.bandPalettes[0].bgDefault }
        if let idx = d.colorIndex, Self.bandPalettes.indices.contains(idx) {
            return Self.bandPalettes[idx].bgDefault
        }
        let idx = abs(d.id.hashValue) % Self.bandPalettes.count
        return Self.bandPalettes[idx].bgDefault
    }

    /// Sheet-innhold: 5 swatches i en rad. Tap velger farge og lukker.
    private var colorPaletteSheet: some View {
        VStack(spacing: 14) {
            Text("Farge")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.neutral900)
            HStack(spacing: 18) {
                ForEach(0..<Self.bandPalettes.count, id: \.self) { idx in
                    let palette = Self.bandPalettes[idx]
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

    private var weekdayStrip: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { bit in
                let isOn = ((draft?.dayMask ?? 0) & (1 << bit)) != 0
                let wouldOverlap = !isOn && dayBitWouldOverlap(bit)
                Button {
                    toggleDraftDayBit(bit)
                } label: {
                    Text(weekdayLetter(bit))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(weekdayLetterColor(isOn: isOn, blocked: wouldOverlap))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(weekdayBg(isOn: isOn, blocked: wouldOverlap))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(isOn ? Color.white : Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        // Sikre at hele 40pt-rektangelet er tap-target, ikke
                        // bare bokstaven. Uten dette blir hit-shape Text-glyf
                        // → taps under bokstaven faller gjennom til wheel.
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(wouldOverlap)
                .opacity(wouldOverlap ? 0.4 : 1.0)
            }
        }
    }

    private func weekdayLetterColor(isOn: Bool, blocked: Bool) -> Color {
        if blocked { return Color.white.opacity(0.4) }
        return isOn ? Color.neutral900 : Color.white
    }

    private func weekdayBg(isOn: Bool, blocked: Bool) -> Color {
        if blocked { return Color.white.opacity(0.04) }
        return isOn ? Color.white : Color.white.opacity(0.08)
    }

    private func weekdayLetter(_ bit: Int) -> String {
        ["M", "T", "O", "T", "F", "L", "S"][bit]
    }

    private func weekdaysShortLabel(mask: Int) -> String {
        var parts: [String] = []
        for bit in 0..<7 where (mask & (1 << bit)) != 0 {
            parts.append(["Ma", "Ti", "On", "To", "Fr", "Lø", "Sø"][bit])
        }
        return parts.joined(separator: ", ")
    }

    private var bandTimeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tidspunkt")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                darkTimeWheel(binding: bandStartBinding)
                darkTimeWheel(binding: bandEndBinding)
            }
        }
    }

    private var bandStartBinding: Binding<Int?> {
        Binding(
            get: { draft.map { $0.startMinutes } },
            set: { newValue in
                if let v = newValue { setDraftStart(minutes: v) }
            }
        )
    }

    private var bandEndBinding: Binding<Int?> {
        Binding(
            get: { draft.map { $0.endMinutes } },
            set: { newValue in
                if let v = newValue { setDraftEnd(minutes: v) }
            }
        )
    }

    @ViewBuilder
    private func darkTimeWheel(binding: Binding<Int?>) -> some View {
        // To smale UIPickerView-wheels med transparent bg + hvit tekst.
        // Inkluderer halvtime-snap (0/30) på minutt-wheelen.
        HStack(spacing: 0) {
            DarkWheelPicker(
                value: Binding(
                    get: { (binding.wrappedValue ?? 0) / 60 },
                    set: { newH in
                        let m = (binding.wrappedValue ?? 0) % 60
                        binding.wrappedValue = newH * 60 + m
                    }
                ),
                values: Array(0...24)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 96)

            Text(":")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            DarkWheelPicker(
                value: Binding(
                    get: { (binding.wrappedValue ?? 0) % 60 },
                    set: { newM in
                        let h = (binding.wrappedValue ?? 0) / 60
                        binding.wrappedValue = h * 60 + newM
                    }
                ),
                values: [0, 30]
            )
            .frame(maxWidth: .infinity)
            .frame(height: 96)
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var bandPriceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pris per time")
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

    // MARK: - FAB "+ Nytt bånd"

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
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay(Capsule().fill(Color.black.opacity(0.55)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
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

/// Mørk wheel-picker bygd på UIPickerView med eksplisitt hvit tekst.
/// SwiftUI Picker(.wheel) respekterer ikke colorScheme(.dark) for inner Text,
/// så vi må gå via UIKit for å få riktig kontrast i den mørke glass-cardet.
struct DarkWheelPicker: UIViewRepresentable {
    @Binding var value: Int
    let values: [Int]

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        picker.backgroundColor = .clear
        // Sett lave kompresjons-prioriteter så SwiftUI kan gi den vilkårlig
        // bredde uten å trigge negative-dimensjon-feil i UIKit-runtime.
        picker.setContentHuggingPriority(.defaultLow, for: .horizontal)
        picker.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return picker
    }

    func updateUIView(_ picker: UIPickerView, context: Context) {
        context.coordinator.parent = self
        if let row = values.firstIndex(of: value), picker.selectedRow(inComponent: 0) != row {
            picker.selectRow(row, inComponent: 0, animated: false)
        }
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: DarkWheelPicker
        init(_ parent: DarkWheelPicker) { self.parent = parent }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            parent.values.count
        }

        /// La rad-bredden følge picker-bredden så vi ikke får default-padding
        /// som klipper "00" til "C" i smale celler.
        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            max(40, pickerView.bounds.width)
        }

        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            32
        }

        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            // Bruk en egen UILabel istedenfor attributedTitle. Dette er mer
            // pålitelig på smale celler — UILabel respekterer textAlignment
            // og clipsToBounds, og vi kan styre adjustsFontSizeToFitWidth.
            let label = (view as? UILabel) ?? UILabel()
            label.text = String(format: "%02d", parent.values[row])
            label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            label.textColor = .white
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.6
            label.baselineAdjustment = .alignCenters
            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            let newValue = parent.values[row]
            if parent.value != newValue {
                parent.value = newValue
            }
        }
    }
}
