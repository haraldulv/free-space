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
                        if index > 0 {
                            copyFromPreviousButton(currentIndex: index)
                        }
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

    @ViewBuilder
    private func copyFromPreviousButton(currentIndex: Int) -> some View {
        let prevIndex = currentIndex - 1
        Button {
            copyPriceFromPrevious(currentIndex: currentIndex)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14, weight: .semibold))
                Text("Bruk samme pris som plass \(prevIndex + 1)")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.primary700)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.primary50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary200, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func copyPriceFromPrevious(currentIndex: Int) {
        let prevIndex = currentIndex - 1
        guard
            form.spotMarkers.indices.contains(prevIndex),
            form.spotMarkers.indices.contains(currentIndex)
        else { return }
        let prev = form.spotMarkers[prevIndex]
        form.spotMarkers[currentIndex].pricePerHour = prev.pricePerHour
        form.spotMarkers[currentIndex].pricePerNight = prev.pricePerNight
        form.spotMarkers[currentIndex].price = prev.price
        form.spotMarkers[currentIndex].priceUnit = prev.priceUnit
    }
}
