import XCTest
@testable import MiniBillCore

final class LedgerRecordFilterTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    func testDayFilterUsesCalendarDayAndSortsNewestFirst() {
        let early = record(
            id: "00000000-0000-0000-0000-000000000001",
            kind: .income,
            project: "Breakfast",
            occurredAt: "2026-08-05T00:30:00Z"
        )
        let late = record(
            id: "00000000-0000-0000-0000-000000000002",
            kind: .expense,
            project: "Stall",
            occurredAt: "2026-08-05T23:59:59Z"
        )
        let previousDay = record(
            id: "00000000-0000-0000-0000-000000000003",
            kind: .income,
            project: "Previous",
            occurredAt: "2026-08-04T23:59:59Z"
        )
        let nextDay = record(
            id: "00000000-0000-0000-0000-000000000004",
            kind: .income,
            project: "Next",
            occurredAt: "2026-08-06T00:00:00Z"
        )

        let result = LedgerRecordFilter.records(
            on: date("2026-08-05T12:00:00Z"),
            from: [early, nextDay, previousDay, late],
            calendar: calendar
        )

        XCTAssertEqual(result.map(\.id), [late.id, early.id])
    }

    func testMonthFilterUsesCalendarBoundariesAcrossYears() {
        var localCalendar = calendar
        localCalendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let previousMonth = record(
            id: "00000000-0000-0000-0000-000000000021",
            kind: .income,
            project: "Previous",
            occurredAt: "2026-12-31T15:59:59Z"
        )
        let monthStart = record(
            id: "00000000-0000-0000-0000-000000000022",
            kind: .income,
            project: "Start",
            occurredAt: "2026-12-31T16:00:00Z"
        )
        let monthEnd = record(
            id: "00000000-0000-0000-0000-000000000023",
            kind: .expense,
            project: "End",
            occurredAt: "2027-01-31T15:59:59Z"
        )
        let nextMonth = record(
            id: "00000000-0000-0000-0000-000000000024",
            kind: .expense,
            project: "Next",
            occurredAt: "2027-01-31T16:00:00Z"
        )

        let result = LedgerRecordFilter.records(
            inMonth: date("2027-01-15T12:00:00Z"),
            from: [monthStart, nextMonth, previousMonth, monthEnd],
            calendar: localCalendar
        )

        XCTAssertEqual(result.map(\.id), [monthEnd.id, monthStart.id])
    }

    func testMonthFilterSortsNewestFirstWithStableIDOrderForTies() {
        let earlier = record(
            id: "00000000-0000-0000-0000-000000000031",
            kind: .income,
            project: "Earlier",
            occurredAt: "2026-08-03T08:00:00Z"
        )
        let firstTie = record(
            id: "00000000-0000-0000-0000-000000000032",
            kind: .expense,
            project: "First",
            occurredAt: "2026-08-20T08:00:00Z"
        )
        let secondTie = record(
            id: "00000000-0000-0000-0000-000000000033",
            kind: .income,
            project: "Second",
            occurredAt: "2026-08-20T08:00:00Z"
        )

        let result = LedgerRecordFilter.records(
            inMonth: date("2026-08-15T12:00:00Z"),
            from: [secondTie, earlier, firstTie],
            calendar: calendar
        )

        XCTAssertEqual(result.map(\.id), [firstTie.id, secondTie.id, earlier.id])
    }

    func testProjectFilterUsesNormalizedNameMonthAndLedgerKind() {
        let olderMatch = record(
            id: "00000000-0000-0000-0000-000000000011",
            kind: .income,
            project: "  ICE\t Cream ",
            occurredAt: "2026-08-03T08:00:00Z"
        )
        let newerMatch = record(
            id: "00000000-0000-0000-0000-000000000012",
            kind: .income,
            project: "ice cream",
            occurredAt: "2026-08-20T08:00:00Z"
        )
        let wrongKind = record(
            id: "00000000-0000-0000-0000-000000000013",
            kind: .expense,
            project: "Ice Cream",
            occurredAt: "2026-08-21T08:00:00Z"
        )
        let wrongMonth = record(
            id: "00000000-0000-0000-0000-000000000014",
            kind: .income,
            project: "Ice Cream",
            occurredAt: "2026-07-31T23:59:59Z"
        )
        let distinctProject = record(
            id: "00000000-0000-0000-0000-000000000015",
            kind: .income,
            project: "ice-cream",
            occurredAt: "2026-08-22T08:00:00Z"
        )

        let result = LedgerRecordFilter.records(
            forProjectKey: "ice cream",
            kind: .income,
            inMonth: date("2026-08-15T12:00:00Z"),
            from: [olderMatch, wrongKind, wrongMonth, newerMatch, distinctProject],
            calendar: calendar
        )

        XCTAssertEqual(result.map(\.id), [newerMatch.id, olderMatch.id])
    }

    private func record(
        id: String,
        kind: LedgerKind,
        project: String,
        occurredAt: String
    ) -> LedgerRecord {
        let instant = date(occurredAt)
        return LedgerRecord(
            id: UUID(uuidString: id)!,
            kind: kind,
            amountCents: 100,
            projectName: project,
            note: nil,
            occurredAt: instant,
            createdAt: instant,
            updatedAt: instant
        )
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
