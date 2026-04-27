import SwiftUI

/// Progress-bar på toppen av wizarden. Animert smooth fill, ingen pin og
/// ingen "Steg X av Y"-tekst — minimalistisk Apple-stil.
struct WizardProgressBar: View {
    /// Fremdrift 0..1. ListingFormModel.displayProgress regner med per-plass-
    /// loop i mini-wizarden, så baren fyller seg jevnt og spoler ikke tilbake.
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.neutral100)
                    .frame(height: 4)

                Capsule()
                    .fill(LinearGradient(
                        colors: [.primary500, .primary600],
                        startPoint: .leading,
                        endPoint: .trailing))
                    .frame(width: max(4, geo.size.width * progress), height: 4)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: progress)
            }
        }
        .frame(height: 4)
    }
}
