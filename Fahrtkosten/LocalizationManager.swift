import Foundation
import SwiftUI
import Combine

// MARK: - AppLanguage Enum
enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case german = "de"
    case english = "en"
    case polish = "pl"
    case czech = "cs"
    case turkish = "tr"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .german:    return "Deutsch"
        case .english:   return "English"
        case .polish:    return "Polski"
        case .czech:     return "Čeština"
        case .turkish:   return "Türkçe"
        }
    }

    var flag: String {
        switch self {
        case .german:    return "🇩🇪"
        case .english:   return "🇬🇧"
        case .polish:    return "🇵🇱"
        case .czech:     return "🇨🇿"
        case .turkish:   return "🇹🇷"
        }
    }
}

// MARK: - LocalizationManager
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var language: AppLanguage

    init() {
        // iOS-Systemsprache verwenden; Fallback auf Deutsch
        let preferred = Locale.preferredLanguages.first.flatMap { tag in
            AppLanguage(rawValue: String(tag.prefix(2)))
        } ?? .german
        self.language = preferred
    }

    func t(_ key: String) -> String {
        return translations[language]?[key] ?? translations[.german]?[key] ?? key
    }
}

// MARK: - Global localization function
func L(_ key: String) -> String {
    return LocalizationManager.shared.t(key)
}
