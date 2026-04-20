import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var localizationManager: LocalizationManager

    private let languages: [(code: String, name: String, flag: String)] = [
        ("nb", "Norsk", "🇳🇴"),
        ("en", "English", "🇬🇧"),
        ("de", "Deutsch", "🇩🇪"),
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
                    Button { openMail("support@tuno.no") } label: {
                        settingsRow(icon: "envelope.fill", title: "Kontakt support", trailing: "support@tuno.no")
                    }
                    .buttonStyle(.plain)

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

    private func openMail(_ address: String) {
        if let url = URL(string: "mailto:\(address)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}
