import SwiftUI

struct WelcomeStep: View {
    @ObservedObject var form: ListingFormModel
    @State private var pinDropped = false
    @State private var shadowOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero — Tuno-grønn pin som drops på et sirkel-shadow.
            // Symboliserer "plassér din plass på kartet". Fungerer for både camping og parkering.
            ZStack {
                // Bakgrunnssirkel (gradient)
                Circle()
                    .fill(LinearGradient(
                        colors: [.primary100, .primary50],
                        startPoint: .top,
                        endPoint: .bottom))
                    .frame(width: 220, height: 220)

                // "Bakke"-shadow som vises når pin lander
                Ellipse()
                    .fill(Color.primary600.opacity(0.18))
                    .frame(width: 70, height: 14)
                    .offset(y: 60)
                    .opacity(shadowOpacity)
                    .scaleEffect(x: pinDropped ? 1.0 : 0.5, y: 1)

                // Tuno-pin
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 80, weight: .semibold))
                    .foregroundStyle(.primary600)
                    .offset(y: pinDropped ? 0 : -120)
                    .scaleEffect(pinDropped ? 1.0 : 0.85)
            }
            .frame(width: 240, height: 240)
            .padding(.bottom, 40)
            .onAppear {
                withAnimation(.interpolatingSpring(stiffness: 180, damping: 14).delay(0.15)) {
                    pinDropped = true
                }
                withAnimation(.easeIn(duration: 0.25).delay(0.55)) {
                    shadowOpacity = 1
                }
            }

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
