import SwiftUI
import AuthenticationServices

struct RegisterView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.webAuthenticationSession) var webAuthenticationSession
    @Environment(\.openURL) var openURL
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showVerificationAlert = false
    @State private var termsAccepted = false
    @State private var termsError = ""
    @FocusState private var focusedField: Field?

    enum Field { case name, email, password }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    socialButtons
                    divider
                    fields
                    termsBlock
                    if let error = authManager.error {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    submitButton
                    loginLink
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.white)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.neutral700)
                    }
                }
            }
        }
        .alert("Sjekk e-posten din", isPresented: $showVerificationAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("Vi har sendt en bekreftelseslenke til \(email). Klikk på lenken for å aktivere kontoen din.")
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 6) {
            Text("Opprett konto")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.neutral900)
            Text("Kom i gang med Tuno")
                .font(.system(size: 15))
                .foregroundStyle(.neutral500)
        }
        .padding(.top, 8)
    }

    /// Sosiale knapper øverst — for de fleste er dette ett-tap registrering.
    /// 2-kolonne grid sparer vertikal plass.
    private var socialButtons: some View {
        HStack(spacing: 10) {
            Button {
                Task {
                    isLoading = true
                    await authManager.signInWithApple()
                    isLoading = false
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18))
                    Text("Apple")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.black)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoading)

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
                HStack(spacing: 8) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 20))
                    Text("Google")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.white)
                .foregroundStyle(.neutral800)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.neutral200, lineWidth: 1)
                )
            }
            .disabled(isLoading)
        }
    }

    private var divider: some View {
        HStack(spacing: 10) {
            Rectangle().frame(height: 1).foregroundStyle(.neutral200)
            Text("eller med e-post")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.neutral400)
            Rectangle().frame(height: 1).foregroundStyle(.neutral200)
        }
    }

    private var fields: some View {
        VStack(spacing: 10) {
            CompactField(
                label: "Navn",
                text: $fullName,
                contentType: .name,
                submitLabel: .next
            )
            .focused($focusedField, equals: .name)
            .onSubmit { focusedField = .email }

            CompactField(
                label: "E-post",
                text: $email,
                contentType: .emailAddress,
                keyboard: .emailAddress,
                submitLabel: .next
            )
            .focused($focusedField, equals: .email)
            .onSubmit { focusedField = .password }

            CompactSecureField(
                label: "Passord (min 6 tegn)",
                text: $password,
                submitLabel: .done
            )
            .focused($focusedField, equals: .password)
            .onSubmit { focusedField = nil }
        }
    }

    private var termsBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                termsAccepted.toggle()
                if termsAccepted { termsError = "" }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: termsAccepted ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundStyle(termsAccepted ? Color.primary600 : Color.neutral400)
                    (Text("Jeg godtar Tunos ")
                        .foregroundStyle(.neutral600)
                     + Text("brukervilkår")
                        .foregroundStyle(.neutral900)
                        .underline()
                     + Text(" og ")
                        .foregroundStyle(.neutral600)
                     + Text("personvernerklæring")
                        .foregroundStyle(.neutral900)
                        .underline())
                    .font(.system(size: 13))
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 14) {
                Button("Les vilkår") {
                    if let url = URL(string: "https://tuno.no/vilkar") { openURL(url) }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary600)
                Button("Les personvern") {
                    if let url = URL(string: "https://tuno.no/personvern") { openURL(url) }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary600)
            }
            .padding(.leading, 30)

            if !termsError.isEmpty {
                Text(termsError)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .padding(.leading, 30)
            }
        }
    }

    private var submitButton: some View {
        Button {
            termsError = ""
            guard termsAccepted else {
                termsError = "Du må godta vilkårene for å opprette konto"
                return
            }
            focusedField = nil
            Task {
                isLoading = true
                let success = await authManager.signUp(fullName: fullName, email: email, password: password)
                isLoading = false
                if success {
                    showVerificationAlert = true
                }
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
            .padding(.vertical, 16)
            .background(canSubmit ? Color.primary600 : Color.primary300)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canSubmit || isLoading)
    }

    private var loginLink: some View {
        HStack(spacing: 4) {
            Text("Har du allerede konto?")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
            Button("Logg inn") { dismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary600)
        }
        .padding(.top, 4)
    }

    private var canSubmit: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= 6
    }
}

// MARK: - Compact field components

/// Mer kompakt enn `InputField` — label inne i feltet (placeholder-stil)
/// så vertikal plass spares uten å miste lesbarhet.
private struct CompactField: View {
    let label: String
    @Binding var text: String
    var contentType: UITextContentType? = nil
    var keyboard: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .return

    var body: some View {
        TextField(label, text: $text)
            .textContentType(contentType)
            .keyboardType(keyboard)
            .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
            .autocorrectionDisabled(keyboard == .emailAddress)
            .submitLabel(submitLabel)
            .font(.system(size: 16))
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.neutral200, lineWidth: 1)
            )
    }
}

private struct CompactSecureField: View {
    let label: String
    @Binding var text: String
    var submitLabel: SubmitLabel = .return

    var body: some View {
        SecureField(label, text: $text)
            .textContentType(.newPassword)
            .submitLabel(submitLabel)
            .font(.system(size: 16))
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Color.neutral50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.neutral200, lineWidth: 1)
            )
    }
}
