import XCTest
@testable import MiniBillCore

final class AppNavigationLayoutPolicyTests: XCTestCase {
    func testRegularWidthUsesSplitView() {
        XCTAssertEqual(
            AppNavigationLayoutPolicy.presentation(isRegularWidth: true),
            .splitView
        )
    }

    func testCompactWidthUsesTabs() {
        XCTAssertEqual(
            AppNavigationLayoutPolicy.presentation(isRegularWidth: false),
            .tabs
        )
    }
}
