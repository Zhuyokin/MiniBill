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

    func testYearlySharePayloadAggregatesMonthlyTotalsWithoutPrivateRecordFields() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let year = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let august = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5))!
        let records = [
            LedgerRecord(id: UUID(), kind: .income, amountCents: 12_500, projectName: "Private client", note: "private customer", occurredAt: year, createdAt: year, updatedAt: year),
            LedgerRecord(id: UUID(), kind: .income, amountCents: 7_500, projectName: "Private client", note: nil, occurredAt: august, createdAt: august, updatedAt: august),
            LedgerRecord(id: UUID(), kind: .expense, amountCents: 3_000, projectName: "Private supplier", note: nil, occurredAt: august, createdAt: august, updatedAt: august)
        ]
        let months = LedgerAnalytics.yearlyTotals(records: records, year: year, calendar: calendar)

        let payload = YearlySharePayload(months: months, year: year)
        let encoded = try JSONEncoder().encode(payload)
        let json = String(decoding: encoded, as: UTF8.self)

        XCTAssertEqual(payload.year, year)
        XCTAssertEqual(payload.incomeCents, 20_000)
        XCTAssertEqual(payload.expenseCents, 3_000)
        XCTAssertEqual(payload.netCents, 17_000)
        XCTAssertEqual(payload.recordCount, 3)
        XCTAssertEqual(payload.months.count, 12)
        XCTAssertEqual(payload.months[0].incomeCents, 12_500)
        XCTAssertEqual(payload.months[7].expenseCents, 3_000)
        XCTAssertEqual(try JSONDecoder().decode(YearlySharePayload.self, from: encoded), payload)
        XCTAssertFalse(json.contains("Private"))
        XCTAssertFalse(json.contains("private customer"))
        XCTAssertFalse(json.contains("note"))
        XCTAssertFalse(json.contains("accountID"))
    }

    func testYearlySharePayloadKeepsAllTwelveMonthsWhenYearHasNoEntries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let year = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let months = LedgerAnalytics.yearlyTotals(records: [], year: year, calendar: calendar)

        let payload = YearlySharePayload(months: months, year: year)

        XCTAssertEqual(payload.incomeCents, 0)
        XCTAssertEqual(payload.expenseCents, 0)
        XCTAssertEqual(payload.netCents, 0)
        XCTAssertEqual(payload.recordCount, 0)
        XCTAssertEqual(payload.months.count, 12)
        XCTAssertTrue(payload.months.allSatisfy { $0.incomeCents == 0 && $0.expenseCents == 0 })
    }

    func testYearlySharePayloadClampsIncomeAndExpenseWithoutOverflow() {
        let year = Date(timeIntervalSince1970: 0)
        let incomeMonths = [
            MonthlyLedgerTotal(month: year, incomeCents: .max, expenseCents: 0, netCents: .max, recordCount: 1),
            MonthlyLedgerTotal(month: year.addingTimeInterval(31 * 86_400), incomeCents: 100, expenseCents: 0, netCents: 100, recordCount: 1)
        ]
        let expenseMonths = [
            MonthlyLedgerTotal(month: year, incomeCents: 0, expenseCents: .max, netCents: -Int64.max, recordCount: 1),
            MonthlyLedgerTotal(month: year.addingTimeInterval(31 * 86_400), incomeCents: 0, expenseCents: 100, netCents: -100, recordCount: 1)
        ]

        let incomePayload = YearlySharePayload(months: incomeMonths, year: year)
        let expensePayload = YearlySharePayload(months: expenseMonths, year: year)

        XCTAssertEqual(incomePayload.incomeCents, .max)
        XCTAssertEqual(incomePayload.netCents, .max)
        XCTAssertEqual(expensePayload.expenseCents, .max)
        XCTAssertEqual(expensePayload.netCents, -Int64.max)
    }
}
