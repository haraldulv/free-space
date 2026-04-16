import SwiftUI
import Combine
import ObjectiveC

private var bundleKey: UInt8 = 0

/// Subclass av Bundle som videresender lookup til en valgt språk-bundle.
final class LocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    /// Bytter Bundle.main sin språk-bundle slik at Text("...") straks bruker ny locale.
    static func setLanguage(_ language: String) {
        let path = Bundle.main.path(forResource: language, ofType: "lproj")
        let bundle = path.flatMap { Bundle(path: $0) }
        objc_setAssociatedObject(Bundle.main, &bundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        object_setClass(Bundle.main, LocalizedBundle.self)
    }
}

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLocale: Locale

    private init() {
        let stored = UserDefaults.standard.string(forKey: "app_language")
        let lang = Self.normalize(stored ?? Locale.current.language.languageCode?.identifier ?? "nb")
        self.currentLocale = Locale(identifier: lang)
        Bundle.setLanguage(lang)
    }

    func setLanguage(_ code: String) {
        let normalized = Self.normalize(code)
        UserDefaults.standard.set(normalized, forKey: "app_language")
        UserDefaults.standard.set([normalized], forKey: "AppleLanguages")
        Bundle.setLanguage(normalized)
        currentLocale = Locale(identifier: normalized)
    }

    var currentLanguageCode: String {
        currentLocale.identifier
    }

    static let supportedLanguages: Set<String> = ["nb", "en", "de"]

    static func normalize(_ code: String) -> String {
        let base = code.split(separator: "-").first.map(String.init) ?? code
        return supportedLanguages.contains(base) ? base : "nb"
    }
}
