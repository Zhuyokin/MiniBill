import XCTest
import SwiftData
@testable import MiniBillCore
@testable import MiniBillData

final class LedgerEntryMapperTests: XCTestCase {
    func testRecordToEntryToRecordPreservesEveryField() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LedgerEntry.self, configurations: configuration)
        let context = ModelContext(container)
        let formatter = ISO8601DateFormatter()
        let original = LedgerRecord(
            id: UUID(uuidString: "31F00AC2-8C09-4B28-8E81-D8838B334B14")!,
            kind: .expense,
            amountCents: 1_250,
            projectName: "矿泉水 🧊",
            note: "two cases",
            occurredAt: formatter.date(from: "2026-08-05T03:30:00Z")!,
            createdAt: formatter.date(from: "2026-08-05T03:31:00Z")!,
            updatedAt: formatter.date(from: "2026-08-05T03:32:00Z")!
        )

        let entry = LedgerEntryMapper.entry(from: original)
        context.insert(entry)
        let mapped = LedgerEntryMapper.record(from: entry)

        XCTAssertEqual(mapped, original)
    }
}
