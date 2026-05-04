import SwiftUI

/// Mini-wizard for kjøretøy-detaljer per plass — én plass per slide.
/// Beskrivelse, kjøretøytyper, maks lengde. Pris er flyttet til neste hovedsteg.
struct SpotDetailsStep: View {
    @ObservedObject var form: ListingFormModel

    var body: some View {
        TabView(selection: $form.currentSpotIndex) {
            ForEach(Array(form.spotMarkers.indices), id: \.self) { index in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        spotHeader(index: index)
                        if index > 0 {
                            CopyFromPreviousSpotButton(label: "Bruk samme detaljer som plass \(index)") {
                                copyFromPrevious(currentIndex: index)
                            }
                        }
                        SpotVehicleContent(form: form, index: index)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.28), value: form.currentSpotIndex)
        .onAppear {
            form.ensureSpotCountMatchesSpots()
        }
    }

    private func spotHeader(index: Int) -> some View {
        let total = form.spotMarkers.count
        return VStack(alignment: .leading, spacing: 6) {
            Text(total == 1 ? "Detaljer om plassen" : "Plass \(index + 1)")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.neutral900)
            Text("Beskriv plassen kort og velg hvilke kjøretøy som passer. Tenk på dybde, høyde og tilgjengelighet.")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
                .lineSpacing(2)
        }
    }

    private func copyFromPrevious(currentIndex: Int) {
        let prev = currentIndex - 1
        guard
            form.spotMarkers.indices.contains(prev),
            form.spotMarkers.indices.contains(currentIndex)
        else { return }
        let src = form.spotMarkers[prev]
        form.spotMarkers[currentIndex].description = src.description
        form.spotMarkers[currentIndex].vehicleType = src.vehicleType
        form.spotMarkers[currentIndex].vehicleMaxLength = src.vehicleMaxLength
    }
}
