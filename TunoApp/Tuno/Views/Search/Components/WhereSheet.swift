import SwiftUI
import CoreLocation

/// Airbnb-stil step-by-step søke-modal. Tre kort som ekspanderer ett ad
/// gangen (Hvor / Når / Hvem) med auto-hopp etter valg. Material-blur
/// bakgrunn lar kartet skinne gjennom subtilt. Kategori-pille svever
/// over kortene som flytende segmentknapp.
struct WhereSheet: View {
    enum Step: Hashable { case hvor, når, hvem }

    @Binding var isPresented: Bool
    @Binding var category: ListingCategory
    @Binding var query: String
    @Binding var checkIn: Date?
    @Binding var checkOut: Date?
    @Binding var flexibility: Int
    @Binding var bookingPref: BookingPreference
    @Binding var vehicles: Set<VehicleType>
    @Binding var openingHoursFilter: OpeningHoursFilter
    @ObservedObject var placesService: PlacesService
    @ObservedObject var locationManager: LocationManager
    let onSelectPlace: (PlacePrediction) -> Void
    let onUseMyLocation: () -> Void
    let onSearch: () -> Void

    @State private var activeStep: Step = .hvor
    @State private var typing: String = ""
    @State private var editingCheckIn: Bool = true
    /// Hvilket date-felt som åpnes i wheel-picker — nil = lukket.
    @State private var wheelPickerField: DateWheelField? = nil

    private static let suggestedDestinations: [SuggestedDestination] = [
        .init(name: "Oslo", subtitle: "Hovedstaden", icon: "building.2.fill",
              tint: Color(red: 0.91, green: 0.31, blue: 0.31), bg: Color(red: 1.0, green: 0.92, blue: 0.92)),
        .init(name: "Bergen", subtitle: "Vestlandet — fjord og fjell", icon: "mountain.2.fill",
              tint: Color(red: 0.23, green: 0.51, blue: 0.96), bg: Color(red: 0.91, green: 0.94, blue: 1.0)),
        .init(name: "Lofoten", subtitle: "Strand og fiske", icon: "fish.fill",
              tint: Color(red: 1.0, green: 0.66, blue: 0.18), bg: Color(red: 1.0, green: 0.96, blue: 0.86)),
    ]

