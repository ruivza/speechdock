import XCTest
@testable import SpeechDock

final class InterfaceLanguageTests: XCTestCase {
    func testLanguageChoicePersistsAndSystemDefaultRemovesOnlyLanguageOverride() {
        let name = "SpeechDockLanguageTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("ja", forKey: "voiceInputLanguage")
        InterfaceLanguage.chinese.apply(to: defaults)
        let relaunched = UserDefaults(suiteName: name)!
        XCTAssertEqual(relaunched.stringArray(forKey: "AppleLanguages"), ["zh-Hans"])
        XCTAssertEqual(relaunched.string(forKey: "interfaceLanguage"), "zh-Hans")
        InterfaceLanguage.system.apply(to: defaults)
        XCTAssertNil(defaults.persistentDomain(forName: name)?["AppleLanguages"])
        XCTAssertEqual(defaults.string(forKey: "voiceInputLanguage"), "ja")
    }

    func testEveryInterfaceLanguageShipsCriticalPermissionSettingsAndInputMethodStrings() throws {
        let languages = InterfaceLanguage.allCases.filter { $0 != .system }
        let keys = ["Interface Language", "Check Again", "Unavailable in this session", "Clear Cache",
                    "SpeechDock Permissions", "Voice Input Settings…", "Preparing speech recognition…"]
        let mainResources = try XCTUnwrap(Bundle.main.resourceURL)
        let inputMethod = try XCTUnwrap(Bundle(url: mainResources.appendingPathComponent("InputMethods/SpeechDockVoiceInput.app")))
        for resources in [mainResources, try XCTUnwrap(inputMethod.resourceURL)] {
            for language in languages {
                let directory = resources.appendingPathComponent(language.rawValue + ".lproj")
                let bundle = try XCTUnwrap(Bundle(url: directory), "Missing localization in \(resources.path)")
                let data = try Data(contentsOf: directory.appendingPathComponent("Localizable.strings"))
                let table = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
                for key in keys {
                    XCTAssertNotNil(table[key], "\(resources.path)/\(language.rawValue): missing \(key)")
                    XCTAssertEqual(bundle.localizedString(forKey: key, value: nil, table: nil), table[key])
                    if language != .english { XCTAssertNotEqual(table[key], key) }
                }
            }
        }
    }
}
