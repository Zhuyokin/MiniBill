import XCTest
@testable import MiniBillCore

final class AppInterfaceStyleTests: XCTestCase {
    func testStoredValuesRoundTripBothSupportedInterfaceStyles() {
        XCTAssertEqual(AppInterfaceStyle(storedValue: "modern"), .modern)
        XCTAssertEqual(AppInterfaceStyle(storedValue: "skeuomorphic"), .skeuomorphic)
    }

    func testMissingOrUnknownStoredValueFallsBackToModern() {
        XCTAssertEqual(AppInterfaceStyle(storedValue: nil), .modern)
        XCTAssertEqual(AppInterfaceStyle(storedValue: "future-style"), .modern)
        XCTAssertEqual(AppInterfaceStyle(storedValue: "expo"), .modern)
    }
}
