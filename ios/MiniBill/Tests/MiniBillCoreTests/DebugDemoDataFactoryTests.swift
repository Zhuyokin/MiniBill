#if DEBUG
import XCTest
@testable import MiniBillCore

final class DebugDemoDataFactoryTests: XCTestCase {
    func testFactoryCreatesOneYearOfDeterministicMixedData() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let referenceDate = ISO8601DateFormatter().date(from: "2026-08-06T12:00:00Z")!

        let first = DebugDemoDataFactory.records(referenceDate: referenceDate, calendar: calendar)
        let second = DebugDemoDataFactory.records(referenceDate: referenceDate, calendar: calendar)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 889)
        XCTAssertEqual(Set(first.map(\.id)).count, first.count)
        XCTAssertEqual(Set(first.filter { $0.kind == .income }.map(\.projectName)).count, 5)
        XCTAssertGreaterThan(Set(first.filter { $0.kind == .expense }.map(\.projectName)).count, 5)
        XCTAssertTrue(first.allSatisfy { $0.amountCents > 0 && $0.amountCents <= EntryValidator.maximumAmountCents })
        XCTAssertTrue(first.allSatisfy { DebugDemoDataFactory.isDemoID($0.id) })

        let days = Set(first.map { calendar.startOfDay(for: $0.occurredAt) })
        XCTAssertEqual(days.count, DebugDemoDataFactory.dayCount)
        XCTAssertEqual(first.filter { $0.kind == .income }.isEmpty, false)
        XCTAssertEqual(first.filter { $0.kind == .expense }.isEmpty, false)
    }

    func testDemoIdentifierDoesNotMatchNormalUUID() {
        XCTAssertFalse(DebugDemoDataFactory.isDemoID(UUID()))
    }
}
#endif
