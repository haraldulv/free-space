import SwiftUI

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

/// Kalender for én annonse — multi-select, bulk-actions (blokker, sett pris,
/// fjern overstyring). Viser inneværende måned pluss 11 fremover som en vertikal
/// liste, Airbnb-stil.
struct HostCalendarView: View {
    let listing: Listing

    @State private var selectedDates: Set<String> = []
    @State private var blockedDates: Set<String> = []
    @State private var rules: [PricingService.Rule] = []
    @State private var overrides: [String: Int] = [:]
    @State private var bookedDates: Set<String> = []
    @State private var isLoading = true
    @State private var saving = false
    @State private var toast: String?
    @State private var showPriceSheet = false
    @State private var showPricingRulesEditor = false

    private let monthsAhead = 12
    private var basePrice: Int { listing.price ?? 0 }

    private let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private let monthNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "nb_NO")
        f.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        return f
    }()

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                if isLoading {
                    ProgressView().padding(.top, 40)
                }
                LazyVStack(spacing: 28, pinnedViews: [.sectionHeaders]) {
                    ForEach(visibleMonthList, id: \.self) { monthStart in
                        monthSection(monthStart)
                    }
                }
                .padding(.vertical, 16)
                .padding(.bottom, selectedDates.isEmpty ? 16 : 140)
            }

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
        .task(id: listing.id) { await loadAll() }
    }

    // MARK: - Month section

    @ViewBuilder
    private func monthSection(_ monthStart: Date) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(monthNameFormatter.string(from: monthStart).capitalized)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.neutral900)
                Spacer()
            }
            .padding(.horizontal, 20)

            // Ukedags-etiketter
            HStack(spacing: 0) {
                ForEach(["Ma", "Ti", "On", "To", "Fr", "Lø", "Sø"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.neutral500)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)

            // Grid
            let days = daysInMonthGrid(monthStart)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(for: date)
                    } else {
                        Color.clear.frame(height: 56)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let iso = isoFormatter.string(from: date)
        let isPast = Calendar.current.compare(date, to: Calendar.current.startOfDay(for: Date()), toGranularity: .day) == .orderedAscending
        let isBooked = bookedDates.contains(iso)
        let isBlocked = blockedDates.contains(iso)
        let isSelected = selectedDates.contains(iso)
        let override = overrides[iso]
        let price = priceForDate(date)
        let source = sourceForDate(date, iso: iso)

        Button {
            guard !isPast, !isBooked else { return }
            if selectedDates.contains(iso) {
                selectedDates.remove(iso)
            } else {
                selectedDates.insert(iso)
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(textColor(isPast: isPast, isBooked: isBooked, isBlocked: isBlocked, isSelected: isSelected))
                if !isPast && !isBooked && !isBlocked {
                    Text("\(price)")
                        .font(.system(size: 10))
                        .foregroundStyle(priceColor(source: source, isSelected: isSelected))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if isBooked {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.neutral500)
                }
                if isBlocked {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.neutral500)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(cellBackground(isPast: isPast, isBooked: isBooked, isBlocked: isBlocked, isSelected: isSelected, isOverride: override != nil))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.primary600 : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(isPast || isBooked)
    }

    private func textColor(isPast: Bool, isBooked: Bool, isBlocked: Bool, isSelected: Bool) -> Color {
        if isPast { return .neutral300 }
        if isBooked { return .neutral500 }
        if isBlocked { return .neutral400 }
        if isSelected { return Color.primary600 }
        return .neutral900
    }

    private func priceColor(source: String, isSelected: Bool) -> Color {
        if isSelected { return Color.primary600 }
        switch source {
        case "override": return Color(hex: "#10b981")
        case "season": return Color(hex: "#f59e0b")
        case "weekend": return Color(hex: "#3b82f6")
        default: return .neutral500
        }
    }

    private func cellBackground(isPast: Bool, isBooked: Bool, isBlocked: Bool, isSelected: Bool, isOverride: Bool) -> Color {
        if isSelected { return Color.primary50 }
        if isBooked { return Color(hex: "#fee2e2") }
        if isBlocked { return Color.neutral100 }
        if isOverride { return Color(hex: "#ecfdf5") }
        return Color.white
    }

    private func priceForDate(_ date: Date) -> Int {
        let iso = isoFormatter.string(from: date)
        if let o = overrides[iso] { return o }
        // Sjekk sesong
        if let season = rules.first(where: { r in
            guard r.kind == "season",
                  let start = r.start_date, let end = r.end_date else { return false }
            return iso >= start && iso <= end
        }) {
            return season.price
        }
        // Helg
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
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        let wd = cal.component(.weekday, from: date)
        return wd == 1 ? 6 : wd - 2
    }

    // MARK: - Selection bar

    private var selectionBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(selectedDates.count) \(selectedDates.count == 1 ? "dag valgt" : "dager valgt")")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Tøm") {
                    withAnimation { selectedDates.removeAll() }
                }
                .font(.system(size: 13))
                .foregroundStyle(.neutral600)
            }

            HStack(spacing: 8) {
                actionButton(
                    icon: "xmark.square.fill",
                    label: allSelectedBlocked ? "Fjern blokkering" : "Blokker"
                ) {
                    Task { await applyBlockToggle() }
                }
                actionButton(icon: "tag.fill", label: "Sett pris") {
                    showPriceSheet = true
                }
                actionButton(icon: "arrow.uturn.backward", label: "Fjern overstyring") {
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

    // MARK: - Data

    private var visibleMonthList: [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        cal.firstWeekday = 2
        var comps = cal.dateComponents([.year, .month], from: Date())
        comps.day = 1
        guard let first = cal.date(from: comps) else { return [] }
        return (0..<monthsAhead).compactMap { i in
            cal.date(byAdding: .month, value: i, to: first)
        }
    }

    private func daysInMonthGrid(_ monthStart: Date) -> [Date?] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo") ?? .current
        cal.firstWeekday = 2
        let range = cal.range(of: .day, in: .month, for: monthStart) ?? 1..<32
        let firstWeekdayOfMonth = cal.component(.weekday, from: monthStart)
        // Konverter til mandag-basert offset (mandag=0, søn=6)
        let leading = (firstWeekdayOfMonth + 5) % 7

        var result: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: monthStart) {
                result.append(d)
            }
        }
        // Pad ut til multipler av 7
        while result.count % 7 != 0 {
            result.append(nil)
        }
        return result
    }

    private func loadAll() async {
        isLoading = true
        blockedDates = Set(listing.blockedDates ?? [])
        rules = await PricingService.fetchRules(listingId: listing.id)
        let fetchedOverrides = await PricingService.fetchOverrides(listingId: listing.id)
        overrides = Dictionary(uniqueKeysWithValues: fetchedOverrides.map { ($0.date, $0.price) })
        await loadBookings()
        isLoading = false
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
            for b in rows {
                guard let start = isoFormatter.date(from: b.checkIn),
                      let end = isoFormatter.date(from: b.checkOut) else { continue }
                var cursor = start
                while cursor < end {
                    set.insert(isoFormatter.string(from: cursor))
                    cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor) ?? end
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
            flashToast(shouldBlock ? "Blokkert" : "Fjernet blokkering")
            selectedDates.removeAll()
        } catch {
            flashToast("Kunne ikke lagre")
            print("block toggle error: \(error)")
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

