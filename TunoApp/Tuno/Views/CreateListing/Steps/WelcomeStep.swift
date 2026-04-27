import SwiftUI

struct WelcomeStep: View {
    @ObservedObject var form: ListingFormModel
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero: roterende globe (Lottie fra LottieFiles, fargejustert
            // til Tuno-paletten). Symboliserer "din plass på kartet".
            LottieOrFallback(name: "Globe") {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 96, weight: .semibold))
                    .foregroundStyle(.primary600)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 360)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)

            VStack(spacing: 16) {
                Text(authManager.hasListings ? "La oss lage en ny annonse" : "La oss lage din første annonse")
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
