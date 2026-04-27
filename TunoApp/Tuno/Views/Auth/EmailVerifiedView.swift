import SwiftUI

/// Vises som full-screen sheet etter at brukeren har klikket
/// verifiseringslenken i e-posten. Universal Link `tuno.no/auth/verified`
/// (eller custom scheme-fallback) trigger denne fra `TunoApp.swift`.
///
/// Tokens fra Supabase ligger som hash-fragment i URL-en og er allerede
/// prosessert av `supabase.auth.session(from:)` før sheetet vises, så
/// brukeren er logget inn idet skjermen kommer opp.
struct EmailVerifiedView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var checkmarkScale: CGFloat = 0.4
    @State private var checkmarkOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.primary50)
                        .frame(width: 140, height: 140)
                    Circle()
                        .fill(Color.primary600)
                        .frame(width: 96, height: 96)
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(checkmarkScale)
                .opacity(checkmarkOpacity)

                VStack(spacing: 12) {
                    Text("E-posten er bekreftet")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.neutral900)
                        .multilineTextAlignment(.center)

                    Text("Velkommen til Tuno! Du er klar til å finne din neste plass eller leie ut din egen.")
                        .font(.system(size: 16))
                        .foregroundStyle(.neutral600)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 24)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Kom i gang")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.primary600)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }
            // Last profil hvis Supabase nettopp logget oss inn fra deep link
            Task { await authManager.loadProfile() }
        }
    }
}
