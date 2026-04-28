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
    @Binding var startMinutes: Int?
    @Binding var endMinutes: Int?
    @Binding var bookingPref: BookingPreference
    @Binding var vehicles: Set<VehicleType>
    @ObservedObject var placesService: PlacesService
    @ObservedObject var locationManager: LocationManager
    let onSelectPlace: (PlacePrediction) -> Void
    let onUseMyLocation: () -> Void
    let onSearch: () -> Void

    @State private var activeStep: Step = .hvor
    @State private var typing: String = ""
    @State private var showDatePicker = false
    @State private var datePickerEditingCheckIn = true

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

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        whereCard
                        whenCard
                        whoCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: activeStep)
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
        .sheet(isPresented: $showDatePicker) {
            DateRangePicker(
                checkIn: $checkIn,
                checkOut: $checkOut,
                initialEditingCheckIn: datePickerEditingCheckIn,
                onDone: {
                    showDatePicker = false
                    // Auto-hopp til "Hvem" når begge datoene er valgt
                    if checkIn != nil && checkOut != nil {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            activeStep = .hvem
                        }
                    }
                }
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Floating header (kategori sveve + xmark)

    private var floatingHeader: some View {
        HStack(spacing: 12) {
            Button { isPresented = false } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color(.systemGray3))
            }
            .accessibilityLabel("Lukk")

            Spacer()

            categoryFloatingPill

            Spacer()

            Color.clear.frame(width: 28, height: 28)
        }
    }

    private var categoryFloatingPill: some View {
        HStack(spacing: 0) {
            categoryFloatingTab(.camping, label: "Camping", icon: "tent.fill")
            categoryFloatingTab(.parking, label: "Parkering", icon: "car.fill")
        }
        .padding(4)
        .background(Capsule().fill(Color.white))
        .shadow(color: .black.opacity(0.10), radius: 8, y: 2)
    }

    private func categoryFloatingTab(_ value: ListingCategory, label: String, icon: String) -> some View {
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
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .neutral500)
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .neutral500)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? Color.neutral900 : Color.clear))
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
                Text("Når?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.neutral900)
                if category == .parking {
                    timeRangeSection
                } else {
                    whenSection
                }
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
            return "\(df.string(from: i))–\(df.string(from: o))"
        }
        if category == .parking, let s = startMinutes, let e = endMinutes {
            return String(format: "%02d:%02d–%02d:%02d", s/60, s%60, e/60, e%60)
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
                ForEach(Self.suggestedDestinations) { dest in
                    Divider().padding(.leading, 60)
                    suggestedRow(dest)
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
            // "I nærheten" lukker hele sheet og søker direkte (Airbnb-paritet)
            onSearch()
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
        }
        .buttonStyle(.plain)
    }

    private func suggestedRow(_ dest: SuggestedDestination) -> some View {
        Button {
            query = dest.name
            typing = dest.name
            placesService.autocomplete(query: dest.name)
            Task {
                // Vent på prediction og auto-hopp til Når-steget når stedet er valgt
                for _ in 0..<15 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if let first = placesService.predictions.first {
                        onSelectPlace(first)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            activeStep = .når
                        }
                        return
                    }
                }
                // Fallback: hadde ikke prediction — hopp likevel
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    activeStep = .når
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
        }
        .buttonStyle(.plain)
    }

    // MARK: - When (camping)

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                dateChip(label: "Innsjekk", date: checkIn) {
                    datePickerEditingCheckIn = true
                    showDatePicker = true
                }
                dateChip(label: "Utsjekk", date: checkOut) {
                    datePickerEditingCheckIn = false
                    showDatePicker = true
                }
            }
        }
    }

    private func dateChip(label: String, date: Date?, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.neutral500)
                Text(date.map(formatDate) ?? "Velg dato")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(date == nil ? .neutral400 : .neutral900)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "d. MMM"
        df.locale = Locale(identifier: "nb_NO")
        return df.string(from: date)
    }

    // MARK: - When (parkering): tidspunkt

    /// Nåværende klokkeslett rundet opp til nærmeste hele 30 minutter.
    /// Eksempler: 14:07 → 14:30, 14:32 → 15:00, 23:50 → 24:00.
    private static func roundedNowMinutes() -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let total = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let snapped = ((total + 29) / 30) * 30
        return min(snapped, 24 * 60)
    }

    private var timeRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                TimeWheelPicker(label: "Fra", minutes: $startMinutes)
                    .frame(maxWidth: .infinity)
                TimeWheelPicker(label: "Til", minutes: $endMinutes)
                    .frame(maxWidth: .infinity)
            }
            .onChange(of: startMinutes) { _, newVal in
                if let s = newVal, let e = endMinutes, e <= s {
                    endMinutes = min(24 * 60, s + 30)
                }
            }

            // Hurtigvalg for varighet — relative til startMinutes
            HStack(spacing: 8) {
                durationChip(label: "1 time", hours: 1)
                durationChip(label: "2 timer", hours: 2)
                durationChip(label: "4 timer", hours: 4)
            }
        }
        .onAppear {
            // Default: starttid = nå rundet opp til halvtimen, slutt = +1 time
            if startMinutes == nil {
                let start = Self.roundedNowMinutes()
                startMinutes = start
                if endMinutes == nil { endMinutes = min(24 * 60, start + 60) }
            }
        }
    }

    private func durationChip(label: String, hours: Int) -> some View {
        let durationMinutes = hours * 60
        let start = startMinutes ?? Self.roundedNowMinutes()
        let isSelected = (endMinutes ?? -1) == min(24 * 60, start + durationMinutes)
        return Button {
            if startMinutes == nil { startMinutes = start }
            endMinutes = min(24 * 60, start + durationMinutes)
            // Auto-hopp til Hvem-steget etter varighet er valgt
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                activeStep = .hvem
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .neutral900)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.neutral900 : Color.neutral50)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.clear : Color.neutral200, lineWidth: 1))
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
            Text("Kjøretøytype (velg flere)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)

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

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button("Fjern alle") {
                    typing = ""
                    query = ""
                    checkIn = nil
                    checkOut = nil
                    startMinutes = nil
                    endMinutes = nil
                    bookingPref = .all
                    vehicles = (category == .camping) ? [.motorhome, .campervan] : [.car]
                    placesService.clear()
                    activeStep = .hvor
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.neutral700)
                .underline()

                Spacer()

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

/// Ekte range-picker for Inn/Ut. To tabs øverst som veksler hvilken
/// dato man redigerer. Validerer at Ut > Inn automatisk.
struct DateRangePicker: View {
    @Binding var checkIn: Date?
    @Binding var checkOut: Date?
    let initialEditingCheckIn: Bool
    let onDone: () -> Void

    @State private var editingCheckIn: Bool = true
    @State private var tempIn: Date = Date()
    @State private var tempOut: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Nullstill") {
                    checkIn = nil
                    checkOut = nil
                    onDone()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.neutral500)

                Spacer()

                Text("Velg datoer")
                    .font(.system(size: 17, weight: .semibold))

                Spacer()

                Button("Bruk") {
                    checkIn = tempIn
                    checkOut = tempOut
                    onDone()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary600)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            HStack(spacing: 8) {
                rangeTab(label: "Innsjekk", date: tempIn, isActive: editingCheckIn) {
                    editingCheckIn = true
                }
                rangeTab(label: "Utsjekk", date: tempOut, isActive: !editingCheckIn) {
                    editingCheckIn = false
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider()

            DatePicker(
                "",
                selection: editingCheckIn ? $tempIn : $tempOut,
                in: editingCheckIn ? Date()... : Calendar.current.date(byAdding: .day, value: 1, to: tempIn)!...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(.horizontal, 12)
            .environment(\.locale, Locale(identifier: "nb_NO"))
            .environment(\.calendar, {
                var cal = Calendar(identifier: .gregorian)
                cal.firstWeekday = 2
                return cal
            }())
            .onChange(of: tempIn) { _, newValue in
                if tempOut <= newValue {
                    tempOut = Calendar.current.date(byAdding: .day, value: 1, to: newValue)!
                }
                if editingCheckIn {
                    withAnimation(.easeInOut(duration: 0.18)) { editingCheckIn = false }
                }
            }

            Spacer()
        }
        .onAppear {
            editingCheckIn = initialEditingCheckIn
            if let i = checkIn { tempIn = i }
            if let o = checkOut { tempOut = o }
            if tempOut <= tempIn {
                tempOut = Calendar.current.date(byAdding: .day, value: 1, to: tempIn)!
            }
        }
    }

    private func rangeTab(label: String, date: Date, isActive: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isActive ? .primary600 : .neutral500)
                Text(formatDate(date))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isActive ? .neutral900 : .neutral500)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isActive ? Color.primary50 : Color.neutral50)
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
        df.dateFormat = "d. MMMM"
        df.locale = Locale(identifier: "nb_NO")
        return df.string(from: date)
    }
}
