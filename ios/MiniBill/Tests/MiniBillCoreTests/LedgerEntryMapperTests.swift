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
            accountID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
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

    func testApplyUpdatesEveryMutableFieldWithoutChangingIdentity() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LedgerEntry.self, configurations: configuration)
        let context = ModelContext(container)
        let originalID = UUID()
        let entry = LedgerEntry(
            id: originalID,
            accountID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            kindRawValue: LedgerKind.income.rawValue,
            amountCents: 100,
            projectName: "Old",
            note: nil,
            occurredAt: Date(timeIntervalSince1970: 10),
            createdAt: Date(timeIntervalSince1970: 5),
            updatedAt: Date(timeIntervalSince1970: 8)
        )
        context.insert(entry)
        let replacement = LedgerRecord(
            id: originalID,
            accountID: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            kind: .expense,
            amountCents: 250,
            projectName: "New",
            note: "note",
            occurredAt: Date(timeIntervalSince1970: 20),
            createdAt: Date(timeIntervalSince1970: 5),
            updatedAt: Date(timeIntervalSince1970: 30)
        )

        LedgerEntryMapper.apply(replacement, to: entry)

        XCTAssertEqual(entry.id, originalID)
        XCTAssertEqual(LedgerEntryMapper.record(from: entry), replacement)
    }
}
