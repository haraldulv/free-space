import SwiftUI

struct LaunchScreen: View {
    @State private var logoScale: CGFloat = 0.86
    @State private var logoOpacity: Double = 0
    @State private var footerOpacity: Double = 0
    @State private var flagBob: CGFloat = 0

    var body: some View {
        ZStack {
            Color(red: 70/255, green: 193/255, blue: 133/255)
                .ignoresSafeArea()

            Image("SplashLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 220)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Text("Utviklet i Norge")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    // Flagg + hjerte: lite norsk flagg stilisert
                    NorwayFlag()
                        .frame(width: 22, height: 16)
                        .offset(y: flagBob)
                }
                .opacity(footerOpacity)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.35)) {
                footerOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(1.0)) {
                flagBob = -3
            }
        }
    }
}

/// Norsk flagg i ren SwiftUI, bygget etter offisielle proporsjoner (22:16).
/// Rødt bakgrunn + hvit kors (6 enheter tykk) + blå kors (2 enheter tykk)
/// sentrert inne i den hvite. Vertikal posisjon x=6-12 (6 enheter bred),
/// horisontal y=5-11 (6 enheter høy) — lik asymmetri som virkelig flagg.
private struct NorwayFlag: View {
    // Offisielle farger (Pantone 200C / 281C)
    private let red = Color(red: 0.729, green: 0.118, blue: 0.161)
    private let blue = Color(red: 0.000, green: 0.161, blue: 0.412)

    var body: some View {
        GeometryReader { geo in
            let u = min(geo.size.width / 22, geo.size.height / 16)  // enhet
            let w = 22 * u
            let h = 16 * u

            ZStack(alignment: .topLeading) {
                red

                // Hvit kors: vertikal stripe x=6-12 (6u bred), start x=6u
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 6 * u, height: h)
                    .offset(x: 6 * u)

                // Hvit kors: horisontal stripe y=5-11 (6u høy), start y=5u
                Rectangle()
                    .fill(Color.white)
                    .frame(width: w, height: 6 * u)
                    .offset(y: 5 * u)

                // Blå kors: vertikal x=8-10 (2u bred)
                Rectangle()
                    .fill(blue)
                    .frame(width: 2 * u, height: h)
                    .offset(x: 8 * u)

                // Blå kors: horisontal y=7-9 (2u høy)
                Rectangle()
                    .fill(blue)
                    .frame(width: w, height: 2 * u)
                    .offset(y: 7 * u)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: u * 0.8))
            .overlay(
                RoundedRectangle(cornerRadius: u * 0.8)
                    .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
            )
        }
    }
}
