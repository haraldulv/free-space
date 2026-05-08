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
                    Text("🇳🇴")
                        .font(.system(size: 18))
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

