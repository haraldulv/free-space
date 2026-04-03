import SwiftUI
import AuthenticationServices

struct RegisterView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.webAuthenticationSession) var webAuthenticationSession
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Text("Opprett konto")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.neutral900)
                        Text("Kom i gang med Tuno")
                            .font(.system(size: 16))
                            .foregroundStyle(.neutral500)
                    }
                    .padding(.top, 40)

                    // Social Sign In
                    VStack(spacing: 10) {
                        // Apple Sign In
                        Button {
                            Task {
                                isLoading = true
                                await authManager.signInWithApple()
                                isLoading = false
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 18))
                                Text("Fortsett med Apple")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.black)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isLoading)

                        // Google Sign In
                        Button {
                            Task {
                                isLoading = true
                                await authManager.signInWithGoogle { url in
                                    try await self.webAuthenticationSession.authenticate(
                                        using: url,
                                        callbackURLScheme: "no.tuno.app"
                                    )
                                }
                                isLoading = false
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "g.circle.fill")
                                    .font(.title3)
                                Text("Fortsett med Google")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white)
                            .foregroundStyle(.neutral700)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.neutral300, lineWidth: 1)
                                )
                        }
                        .disabled(isLoading)
                    }

                    HStack {
                        Rectangle().frame(height: 1).foregroundStyle(.neutral200)
                        Text("eller")
                            .font(.system(size: 14))
                            .foregroundStyle(.neutral400)
                        Rectangle().frame(height: 1).foregroundStyle(.neutral200)
                    }

                    VStack(spacing: 16) {
                        InputField(label: "Fullt navn", text: $fullName, contentType: .name)
                        InputField(label: "E-post", text: $email, contentType: .emailAddress, keyboard: .emailAddress)
                        SecureInputField(label: "Passord", text: $password)
                    }

                    if let error = authManager.error {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task {
                            isLoading = true
                            await authManager.signUp(fullName: fullName, email: email, password: password)
                            isLoading = false
                        }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Registrer deg")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.primary600)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(fullName.isEmpty || email.isEmpty || password.count < 6 || isLoading)
                    .opacity(fullName.isEmpty || email.isEmpty || password.count < 6 ? 0.6 : 1)

                    HStack(spacing: 4) {
                        Text("Har du allerede konto?")
                            .font(.system(size: 14))
                            .foregroundStyle(.neutral500)
                        Button("Logg inn") { dismiss() }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary600)
                    }
                }
                .padding(.horizontal, 24)
            }
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
