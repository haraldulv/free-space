import SwiftUI

/// Ett-stegs søkeark for parkering (Asker-pivoten): stedfelt med Asker-
/// forslag, «I nærheten», valgfrie fra/til-datoer og én stor Søk-knapp.
/// Erstatter den tre-stegs WhereSheet-accordionen i parkering-modus;
/// kjøretøytype bor i Filtre-arket.
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

                dateSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Color.paper)
        .safeAreaInset(edge: .bottom) { searchButton }
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

    // MARK: - Stedfelt

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.neutral500)
            TextField("Søk sted eller adresse", text: $typing)
                .font(.tuno(.body))
                .autocorrectionDisabled()
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
                onUseMyLocation()
                dismiss()
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
                    dismiss()
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
        dismiss()
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

    // MARK: - Datoer

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Når? (valgfritt)")
                .font(.tuno(.label))
                .foregroundStyle(.neutral600)

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

    // MARK: - Søk

    private var searchButton: some View {
        Button("Søk") {
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
