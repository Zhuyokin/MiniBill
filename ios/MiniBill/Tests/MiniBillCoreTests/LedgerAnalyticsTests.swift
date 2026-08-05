import XCTest
@testable import MiniBillCore

final class LedgerAnalyticsTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testSummaryUsesIntegerCentsAndSelectedMonthOnly() throws {
        let records = [
            record(.income, 10_005, "  Ice   Cream ", "2026-08-01T02:00:00Z"),
            record(.income, 95, "ice cream", "2026-08-02T02:00:00Z"),
            record(.expense, 2_050, "Stall", "2026-08-02T03:00:00Z"),
            record(.income, 9_999, "Other month", "2026-07-31T02:00:00Z"),
        ]

        let result = LedgerAnalytics.summary(records: records, month: date("2026-08-15T00:00:00Z"), calendar: calendar)

        XCTAssertEqual(result.incomeCents, 10_100)
        XCTAssertEqual(result.expenseCents, 2_050)
        XCTAssertEqual(result.netCents, 8_050)
        XCTAssertEqual(result.recordCount, 3)
        XCTAssertEqual(result.incomeProjects.map(\.totalCents), [10_100])
        XCTAssertEqual(result.incomeProjects.map(\.displayName), ["ice cream"])
        XCTAssertEqual(result.expenseProjects.map(\.displayName), ["Stall"])
        XCTAssertEqual(result.dailyNet.map(\.netCents), [10_005, -1_955])
    }

    func testEmptyMonthReturnsZeroTotalsAndNoRankings() {
        let result = LedgerAnalytics.summary(records: [], month: date("2026-08-15T00:00:00Z"), calendar: calendar)

        XCTAssertEqual(result.incomeCents, 0)
        XCTAssertEqual(result.expenseCents, 0)
        XCTAssertEqual(result.netCents, 0)
        XCTAssertEqual(result.recordCount, 0)
        XCTAssertTrue(result.incomeProjects.isEmpty)
        XCTAssertTrue(result.expenseProjects.isEmpty)
        XCTAssertTrue(result.dailyNet.isEmpty)
    }

    func testRankingsAreIndependentAndTiesUseNormalizedKey() {
        let records = [
            record(.income, 500, "Zulu", "2026-08-03T00:00:00Z"),
            record(.income, 500, "alpha", "2026-08-04T00:00:00Z"),
            record(.expense, 800, "Zulu", "2026-08-05T00:00:00Z"),
            record(.expense, 300, "Beta", "2026-08-06T00:00:00Z"),
        ]

        let result = LedgerAnalytics.summary(records: records, month: date("2026-08-15T00:00:00Z"), calendar: calendar)

        XCTAssertEqual(result.incomeProjects.map(\.displayName), ["alpha", "Zulu"])
        XCTAssertEqual(result.expenseProjects.map(\.displayName), ["Zulu", "Beta"])
        XCTAssertEqual(result.expenseProjects.map(\.totalCents), [800, 300])
    }

    private func record(_ kind: LedgerKind, _ cents: Int64, _ project: String, _ occurred: String) -> LedgerRecord {
        let instant = date(occurred)
        return LedgerRecord(id: UUID(), kind: kind, amountCents: cents, projectName: project, note: nil, occurredAt: instant, createdAt: instant, updatedAt: instant)
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
