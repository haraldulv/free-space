import SwiftUI

/// Vises kort etter Apple/Google-innlogging eller e-post/passord-registrering
/// før auth-arket dismisses. Gir brukeren tydelig "du er logget inn"-feedback
/// — særlig viktig for Apple/Google der det ikke kommer noen verifiserings-
/// e-post.
struct AuthSuccessOverlay: View {
    let displayName: String?
    let isNewAccount: Bool

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.primary50)
                        .frame(width: 96, height: 96)
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Color.primary600)
                }

                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.neutral900)
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(.neutral500)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }

    private var title: String {
        let trimmedName = (displayName ?? "").trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty {
            let firstName = trimmedName.split(separator: " ").first.map(String.init) ?? trimmedName
            return isNewAccount ? "Velkommen, \(firstName)!" : "Hei igjen, \(firstName)!"
        }
        return isNewAccount ? "Velkommen!" : "Du er logget inn"
    }

    private var subtitle: String {
        isNewAccount
            ? "Kontoen din er opprettet. Vi tar deg videre."
            : "Tar deg videre."
    }
}

#Preview {
    AuthSuccessOverlay(displayName: "Harald Ulvestad Salvesen", isNewAccount: true)
}
