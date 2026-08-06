#if DEBUG
import XCTest
import SwiftData
@testable import MiniBillCore
@testable import MiniBillData

@MainActor
final class DebugDemoDataSeederTests: XCTestCase {
    func testSeederPreservesManualEntriesAndDoesNotDuplicateDemoData() throws {
        let container = try ModelContainer(
            for: LedgerEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let manualID = UUID()
        let context = container.mainContext
        context.insert(
            LedgerEntry(
                id: manualID,
                kindRawValue: LedgerKind.income.rawValue,
                amountCents: 12_300,
                projectName: "手工记录",
                occurredAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
        try context.save()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let referenceDate = ISO8601DateFormatter().date(from: "2026-08-06T12:00:00Z")!

        try DebugDemoDataSeeder.seedIfNeeded(
            in: container,
            referenceDate: referenceDate,
            calendar: calendar
        )
        try DebugDemoDataSeeder.seedIfNeeded(
            in: container,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let entries = try context.fetch(FetchDescriptor<LedgerEntry>())
        XCTAssertEqual(entries.count, 890)
        XCTAssertEqual(entries.filter { DebugDemoDataFactory.isDemoID($0.id) }.count, 889)
        XCTAssertNotNil(entries.first { $0.id == manualID })
    }
}
#endif