    var body: some View {
        ZStack {
            // Material-blur bakgrunn — lar kartet/forsiden skinne gjennom
            // som subtilt blurret stoff. Etterligner Airbnb sin søke-overlay.
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                floatingHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            whereCard.id(Step.hvor)
                            whenCard.id(Step.når)
                            whoCard.id(Step.hvem)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: activeStep)
                    }
                    .onChange(of: activeStep) { _, newStep in
                        // Scroll det aktive cardet helt opp i viewet så bruker
                        // får full plass — collapserte cards over forsvinner.
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            proxy.scrollTo(newStep, anchor: .top)
                        }
                    }
                }

                bottomBar
            }
        }
        .onAppear { typing = query }
        .onChange(of: typing) { _, newValue in
            if newValue.isEmpty {
                placesService.clear()
            } else {
                placesService.autocomplete(query: newValue)
            }
        }
        .sheet(item: $wheelPickerField) { field in
            DateWheelSheet(
                field: field,
                checkIn: $checkIn,
                checkOut: $checkOut,
                allowSameDayCheckOut: false,
                onClose: { wheelPickerField = nil }
            )
            .presentationDetents([.height(380)])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(28)
        }
    }

    // MARK: - Floating header (kategori sveve + xmark)

    private var floatingHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { isPresented = false } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.neutral700)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Lukk")
            .padding(.top, 8)

            Spacer()

            categoryFloatingTabs

            Spacer()

            Color.clear.frame(width: 32, height: 32)
        }
    }

    /// Airbnb-stil floating kategori-tabs: ikoner med tekst under, hviler
    /// rett oppå blur-bakgrunnen (ingen pille). Aktiv kategori har en
    /// kort sort strek under teksten.
    private var categoryFloatingTabs: some View {
        HStack(alignment: .top, spacing: 28) {
            categoryFloatingTab(.camping, label: "Camping")
            categoryFloatingTab(.parking, label: "Parkering")
        }
    }

    private func categoryFloatingTab(_ value: ListingCategory, label: String) -> some View {
        let isSelected = category == value
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                let previous = category
                category = value
                if previous != value {
                    vehicles = (value == .camping) ? [.motorhome, .campervan] : [.car]
                }
            }
        } label: {
            VStack(spacing: 4) {
                Image(value.categoryIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .opacity(isSelected ? 1.0 : 0.55)
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .neutral900 : .neutral500)
                Rectangle()
                    .fill(isSelected ? Color.neutral900 : Color.clear)
                    .frame(height: 2)
                    .frame(width: 24)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cards

    @ViewBuilder
    private var whereCard: some View {
        if activeStep == .hvor {
            VStack(alignment: .leading, spacing: 16) {
                Text("Hvor?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.neutral900)
                searchField
                nearbyAndSuggestedSection
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        } else {
            collapsedCard(title: "Hvor", value: query.isEmpty ? "Søk etter reisemål" : query, step: .hvor)
        }
    }

    @ViewBuilder
    private var whenCard: some View {
        if activeStep == .når {
            VStack(alignment: .leading, spacing: 16) {
                Text("Hvor lenge?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.neutral900)
                inlineDatePicker
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        } else {
            collapsedCard(title: "Når", value: whenSummary, step: .når)
        }
    }

    @ViewBuilder
    private var whoCard: some View {
        if activeStep == .hvem {
            VStack(alignment: .leading, spacing: 20) {
                Text(category == .parking ? "Hva slags bil?" : "Hva slags kjøretøy?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.neutral900)
                vehicleSection
                bookingPrefSection
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        } else {
            collapsedCard(title: "Kjøretøy", value: whoSummary, step: .hvem)
        }
    }

    private func collapsedCard(title: String, value: String, step: Step) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                activeStep = step
            }
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.neutral500)
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral900)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var whenSummary: String {
        if let i = checkIn, let o = checkOut {
            let df = DateFormatter()
            df.dateFormat = "d. MMM"
            df.locale = Locale(identifier: "nb_NO")
            let dates = "\(df.string(from: i))–\(df.string(from: o))"
            if flexibility > 0 {
                return "\(dates) · ± \(flexibility) \(flexibility == 1 ? "dag" : "dager")"
            }
            return dates
        }
        return "Legg til datoer"
    }

    private var whoSummary: String {
        if vehicles.isEmpty { return "Alle kjøretøy" }
        if vehicles.count == 1, let v = vehicles.first { return v.displayName }
        return "\(vehicles.count) kjøretøy"
    }

    // MARK: - Where: search field + suggestions

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
            TextField("Søk etter reisemål", text: $typing)
                .font(.system(size: 16))
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !typing.isEmpty {
                Button {
                    typing = ""
                    placesService.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral300)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
    }

    @ViewBuilder
    private var nearbyAndSuggestedSection: some View {
        if !placesService.predictions.isEmpty {
            autocompleteList
        } else {
            VStack(spacing: 0) {
                nearbyShortcut
                if !RecentSearchesStore.shared.entries.isEmpty {
                    Divider().padding(.leading, 60)
                    recentSearchesList
                }
                ForEach(Self.suggestedDestinations) { dest in
                    Divider().padding(.leading, 60)
                    suggestedRow(dest)
                }
            }
        }
    }

    @ViewBuilder
    private var recentSearchesList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Nylige søk")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.neutral500)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 12)
            .padding(.bottom, 6)

            ForEach(RecentSearchesStore.shared.entries) { entry in
                Button {
                    typing = entry.placeName
                    query = entry.placeName
                    if let cat = ListingCategory(rawValue: entry.category) {
                        category = cat
                    }
                    checkIn = entry.checkIn
                    checkOut = entry.checkOut
                    placesService.autocomplete(query: entry.placeName)
                    Task {
                        for _ in 0..<15 {
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            if let first = placesService.predictions.first {
                                onSelectPlace(first)
                                await MainActor.run {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        activeStep = .når
                                    }
                                }
                                return
                            }
                        }
                        await MainActor.run {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                activeStep = .når
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.neutral100)
                                .frame(width: 40, height: 40)
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 16))
                                .foregroundStyle(.neutral600)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.placeName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.neutral900)
                            if let label = entry.dateRangeLabel {
                                Text(label)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.neutral500)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if entry.id != RecentSearchesStore.shared.entries.last?.id {
                    Divider().padding(.leading, 58)
                }
            }
        }
    }

    private var autocompleteList: some View {
        VStack(spacing: 0) {
            ForEach(placesService.predictions) { prediction in
                Button {
                    query = prediction.mainText
                    typing = prediction.mainText
                    placesService.clear()
                    onSelectPlace(prediction)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        activeStep = .når
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.primary50)
                                .frame(width: 40, height: 40)
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.primary600)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prediction.mainText)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.neutral900)
                            if !prediction.secondaryText.isEmpty {
                                Text(prediction.secondaryText)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.neutral500)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if prediction.id != placesService.predictions.last?.id {
                    Divider().padding(.leading, 58)
                }
            }
        }
    }

    private var nearbyShortcut: some View {
        Button {
            onUseMyLocation()
            query = "I nærheten"
            typing = "I nærheten"
            // Auto-hopp til Når-steget slik som de andre destinasjons-handlerne.
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                activeStep = .når
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary50)
                        .frame(width: 40, height: 40)
                    Image(systemName: "location.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary600)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("I nærheten")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text("Finn ut hva som finnes der du er")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func suggestedRow(_ dest: SuggestedDestination) -> some View {
        Button {
            query = dest.name
            typing = dest.name
            placesService.autocomplete(query: dest.name)
            Task {
                // Vent på prediction og oppdater søk når stedet er valgt,
                // deretter auto-hopp til Når-steget.
                for _ in 0..<15 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if let first = placesService.predictions.first {
                        onSelectPlace(first)
                        await MainActor.run {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                activeStep = .når
                            }
                        }
                        return
                    }
                }
                await MainActor.run {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        activeStep = .når
                    }
                }
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(dest.bg)
                        .frame(width: 40, height: 40)
                    Image(systemName: dest.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(dest.tint)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(dest.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text(dest.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - When (camping)

    /// Inline date picker — embedded direkte i whenCard (ingen separat sheet).
    /// Periode-toggle (Dag/Uke/Måned/År) på toppen som auto-velger range i kalenderen,
    /// så Innsjekk/Utsjekk-tabs og graphical kalender-grid under for fin-justering.
    private var inlineDatePicker: some View {
        VStack(spacing: 12) {
            rentalPeriodToggle

            HStack(spacing: 8) {
                dateTab(label: "Innsjekk", date: checkIn, isActive: editingCheckIn) {
                    editingCheckIn = true
                    wheelPickerField = .checkIn
                }
                dateTab(label: "Utsjekk", date: checkOut, isActive: !editingCheckIn) {
                    editingCheckIn = false
                    wheelPickerField = .checkOut
                }
            }

            // SearchDateRangePicker: pure-SwiftUI range-kalender. Tap dato 1
            // → checkIn (anchor). Tap dato 2 (senere) → checkOut + visuell
            // range mellom. Tap dato 2 (tidligere) eller etter begge er satt
            // → reset til ny anchor. Erstatter UICalendarView som hadde
            // sizing-problemer i kort-baserte WhereSheet-layouten.
            SearchDateRangePicker(
                checkIn: $checkIn,
                checkOut: $checkOut
            )
            .frame(maxHeight: 280)

            flexibilityChips

            if checkIn != nil || checkOut != nil {
                Button("Nullstill datoer") {
                    checkIn = nil
                    checkOut = nil
                    flexibility = 0
                    editingCheckIn = true
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.neutral600)
            }
        }
    }

    /// Periode-velger (1 dag / 1 uke / 1 måned / 1 år) — auto-strekker checkOut.
    /// Default = 1 dag (i dag → i dag).
    private var rentalPeriodToggle: some View {
        HStack(spacing: 8) {
            periodChip(label: "1 dag", icon: "sun.max", days: 1)
            periodChip(label: "1 uke", icon: "calendar.badge.clock", days: 7)
            periodChip(label: "1 måned", icon: "calendar", days: 30)
            periodChip(label: "1 år", icon: "infinity", days: 365)
        }
    }

    @ViewBuilder
    private func periodChip(label: String, icon: String, days: Int) -> some View {
        let isActive = isPeriodActive(days: days)
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                applyPeriodPreset(days: days)
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(isActive ? Color.primary700 : Color.neutral600)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActive ? Color.primary700 : Color.neutral700)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isActive ? Color.primary50 : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isActive ? Color.primary600 : Color.neutral200, lineWidth: isActive ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func isPeriodActive(days: Int) -> Bool {
        guard let inDate = checkIn, let outDate = checkOut else {
            // "1 dag" er aktiv hvis ingen datoer er satt (default-tilstand).
            return days == 1 && checkIn == nil && checkOut == nil
        }
        let cal = Calendar(identifier: .gregorian)
        let span = cal.dateComponents([.day], from: inDate, to: outDate).day ?? 0
        // Vi teller antall dager inklusivt begge endepunkter: 7-7 = 1 dag,
        // 7-13 = 7 dager (1 uke), 7-8 = 2 dager. Så span+1 = total dager.
        return span == days - 1
    }

    private func applyPeriodPreset(days: Int) {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        // Anchor = eksisterende checkIn, men aldri i fortiden — klampes til
        // today så preset-knappene aldri stretcher en stale dato.
        let storedAnchor = checkIn.map(cal.startOfDay(for:))
        let anchor = (storedAnchor.map { max($0, today) }) ?? today
        checkIn = anchor
        // 1 dag = samme dag (7. mai → 7. mai). 1 uke = X → X+6 (begge dager teller, totalt 7).
        // 1 måned = X → X+29 (30 dager). 1 år = X → X+364 (365 dager).
        if days == 1 {
            checkOut = anchor
        } else {
            checkOut = cal.date(byAdding: .day, value: days - 1, to: anchor) ?? anchor
        }
        editingCheckIn = false
    }

    /// "Jeg er fleksibel"-chips. Lar brukeren utvide søket med ±N dager
    /// rundt valgt periode. Speiler Airbnb sin "I'm flexible"-funksjonalitet.
    @ViewBuilder
    private var flexibilityChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Jeg er fleksibel")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral700)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    flexChip(label: "Eksakt", value: 0)
                    flexChip(label: "± 1 dag", value: 1)
                    flexChip(label: "± 2 dager", value: 2)
                    flexChip(label: "± 3 dager", value: 3)
                    flexChip(label: "± 7 dager", value: 7)
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private func flexChip(label: String, value: Int) -> some View {
        let active = flexibility == value
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { flexibility = value }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? .white : .neutral800)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(active ? Color.neutral900 : Color.neutral50)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(active ? Color.neutral900 : Color.neutral200, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func dateTab(label: String, date: Date?, isActive: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isActive ? Color.primary700 : Color.neutral500)
                Text(date.map(formatDate) ?? "Velg dato")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(date == nil ? .neutral400 : .neutral900)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isActive ? Color.primary50 : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.primary600 : Color.neutral200, lineWidth: isActive ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "d. MMM"
        df.locale = Locale(identifier: "nb_NO")
        return df.string(from: date)
    }

    // MARK: - Opening hours (parkering only)

    private var openingHoursSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tilgjengelighet")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)

            HStack(spacing: 0) {
                openingHoursSegment(.any, label: "Alle")
                openingHoursSegment(.alwaysOpen, label: "Hele dagen", icon: "clock.fill")
            }
            .padding(3)
            .background(Color.neutral100)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func openingHoursSegment(_ value: OpeningHoursFilter, label: String, icon: String? = nil) -> some View {
        let isSelected = openingHoursFilter == value
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { openingHoursFilter = value }
        } label: {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                }
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .neutral900 : .neutral500)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(isSelected ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .shadow(color: isSelected ? .black.opacity(0.06) : .clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Booking preference

    private var bookingPrefSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bestillingstype")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)

            HStack(spacing: 0) {
                bookingPrefSegment(.all, label: "Alle")
                bookingPrefSegment(.directOnly, label: "Direkte", icon: "bolt.fill")
                bookingPrefSegment(.requestOnly, label: "Forespørsel", icon: "envelope.fill")
            }
            .padding(3)
            .background(Color.neutral100)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func bookingPrefSegment(_ value: BookingPreference, label: String, icon: String? = nil) -> some View {
        let isSelected = bookingPref == value
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { bookingPref = value }
        } label: {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                }
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .neutral900 : .neutral500)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(isSelected ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .shadow(color: isSelected ? .black.opacity(0.06) : .clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Vehicle multi-select

    private var vehicleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(VehicleType.allCases, id: \.self) { type in
                    vehicleChip(type)
                }
            }
        }
    }

    private func vehicleChip(_ type: VehicleType) -> some View {
        let isSelected = vehicles.contains(type)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    if vehicles.count > 1 { vehicles.remove(type) }
                } else {
                    vehicles.insert(type)
                }
            }
        } label: {
            VStack(spacing: 4) {
                Image(type.lucideIcon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(isSelected ? Color.primary600 : .neutral500)
                Text(type.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? .neutral900 : .neutral500)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.primary50 : Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.primary600 : Color.neutral200, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom bar

    /// Steg-rekkefølge for "Neste"-knappen.
    private var nextStep: Step? {
        switch activeStep {
        case .hvor: return .når
        case .når: return .hvem
        case .hvem: return nil  // siste — knappen blir "Søk"
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button("Fjern alle") {
                    typing = ""
                    query = ""
                    checkIn = nil
                    checkOut = nil
                    bookingPref = .all
                    vehicles = (category == .camping) ? [.motorhome, .campervan] : [.car]
                    placesService.clear()
                    activeStep = .hvor
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.neutral700)
                .underline()

                Spacer()

                if let next = nextStep {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            activeStep = next
                        }
                    } label: {
                        Text("Neste")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 36)
                            .padding(.vertical, 14)
                            .background(Color.neutral900)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                } else {
                    Button {
                        onSearch()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Søk")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.primary600)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
    }
}

private struct SuggestedDestination: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let icon: String
    let tint: Color
    let bg: Color
}

/// Kompakt rullehjul-tidsvelger. To wheels: time (0..23) + minutt (0/30).
/// Eksponerer total minutter siden midnatt via `minutes`-binding.
struct TimeWheelPicker: View {
    let label: String
    @Binding var minutes: Int?

    private var hour: Int { (minutes ?? 0) / 60 }
    private var minute: Int { (minutes ?? 0) % 60 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.neutral500)

            HStack(spacing: 0) {
                Picker("", selection: Binding(
                    get: { hour },
                    set: { newH in
                        let m = minute
                        minutes = newH * 60 + m
                    }
                )) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 110)
                .clipped()

                Text(":")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(minutes == nil ? .neutral400 : .neutral900)

                Picker("", selection: Binding(
                    get: { minute },
                    set: { newM in
                        let h = hour
                        minutes = h * 60 + newM
                    }
                )) {
                    ForEach([0, 30], id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 110)
                .clipped()
            }
            .background(Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
        }
    }
}

// MARK: - Date wheel-picker sheet

/// Identifier for hvilket date-felt wheel-pickeren åpnes for.
enum DateWheelField: Identifiable {
    case checkIn, checkOut
    var id: Self { self }
}

/// Wheel-picker for direkte dato-valg på Innsjekk eller Utsjekk.
/// Glassmorphism-sheet (ultraThinMaterial) — speiler resten av søke-modal-stilen.
/// Brukes både i WhereSheet (søk) og BookingView.
struct DateWheelSheet: View {
    let field: DateWheelField
    @Binding var checkIn: Date?
    @Binding var checkOut: Date?
    /// I booking-konteksten er checkOut samme dag tillatt (1-dag-booking).
    /// I søk-konteksten kreves checkOut > checkIn (range med ≥1 natt).
    /// Default true (samme dag = OK) — bookings setter dette eksplisitt.
    var allowSameDayCheckOut: Bool = true
    let onClose: () -> Void

    @State private var draftDate: Date = Date()

    private var fieldLabel: String {
        switch field {
        case .checkIn: return "Innsjekk"
        case .checkOut: return "Utsjekk"
        }
    }

    private var minDate: Date {
        let cal = Calendar(identifier: .gregorian)
        switch field {
        case .checkIn: return cal.startOfDay(for: Date())
        case .checkOut:
            if let ci = checkIn {
                let offset = allowSameDayCheckOut ? 0 : 1
                return cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: ci)) ?? Date()
            }
            return cal.startOfDay(for: Date())
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(fieldLabel)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.neutral900)
                .padding(.top, 18)

            DatePicker(
                "",
                selection: $draftDate,
                in: minDate...,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "nb_NO"))

            Button {
                let cal = Calendar(identifier: .gregorian)
                let normalized = cal.startOfDay(for: draftDate)
                switch field {
                case .checkIn:
                    checkIn = normalized
                    if let co = checkOut {
                        let coStart = cal.startOfDay(for: co)
                        // Hvis utsjekk er nå før innsjekk, eller (i søk-modus) samme dag → reset
                        if coStart < normalized || (!allowSameDayCheckOut && coStart == normalized) {
                            checkOut = nil
                        }
                    }
                case .checkOut:
                    checkOut = normalized
                    if checkIn == nil {
                        checkIn = cal.startOfDay(for: Date())
                    }
                }
                onClose()
            } label: {
                Text("Bruk \(fieldLabel.lowercased())")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.neutral900)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            switch field {
            case .checkIn: draftDate = checkIn ?? Date()
            case .checkOut: draftDate = checkOut ?? minDate
            }
        }
    }
}

