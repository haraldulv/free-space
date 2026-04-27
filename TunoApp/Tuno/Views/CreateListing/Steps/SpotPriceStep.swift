import SwiftUI

/// Mini-wizard for pris per plass — én plass per slide.
/// Pris-modell (kun parkering) + stor pris-display.
struct SpotPriceStep: View {
    @ObservedObject var form: ListingFormModel

    var body: some View {
        TabView(selection: $form.currentSpotIndex) {
            ForEach(Array(form.spotMarkers.indices), id: \.self) { index in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        spotHeader(index: index)
                        SpotPriceContent(form: form, index: index)
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
    }

    private func spotHeader(index: Int) -> some View {
        let total = form.spotMarkers.count
        return VStack(alignment: .leading, spacing: 6) {
            Text(total == 1 ? "Hva koster det å leie plassen?" : "Pris for plass \(index + 1)")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.neutral900)
            Text("Sett en pris du synes er rettferdig. Du kan endre den senere.")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
                .lineSpacing(2)
        }
    }
}
