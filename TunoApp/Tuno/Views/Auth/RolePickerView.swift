import SwiftUI

/// Rollevalg rett etter registrering (kun parkering): finn parkering eller
/// lei ut egen plass. Vises én gang per bruker (styrt av
/// AuthManager.pendingRolePick + UserDefaults). Begge veier er likeverdige,
/// og bunnteksten gjør det tydelig at man kan gjøre begge deler.
struct RolePickerView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var showHostWizard = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 32)

            Text("Velkommen\(firstNameSuffix)!")
                .font(.tuno(.display))
                .foregroundStyle(Color.inkText)
                .multilineTextAlignment(.center)
                .padding(.top, 26)

            Text("Hva vil du gjøre? Du kan gjøre begge deler når som helst.")
                .font(.tuno(size: 15, weight: .regular))
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            Spacer(minLength: 28)

            VStack(spacing: 14) {
                roleCard(
                    icon: "map.fill",
                    title: "Finn parkering",
                    body: "Se ledige plasser på kartet og book i appen.",
                ) {
                    authManager.completeRolePick()
                }
                roleCard(
                    icon: "house.fill",
                    title: "Lei ut plassen min",
                    body: "Legg ut plassen din på noen minutter og tjen penger.",
                ) {
                    showHostWizard = true
                }
            }

            Spacer(minLength: 36)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // Samme myke glow-bakgrunn som WelcomeView, så de to
            // brand-skjermene henger sammen.
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
        .fullScreenCover(isPresented: $showHostWizard, onDismiss: {
            // Uansett om annonsen ble publisert eller wizarden lukket:
            // rollevalget er gjort, og profil/vert-status hentes på nytt
            // så Profil-fanen er fersk når MainTabView tar over.
            authManager.completeRolePick()
            Task { await authManager.loadProfile() }
        }) {
            NavigationStack { BecomeHostView() }
        }
    }

    /// ", Harald" når vi har fornavnet, ellers tom.
    private var firstNameSuffix: String {
        guard let first = authManager.profile?.fullName?
            .split(separator: " ").first, !first.isEmpty else { return "" }
        return ", \(first)"
    }

    @ViewBuilder
    private func roleCard(
        icon: String,
        title: String,
        body bodyText: String,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.mint)
                    .frame(width: 48, height: 48)
                    .background(Color.mint.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.tuno(size: 17, weight: .bold))
                        .foregroundStyle(Color.inkText)
                    Text(bodyText)
                        .font(.tuno(size: 14, weight: .regular))
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
