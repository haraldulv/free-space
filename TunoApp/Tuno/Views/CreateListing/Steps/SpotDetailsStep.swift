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
            Text(total == 1 ? "Hva slags kjøretøy passer her?" : "Kjøretøy for plass \(index + 1)")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.neutral900)
            Text("Velg én eller flere typer som passer, og evt. hvor stort kjøretøy plassen tar imot.")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
                .lineSpacing(2)
        }
    }
}
