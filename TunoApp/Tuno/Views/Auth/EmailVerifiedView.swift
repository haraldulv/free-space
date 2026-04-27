import SwiftUI

/// Vises som full-screen sheet etter at brukeren har klikket
/// verifiseringslenken i e-posten. Viser loading mens `verifyOTP`
/// kjører i `TunoApp.handleAuthURL`, og auto-fortsetter til hovedview
/// når verifiseringen er vellykket.
///
/// Brukeren skal IKKE måtte trykke noe — det er en bekreftelse, ikke
/// en handling. "Kom i gang"-knappen er bare en backup hvis brukeren
/// vil dismisse manuelt.
struct EmailVerifiedView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @Environment(\.dismiss) private var dismiss
    @State private var checkmarkScale: CGFloat = 0.4
    @State private var checkmarkOpacity: Double = 0
    @State private var hasAutoDismissed = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                content

                Spacer()

                if case .failed = deepLinkManager.verifyStatus {
                    Button(action: { dismiss() }) {
                        Text("Lukk")
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
        }
        .onChange(of: deepLinkManager.verifyStatus) {
            if case .success = deepLinkManager.verifyStatus {
                triggerSuccessAnimation()
            }
        }
        .onAppear {
            if case .success = deepLinkManager.verifyStatus {
                triggerSuccessAnimation()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch deepLinkManager.verifyStatus {
        case .verifying:
            verifyingState
        case .success:
            successState
        case .failed(let message):
            failedState(message: message)
        }
    }

    private var verifyingState: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Color.primary50)
                    .frame(width: 140, height: 140)
                ProgressView()
                    .scaleEffect(2.0)
                    .tint(.primary600)
            }
            VStack(spacing: 8) {
                Text("Bekrefter e-posten...")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.neutral900)
                Text("Dette tar bare et øyeblikk.")
                    .font(.system(size: 15))
                    .foregroundStyle(.neutral500)
            }
        }
    }

    private var successState: some View {
        VStack(spacing: 28) {
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

                Text("Velkommen til Tuno!")
                    .font(.system(size: 17))
                    .foregroundStyle(.neutral500)
            }
        }
    }

    private func failedState(message: String) -> some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 140, height: 140)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.red)
            }
            VStack(spacing: 12) {
                Text("Kunne ikke bekrefte")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.neutral900)
                    .multilineTextAlignment(.center)
                Text(message.isEmpty ? "Lenken har utløpt eller er allerede brukt." : message)
                    .font(.system(size: 15))
                    .foregroundStyle(.neutral500)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }

    private func triggerSuccessAnimation() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) {
            checkmarkScale = 1.0
            checkmarkOpacity = 1.0
        }
        Task {
            await authManager.loadProfile()
            // Auto-dismiss etter 2s så brukeren kommer rett inn i appen
            // uten å måtte trykke noe.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !hasAutoDismissed {
                hasAutoDismissed = true
                dismiss()
            }
        }
    }
}
