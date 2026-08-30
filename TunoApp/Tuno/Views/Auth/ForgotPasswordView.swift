import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var showCaptcha = false
    @State private var sent = false
    @State private var isLoading = false

    private func performReset(captchaToken: String?) {
        Task {
            isLoading = true
            sent = await authManager.resetPassword(email: email, captchaToken: captchaToken)
            isLoading = false
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if sent {
                    VStack(spacing: 16) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.primary600)

                        Text("Sjekk e-posten din")
                            .font(.system(size: 22, weight: .bold))

                        Text("Vi har sendt en lenke for å tilbakestille passordet ditt til \(email).")
                            .font(.system(size: 15))
                            .foregroundStyle(.neutral500)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)

                    Button("Ferdig") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.primary600)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(spacing: 8) {
                        Text("Glemt passord?")
                            .font(.system(size: 22, weight: .bold))
                        Text("Skriv inn e-posten din, så sender vi deg en tilbakestillingslenke.")
                            .font(.system(size: 15))
                            .foregroundStyle(.neutral500)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    InputField(label: "E-post", text: $email, contentType: .emailAddress, keyboard: .emailAddress)

                    if let error = authManager.error {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task {
                            if await authManager.isTurnstileRequired() {
                                showCaptcha = true
                            } else {
                                performReset(captchaToken: nil)
                            }
                        }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Send tilbakestillingslenke")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.primary600)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(email.isEmpty || isLoading)
                    .opacity(email.isEmpty ? 0.6 : 1)
                    .sheet(isPresented: $showCaptcha) {
                        TurnstileSheet { token in performReset(captchaToken: token) }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .background(.white)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.neutral600)
                    }
                }
            }
        }
    }
}
