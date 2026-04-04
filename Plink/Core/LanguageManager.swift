import Foundation
import ObjectiveC

// Swizzles Bundle.main so all NSLocalizedString calls route through the
// user-selected language lproj, regardless of system language.
final class _LanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard
            let lang = UserDefaults.standard.string(forKey: "appLanguage"),
            let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

enum LanguageManager {
    /// Call once at app startup (before any UI). Safe to call multiple times.
    static func apply() {
        guard object_getClass(Bundle.main) !== _LanguageBundle.self else { return }
        object_setClass(Bundle.main, _LanguageBundle.self)
    }

    /// Returns the active language code, defaulting to macOS system language.
    static var current: String {
        if let saved = UserDefaults.standard.string(forKey: "appLanguage") { return saved }
        let sys = Locale.current.language.languageCode?.identifier ?? "en"
        return sys == "de" ? "de" : "en"
    }
}
