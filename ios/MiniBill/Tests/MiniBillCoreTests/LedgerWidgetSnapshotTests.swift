import XCTest
@testable import MiniBillCore

final class LedgerWidgetSnapshotTests: XCTestCase {
    private let firstID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let secondID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    func testSnapshotSharesOnlySelectedAccountTotalsWithoutEntryDetails() throws {
        let snapshot = makeSnapshot(records: [
            record(.income, 1_500, "2026-10-02T03:00:00Z"),
            record(.expense, 200, "2026-10-02T04:00:00Z"),
            record(.income, 90_000, "2026-10-02T04:00:00Z", accountID: secondID),
        ])
        let totals = snapshot.totals(in: .month, at: date("2026-10-02T12:00:00Z"), calendar: calendar())

        XCTAssertEqual(snapshot.accountID, firstID)
        XCTAssertEqual(snapshot.accountName, "Shop")
        XCTAssertEqual(snapshot.languageCode, "de")
        XCTAssertEqual(totals.incomeCents, 1_500)
        XCTAssertEqual(totals.expenseCents, 200)
        XCTAssertEqual(totals.netCents, 1_300)
        XCTAssertEqual(totals.recordCount, 2)
        let data = try JSONEncoder().encode(snapshot)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let records = try XCTUnwrap(json["records"] as? [[String: Any]])
        XCTAssertTrue(records.allSatisfy { Set($0.keys) == ["kind", "amountCents", "occurredAt"] })
        XCTAssertEqual(try JSONDecoder().decode(LedgerWidgetSnapshot.self, from: data), snapshot)
    }

    func testMissingSelectionUsesEarliestCreatedAccount() {
        let early = LedgerAccountRecord(id: secondID, name: "Earlier", createdAt: date("2020-01-01T00:00:00Z"), updatedAt: Date())
        let late = LedgerAccountRecord(id: firstID, name: "Later", createdAt: date("2021-01-01T00:00:00Z"), updatedAt: Date())
        let snapshot = LedgerWidgetSnapshot(
            records: [record(.income, 700, "2026-10-02T00:00:00Z", accountID: secondID)],
            accounts: [late, early], selectedAccountID: UUID(), languageCode: "en"
        )

        XCTAssertEqual(snapshot.accountID, secondID)
        XCTAssertEqual(snapshot.accountName, "Earlier")
        XCTAssertEqual(snapshot.totals(in: .month, at: date("2026-10-02T00:00:00Z"), calendar: calendar()).incomeCents, 700)
    }

    func testMonthlyTotalsIncludeFutureEntriesAndExcludeNextMonthBoundary() {
        let snapshot = makeSnapshot(records: [
            record(.income, 50_000, "2026-09-30T23:59:59Z"),
            record(.income, 100, "2026-10-01T00:00:00Z"),
            record(.income, 250, "2026-10-31T23:59:59Z"),
            record(.expense, 80, "2026-10-31T00:00:00Z"),
            record(.expense, 9_000, "2026-11-01T00:00:00Z"),
        ])

        let totals = snapshot.totals(in: .month, at: date("2026-10-02T12:00:00Z"), calendar: calendar())

        XCTAssertEqual(totals.incomeCents, 350)
        XCTAssertEqual(totals.expenseCents, 80)
        XCTAssertEqual(totals.netCents, 270)
        XCTAssertEqual(totals.recordCount, 3)
    }

    func testDailyTotalsUseLocalDayAndExclusiveEnd() {
        let snapshot = makeSnapshot(records: [
            record(.income, 8_000, "2026-10-01T15:59:59Z"),
            record(.income, 500, "2026-10-01T16:00:00Z"),
            record(.expense, 70, "2026-10-02T15:59:59Z"),
            record(.income, 9_000, "2026-10-02T16:00:00Z"),
        ])

        let totals = snapshot.totals(in: .day, at: date("2026-10-02T04:00:00Z"), calendar: calendar(offset: 8 * 3_600))

        XCTAssertEqual(totals.incomeCents, 500)
        XCTAssertEqual(totals.expenseCents, 70)
        XCTAssertEqual(totals.netCents, 430)
        XCTAssertEqual(totals.recordCount, 2)
    }

    func testSnapshotRecomputesAfterMonthRolloverWithoutAnotherAppSave() {
        let snapshot = makeSnapshot(records: [
            record(.income, 500, "2026-10-31T12:00:00Z"),
            record(.expense, 200, "2026-11-01T12:00:00Z"),
        ])
        let october = snapshot.totals(in: .month, at: date("2026-10-31T12:00:00Z"), calendar: calendar())
        let november = snapshot.totals(in: .month, at: date("2026-11-01T12:00:00Z"), calendar: calendar())

        XCTAssertEqual(october.netCents, 500)
        XCTAssertEqual(november.netCents, -200)
        XCTAssertEqual(november.recordCount, 1)
    }

    func testEmptyPeriodHasZeroTotals() {
        let snapshot = makeSnapshot(records: [record(.income, 500, "2026-10-02T00:00:00Z")])
        let totals = snapshot.totals(in: .day, at: date("2026-10-03T00:00:00Z"), calendar: calendar())

        XCTAssertEqual(totals.incomeCents, 0)
        XCTAssertEqual(totals.expenseCents, 0)
        XCTAssertEqual(totals.netCents, 0)
        XCTAssertEqual(totals.recordCount, 0)
    }

    func testTotalsMatchLedgerRulesForNonpositiveAndOverflowingAmounts() {
        let snapshot = makeSnapshot(records: [
            record(.income, .max, "2026-10-02T00:00:00Z"),
            record(.income, 1, "2026-10-02T00:00:00Z"),
            record(.expense, 500, "2026-10-02T00:00:00Z"),
            record(.income, .min, "2026-10-02T00:00:00Z"),
            record(.expense, 0, "2026-10-02T00:00:00Z"),
        ])
        let totals = snapshot.totals(in: .day, at: date("2026-10-02T12:00:00Z"), calendar: calendar())

        XCTAssertEqual(totals.incomeCents, Int64.max)
        XCTAssertEqual(totals.expenseCents, 500)
        XCTAssertEqual(totals.netCents, Int64.max - 500)
        XCTAssertEqual(totals.recordCount, 3)
    }

    func testSourceFetchOrderDoesNotChangeSnapshot() {
        let records = [
            record(.income, 500, "2026-10-02T00:00:00Z"),
            record(.expense, 200, "2026-10-03T00:00:00Z"),
        ]

        XCTAssertEqual(makeSnapshot(records: records), makeSnapshot(records: records.reversed()))
    }

    private func makeSnapshot(records: [LedgerRecord]) -> LedgerWidgetSnapshot {
        let instant = date("2026-01-01T00:00:00Z")
        return LedgerWidgetSnapshot(
            records: records,
            accounts: [
                LedgerAccountRecord(id: firstID, name: "Shop", createdAt: instant, updatedAt: instant),
                LedgerAccountRecord(id: secondID, name: "Private", createdAt: instant, updatedAt: instant),
            ],
            selectedAccountID: firstID,
            languageCode: "de"
        )
    }

    private func record(_ kind: LedgerKind, _ cents: Int64, _ occurredAt: String, accountID: UUID? = nil) -> LedgerRecord {
        let instant = date(occurredAt)
        return LedgerRecord(
            id: UUID(), accountID: accountID ?? firstID, kind: kind, amountCents: cents,
            projectName: "Private project", note: "Private note", occurredAt: instant,
            createdAt: instant, updatedAt: instant
        )
    }

    private func calendar(offset: Int = 0) -> Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(secondsFromGMT: offset)!
        return result
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
