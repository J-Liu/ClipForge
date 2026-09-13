// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

enum Language: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        }
    }

    var nativeName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        }
    }
}

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
        }
    }

    private var strings: [String: String] = [:]

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = Language(rawValue: saved) {
            currentLanguage = lang
        } else {
            currentLanguage = .english
        }
        loadStrings()
    }

    func setLanguage(_ language: Language) {
        currentLanguage = language
        loadStrings()
    }

    private func loadStrings() {
        let bundle = Bundle.main
        let path: String?

        switch currentLanguage {
        case .english:
            path = bundle.path(forResource: "en", ofType: "lproj")
        case .simplifiedChinese:
            path = bundle.path(forResource: "zh-Hans", ofType: "lproj")
        case .traditionalChinese:
            path = bundle.path(forResource: "zh-Hant", ofType: "lproj")
        }

        if let path = path {
            let stringsPath = (path as NSString).appendingPathComponent("Localizable.strings")
            if let dict = NSDictionary(contentsOfFile: stringsPath) as? [String: String] {
                strings = dict
                return
            }
        }

        // Fallback to embedded strings
        strings = Self.fallbackStrings(for: currentLanguage)
    }

    func string(for key: String) -> String {
        return strings[key] ?? key
    }

    func string(for key: String, args: CVarArg...) -> String {
        let format = strings[key] ?? key
        return String(format: format, arguments: args)
    }

    static func fallbackStrings(for language: Language) -> [String: String] {
        switch language {
        case .english:
            return enStrings
        case .simplifiedChinese:
            return zhHansStrings
        case .traditionalChinese:
            return zhHantStrings
        }
    }
}

// MARK: - Convenience function

func L(_ key: String) -> String {
    return LocalizationManager.shared.string(for: key)
}

func L(_ key: String, _ args: CVarArg...) -> String {
    return LocalizationManager.shared.string(for: key, args: args)
}