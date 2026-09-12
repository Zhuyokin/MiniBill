#if DEBUG
import XCTest
@testable import MiniBillCore

final class DebugWatchDemoTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private let date = Date(timeIntervalSince1970: 1_788_307_200)

    func testFirstLaunchSeedsMultipleAccountsAndCurrentReports() {
        let state = DebugWatchDemo.seedIfNeeded(WatchLedgerState(), referenceDate: date, calendar: calendar)
        XCTAssertEqual(state.accounts.count, 3)
        XCTAssertGreaterThan(state.records.count, 800)
        XCTAssertEqual(Set(state.records.map(\.id)).count, state.records.count)
        for account in state.accounts {
            let records = state.records.filter { $0.accountID == account.id }
            XCTAssertFalse(records.isEmpty)
            let summary = LedgerAnalytics.summary(records: records, month: date, calendar: calendar)
            XCTAssertGreaterThan(summary.recordCount, 0)
        }
        XCTAssertTrue(state.pending.isEmpty)
        XCTAssertEqual(DebugWatchDemo.seedIfNeeded(state, referenceDate: date, calendar: calendar), state)
    }

    func testDemoEditsPersistWithoutEnteringSyncOutbox() throws {
        let state = DebugWatchDemo.seedIfNeeded(WatchLedgerState(), referenceDate: date, calendar: calendar)
        let original = try XCTUnwrap(state.records.first)
        var changed = original
        changed.amountCents = 12345
        let next = try DebugWatchDemo.applying(
            .init(ledgerID: DebugWatchDemo.ledgerID, kind: .saveEntry, record: changed, baseRecord: original),
            to: state
        )
        let restored = try JSONDecoder().decode(WatchLedgerState.self, from: JSONEncoder().encode(next))
        XCTAssertEqual(restored.records.first(where: { $0.id == original.id })?.amountCents, 12345)
        XCTAssertTrue(restored.pending.isEmpty)
        let deleted = try DebugWatchDemo.applying(
            .init(ledgerID: DebugWatchDemo.ledgerID, kind: .deleteEntry, record: changed, baseRecord: changed),
            to: restored
        )
        XCTAssertFalse(deleted.records.contains(where: { $0.id == original.id }))
        XCTAssertTrue(deleted.pending.isEmpty)
    }

    func testRealLedgerCannotBeSeededOrChangedAsDemo() {
        var state = WatchLedgerState()
        state.receive(.init(ledgerID: UUID(), revision: 1, languageCode: "en", accounts: [.default], records: []))
        XCTAssertEqual(DebugWatchDemo.seedIfNeeded(state, referenceDate: date, calendar: calendar), state)
        XCTAssertThrowsError(try DebugWatchDemo.applying(
            .init(ledgerID: DebugWatchDemo.ledgerID, kind: .deleteAccount, account: .default, baseAccount: .default, accountEntries: []),
            to: state
        ))
    }
}
#endif
