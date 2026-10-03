import XCTest
@testable import MiniBillCore

final class LedgerWidgetRouteTests: XCTestCase {
    func testRoutesPreserveAccountAndEntryKind() {
        let accountID = UUID()
        let routes: [LedgerWidgetRoute] = [
            .overview(accountID: accountID),
            .entry(accountID: accountID, kind: .income),
            .entry(accountID: accountID, kind: .expense)
        ]
        for route in routes {
            XCTAssertEqual(LedgerWidgetRoute(url: route.url), route)
        }
    }

    func testMalformedLinksCannotOpenAnEntryInAnUnspecifiedAccount() {
        let account = UUID().uuidString
        for value in [
            "https://entry?account=\(account)&kind=income",
            "minibill://entry?kind=income",
            "minibill://entry?account=bad&kind=income",
            "minibill://entry?account=\(account)",
            "minibill://entry?account=\(account)&kind=transfer",
            "minibill://entry?account=\(account)&account=\(UUID())&kind=income",
            "minibill://entry?account=\(account)&kind=income&kind=expense",
            "minibill://unknown?account=\(account)",
            "minibill://entry/other?account=\(account)&kind=income"
        ] {
            XCTAssertNil(LedgerWidgetRoute(url: URL(string: value)!), value)
        }
    }
}
