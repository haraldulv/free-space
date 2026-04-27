import SwiftUI
import CoreLocation

/// Airbnb-stil "Hvor?"-modal som åpnes ved tap på SearchPill.
/// Stacked cards: Hvor, Når, Direktebooking, Kjøretøystype.
/// Kun ett kort er expanded om gangen — de andre vises som compact rows
/// med label + valgt verdi, og ekspanderer når man trykker på dem.
struct WhereSheet: View {
    @Binding var isPresented: Bool
    @Binding var query: String
    @Binding var checkIn: Date?
    @Binding var checkOut: Date?
    @Binding var instantOnly: Bool
    @Binding var vehicle: VehicleType
    @ObservedObject var placesService: PlacesService
    @ObservedObject var locationManager: LocationManager
    let onSelectPlace: (PlacePrediction) -> Void
    let onUseMyLocation: () -> Void
    let onSearch: () -> Void

    enum Step: Hashable { case wherePlace, when, instant, vehicle }

    @State private var activeStep: Step = .wherePlace
    @State private var typing: String = ""

    private static let suggestedDestinations: [SuggestedDestination] = [
        .init(name: "Oslo", subtitle: "Hovedstaden — bynære plasser", icon: "building.2.fill"),
        .init(name: "Bergen", subtitle: "Vestlandet — fjord og fjell", icon: "mountain.2.fill"),
        .init(name: "Trondheim", subtitle: "Midt-Norge — hytteliv", icon: "tree.fill"),
        .init(name: "Stavanger", subtitle: "Preikestolen og Lysefjorden", icon: "drop.fill"),
        .init(name: "Tromsø", subtitle: "Nord-Norge — nordlys", icon: "sparkles"),
        .init(name: "Lofoten", subtitle: "Strand og fiske", icon: "fish.fill"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    whereCard
                    whenCard
                    instantCard
                    vehicleCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 140)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: activeStep)
            }
            .background(Color.neutral100)
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
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
                            .background(Circle().fill(Color.white))
                            .overlay(Circle().stroke(Color.neutral200, lineWidth: 1))
                    }
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
        }
    }

    // MARK: - Cards

    private var whereCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if activeStep == .wherePlace {
                expandedHeader(title: "Hvor?")
                searchField
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                if !placesService.predictions.isEmpty {
                    autocompleteList
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                } else {
                    nearbyShortcut
                        .padding(.horizontal, 12)
                        .padding(.top, 12)

                    suggestedSection
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                }
            } else {
                compactRow(
                    label: "Hvor",
                    value: query.isEmpty ? "Hvor som helst" : query,
                    onTap: { activeStep = .wherePlace }
                )
            }
        }
        .padding(.bottom, activeStep == .wherePlace ? 20 : 0)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private var whenCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if activeStep == .when {
                expandedHeader(title: "Når")
                DatePicker(
                    "Innsjekk",
                    selection: Binding(
                        get: { checkIn ?? Date() },
                        set: { newValue in
                            checkIn = newValue
                            if let out = checkOut, out <= newValue {
                                checkOut = Calendar.current.date(byAdding: .day, value: 1, to: newValue)
                            } else if checkOut == nil {
                                checkOut = Calendar.current.date(byAdding: .day, value: 1, to: newValue)
                            }
                        }
                    ),
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "nb_NO"))
                .environment(\.calendar, {
                    var cal = Calendar(identifier: .gregorian)
                    cal.firstWeekday = 2
                    return cal
                }())
                .padding(.horizontal, 12)

                HStack(spacing: 8) {
                    dateLabelChip(text: "Inn", date: checkIn)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.neutral400)
                    dateLabelChip(text: "Ut", date: checkOut)
                    Spacer()
                    Button("Nullstill") {
                        checkIn = nil
                        checkOut = nil
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.neutral500)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 14)
            } else {
                compactRow(label: "Når", value: dateLabel, onTap: { activeStep = .when })
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private var instantCard: some View {
        Group {
            if activeStep == .instant {
                VStack(alignment: .leading, spacing: 0) {
                    expandedHeader(title: "Direktebooking")
                    Button {
                        instantOnly.toggle()
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(instantOnly ? Color.primary50 : Color.neutral50)
                                    .frame(width: 48, height: 48)
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(instantOnly ? Color.primary600 : .neutral500)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Kun direktebooking")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.neutral900)
                                Text("Plasser du kan booke umiddelbart")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.neutral500)
                            }
                            Spacer()
                            ZStack {
                                Capsule()
                                    .fill(instantOnly ? Color.primary600 : Color.neutral200)
                                    .frame(width: 44, height: 26)
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 22, height: 22)
                                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                                    .offset(x: instantOnly ? 9 : -9)
                            }
                            .animation(.easeInOut(duration: 0.2), value: instantOnly)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                }
            } else {
                compactRow(
                    label: "Direktebooking",
                    value: instantOnly ? "På" : "Av",
                    onTap: { activeStep = .instant }
                )
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private var vehicleCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if activeStep == .vehicle {
                expandedHeader(title: "Kjøretøystype")
                VStack(spacing: 8) {
                    ForEach(VehicleType.allCases, id: \.self) { type in
                        Button {
                            vehicle = type
                        } label: {
                            HStack(spacing: 14) {
                                Image(type.lucideIcon)
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 28, height: 28)
                                    .foregroundStyle(vehicle == type ? Color.primary600 : .neutral500)
                                Text(type.displayName)
                                    .font(.system(size: 15, weight: vehicle == type ? .semibold : .medium))
                                    .foregroundStyle(.neutral900)
                                Spacer()
                                if vehicle == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.primary600)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(vehicle == type ? Color.primary50 : Color.neutral50)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            } else {
                compactRow(
                    label: "Kjøretøystype",
                    value: vehicle.displayName,
                    onTap: { activeStep = .vehicle }
                )
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Sub-views

    private func expandedHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.neutral900)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private func compactRow(label: String, value: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral500)
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral900)
                    .lineLimit(1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

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
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.neutral200, lineWidth: 1))
    }

    private var autocompleteList: some View {
        VStack(spacing: 0) {
            ForEach(placesService.predictions) { prediction in
                Button {
                    query = prediction.mainText
                    typing = prediction.mainText
                    placesService.clear()
                    onSelectPlace(prediction)
                    advanceFromWhere()
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.primary50)
                                .frame(width: 44, height: 44)
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 20))
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                if prediction.id != placesService.predictions.last?.id {
                    Divider().padding(.leading, 66)
                }
            }
        }
    }

    private var nearbyShortcut: some View {
        Button {
            onUseMyLocation()
            query = "I nærheten"
            typing = "I nærheten"
            advanceFromWhere()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary50)
                        .frame(width: 44, height: 44)
                    Image(systemName: "location.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.primary600)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("I nærheten")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text("Finn ut hva som finnes der du er")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Foreslåtte reisemål")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)
                .padding(.horizontal, 8)
                .padding(.top, 4)

            VStack(spacing: 0) {
                ForEach(Self.suggestedDestinations) { dest in
                    Button {
                        query = dest.name
                        typing = dest.name
                        placesService.autocomplete(query: dest.name)
                        Task {
                            try? await Task.sleep(nanoseconds: 350_000_000)
                            if let first = placesService.predictions.first {
                                onSelectPlace(first)
                                advanceFromWhere()
                            }
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.primary50)
                                    .frame(width: 44, height: 44)
                                Image(systemName: dest.icon)
                                    .font(.system(size: 18))
                                    .foregroundStyle(.primary600)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dest.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.neutral900)
                                Text(dest.subtitle)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.neutral500)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func dateLabelChip(text: String, date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.neutral500)
            Text(date.map(formatDate) ?? "Velg")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral900)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "d. MMM"
        df.locale = Locale(identifier: "nb_NO")
        return df.string(from: date)
    }

    private var dateLabel: String {
        guard let i = checkIn, let o = checkOut else { return "Når som helst" }
        return "\(formatDate(i))–\(formatDate(o))"
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
                    instantOnly = false
                    vehicle = .motorhome
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
                    .padding(.horizontal, 28)
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

    /// Etter brukeren har valgt et sted, kollaps Hvor og hopp til Når.
    private func advanceFromWhere() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            activeStep = .when
        }
    }
}

private struct SuggestedDestination: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let icon: String
}
