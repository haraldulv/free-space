import SwiftUI

/// Mini-wizard for tillegg per plass — én plass per slide.
/// Gjenbruker `currentSpotIndex` fra ListingFormModel.
struct SpotExtrasStep: View {
    @ObservedObject var form: ListingFormModel

    var body: some View {
        TabView(selection: $form.currentSpotIndex) {
            ForEach(Array(form.spotMarkers.indices), id: \.self) { index in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        spotHeader(index: index)
                        SpotExtrasContent(form: form, index: index)
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
        let label = (form.spotMarkers[safe: index]?.label ?? "Plass \(index + 1)")
        return VStack(alignment: .leading, spacing: 6) {
            Text(total == 1 ? "Tillegg for plassen" : "Tillegg for \(label)")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.neutral900)
            Text("Velg hva som er inkludert eller tilgjengelig på denne plassen. Alt er valgfritt, du kan justere prisen og legge til egne tillegg.")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
                .lineSpacing(2)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
