import XCTest
import SwiftData
@testable import MiniBillCore
@testable import MiniBillData

@MainActor
final class LedgerMutationStoreTests: XCTestCase {
    func testConcurrentEntryUpdateRejectsStaleSaveAndDelete() throws {
        let original = record(amount: 100)
        let updated = record(id: original.id, amount: 200)
        let container = try container(records: [updated])

        for kind in [WatchMutationKind.saveEntry, .deleteEntry] {
            let mutation = WatchLedgerMutation(ledgerID: UUID(), kind: kind, record: original, baseRecord: original)
            XCTAssertThrowsError(try LedgerMutationStore.apply(mutation, in: container)) { error in
                XCTAssertEqual(error as? WatchSyncRejection, .conflict)
            }
        }

        XCTAssertEqual(try records(in: container), [updated])
    }

    func testDeletedEntryRejectsStaleSaveAndDelete() throws {
        let original = record(amount: 100)
        let container = try container()

        for kind in [WatchMutationKind.saveEntry, .deleteEntry] {
            let mutation = WatchLedgerMutation(ledgerID: UUID(), kind: kind, record: original, baseRecord: original)
            XCTAssertThrowsError(try LedgerMutationStore.apply(mutation, in: container)) { error in
                XCTAssertEqual(error as? WatchSyncRejection, .conflict)
            }
        }

        XCTAssertTrue(try records(in: container).isEmpty)
    }

    func testMissingAccountRejectsNewEntry() throws {
        let container = try container()
        let record = record(accountID: UUID(), amount: 100)

        XCTAssertThrowsError(try LedgerMutationStore.apply(
            WatchLedgerMutation(ledgerID: UUID(), kind: .saveEntry, record: record), in: container
        )) { error in
            XCTAssertEqual(error as? WatchSyncRejection, .accountMissing)
        }

        XCTAssertTrue(try records(in: container).isEmpty)
    }

    func testDeletedAccountCannotBeRecreatedByRename() throws {
        let container = try container()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let original = LedgerAccountRecord(id: UUID(), name: "Business", createdAt: date, updatedAt: date)
        let renamed = LedgerAccountRecord(id: original.id, name: "Renamed", createdAt: date, updatedAt: date)

        XCTAssertThrowsError(try LedgerMutationStore.apply(
            WatchLedgerMutation(ledgerID: UUID(), kind: .saveAccount, account: renamed, baseAccount: original), in: container
        )) { error in
            XCTAssertEqual(error as? WatchSyncRejection, .conflict)
        }

        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<LedgerAccount>()).map(LedgerAccountMapper.record), [.default])
    }

    func testLocalSaveCommitsWithoutWatchReceipt() throws {
        let original = record(amount: 100)
        let container = try container(records: [original])
        let updated = record(id: original.id, amount: 200)

        try LedgerMutationStore.apply(
            WatchLedgerMutation(ledgerID: UUID(), kind: .saveEntry, record: updated, baseRecord: original), in: container
        )

        XCTAssertEqual(try records(in: container), [updated])
        XCTAssertTrue(try ModelContext(container).fetch(FetchDescriptor<WatchMutationReceiptEntity>()).isEmpty)
    }

    private func container(records: [LedgerRecord] = []) throws -> ModelContainer {
        let container = try ModelContainer(
            for: LedgerEntry.self, LedgerAccount.self, WatchMutationReceiptEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.insert(LedgerAccountMapper.account(from: .default))
        for record in records { context.insert(LedgerEntryMapper.entry(from: record)) }
        try context.save()
        return container
    }

    private func records(in container: ModelContainer) throws -> [LedgerRecord] {
        try ModelContext(container).fetch(FetchDescriptor<LedgerEntry>()).map(LedgerEntryMapper.record)
    }

    private func record(id: UUID = UUID(), accountID: UUID = LedgerAccountDefaults.id, amount: Int64) -> LedgerRecord {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        return LedgerRecord(
            id: id, accountID: accountID, kind: .expense, amountCents: amount,
            projectName: "Coffee", note: nil, occurredAt: date, createdAt: date, updatedAt: date
        )
    }
}
