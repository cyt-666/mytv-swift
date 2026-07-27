import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Hashable {
    case zhHans = "zh-Hans"
    case en = "en"
    case ja = "ja"
    case ko = "ko"

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var nativeName: String {
        switch self {
        case .zhHans: return "简体中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .ko: return "한국어"
        }
    }

    var localizedNameKey: LocalizedStringKey {
        switch self {
        case .zhHans: return "简体中文"
        case .en: return "英文"
        case .ja: return "日文"
        case .ko: return "韩文"
        }
    }

    static var preferredSystemLanguage: AppLanguage {
        for languageCode in Locale.preferredLanguages {
            if languageCode.hasPrefix("zh") {
                return .zhHans
            }
            if languageCode.hasPrefix("en") {
                return .en
            }
            if languageCode.hasPrefix("ja") {
                return .ja
            }
            if languageCode.hasPrefix("ko") {
                return .ko
            }
        }
        return .zhHans
    }
}

enum AppLanguageStorage {
    static let appLanguage = "MyTV.AppLanguage"
    static let didChooseLanguage = "MyTV.DidChooseLanguage"
}

enum L10n {
    static var language: AppLanguage {
        let storedLanguageCode = UserDefaults.standard.string(forKey: AppLanguageStorage.appLanguage)
        return storedLanguageCode.flatMap(AppLanguage.init(rawValue:)) ?? .preferredSystemLanguage
    }

    static var locale: Locale {
        language.locale
    }

    static func string(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main.localizedString(forKey: key, value: key, table: nil)
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func string(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }
}

struct AppLocalizedRoot<Content: View>: View {
    @Environment(AppState.self) private var appState
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        @Bindable var state = appState

        content
            .environment(\.locale, state.appLanguage.locale)
            .sheet(isPresented: $state.needsLanguageSelection) {
                LanguageSelectionView(isRequired: true)
                    .environment(appState)
                    .environment(\.locale, state.appLanguage.locale)
                    .interactiveDismissDisabled(true)
            }
    }
}
