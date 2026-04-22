import SwiftUI
import UIKit

/// Root-view for host-kalender. Henter alle hostens annonser og lar brukeren
/// velge en — eller går rett til HostCalendarView hvis det bare finnes én.
struct CalendarRootView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var listings: [Listing] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if listings.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "calendar")
                        .font(.system(size: 36))
                        .foregroundStyle(.neutral300)
                    Text("Ingen annonser ennå")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Opprett en annonse for å administrere priser og blokkere datoer.")
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral500)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if listings.count == 1, let only = listings.first {
                HostCalendarView(listing: only)
            } else {
                List {
                    Section {
                        ForEach(listings) { listing in
                            NavigationLink {
                                HostCalendarView(listing: listing)
                            } label: {
                                HStack(spacing: 12) {
                                    AsyncImage(url: URL(string: listing.images?.first ?? "")) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        default:
                                            Rectangle().fill(Color.neutral100)
                                        }
                                    }
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(listing.internalName ?? listing.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .lineLimit(1)
                                        if let city = listing.city {
                                            Text(city)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.neutral500)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "calendar")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.neutral400)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text("Velg annonse")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Kalender")
        .task { await load() }
    }

    private func load() async {
        guard let userId = authManager.currentUser?.id else {
            isLoading = false; return
        }
        do {
            listings = try await supabase
                .from("listings")
                .select()
                .eq("host_id", value: userId.uuidString.lowercased())
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            print("CalendarRootView load error: \(error)")
        }
        isLoading = false
    }
}

// MARK: - HostCalendarView

/// Rullende multi-måned-kalender med tap-anker-range-select. INGEN
/// gestus-modifiers, INGEN drag, INGEN paint-mode. Bare Button-tap per celle
/// slik at hit-testing er bulletproof. Tydelig visuell tilbakemelding med
/// anker-puls og full-celle fyld for valgte datoer.
struct HostCalendarView: View {
    let listing: Listing

    @State private var selectedDates: Set<String> = []
    @State private var rangeAnchor: String?
    @State private var blockedDates: Set<String> = []
    @State private var rules: [PricingService.Rule] = []
    @State private var overrides: [String: Int] = [:]
    @State private var bookedDates: Set<String> = []
    @State private var isLoading = true
    @State private var saving = false
    @State private var toast: String?
    @State private var showPriceSheet = false
    @State private var showPricingRulesEditor = false
    @State private var anchorPulse = false

    // Hint-bar: persistent "ikke vis igjen"
    @AppStorage("hostCalendarHintDismissed") private var hintDismissed = false

    // Plass-velger
    @State private var spotMarkers: [SpotMarker] = []
    @State private var selectedSpotIds: Set<String> = []
    @State private var showSpotPicker = false

    private let monthsAhead = 12
    private var basePrice: Int { listing.price ?? 0 }

    private var hasMultipleSpots: Bool { spotMarkers.count > 1 }

    private var spotSelectionLabel: String {
        if !hasMultipleSpots { return "" }
        if selectedSpotIds.count == spotMarkers.count {
            return "Alle \(spotMarkers.count) plasser"
        }
        return "\(selectedSpotIds.count) av \(spotMarkers.count)"
    }

    /// Eneste sted tid-soner blir håndtert. Alle isoFormatter + calendar-
    /// operasjoner bruker Europe/Oslo for å unngå drift på tvers av enheter.
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

    private static var osloCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        cal.firstWeekday = 2
        return cal
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVStack(spacing: 24, pinnedViews: []) {
                    if hasMultipleSpots {
                        spotPickerButton
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }

                    if isLoading {
                        ProgressView().padding(.top, 40)
                    } else {
                        ForEach(visibleMonthList, id: \.self) { monthStart in
                            monthSection(monthStart)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, selectedDates.isEmpty ? 20 : 160)
            }

            if !selectedDates.isEmpty {
                selectionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedDates.isEmpty)
        .overlay(alignment: .top) {
            // Hint-bar som floating overlay — påvirker ikke scroll-posisjon.
            // Vises kun når ankeret er satt OG brukeren ikke har dismissed den.
            if rangeAnchor != nil && !hintDismissed {
                rangeHint
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.neutral900)
                    .clipShape(Capsule())
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .shadow(radius: 6)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: rangeAnchor)
        .navigationTitle(listing.internalName ?? listing.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showPricingRulesEditor = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $showPricingRulesEditor, onDismiss: {
            Task { await refreshPricing() }
        }) {
            NavigationStack {
                PricingRulesEditorView(listingId: listing.id, basePrice: basePrice)
            }
        }
        .sheet(isPresented: $showPriceSheet) {
            PriceSheet(
                basePrice: basePrice,
                selectedCount: selectedDates.count,
                onSave: { newPrice in
                    Task { await applyPriceOverride(newPrice) }
                }
            )
            .presentationDetents([.fraction(0.35)])
        }
        .sheet(isPresented: $showSpotPicker) {
            SpotPickerSheet(
                spots: spotMarkers,
                selectedSpotIds: $selectedSpotIds
            )
            .presentationDetents([.medium, .large])
        }
        .task(id: listing.id) { await loadAll() }
        .onAppear {
            // Start puls-animasjon for ankeret
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                anchorPulse.toggle()
            }
        }
    }

    // MARK: - Spot-velger-knapp

    @ViewBuilder
    private var spotPickerButton: some View {
        Button {
            showSpotPicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary600)
                Text("Plasser: ")
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral600)
                + Text(spotSelectionLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.neutral900)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.neutral400)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.primary50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary600.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Range-hint bar (vises når anker er satt)

    @ViewBuilder
    private var rangeHint: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.primary600)
                        .frame(width: 22, height: 22)
                    Text("1")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Start-dato satt")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text("Trykk slutt-dato for å velge hele området")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral600)
                }
                Spacer()
                Button("Avbryt") {
                    rangeAnchor = nil
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary600)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white)
                .clipShape(Capsule())
            }
            HStack {
                Spacer()
                Button {
                    hintDismissed = true
                } label: {
                    Text("Ikke vis denne meldingen igjen")
                        .font(.system(size: 11))
                        .foregroundStyle(.neutral500)
                        .underline()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Color.primary50
                .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary600.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Måned-seksjon

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

            let days = daysInMonthGrid(monthStart)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7),
                spacing: 3
            ) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(for: date)
                    } else {
                        Color.clear.frame(height: 54)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let iso = Self.isoFormatter.string(from: date)
        let startOfToday = Self.osloCalendar.startOfDay(for: Date())
        let isPast = Self.osloCalendar.startOfDay(for: date) < startOfToday
        let isBooked = bookedDates.contains(iso)
        let isBlocked = blockedDates.contains(iso)
        let isSelected = selectedDates.contains(iso)
        let isAnchor = rangeAnchor == iso
        let override = overrides[iso]
        let price = priceForDate(date)
        let source = sourceForDate(date, iso: iso)
        let dayNumber = Self.osloCalendar.component(.day, from: date)

        Button {
            handleTap(iso: iso)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(cellBackground(
                        isPast: isPast,
                        isBooked: isBooked,
                        isBlocked: isBlocked,
                        isSelected: isSelected,
                        isAnchor: isAnchor,
                        isOverride: override != nil
                    ))

                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        borderColor(isSelected: isSelected, isAnchor: isAnchor),
                        lineWidth: isAnchor ? 2.5 : (isSelected ? 1.5 : 0)
                    )

                VStack(spacing: 1) {
                    Text("\(dayNumber)")
                        .font(.system(size: 15, weight: (isSelected || isAnchor) ? .bold : .medium))
                        .foregroundStyle(textColor(isPast: isPast, isBooked: isBooked, isBlocked: isBlocked, isSelected: isSelected, isAnchor: isAnchor))

                    if !isPast && !isBooked && !isBlocked {
                        Text("\(price)")
                            .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(priceColor(source: source, isSelected: isSelected, isAnchor: isAnchor))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else if isBooked {
                        // Tydelig BOOKET-label så det ikke forveksles med valgt
                        Text("BOOKET")
                            .font(.system(size: 7, weight: .heavy))
                            .tracking(0.4)
                            .foregroundStyle(.neutral500)
                    } else if isBlocked {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.neutral500)
                    }
                }
            }
            .frame(height: 54)
            .scaleEffect(isAnchor && anchorPulse ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isPast || isBooked)
    }

    // MARK: - Tap-logikk (tap-anker-pattern)

    private func handleTap(iso: String) {
        guard canSelectIso(iso) else { return }

        if let anchor = rangeAnchor {
            if anchor == iso {
                // Tap på ankeret igjen → fjern + clear
                selectedDates.remove(iso)
                rangeAnchor = nil
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                // Tap #2 — fyll området inn
                let range = isoRange(from: anchor, to: iso)
                withAnimation(.easeInOut(duration: 0.18)) {
                    for d in range where canSelectIso(d) {
                        selectedDates.insert(d)
                    }
                    rangeAnchor = nil
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        } else {
            // Tap #1 — toggle eller sett som anker
            if selectedDates.contains(iso) {
                selectedDates.remove(iso)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedDates.insert(iso)
                    rangeAnchor = iso
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private func canSelectIso(_ iso: String) -> Bool {
        guard let date = Self.isoFormatter.date(from: iso) else { return false }
        let startOfToday = Self.osloCalendar.startOfDay(for: Date())
        if Self.osloCalendar.startOfDay(for: date) < startOfToday { return false }
        // Booked dager kan ikke velges (bekreftet booking eier dagen)
        return !bookedDates.contains(iso)
    }

    private func isoRange(from a: String, to b: String) -> [String] {
        guard let dateA = Self.isoFormatter.date(from: a),
              let dateB = Self.isoFormatter.date(from: b) else { return [] }
        let (start, end) = dateA < dateB ? (dateA, dateB) : (dateB, dateA)
        let cal = Self.osloCalendar
        var cursor = cal.startOfDay(for: start)
        let last = cal.startOfDay(for: end)
        var result: [String] = []
        while cursor <= last {
            result.append(Self.isoFormatter.string(from: cursor))
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    // MARK: - Celle-styling

    private func cellBackground(isPast: Bool, isBooked: Bool, isBlocked: Bool, isSelected: Bool, isAnchor: Bool, isOverride: Bool) -> Color {
        if isAnchor { return Color.primary600.opacity(0.22) }
        if isSelected { return Color.primary600.opacity(0.13) }
        // Booked + blokkert: begge er grå og tydelig "ikke tilgjengelig" —
        // skal aldri forveksles med valg (som er grønt). Booked får en litt
        // varmere grå for å skille seg fra manuelt blokkert.
        if isBooked { return Color(hex: "#f5f1ef") }
        if isBlocked { return Color.neutral100 }
        if isOverride { return Color(hex: "#ecfdf5") }
        return Color.white
    }

    private func borderColor(isSelected: Bool, isAnchor: Bool) -> Color {
        if isAnchor { return Color.primary600 }
        if isSelected { return Color.primary600.opacity(0.55) }
        return Color.clear
    }

    private func textColor(isPast: Bool, isBooked: Bool, isBlocked: Bool, isSelected: Bool, isAnchor: Bool) -> Color {
        if isPast { return .neutral300 }
        if isBooked { return .neutral500 }
        if isBlocked { return .neutral400 }
        if isAnchor || isSelected { return Color.primary600 }
        return .neutral900
    }

    private func priceColor(source: String, isSelected: Bool, isAnchor: Bool) -> Color {
        if isSelected || isAnchor { return Color.primary600 }
        switch source {
        case "override": return Color(hex: "#10b981")
        case "season": return Color(hex: "#f59e0b")
        case "weekend": return Color(hex: "#3b82f6")
        default: return .neutral500
        }
    }

    // MARK: - Pris-logikk (speiler PricingService)

    private func priceForDate(_ date: Date) -> Int {
        let iso = Self.isoFormatter.string(from: date)
        if let o = overrides[iso] { return o }
        if let season = rules.first(where: { r in
            guard r.kind == "season",
                  let start = r.start_date, let end = r.end_date else { return false }
            return iso >= start && iso <= end
        }) {
            return season.price
        }
        if let weekend = rules.first(where: { r in
            r.kind == "weekend" && ((r.day_mask ?? 0) & (1 << weekdayBit(date))) != 0
        }) {
            return weekend.price
        }
        return basePrice
    }

    private func sourceForDate(_ date: Date, iso: String) -> String {
        if overrides[iso] != nil { return "override" }
        if rules.contains(where: { r in
            guard r.kind == "season", let s = r.start_date, let e = r.end_date else { return false }
            return iso >= s && iso <= e
        }) { return "season" }
        if rules.contains(where: { r in
            r.kind == "weekend" && ((r.day_mask ?? 0) & (1 << weekdayBit(date))) != 0
        }) { return "weekend" }
        return "base"
    }

    private func weekdayBit(_ date: Date) -> Int {
        let wd = Self.osloCalendar.component(.weekday, from: date)
        return wd == 1 ? 6 : wd - 2
    }

    // MARK: - Månedsliste + grid

    private var visibleMonthList: [Date] {
        let cal = Self.osloCalendar
        var comps = cal.dateComponents([.year, .month], from: Date())
        comps.day = 1
        guard let first = cal.date(from: comps) else { return [] }
        return (0..<monthsAhead).compactMap { i in
            cal.date(byAdding: .month, value: i, to: first)
        }
    }

    private func daysInMonthGrid(_ monthStart: Date) -> [Date?] {
        let cal = Self.osloCalendar
        let range = cal.range(of: .day, in: .month, for: monthStart) ?? 1..<32
        let firstWeekdayOfMonth = cal.component(.weekday, from: monthStart)
        // firstWeekday=2 (mandag), så leading = (weekday - 2 + 7) % 7
        let leading = (firstWeekdayOfMonth + 5) % 7

        var result: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: monthStart) {
                result.append(d)
            }
        }
        while result.count % 7 != 0 {
            result.append(nil)
        }
        return result
    }

    // MARK: - Selection bar

    private var selectionBar: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedDates.count) \(selectedDates.count == 1 ? "dag valgt" : "dager valgt")")
                        .font(.system(size: 14, weight: .semibold))
                    if hasMultipleSpots {
                        Text(spotSelectionLabel)
                            .font(.system(size: 11))
                            .foregroundStyle(.neutral500)
                    }
                }
                Spacer()
                Button("Tøm") {
                    withAnimation {
                        selectedDates.removeAll()
                        rangeAnchor = nil
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(.neutral600)
            }

            HStack(spacing: 8) {
                actionButton(
                    icon: "xmark.square.fill",
                    label: allSelectedBlocked ? "Fjern blokk." : "Blokker"
                ) {
                    Task { await applyBlockToggle() }
                }
                actionButton(icon: "tag.fill", label: "Sett pris") {
                    showPriceSheet = true
                }
                actionButton(icon: "arrow.uturn.backward", label: "Fjern overst.") {
                    Task { await applyClearOverrides() }
                }
            }
        }
        .padding(14)
        .background(
            Color.white
                .shadow(color: .black.opacity(0.1), radius: 12, y: -2)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(Color.neutral200).frame(height: 1)
        }
    }

    private var allSelectedBlocked: Bool {
        !selectedDates.isEmpty && selectedDates.allSatisfy { blockedDates.contains($0) }
    }

    @ViewBuilder
    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(.neutral900)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.neutral100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(saving)
    }

    // MARK: - Data-lasting

    private func loadAll() async {
        isLoading = true
        blockedDates = Set(listing.blockedDates ?? [])
        rules = await PricingService.fetchRules(listingId: listing.id)
        let fetchedOverrides = await PricingService.fetchOverrides(listingId: listing.id)
        overrides = Dictionary(uniqueKeysWithValues: fetchedOverrides.map { ($0.date, $0.price) })

        let markers = await fetchSpotMarkers()
        spotMarkers = markers
        if selectedSpotIds.isEmpty {
            selectedSpotIds = Set(markers.compactMap { $0.id })
        }

        await loadBookings()
        isLoading = false
    }

    private func fetchSpotMarkers() async -> [SpotMarker] {
        do {
            struct Row: Decodable { let spotMarkers: [SpotMarker]?
                enum CodingKeys: String, CodingKey { case spotMarkers = "spot_markers" }
            }
            let rows: [Row] = try await supabase
                .from("listings")
                .select("spot_markers")
                .eq("id", value: listing.id)
                .limit(1)
                .execute()
                .value
            return rows.first?.spotMarkers ?? []
        } catch {
            print("fetchSpotMarkers error: \(error)")
            return []
        }
    }

    private func refreshPricing() async {
        rules = await PricingService.fetchRules(listingId: listing.id)
        let fetched = await PricingService.fetchOverrides(listingId: listing.id)
        overrides = Dictionary(uniqueKeysWithValues: fetched.map { ($0.date, $0.price) })
    }

    private func loadBookings() async {
        do {
            struct BookingDates: Decodable {
                let checkIn: String
                let checkOut: String
                enum CodingKeys: String, CodingKey { case checkIn = "check_in"; case checkOut = "check_out" }
            }
            let rows: [BookingDates] = try await supabase
                .from("bookings")
                .select("check_in, check_out")
                .eq("listing_id", value: listing.id)
                .eq("status", value: "confirmed")
                .execute()
                .value
            var set = Set<String>()
            let cal = Self.osloCalendar
            for b in rows {
                guard let start = Self.isoFormatter.date(from: b.checkIn),
                      let end = Self.isoFormatter.date(from: b.checkOut) else { continue }
                var cursor = cal.startOfDay(for: start)
                let lastNight = cal.startOfDay(for: end)
                while cursor < lastNight {
                    set.insert(Self.isoFormatter.string(from: cursor))
                    guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
                    cursor = next
                }
            }
            bookedDates = set
        } catch {
            print("loadBookings error: \(error)")
        }
    }

    // MARK: - Actions

    @MainActor
    private func applyBlockToggle() async {
        saving = true
        defer { saving = false }
        let shouldBlock = !allSelectedBlocked

        let allSpots = spotMarkers.count
        let selectingAll = !hasMultipleSpots || selectedSpotIds.count == allSpots

        if selectingAll {
            var next = blockedDates
            for iso in selectedDates {
                if shouldBlock { next.insert(iso) } else { next.remove(iso) }
            }
            do {
                struct Payload: Encodable { let blocked_dates: [String] }
                try await supabase
                    .from("listings")
                    .update(Payload(blocked_dates: Array(next).sorted()))
                    .eq("id", value: listing.id)
                    .execute()
                blockedDates = next
                flashToast(shouldBlock ? "Blokkert \(selectedDates.count) dager" : "Fjernet blokkering")
                selectedDates.removeAll()
                rangeAnchor = nil
            } catch {
                flashToast("Kunne ikke lagre")
                print("block toggle error: \(error)")
            }
        } else {
            var updatedMarkers = spotMarkers
            for i in 0..<updatedMarkers.count {
                guard let sid = updatedMarkers[i].id, selectedSpotIds.contains(sid) else { continue }
                var existing = Set(updatedMarkers[i].blockedDates ?? [])
                for iso in selectedDates {
                    if shouldBlock { existing.insert(iso) } else { existing.remove(iso) }
                }
                updatedMarkers[i].blockedDates = existing.isEmpty ? nil : Array(existing).sorted()
            }
            do {
                struct Payload: Encodable { let spot_markers: [SpotMarker] }
                try await supabase
                    .from("listings")
                    .update(Payload(spot_markers: updatedMarkers))
                    .eq("id", value: listing.id)
                    .execute()
                spotMarkers = updatedMarkers
                let count = selectedSpotIds.count
                flashToast(shouldBlock
                    ? "Blokkert for \(count) \(count == 1 ? "plass" : "plasser")"
                    : "Fjernet blokkering for \(count) \(count == 1 ? "plass" : "plasser")")
                selectedDates.removeAll()
                rangeAnchor = nil
            } catch {
                flashToast("Kunne ikke lagre")
                print("per-spot block toggle error: \(error)")
            }
        }
    }

    @MainActor
    private func applyPriceOverride(_ price: Int) async {
        saving = true
        defer { saving = false }
        let dates = Array(selectedDates)
        do {
            try await PricingService.setOverrides(listingId: listing.id, dates: dates, price: price)
            for d in dates { overrides[d] = price }
            flashToast("Pris satt til \(price) kr")
            selectedDates.removeAll()
            rangeAnchor = nil
            showPriceSheet = false
        } catch {
            flashToast("Kunne ikke lagre")
            print("set override error: \(error)")
        }
    }

    @MainActor
    private func applyClearOverrides() async {
        saving = true
        defer { saving = false }
        let dates = Array(selectedDates)
        do {
            try await PricingService.clearOverrides(listingId: listing.id, dates: dates)
            for d in dates { overrides.removeValue(forKey: d) }
            flashToast("Overstyring fjernet")
            selectedDates.removeAll()
            rangeAnchor = nil
        } catch {
            flashToast("Kunne ikke lagre")
            print("clear overrides error: \(error)")
        }
    }

    private func flashToast(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { toast = nil }
        }
    }
}

