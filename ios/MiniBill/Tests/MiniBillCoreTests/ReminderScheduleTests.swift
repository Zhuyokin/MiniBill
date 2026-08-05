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

    func testReplacingReminderBatchRemovesPartialRequestsWhenAddFails() async {
        let recorder = ReminderBatchRecorder(failingIdentifier: "month-2")

        do {
            try await ReminderBatchScheduler.replace(
                items: ["month-1", "month-2", "month-3"],
                removeExisting: { await recorder.removeAll() },
                add: { try await recorder.add($0) }
            )
            XCTFail("Expected the second notification request to fail")
        } catch {
            let snapshot = await recorder.snapshot()
            XCTAssertEqual(snapshot.removalCount, 2)
            XCTAssertEqual(snapshot.addedIdentifiers, [])
            XCTAssertEqual(snapshot.addAttempts, ["month-1", "month-2"])
        }
    }

    func testReplacingReminderBatchKeepsAllRequestsAfterSuccessfulAdds() async throws {
        let recorder = ReminderBatchRecorder(failingIdentifier: nil)

        try await ReminderBatchScheduler.replace(
            items: ["daily"],
            removeExisting: { await recorder.removeAll() },
            add: { try await recorder.add($0) }
        )

        let snapshot = await recorder.snapshot()
        XCTAssertEqual(snapshot.removalCount, 1)
        XCTAssertEqual(snapshot.addedIdentifiers, ["daily"])
        XCTAssertEqual(snapshot.addAttempts, ["daily"])
    }
}

private enum ReminderBatchRecorderError: Error {
    case rejected
}

private actor ReminderBatchRecorder {
    private let failingIdentifier: String?
    private var removalCount = 0
    private var addedIdentifiers: [String] = []
    private var addAttempts: [String] = []

    init(failingIdentifier: String?) {
        self.failingIdentifier = failingIdentifier
    }

    func removeAll() {
        removalCount += 1
        addedIdentifiers.removeAll()
    }

    func add(_ identifier: String) throws {
        addAttempts.append(identifier)
        if identifier == failingIdentifier {
            throw ReminderBatchRecorderError.rejected
        }
        addedIdentifiers.append(identifier)
    }

    func snapshot() -> (removalCount: Int, addedIdentifiers: [String], addAttempts: [String]) {
        (removalCount, addedIdentifiers, addAttempts)
    }
}
