import Foundation

enum AppLocalization {
    static func string(_ key: String, language: AppLanguage = .current) -> String {
        localizedBundle(for: language).localizedString(forKey: key, value: key, table: nil)
    }

    private static func localizedBundle(for language: AppLanguage) -> Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
