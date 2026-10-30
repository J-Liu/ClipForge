// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

extension Notification.Name {
    static let languageChanged = Notification.Name("LanguageChanged")
    static let recordingModeChanged = Notification.Name("RecordingModeChanged")
}

enum Language: String, CaseIterable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    var displayName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        }
    }

    var nativeName: String {
        switch self {
        case .system: return L("settings.language.system")
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
            loadStrings()
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }

    private var strings: [String: String] = [:]

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = Language(rawValue: saved) {
            currentLanguage = lang
        } else {
            currentLanguage = .system
        }
        loadStrings()
    }

    func setLanguage(_ language: Language) {
        currentLanguage = language
    }

    /// Returns the actual language to use (resolves .system to actual language)
    private func effectiveLanguage() -> Language {
        if currentLanguage == .system {
            return detectSystemLanguage()
        }
        return currentLanguage
    }

    /// Detects the system preferred language
    private func detectSystemLanguage() -> Language {
        let preferredLanguages = Locale.preferredLanguages
        guard let preferred = preferredLanguages.first else {
            return .english
        }

        // Parse language code (e.g., "zh-Hans-CN" -> "zh-Hans")
        let locale = Locale(identifier: preferred)
        let languageCode = locale.language.languageCode?.identifier
        let script = locale.language.script?.identifier

        if let languageCode = languageCode, let script = script {
            let fullCode = "\(languageCode)-\(script)"
            if fullCode == "zh-Hans" {
                return .simplifiedChinese
            } else if fullCode == "zh-Hant" {
                return .traditionalChinese
            }
        }

        if let languageCode = languageCode {
            if languageCode == "zh" {
                // Chinese without script - use region to determine
                if let region = locale.region?.identifier {
                    if region == "CN" || region == "SG" {
                        return .simplifiedChinese
                    }
                }
                return .simplifiedChinese // Default to simplified for ambiguous Chinese
            } else if languageCode == "en" {
                return .english
            }
        }

        return .english
    }

    private func loadStrings() {
        let effective = effectiveLanguage()
        let bundle = Bundle.main
        let path: String?

        switch effective {
        case .english, .system:
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
        strings = Self.fallbackStrings(for: effective)
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
        case .english, .system:
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
