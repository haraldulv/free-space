import SwiftUI

struct WelcomeStep: View {
    @ObservedObject var form: ListingFormModel
    @State private var pinDropped = false
    @State private var pulse1: CGFloat = 0
    @State private var pulse2: CGFloat = 0
    @State private var pulse3: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero: pin lander på et "kart"-bakgrunn og sender ut pulserende
            // ringer som symboliserer at plassen blir oppdaget av gjester.
            // Continuous pulse-loop holder skjermen levende mens brukeren
            // leser intro-teksten.
            ZStack {
                // Bakgrunns-"kart" — soft gradient med rounded corners
                RoundedRectangle(cornerRadius: 36)
                    .fill(LinearGradient(
                        colors: [.primary100, .primary50],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                    .frame(width: 240, height: 240)

                // Pulse-ringer (radar-effekt fra pin-posisjon)
                ForEach(0..<3) { i in
                    let progress = [pulse1, pulse2, pulse3][i]
                    Circle()
                        .strokeBorder(Color.primary600.opacity(1 - Double(progress)), lineWidth: 2)
                        .frame(width: 60 + 140 * progress, height: 60 + 140 * progress)
                        .offset(y: 8)
                }

                // "Bakke"-shadow under pin
                Ellipse()
                    .fill(Color.primary700.opacity(0.18))
                    .frame(width: 60, height: 12)
                    .offset(y: 50)
                    .opacity(pinDropped ? 1 : 0)

                // Tuno-pin (lander oppå kartet)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 76, weight: .semibold))
                    .foregroundStyle(.primary600)
                    .shadow(color: .primary700.opacity(0.25), radius: 8, y: 4)
                    .offset(y: pinDropped ? 0 : -140)
                    .scaleEffect(pinDropped ? 1.0 : 0.7)
            }
            .frame(width: 260, height: 260)
            .padding(.bottom, 40)
            .onAppear {
                withAnimation(.interpolatingSpring(stiffness: 180, damping: 14).delay(0.15)) {
                    pinDropped = true
                }
                // Start pulse-loops etter at pin har landet
                Task {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    startPulse(value: $pulse1)
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    startPulse(value: $pulse2)
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    startPulse(value: $pulse3)
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

    /// Looper en pulse-ring fra 0 til 1 og resetter, kontinuerlig.
    /// Tre overlappende ringer gir en radar-effekt rundt pin-en.
    @MainActor
    private func startPulse(value: Binding<CGFloat>) {
        Task {
            while !Task.isCancelled {
                value.wrappedValue = 0
                withAnimation(.easeOut(duration: 2.1)) {
                    value.wrappedValue = 1
                }
                try? await Task.sleep(nanoseconds: 2_100_000_000)
            }
        }
    }
}