// MARK: - Plass-velger-sheet

private struct SpotPickerSheet: View {
    let spots: [SpotMarker]
    @Binding var selectedSpotIds: Set<String>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedSpotIds = Set(spots.compactMap { $0.id })
                    } label: {
                        HStack {
                            Text("Velg alle")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary600)
                            Spacer()
                            Text("\(selectedSpotIds.count)/\(spots.count)")
                                .font(.system(size: 13))
                                .foregroundStyle(.neutral500)
                        }
                    }
                } footer: {
                    Text("Velg hvilke plasser blokkering gjelder for. Prisoverstyringer gjelder hele annonsen.")
                        .font(.system(size: 12))
                }

                Section("Plasser") {
                    ForEach(Array(spots.enumerated()), id: \.offset) { index, spot in
                        let sid = spot.id ?? "\(index)"
                        Button {
                            if selectedSpotIds.contains(sid) {
                                if selectedSpotIds.count > 1 {
                                    selectedSpotIds.remove(sid)
                                }
                            } else {
                                selectedSpotIds.insert(sid)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(selectedSpotIds.contains(sid) ? Color.primary600 : Color.neutral100)
                                        .frame(width: 26, height: 26)
                                    if selectedSpotIds.contains(sid) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(spot.label ?? "Plass \(index + 1)")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.neutral900)
                                    if let price = spot.price {
                                        Text("\(price) kr/natt")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.neutral500)
                                    }
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Velg plasser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ferdig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Price-input sheet

private struct PriceSheet: View {
    let basePrice: Int
    let selectedCount: Int
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var priceText: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sett pris for \(selectedCount) \(selectedCount == 1 ? "dag" : "dager")")
                    .font(.system(size: 15))
                    .foregroundStyle(.neutral600)

                HStack(spacing: 8) {
                    TextField("\(basePrice)", text: $priceText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 36, weight: .bold))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.neutral100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("kr")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neutral600)
                }

                Text("Standardpris er \(basePrice) kr. La stå tomt for å beholde standardpris.")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)

                Spacer()

                Button {
                    if let value = Int(priceText), value > 0 {
                        onSave(value)
                    } else {
                        dismiss()
                    }
                } label: {
                    Text("Bruk")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.primary600)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(Int(priceText) ?? 0 <= 0)
                .opacity((Int(priceText) ?? 0) > 0 ? 1 : 0.5)
            }
            .padding(20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") { dismiss() }
                }
            }
        }
    }
}
