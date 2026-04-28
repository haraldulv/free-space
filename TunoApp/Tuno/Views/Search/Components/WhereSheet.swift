import SwiftUI
import CoreLocation

/// Airbnb-stil full-screen "Hvor?"-modal som åpnes ved tap på SearchPill.
/// Alle inputs er synlige uten å scrolle på normale skjermer:
/// - Søkefelt + 3 stedsforslag (i nærheten + Oslo + Bergen + Lofoten)
/// - Inn/Ut datovelger med ekte range-picker (tap chip → bytter aktiv dato)
/// - Direktebooking 3-state segment: Alle / Direkte / Forespørsel
/// - Multi-select kjøretøystyper som chips
/// - Bunnbar med "Fjern alle" + "Søk"
struct WhereSheet: View {
    @Binding var isPresented: Bool
    @Binding var category: ListingCategory
    @Binding var query: String
    @Binding var checkIn: Date?
    @Binding var checkOut: Date?
    /// Tidspunkt for parkering. NULL = uspesifisert (vis kun datoer).
    @Binding var startHour: Int?
    @Binding var endHour: Int?
    @Binding var bookingPref: BookingPreference
    @Binding var vehicles: Set<VehicleType>
    @ObservedObject var placesService: PlacesService
    @ObservedObject var locationManager: LocationManager
    let onSelectPlace: (PlacePrediction) -> Void
    let onUseMyLocation: () -> Void
    let onSearch: () -> Void

    @State private var typing: String = ""
    @State private var showDatePicker = false
    @State private var datePickerEditingCheckIn = true

    /// 3 destinasjoner med varierte ikon-bakgrunnsfarger så Hvor-listen
    /// ikke blir for grønn.
    private static let suggestedDestinations: [SuggestedDestination] = [
        .init(name: "Oslo", subtitle: "Hovedstaden", icon: "building.2.fill",
              tint: Color(red: 0.91, green: 0.31, blue: 0.31), bg: Color(red: 1.0, green: 0.92, blue: 0.92)),
        .init(name: "Bergen", subtitle: "Vestlandet — fjord og fjell", icon: "mountain.2.fill",
              tint: Color(red: 0.23, green: 0.51, blue: 0.96), bg: Color(red: 0.91, green: 0.94, blue: 1.0)),
        .init(name: "Lofoten", subtitle: "Strand og fiske", icon: "fish.fill",
              tint: Color(red: 1.0, green: 0.66, blue: 0.18), bg: Color(red: 1.0, green: 0.96, blue: 0.86)),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        categorySection
                        searchField
                        nearbyAndSuggestedSection
                        whenSection
                        if category == .parking {
                            timeRangeSection
                        }
                        bookingPrefSection
                        vehicleSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }

                bottomBar
            }
            .background(Color.white.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.neutral900)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.neutral50))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Hvor?")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.neutral900)
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
                    onDone: { showDatePicker = false }
                )
                .presentationDetents([.large])
            }
        }
    }

    // MARK: - Category picker (camping vs parkering)

    private var categorySection: some View {
        HStack(spacing: 0) {
            categorySegment(.camping, label: "Camping", icon: "tent.fill", subtitle: "Per natt")
            categorySegment(.parking, label: "Parkering", icon: "car.fill", subtitle: "Per time")
        }
        .padding(3)
        .background(Color.neutral100)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func categorySegment(_ value: ListingCategory, label: String, icon: String, subtitle: String) -> some View {
        let isSelected = category == value
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                category = value
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? .primary600 : .neutral500)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .neutral900 : .neutral500)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? .primary600 : .neutral400)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .shadow(color: isSelected ? .black.opacity(0.06) : .clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Time range (kun parkering)

    private var timeRangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tidspunkt")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.neutral500)
                    .textCase(.uppercase)
                Spacer()
                if startHour != nil || endHour != nil {
                    Button("Nullstill") {
                        startHour = nil
                        endHour = nil
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.neutral500)
                }
            }

            HStack(spacing: 8) {
                hourChip(label: "Fra", value: startHour) { newVal in
                    startHour = newVal
                    if let s = startHour, let e = endHour, e <= s {
                        endHour = min(24, s + 1)
                    }
                }
                hourChip(label: "Til", value: endHour) { newVal in
                    endHour = newVal
                }
            }

            Text("Default-søk er hele dagen. Velg tid for å filtrere på parkeringer som er ledige akkurat da.")
                .font(.system(size: 11))
                .foregroundStyle(.neutral400)
        }
    }

    private func hourChip(label: String, value: Int?, onSelect: @escaping (Int) -> Void) -> some View {
        Menu {
            ForEach(0..<24, id: \.self) { h in
                Button(String(format: "%02d:00", h)) { onSelect(h) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.neutral500)
                Text(value.map { String(format: "%02d:00", $0) } ?? "Velg tid")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(value == nil ? .neutral400 : .neutral900)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
        }
    }

    // MARK: - Search field & destinations

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
            // Trigger søket — onSearch lukker sheet og åpner kartet via parent.
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
                // Vent opp til 1.5s på prediction før vi gir opp.
                // 350ms-fast-sleep slo ofte ut når Places API var treg, og brukeren
                // havnet tilbake på forsiden uten place satt.
                for _ in 0..<15 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if let first = placesService.predictions.first {
                        onSelectPlace(first)
                        onSearch()
                        return
                    }
                }
                // Fallback: hadde ikke en prediction, men feltet er fylt — la søket gå
                // med kun query (SearchView geokoder selv ved fallback).
                onSearch()
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

    // MARK: - When section

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Når")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)

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
            Text("Kjøretøystype (velg flere)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)

            // 3 chips per rad, deretter 2 til = 5 totalt på 2 rader
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
                    startHour = nil
                    endHour = nil
                    bookingPref = .all
                    vehicles = [.motorhome]
                    placesService.clear()
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
        .background(Color.white)
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
                // Når Inn endres: hold Ut > Inn. Bytt automatisk til Ut-tab
                // sånn at brukeren kan velge Ut umiddelbart etter.
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
