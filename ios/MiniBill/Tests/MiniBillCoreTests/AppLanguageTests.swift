import XCTest
@testable import MiniBillCore

final class AppLanguageTests: XCTestCase {
    func testSupportedLanguageCodesRoundTrip() {
        XCTAssertEqual(AppLanguage.allCases.map(\.rawValue), ["zh-Hans", "zh-Hant", "en", "ja", "ko", "de"])

        for language in AppLanguage.allCases {
            XCTAssertEqual(AppLanguage(storedCode: language.rawValue), language)
        }
    }

    func testMissingOrUnknownLanguageFallsBackToSimplifiedChinese() {
        XCTAssertEqual(AppLanguage(storedCode: nil), .simplifiedChinese)
        XCTAssertEqual(AppLanguage(storedCode: "unsupported"), .simplifiedChinese)
    }

    func testGermanUsesGermanLocaleAndNativeDisplayName() {
        XCTAssertEqual(AppLanguage(storedCode: "de"), .german)
        XCTAssertEqual(AppLanguage.german.locale.identifier, "de")
        XCTAssertEqual(AppLanguage.german.displayName, "Deutsch")
    }
}
