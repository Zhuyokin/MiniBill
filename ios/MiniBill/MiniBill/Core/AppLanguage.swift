import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case german = "de"

    public static let storageKey = "app.language"

    public init(storedCode: String?) {
        self = storedCode.flatMap(Self.init(rawValue:)) ?? .simplifiedChinese
    }

    public var id: String { rawValue }

    public var locale: Locale {
        Locale(identifier: rawValue)
    }

    public var displayName: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .english: "English"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .german: "Deutsch"
        }
    }

    public static var current: AppLanguage {
        AppLanguage(storedCode: UserDefaults.standard.string(forKey: storageKey))
    }
}
