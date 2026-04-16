import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var localizationManager: LocalizationManager

    private let languages: [(code: String, name: String, flag: String)] = [
        ("nb", "Norsk", "🇳🇴"),
        ("en", "English", "🇬🇧"),
        ("de", "Deutsch", "🇩🇪"),
    ]

    var body: some View {
        List {
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
                }
            } header: {
                Text("Språk")
            }
        }
        .navigationTitle("Innstillinger")
    }
}
