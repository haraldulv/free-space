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

/// Stilisert norsk flagg i ren SwiftUI. Blå kors på hvitt på rødt.
private struct NorwayFlag: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let stripeH = h * 0.22
            let stripeV = w * 0.22
            let vPos = w * 0.33

            ZStack(alignment: .topLeading) {
                Color(red: 0.73, green: 0.12, blue: 0.15) // rødt
                // Hvit kors
                Rectangle()
                    .fill(Color.white)
                    .frame(width: w, height: stripeH * 1.4)
                    .offset(y: (h - stripeH * 1.4) / 2)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: stripeV * 1.4, height: h)
                    .offset(x: vPos - (stripeV * 1.4 - stripeV) / 2)
                // Blå kors
                Rectangle()
                    .fill(Color(red: 0.0, green: 0.19, blue: 0.50))
                    .frame(width: w, height: stripeH)
                    .offset(y: (h - stripeH) / 2)
                Rectangle()
                    .fill(Color(red: 0.0, green: 0.19, blue: 0.50))
                    .frame(width: stripeV, height: h)
                    .offset(x: vPos)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }
}
