import XCTest
@testable import MiniBillCore

final class SharePayloadTests: XCTestCase {
    func testEntrySharePayloadOmitsNoteAndOtherLedgerFields() throws {
        let date = ISO8601DateFormatter().date(from: "2026-08-05T03:30:00Z")!
        let record = LedgerRecord(id: UUID(), kind: .income, amountCents: 12_500, projectName: "Delivery", note: "private customer", occurredAt: date, createdAt: date, updatedAt: date)

        let payload = EntrySharePayload(record: record)
        let encoded = try JSONEncoder().encode(payload)
        let json = String(decoding: encoded, as: UTF8.self)

        XCTAssertEqual(payload.kind, .income)
        XCTAssertEqual(payload.amountCents, 12_500)
        XCTAssertEqual(payload.projectName, "Delivery")
        XCTAssertEqual(payload.occurredAt, date)
        XCTAssertFalse(json.contains("private customer"))
        XCTAssertFalse(json.contains("note"))
        XCTAssertFalse(json.contains("createdAt"))
        XCTAssertFalse(json.contains("updatedAt"))
    }

    func testMonthlySharePayloadContainsApprovedSummaryFieldsWithoutAnyNotes() throws {
        let date = ISO8601DateFormatter().date(from: "2026-08-05T03:30:00Z")!
        let record = LedgerRecord(id: UUID(), kind: .income, amountCents: 12_500, projectName: "Delivery", note: "private customer", occurredAt: date, createdAt: date, updatedAt: date)
        let summary = LedgerAnalytics.summary(records: [record], month: date, calendar: Calendar(identifier: .gregorian))

        let payload = MonthlySharePayload(summary: summary)
        let json = String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)

        XCTAssertEqual(payload.netCents, 12_500)
        XCTAssertEqual(payload.recordCount, 1)
        XCTAssertEqual(payload.topIncomeProject?.displayName, "Delivery")
        XCTAssertFalse(json.contains("private customer"))
        XCTAssertFalse(json.contains("note"))
    }
}
