import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var localizationManager: LocalizationManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var chatService: ChatService
    @EnvironmentObject var pushRouter: PushRouter
    @State private var showDeleteAccountConfirm = false
    @State private var deletingAccount = false
    @State private var deleteError: String?
    @State private var openingSupport = false

    private let languages: [(code: String, name: String, flag: String)] = [
        ("nb", "Norsk", "🇳🇴"),
        ("en", "English", "🇬🇧"),
    ]

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    var body: some View {
        ZStack {
            List {
                // Språk
                Section {
                    ForEach(languages, id: \.code) { lang in
                        Button {
                            localizationManager.setLanguage(lang.code)
                        } label: {
                            HStack {
                                Text(lang.flag)
                                    .font(.system(size: 22))
                                Text(lang.name)
                                    .foregroundStyle(.neutral900)
                                Spacer()
                                if localizationManager.currentLanguageCode == lang.code {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.primary600)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(localizationManager.isChangingLanguage)
                    }
                } header: {
                    Text("Språk")
                }

                // Varsler
                Section {
                    Button {
                        openIOSSettings()
                    } label: {
                        settingsRow(icon: "bell.fill", title: "Push-varslinger", trailing: "iOS-innstillinger")
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Varsler")
                } footer: {
                    Text("Administrer push-varslinger i iOS-innstillinger.")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                }

                // Hjelp & support
                Section {
                    Button {
                        Task { await openSupportChat() }
                    } label: {
                        settingsRow(
                            icon: "bubble.left.and.bubble.right.fill",
                            title: "Kontakt support",
                            trailing: openingSupport ? "Åpner…" : nil
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(openingSupport)

                    Button { openURL("https://tuno.no/retningslinjer") } label: {
                        settingsRow(icon: "book.fill", title: "Retningslinjer")
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Hjelp")
                }

                // Juridisk
                Section {
                    Button { openURL("https://tuno.no/vilkar") } label: {
                        settingsRow(icon: "doc.text.fill", title: "Brukervilkår")
                    }
                    .buttonStyle(.plain)

                    Button { openURL("https://tuno.no/utleiervilkar") } label: {
                        settingsRow(icon: "doc.text.fill", title: "Utleiervilkår")
                    }
                    .buttonStyle(.plain)

                    Button { openURL("https://tuno.no/personvern") } label: {
                        settingsRow(icon: "lock.shield.fill", title: "Personvernerklæring")
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Juridisk")
                }

                // Om appen
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.neutral500)
                            .frame(width: 24)
                        Text("Versjon")
                            .foregroundStyle(.neutral900)
                        Spacer()
                        Text(appVersion)
                            .font(.system(size: 13))
                            .foregroundStyle(.neutral500)
                    }
                } header: {
                    Text("Om appen")
                }

                // Konto
                Section {
                    Button {
                        showDeleteAccountConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundStyle(.red)
                                .frame(width: 24)
                            Text("Slett konto")
                                .foregroundStyle(.red)
                            Spacer()
                            if deletingAccount {
                                ProgressView().scaleEffect(0.8)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(deletingAccount)
                } header: {
                    Text("Konto")
                } footer: {
                    Text("Sletting fjerner profilen din og alle tilknyttede data permanent. Aktive bookinger må avsluttes før du sletter.")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                }
            }
            .disabled(localizationManager.isChangingLanguage)

            if localizationManager.isChangingLanguage {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.3)
                    Text("Bytter språk…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.neutral700)
                }
                .padding(24)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            }
        }
        .navigationTitle("Innstillinger")
        .alert("Slett konto", isPresented: $showDeleteAccountConfirm) {
            Button("Slett", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Profilen din og alle bookinger, annonser og favoritter vil bli fjernet permanent. Dette kan ikke angres.")
        }
        .alert(
            "Kunne ikke slette",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("OK") {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func deleteAccount() async {
        guard authManager.currentUser != nil else { return }
        deletingAccount = true
        defer { deletingAccount = false }
        do {
            let accessToken = try await supabase.auth.session.accessToken
            guard let url = URL(string: "\(AppConfig.siteURL)/api/user/delete") else {
                deleteError = "Ugyldig URL"
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200 {
                await authManager.signOut()
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let serverError = json["error"] as? String {
                deleteError = serverError
            } else {
                deleteError = "Kunne ikke slette konto (HTTP \(status))"
            }
        } catch {
            deleteError = error.localizedDescription
        }
    }

    // MARK: - Row helper

    @ViewBuilder
    private func settingsRow(icon: String, title: String, trailing: String? = nil) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.neutral500)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(.neutral900)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 13))
                    .foregroundStyle(.neutral500)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.neutral400)
        }
    }

    // MARK: - Actions

    private func openIOSSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func openSupportChat() async {
        guard let userId = authManager.currentUser?.id else { return }
        openingSupport = true
        defer { openingSupport = false }
        await chatService.openOrCreateSupportConversation(
            userId: userId,
            pushRouter: pushRouter
        )
    }

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}
