import SwiftUI

/// Velkomstskjerm for utloggede brukere ved kaldstart (kun parkering).
/// Vises ved hver app-start til man har konto. «Utforsk først» hopper
/// over for denne økten via onSkip (styres i TunoApp-roten).
struct WelcomeView: View {
    @EnvironmentObject var authManager: AuthManager
    let onSkip: () -> Void

    @State private var showLogin = false
    @State private var showRegister = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 40)

            Text("Finn eller lei ut parkeringsplass")
                .font(.tuno(.display))
                .foregroundStyle(Color.inkText)
                .multilineTextAlignment(.center)
                .padding(.top, 28)

            Spacer(minLength: 24)

            // Glass-kort rundt punktene: frosted flate over glow-bakgrunnen
            // (Harald 2026-10-14: «svart, men litt mykere»).
            VStack(alignment: .leading, spacing: 22) {
                welcomeRow(
                    icon: "map.fill",
                    title: "Finn ledig plass",
                    body: "Se plassene på kartet, med pris og gangavstand til stasjonen.",
                )
                welcomeRow(
                    icon: "creditcard.fill",
                    title: "Book og betal i appen",
                    body: "Trygt og enkelt, per dag eller som fast månedsplass.",
                )
                welcomeRow(
                    icon: "house.fill",
                    title: "Lei ut din egen plass",
                    body: "Du setter prisen og får hele summen selv.",
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )

            Spacer(minLength: 24)

            VStack(spacing: 14) {
                Button { showRegister = true } label: {
                    Text("Kom i gang")
                }
                .buttonStyle(TunoPillButtonStyle(variant: .mint))

                Button { showLogin = true } label: {
                    Text("Jeg har allerede konto")
                        .font(.tuno(size: 15, weight: .semibold))
                        .foregroundStyle(Color.inkText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.07), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }

                Button(action: onSkip) {
                    Text("Utforsk først")
                        .font(.tuno(size: 14, weight: .medium))
                        .foregroundStyle(Color.inkMuted)
                        .padding(.vertical, 6)
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // Svart flate med myke mint-glows: beholder brand-øyeblikket,
            // men tar bort det harde «dev-svarte».
            ZStack {
                Color.ink
                Circle()
                    .fill(Color.mint.opacity(0.20))
                    .frame(width: 360, height: 360)
                    .blur(radius: 90)
                    .offset(x: -150, y: -310)
                Circle()
                    .fill(Color.mint.opacity(0.10))
                    .frame(width: 320, height: 320)
                    .blur(radius: 100)
                    .offset(x: 170, y: 330)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginView()
        }
        .fullScreenCover(isPresented: $showRegister) {
            RegisterView()
        }
    }

    @ViewBuilder
    private func welcomeRow(icon: String, title: String, body bodyText: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.mint)
                .frame(width: 42, height: 42)
                .background(Color.mint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.tuno(size: 16, weight: .bold))
                    .foregroundStyle(Color.inkText)
                Text(bodyText)
                    .font(.tuno(size: 14, weight: .regular))
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
