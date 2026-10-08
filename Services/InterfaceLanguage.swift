import Foundation

/// Foundation and SwiftUI use the same language after the app restarts.
enum InterfaceLanguage: String, CaseIterable, Identifiable {
    case system = ""
    case english = "en", chinese = "zh-Hans", japanese = "ja"
    case german = "de", french = "fr", korean = "ko"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .system: return NSLocalizedString("System Default", comment: "Interface language")
        case .english: return "English"
        case .chinese: return "简体中文"
        case .japanese: return "日本語"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .korean: return "한국어"
        }
    }
    func apply(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: "interfaceLanguage")
        if self == .system { defaults.removeObject(forKey: "AppleLanguages") }
        else { defaults.set([rawValue], forKey: "AppleLanguages") }
    }
}
