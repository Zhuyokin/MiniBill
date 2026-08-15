import XCTest

final class LocalizableCatalogTests: XCTestCase {
    func testSettingsHelpButtonLabelsHaveGermanTranslations() throws {
        let catalog = try loadLocalizableCatalog()
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])

        let requiredKeys = [
            "Account Help",
            "Reminder Help",
            "Backup Help",
        ]

        for key in requiredKeys {
            let entry = try XCTUnwrap(strings[key] as? [String: Any], "Missing key: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], "Missing localizations: \(key)")
            let german = try XCTUnwrap(localizations["de"] as? [String: Any], "Missing German localization: \(key)")
            let stringUnit = try XCTUnwrap(german["stringUnit"] as? [String: Any], "Missing German string unit: \(key)")
            let value = try XCTUnwrap(stringUnit["value"] as? String, "Missing German value: \(key)")

            XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty German value: \(key)")
        }
    }

    func testAccountManagementStringsAreTranslatedForEverySupportedLocale() throws {
        let catalog = try loadLocalizableCatalog()
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        let localeCodes = ["zh-Hans", "zh-Hant", "ja", "ko", "de"]
        let requiredKeys = [
            "Could not update accounts",
            "Delete this account?",
            "Each account has independent entries and statistics. Backups include every account.",
            "Entries and statistics are isolated by account.",
            "This permanently deletes %lld entries in %@.",
            "Use 1–30 characters.",
        ]

        for key in requiredKeys {
            let entry = try XCTUnwrap(strings[key] as? [String: Any], "Missing key: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], "Missing localizations: \(key)")

            for localeCode in localeCodes {
                let localization = try XCTUnwrap(
                    localizations[localeCode] as? [String: Any],
                    "Missing \(localeCode) localization: \(key)"
                )
                let stringUnit = try XCTUnwrap(
                    localization["stringUnit"] as? [String: Any],
                    "Missing \(localeCode) string unit: \(key)"
                )
                let value = try XCTUnwrap(
                    stringUnit["value"] as? String,
                    "Missing \(localeCode) value: \(key)"
                )
                XCTAssertFalse(
                    value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "Empty \(localeCode) value: \(key)"
                )
            }
        }
    }

    func testThemeNamesUseRequestedChineseLabels() throws {
        let catalog = try loadLocalizableCatalog()
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])

        XCTAssertEqual(
            try localizedValue(for: "Modern Minimalist", localeCode: "zh-Hans", strings: strings),
            "现代极简"
        )
        XCTAssertEqual(
            try localizedValue(for: "Retro Skeuomorphic", localeCode: "zh-Hans", strings: strings),
            "复古拟物"
        )
    }

    func testThemeSubtitlesUseRequestedCopyInEverySupportedLocale() throws {
        let catalog = try loadLocalizableCatalog()
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        let keys = [
            "Teal-toned minimalist texture",
            "Retro skeuomorphic texture",
        ]

        for key in keys {
            for localeCode in ["zh-Hans", "zh-Hant", "ja", "ko", "de"] {
                XCTAssertFalse(
                    try localizedValue(for: key, localeCode: localeCode, strings: strings)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                )
            }
        }

        XCTAssertEqual(
            try localizedValue(for: keys[0], localeCode: "zh-Hans", strings: strings),
            "青调极简质感"
        )
        XCTAssertEqual(
            try localizedValue(for: keys[1], localeCode: "zh-Hans", strings: strings),
            "复古拟物质感"
        )
    }

    private func localizedValue(
        for key: String,
        localeCode: String,
        strings: [String: Any]
    ) throws -> String {
        let entry = try XCTUnwrap(strings[key] as? [String: Any], "Missing key: \(key)")
        let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], "Missing localizations: \(key)")
        let localization = try XCTUnwrap(
            localizations[localeCode] as? [String: Any],
            "Missing \(localeCode) localization: \(key)"
        )
        let stringUnit = try XCTUnwrap(
            localization["stringUnit"] as? [String: Any],
            "Missing \(localeCode) string unit: \(key)"
        )
        return try XCTUnwrap(stringUnit["value"] as? String, "Missing \(localeCode) value: \(key)")
    }

    private func loadLocalizableCatalog() throws -> [String: Any] {
        let testFile = URL(fileURLWithPath: #filePath)
        let packageRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = packageRoot
            .appendingPathComponent("MiniBill")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)

        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
