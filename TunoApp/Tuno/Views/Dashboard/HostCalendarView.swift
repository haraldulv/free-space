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

// MARK: - HostCalendarView (SwiftUI-shell rundt UICalendarView)

/// Kalender for én annonse. Bruker Apples native `UICalendarView` via
/// `UIViewRepresentable` for scroll + tap, og Airbnb-stil tap-anker-pattern
/// (tap start → tap slutt = område) for range-valg. Flere disjunkte områder
/// kan akkumuleres. Bulk-actions (blokker, sett pris, fjern overstyring) med
/// plass-velger for host som har flere plasser.
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

    // Plass-velger
    @State private var spotMarkers: [SpotMarker] = []
    @State private var selectedSpotIds: Set<String> = []
    @State private var showSpotPicker = false

    private var basePrice: Int { listing.price ?? 0 }
    private var hasMultipleSpots: Bool { spotMarkers.count > 1 }

    private var spotSelectionLabel: String {
        if !hasMultipleSpots { return "" }
        if selectedSpotIds.count == spotMarkers.count {
            return "Alle \(spotMarkers.count) plasser"
        }
        return "\(selectedSpotIds.count) av \(spotMarkers.count)"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if hasMultipleSpots {
                    spotPickerButton
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                }

                if rangeAnchor != nil {
                    rangeHint
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 4)
                }

                if isLoading {
                    ProgressView().padding(.top, 40)
                    Spacer()
                } else {
                    HostCalendarUIView(
                        selectedDates: $selectedDates,
                        rangeAnchor: $rangeAnchor,
                        blockedDates: blockedDates,
                        bookedDates: bookedDates,
                        overrides: overrides,
                        rules: rules,
                        basePrice: basePrice
                    )
                }
            }
            .padding(.bottom, selectedDates.isEmpty ? 0 : 140)

            if !selectedDates.isEmpty {
                selectionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedDates.isEmpty)
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

    // MARK: - Range-hint bar

    @ViewBuilder
    private var rangeHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary600)
            Text("Trykk en dato til for å velge område")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.neutral700)
            Spacer()
            Button("Avbryt") {
                rangeAnchor = nil
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primary600)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary50)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Selection bar (bunnen)

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

        // Last spot_markers fra DB — listing.spotMarkers kan være utdatert
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
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
            f.locale = Locale(identifier: "en_US_POSIX")
            for b in rows {
                guard let start = f.date(from: b.checkIn),
                      let end = f.date(from: b.checkOut) else { continue }
                var cursor = start
                while cursor < end {
                    set.insert(f.string(from: cursor))
                    cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor) ?? end
                }
            }
            bookedDates = set
        } catch {
            print("loadBookings error: \(error)")
        }
    }

    // MARK: - Actions (blokker, pris, fjern overstyring)

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

// MARK: - HostCalendarUIView — UICalendarView wrapper

/// Wrapper rundt Apples native `UICalendarView` (iOS 16+). Gir native scroll
/// + tap-hit-testing uten gestus-krig. Coordinator håndterer tap-anker-pattern
/// (tap start → tap slutt = område) via `UICalendarSelectionSingleDate`-
/// delegaten, og tegner valg/blokk/booking/pris per dag via `decorationFor`.
private struct HostCalendarUIView: UIViewRepresentable {
    @Binding var selectedDates: Set<String>
    @Binding var rangeAnchor: String?
    let blockedDates: Set<String>
    let bookedDates: Set<String>
    let overrides: [String: Int]
    let rules: [PricingService.Rule]
    let basePrice: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        cal.firstWeekday = 2  // Mandag først
        view.calendar = cal
        view.locale = Locale(identifier: "nb")
        view.tintColor = UIColor(red: 70/255, green: 193/255, blue: 133/255, alpha: 1) // #46C185

