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
            .padding(.horizontal, 6)

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
                        .padding(.vertical, 10)
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
        .background(Color.ink.ignoresSafeArea())
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
