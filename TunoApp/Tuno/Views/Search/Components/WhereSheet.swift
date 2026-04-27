import SwiftUI
import CoreLocation

/// Airbnb-stil "Hvor?"-modal som åpnes ved tap på SearchPill.
/// Innhold: kategori-tabs (kun "Hjem" aktiv for Tuno), søkefelt med
/// Google Places autocomplete, "I nærheten"-snarvei, foreslåtte
/// destinasjoner, og rader for datoer + gjester.
struct WhereSheet: View {
    @Binding var isPresented: Bool
    @Binding var query: String
    @Binding var checkIn: Date?
    @Binding var checkOut: Date?
    @Binding var guests: Int
    @ObservedObject var placesService: PlacesService
    @ObservedObject var locationManager: LocationManager
    let onSelectPlace: (PlacePrediction) -> Void
    let onUseMyLocation: () -> Void
    let onSearch: () -> Void

    @State private var showDatePicker = false
    @State private var showGuestPicker = false
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
                VStack(spacing: 24) {
                    searchField
                    if !placesService.predictions.isEmpty {
                        autocompleteList
                    } else {
                        nearbyShortcut
                        suggestedSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 200)
            }
            .background(Color.white)
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.neutral700)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Hvor?")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DateRangePickerSheet(checkIn: $checkIn, checkOut: $checkOut) {
                showDatePicker = false
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showGuestPicker) {
            GuestPickerSheet(guests: $guests) {
                showGuestPicker = false
            }
            .presentationDetents([.height(280)])
        }
        .onAppear {
            typing = query
        }
        .onChange(of: typing) { _, newValue in
            if newValue.isEmpty {
                placesService.clear()
            } else {
                placesService.autocomplete(query: newValue)
            }
        }
    }

    // MARK: - Sections

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
                    isPresented = false
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
                    .padding(.vertical, 6)
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
            isPresented = false
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
        }
        .buttonStyle(.plain)
    }

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Foreslåtte reisemål")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral500)
                .textCase(.uppercase)

            VStack(spacing: 4) {
                ForEach(Self.suggestedDestinations) { dest in
                    Button {
                        query = dest.name
                        typing = dest.name
                        placesService.autocomplete(query: dest.name)
                        // La autocomplete-svaret komme + bruk første resultat
                        Task {
                            try? await Task.sleep(nanoseconds: 350_000_000)
                            if let first = placesService.predictions.first {
                                onSelectPlace(first)
                                isPresented = false
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
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Divider()
            HStack(spacing: 8) {
                bottomRow(
                    icon: "calendar",
                    label: "Når",
                    value: dateLabel,
                    onTap: { showDatePicker = true }
                )
                bottomRow(
                    icon: "person.2.fill",
                    label: "Hvem",
                    value: guests > 0 ? "\(guests) gjest\(guests == 1 ? "" : "er")" : "Legg til",
                    onTap: { showGuestPicker = true }
                )
            }
            .padding(.horizontal, 16)

            HStack {
                Button("Fjern alle") {
                    typing = ""
                    query = ""
                    checkIn = nil
                    checkOut = nil
                    guests = 0
                    placesService.clear()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.neutral700)
                .underline()

                Spacer()

                Button {
                    onSearch()
                    isPresented = false
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Søk")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.primary600)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color.white)
    }

    private func bottomRow(icon: String, label: String, value: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral500)
                VStack(alignment: .leading, spacing: 0) {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.neutral500)
                    Text(value)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.neutral900)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.neutral200, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var dateLabel: String {
        guard let i = checkIn, let o = checkOut else { return "Legg til datoer" }
        let df = DateFormatter()
        df.dateFormat = "d. MMM"
        df.locale = Locale(identifier: "nb_NO")
        return "\(df.string(from: i))–\(df.string(from: o))"
    }
}

private struct SuggestedDestination: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let icon: String
}

/// Mini-sheet for å velge antall gjester. Holder det enkelt — kan
/// utvides med voksne/barn/spedbarn senere.
struct GuestPickerSheet: View {
    @Binding var guests: Int
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Nullstill") {
                    guests = 0
                    onDone()
                }
                .font(.system(size: 15))
                .foregroundStyle(.neutral500)
                Spacer()
                Text("Hvem kommer?")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Bruk") { onDone() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary600)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gjester")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neutral900)
                    Text("Voksne og barn")
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                }
                Spacer()
                stepperButton(systemName: "minus", enabled: guests > 0) {
                    guests = max(0, guests - 1)
                }
                Text("\(guests)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.neutral900)
                    .frame(minWidth: 28)
                stepperButton(systemName: "plus", enabled: guests < 16) {
                    guests = min(16, guests + 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)

            Spacer()
        }
    }

    private func stepperButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(enabled ? .neutral900 : .neutral300)
                .frame(width: 32, height: 32)
                .background(Color.white)
                .overlay(Circle().stroke(enabled ? Color.neutral400 : Color.neutral200, lineWidth: 1))
                .clipShape(Circle())
        }
        .disabled(!enabled)
    }
}
