import XCTest
@testable import MiniBillCore

final class ReminderScheduleTests: XCTestCase {
    func testMonthEndsCoverLeapYearAllLengthsAndYearRollover() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = ISO8601DateFormatter().date(from: "2024-01-15T12:00:00Z")!

        let dates = ReminderSchedule.monthEnds(startingAt: start, count: 12, calendar: calendar)
        let components = dates.map { calendar.dateComponents([.year, .month, .day], from: $0) }
        let literals = components.map { "\($0.year!)-\($0.month!)-\($0.day!)" }

        XCTAssertEqual(literals, ["2024-1-31", "2024-2-29", "2024-3-31", "2024-4-30", "2024-5-31", "2024-6-30", "2024-7-31", "2024-8-31", "2024-9-30", "2024-10-31", "2024-11-30", "2024-12-31"])

        let rollover = ReminderSchedule.monthEnds(startingAt: ISO8601DateFormatter().date(from: "2025-12-20T00:00:00Z")!, count: 2, calendar: calendar)
        XCTAssertEqual(rollover.map { calendar.component(.year, from: $0) }, [2025, 2026])
        XCTAssertEqual(rollover.map { calendar.component(.day, from: $0) }, [31, 31])
    }
}
