import XCTest
@testable import MiniBillCore

final class AppLanguageTests: XCTestCase {
    func testSupportedLanguageCodesRoundTrip() {
        XCTAssertEqual(AppLanguage.allCases.map(\.rawValue), ["zh-Hans", "zh-Hant", "en", "ja", "ko"])

        for language in AppLanguage.allCases {
            XCTAssertEqual(AppLanguage(storedCode: language.rawValue), language)
        }
    }

    func testMissingOrUnknownLanguageFallsBackToSimplifiedChinese() {
        XCTAssertEqual(AppLanguage(storedCode: nil), .simplifiedChinese)
        XCTAssertEqual(AppLanguage(storedCode: "unsupported"), .simplifiedChinese)
    }
}