        // Tilgjengelig område: i dag → +2 år
        let startOfToday = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .year, value: 2, to: startOfToday) ?? startOfToday
        view.availableDateRange = DateInterval(start: startOfToday, end: end)

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        view.selectionBehavior = selection
        context.coordinator.selection = selection
        context.coordinator.calendarView = view

        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        context.coordinator.parent = self
        uiView.reloadDecorations(
            forDateComponents: context.coordinator.decorableComponents(),
            animated: false
        )
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: HostCalendarUIView
        weak var calendarView: UICalendarView?
        weak var selection: UICalendarSelectionSingleDate?

        private let isoFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }()

        private var calendar: Calendar {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
            cal.firstWeekday = 2
            return cal
        }

        init(parent: HostCalendarUIView) {
            self.parent = parent
        }

        /// Datoer som skal re-dekoreres — 14 måneder frem i tid dekker
        /// `availableDateRange`. UICalendarView kaller bare `decorationFor`
        /// for synlige måneder internt, så performance er OK.
        func decorableComponents() -> [DateComponents] {
            var out: [DateComponents] = []
            let today = Date()
            for monthOffset in 0..<14 {
                guard let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: today) else { continue }
                let comps = calendar.dateComponents([.year, .month], from: monthStart)
                guard let firstOfMonth = calendar.date(from: comps),
                      let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { continue }
                for day in range {
                    if let d = calendar.date(bySetting: .day, value: day, of: firstOfMonth) {
                        out.append(calendar.dateComponents([.year, .month, .day], from: d))
                    }
                }
            }
            return out
        }

        // MARK: Selection-delegate

        func dateSelection(_ selection: UICalendarSelectionSingleDate, canSelectDate dateComponents: DateComponents?) -> Bool {
            guard let dc = dateComponents, let date = calendar.date(from: dc) else { return false }
            let startOfToday = calendar.startOfDay(for: Date())
            if calendar.startOfDay(for: date) < startOfToday { return false }
            let iso = isoFormatter.string(from: date)
            // Booket dag kan ikke velges; blokkert dag kan velges (så host
            // kan fjerne blokkeringen via bulk-action).
            return !parent.bookedDates.contains(iso)
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dc = dateComponents, let date = calendar.date(from: dc) else { return }
            let iso = isoFormatter.string(from: date)

            // Oppdater modellen via bindings — dette trigger updateUIView →
            // reloadDecorations og tegner fersk state.
            handleTap(iso: iso)

            // Fjern Apple sitt selection-ring umiddelbart — vi tegner alt selv
            // via dekorasjoner, så seleksjonsringen ville vært duplisering.
            DispatchQueue.main.async { [weak self] in
                self?.selection?.setSelected(nil, animated: false)
            }
        }

        private func handleTap(iso: String) {
            if let anchor = parent.rangeAnchor {
                if anchor == iso {
                    // Samme dato tappet → fjern valg + anker
                    parent.selectedDates.remove(iso)
                    parent.rangeAnchor = nil
                } else {
                    // Tap #2: fyll området fra anker til tappet dato
                    let range = isoRange(from: anchor, to: iso).filter { canSelectIso($0) }
                    for d in range {
                        parent.selectedDates.insert(d)
                    }
                    parent.rangeAnchor = nil
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } else {
                if parent.selectedDates.contains(iso) {
                    // Toggle av allerede-valgt dato
                    parent.selectedDates.remove(iso)
                } else {
                    // Tap #1: velg + sett som anker
                    parent.selectedDates.insert(iso)
                    parent.rangeAnchor = iso
                }
            }
        }

        private func canSelectIso(_ iso: String) -> Bool {
            guard let date = isoFormatter.date(from: iso) else { return false }
            if calendar.startOfDay(for: date) < calendar.startOfDay(for: Date()) { return false }
            return !parent.bookedDates.contains(iso)
        }

        private func isoRange(from a: String, to b: String) -> [String] {
            guard let dateA = isoFormatter.date(from: a),
                  let dateB = isoFormatter.date(from: b) else { return [] }
            let (start, end) = dateA < dateB ? (dateA, dateB) : (dateB, dateA)
            var cursor = start
            var result: [String] = []
            while cursor <= end {
                result.append(isoFormatter.string(from: cursor))
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            return result
        }

        // MARK: Decorations — valg, status, pris

        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let date = calendar.date(from: dateComponents) else { return nil }
            let iso = isoFormatter.string(from: date)

            let isSelected = parent.selectedDates.contains(iso)
            let isAnchor = parent.rangeAnchor == iso
            let isBlocked = parent.blockedDates.contains(iso)
            let isBooked = parent.bookedDates.contains(iso)
            let override = parent.overrides[iso]

            let price = priceForDate(date, iso: iso)
            let source = sourceForDate(date, iso: iso)

            return .customView {
                Self.buildDecoration(
                    isSelected: isSelected,
                    isAnchor: isAnchor,
                    isBlocked: isBlocked,
                    isBooked: isBooked,
                    hasOverride: override != nil,
                    price: price,
                    source: source
                )
            }
        }

        /// Prioritet: anker (tykk ring) → valgt (fyld dot) → booking-ikon →
        /// blokkert-xmark → pris-label (farge etter kilde).
        static func buildDecoration(
            isSelected: Bool,
            isAnchor: Bool,
            isBlocked: Bool,
            isBooked: Bool,
            hasOverride: Bool,
            price: Int,
            source: String
        ) -> UIView {
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false

            let primary600 = UIColor(red: 70/255, green: 193/255, blue: 133/255, alpha: 1)

            if isAnchor {
                // Tykk ring for anker (start av aktivt område)
                let ring = UIView()
                ring.translatesAutoresizingMaskIntoConstraints = false
                ring.layer.borderColor = primary600.cgColor
                ring.layer.borderWidth = 2
                ring.layer.cornerRadius = 6
                container.addSubview(ring)
                NSLayoutConstraint.activate([
                    ring.widthAnchor.constraint(equalToConstant: 12),
                    ring.heightAnchor.constraint(equalToConstant: 12),
                    ring.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    ring.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                ])
            } else if isSelected {
                // Grønn fyld-dot for alminnelige valgte datoer
                let dot = UIView()
                dot.translatesAutoresizingMaskIntoConstraints = false
                dot.backgroundColor = primary600
                dot.layer.cornerRadius = 5
                container.addSubview(dot)
                NSLayoutConstraint.activate([
                    dot.widthAnchor.constraint(equalToConstant: 10),
                    dot.heightAnchor.constraint(equalToConstant: 10),
                    dot.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                ])
            } else if isBooked {
                let img = UIImageView(image: UIImage(systemName: "calendar.badge.checkmark"))
                img.translatesAutoresizingMaskIntoConstraints = false
                img.tintColor = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1)
                img.contentMode = .scaleAspectFit
                container.addSubview(img)
                NSLayoutConstraint.activate([
                    img.widthAnchor.constraint(equalToConstant: 12),
                    img.heightAnchor.constraint(equalToConstant: 12),
                    img.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    img.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                ])
            } else if isBlocked {
                let img = UIImageView(image: UIImage(systemName: "xmark"))
                img.translatesAutoresizingMaskIntoConstraints = false
                img.tintColor = .systemGray
                img.contentMode = .scaleAspectFit
                container.addSubview(img)
                NSLayoutConstraint.activate([
                    img.widthAnchor.constraint(equalToConstant: 10),
                    img.heightAnchor.constraint(equalToConstant: 10),
                    img.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    img.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                ])
            } else {
                // Pris-label — farge etter kilde
                let label = UILabel()
                label.translatesAutoresizingMaskIntoConstraints = false
                label.text = "\(price)"
                label.font = .systemFont(ofSize: 9, weight: .medium)
                label.textColor = priceColor(source: source, hasOverride: hasOverride)
                label.textAlignment = .center
                container.addSubview(label)
                NSLayoutConstraint.activate([
                    label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
                    label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
                ])
            }
            return container
        }

        private static func priceColor(source: String, hasOverride: Bool) -> UIColor {
            if hasOverride { return UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1) }
            switch source {
            case "season": return UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1)
            case "weekend": return UIColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 1)
            default: return UIColor.systemGray
            }
        }

        // MARK: Pris-logikk (speiler PricingService)

        private func priceForDate(_ date: Date, iso: String) -> Int {
            if let o = parent.overrides[iso] { return o }
            if let season = parent.rules.first(where: { r in
                guard r.kind == "season",
                      let start = r.start_date, let end = r.end_date else { return false }
                return iso >= start && iso <= end
            }) {
                return season.price
            }
            if let weekend = parent.rules.first(where: { r in
                r.kind == "weekend" && ((r.day_mask ?? 0) & (1 << weekdayBit(date))) != 0
            }) {
                return weekend.price
            }
            return parent.basePrice
        }

        private func sourceForDate(_ date: Date, iso: String) -> String {
            if parent.overrides[iso] != nil { return "override" }
            if parent.rules.contains(where: { r in
                guard r.kind == "season", let s = r.start_date, let e = r.end_date else { return false }
                return iso >= s && iso <= e
            }) { return "season" }
            if parent.rules.contains(where: { r in
                r.kind == "weekend" && ((r.day_mask ?? 0) & (1 << weekdayBit(date))) != 0
            }) { return "weekend" }
            return "base"
        }

        private func weekdayBit(_ date: Date) -> Int {
            let wd = calendar.component(.weekday, from: date)
            return wd == 1 ? 6 : wd - 2
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
