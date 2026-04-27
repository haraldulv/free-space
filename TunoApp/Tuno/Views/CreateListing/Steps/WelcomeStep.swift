import SwiftUI

struct WelcomeStep: View {
    @ObservedObject var form: ListingFormModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero-animasjon: illustrert person som lager en annonse
            // (Lottie fra Creattie, fargejustert til Tuno-paletten).
            LottieOrFallback(name: "ny-annonse") {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 96, weight: .semibold))
                    .foregroundStyle(.primary600)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 380)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)

            VStack(spacing: 16) {
                Text("La oss lage din første annonse")
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.neutral900)

                Text("Det tar noen minutter. Vi guider deg steg for steg, og du kan endre alt senere.")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.neutral500)
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
