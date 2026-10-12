import SwiftUI

/// To-stegs søkeark for parkering (Kim-feedback 2026-10-12): steg 1 «Hvor?»
/// med stedfelt og Asker-forslag, steg 2 «Når?» med valgfrie fra/til-datoer
/// og Søk-knappen. Valg av sted sentrerer kartet bak arket uten å søke;
/// søket kjører først på Søk. Kjøretøytype bor i Filtre-arket.
struct ParkingSearchSheet: View {
    @Binding var query: String
    @Binding var checkIn: Date?
    @Binding var checkOut: Date?
    @ObservedObject var placesService: PlacesService
    let onSelectPlace: (PlacePrediction) -> Void
    /// Områdeforslag med kjent koordinat (Asker-stasjonene): navn, lat, lng.
    /// Løses lokalt, ingen Places-rundtur.
    let onPickArea: (String, Double, Double) -> Void
    let onUseMyLocation: () -> Void
    let onSearch: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var typing: String = ""
    @State private var wheelPickerField: DateWheelField? = nil
    @FocusState private var searchFocused: Bool

    private enum Step: Equatable {
        case place
        case dates
    }

    @State private var step: Step = .place

    private struct AreaSuggestion: Identifiable {
        let name: String
        let subtitle: String
        let icon: String
        let lat: Double
        let lng: Double
        var id: String { name }
    }

    /// Asker-lanseringen: stasjonsnære områder der vi starter.
    private static let areaSuggestions: [AreaSuggestion] = [
        .init(name: "Asker", subtitle: "Sentrum og stasjonen", icon: "tram.fill", lat: 59.8333, lng: 10.4356),
        .init(name: "Heggedal", subtitle: "Stasjon på Spikkestadbanen", icon: "house.fill", lat: 59.7905, lng: 10.4387),
        .init(name: "Billingstad", subtitle: "Billingstad og Slependen", icon: "car.fill", lat: 59.8655, lng: 10.4919),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch step {
                case .place:
                    placeStep
                        .transition(.move(edge: .leading).combined(with: .opacity))
                case .dates:
                    dateStep
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Color.paper)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: step)
        .onAppear { typing = query }
        .onChange(of: typing) { _, newValue in
            // pick()/forslagsrader setter typing programmatisk idet vi går til
            // steg 2 — ikke start en ny autocomplete da.
            guard step == .place else { return }
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

    // MARK: - Steg 1: Hvor?

    private var placeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Hvor vil du parkere?")
                .font(.tuno(.title))
                .foregroundStyle(.neutral900)
                .padding(.top, 18)

            searchField

            if placesService.predictions.isEmpty {
                suggestionList
            } else {
                predictionList
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.neutral500)
            TextField("Søk sted eller adresse", text: $typing)
                .font(.tuno(.body))
                .autocorrectionDisabled()
                .focused($searchFocused)
                .onSubmit {
                    if let first = placesService.predictions.first {
                        pick(first)
                    }
                }
            if !typing.isEmpty {
                Button {
                    typing = ""
                    placesService.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral300)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.paperCard)
        .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TunoRadius.control, style: .continuous)
                .stroke(Color.paperLine, lineWidth: 1)
        )
    }

    // MARK: - Forslag

    private var suggestionList: some View {
        VStack(spacing: 0) {
            Button {
                query = "Min posisjon"
                typing = "Min posisjon"
                onUseMyLocation()
                advanceToDates()
            } label: {
                suggestionRowLabel(icon: "location.fill", title: "I nærheten", subtitle: "Bruk min posisjon")
            }
            .buttonStyle(.plain)

            ForEach(Self.areaSuggestions) { area in
                Divider().padding(.leading, 54)
                Button {
                    query = area.name
                    typing = area.name
                    onPickArea(area.name, area.lat, area.lng)
                    advanceToDates()
                } label: {
                    suggestionRowLabel(icon: area.icon, title: area.name, subtitle: area.subtitle)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var predictionList: some View {
        VStack(spacing: 0) {
            ForEach(placesService.predictions) { prediction in
                Button {
                    pick(prediction)
                } label: {
                    suggestionRowLabel(
                        icon: "mappin.circle.fill",
                        title: prediction.mainText,
                        subtitle: prediction.secondaryText
                    )
                }
                .buttonStyle(.plain)
                if prediction.id != placesService.predictions.last?.id {
                    Divider().padding(.leading, 54)
                }
            }
        }
    }

    private func pick(_ prediction: PlacePrediction) {
        query = prediction.mainText
        typing = prediction.mainText
        placesService.clear()
        onSelectPlace(prediction)
        advanceToDates()
    }

    private func advanceToDates() {
        searchFocused = false
        step = .dates
    }

    private func suggestionRowLabel(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.mint.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.mintInk)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.tuno(.body))
                    .foregroundStyle(.neutral900)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.tuno(.caption))
                        .foregroundStyle(.neutral500)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - Steg 2: Når?

    private var dateStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Button {
                    step = .place
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.neutral600)
                        .frame(width: 32, height: 32)
                        .background(Color.paperCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tilbake til stedvalg")

                Text("Når vil du parkere?")
                    .font(.tuno(.title))
                    .foregroundStyle(.neutral900)
            }
            .padding(.top, 18)

            Button {
                step = .place
            } label: {
                suggestionRowLabel(
                    icon: "mappin.circle.fill",
                    title: query.isEmpty ? "Velg sted" : query,
                    subtitle: "Endre sted"
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                Text("Valgfritt. Du kan søke uten datoer.")
                    .font(.tuno(.caption))
                    .foregroundStyle(.neutral500)

                HStack(spacing: 10) {
                    datePill(label: "Fra dato", date: checkIn) { wheelPickerField = .checkIn }
                    datePill(label: "Til dato", date: checkOut) { wheelPickerField = .checkOut }
                }

                if checkIn != nil || checkOut != nil {
                    Button("Nullstill datoer") {
                        checkIn = nil
                        checkOut = nil
                    }
                    .font(.tuno(.caption))
                    .foregroundStyle(.neutral600)
                }
            }
        }
    }

    private func datePill(label: String, date: Date?, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.tuno(.caption))
                    .foregroundStyle(.neutral500)
                Text(date.map(Self.formatDate) ?? "Velg dato")
                    .font(.tuno(.body))
                    .foregroundStyle(date == nil ? .neutral400 : .neutral900)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.paperCard)
            .clipShape(RoundedRectangle(cornerRadius: TunoRadius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TunoRadius.control, style: .continuous)
                    .stroke(Color.paperLine, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private static func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "d. MMM"
        df.locale = Locale(identifier: "nb_NO")
        return df.string(from: date)
    }

    // MARK: - Bunnbar

    @ViewBuilder
    private var bottomBar: some View {
        switch step {
        case .place:
            if !query.isEmpty {
                Button("Neste") {
                    advanceToDates()
                }
                .buttonStyle(TunoPillButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Color.paper)
            }
        case .dates:
            Button(checkIn == nil && checkOut == nil ? "Søk uten datoer" : "Søk") {
                dismiss()
                onSearch()
            }
            .buttonStyle(TunoPillButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Color.paper)
        }
    }
}
