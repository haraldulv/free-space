import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.webAuthenticationSession) var webAuthenticationSession
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showRegister = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo
                    VStack(spacing: 8) {
                        Text("tuno")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.neutral900)

                        Text("Finn din plass")
                            .font(.system(size: 16))
                            .foregroundStyle(.neutral500)
                    }
                    .padding(.top, 60)

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

                    // Divider
                    HStack {
                        Rectangle().frame(height: 1).foregroundStyle(.neutral200)
                        Text("eller")
                            .font(.system(size: 14))
                            .foregroundStyle(.neutral400)
                        Rectangle().frame(height: 1).foregroundStyle(.neutral200)
                    }

                    // Email/Password
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("E-post")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.neutral700)
                            TextField("din@epost.no", text: $email)
                                .textFieldStyle(.plain)
                                .padding(14)
                                .background(.neutral50)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.neutral200, lineWidth: 1)
                                )
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Passord")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.neutral700)
                            SecureField("••••••••", text: $password)
                                .textFieldStyle(.plain)
                                .padding(14)
                                .background(.neutral50)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.neutral200, lineWidth: 1)
                                )
                                .textContentType(.password)
                        }
                    }

                    // Error
                    if let error = authManager.error {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                    }

                    // Login button
                    Button {
                        Task {
                            isLoading = true
                            await authManager.signIn(email: email, password: password)
                            isLoading = false
                        }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Logg inn")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.primary600)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                    .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)

                    // Forgot password
                    Button {
                        showForgotPassword = true
                    } label: {
                        Text("Glemt passord?")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary600)
                    }

                    Spacer()

                    // Register link
                    HStack(spacing: 4) {
                        Text("Har du ikke konto?")
                            .font(.system(size: 14))
                            .foregroundStyle(.neutral500)
                        Button("Registrer deg") {
                            showRegister = true
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary600)
                    }
                    .padding(.bottom, 20)
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
            .fullScreenCover(isPresented: $showRegister) {
                RegisterView()
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
        }
    }
}
