import XCTest
import SwiftData
@testable import MiniBillCore
@testable import MiniBillData

@MainActor
final class WatchLedgerPhoneStoreTests: XCTestCase {
    private let ledgerID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    func testEntryCreateUpdateAndDeletePersistEveryFieldAndReceipts() throws {
        let container = try container()
        let original = record()
        let create = WatchLedgerMutation(ledgerID: ledgerID, kind: .saveEntry, record: original)
        XCTAssertNil(try apply(create, in: container).rejection)
        XCTAssertEqual(try snapshot(in: container).records, [original])

        let updated = LedgerRecord(
            id: original.id, accountID: original.accountID, kind: .income,
            amountCents: 5_678, projectName: "Sale", note: "Updated note",
            occurredAt: date.addingTimeInterval(60), createdAt: original.createdAt,
            updatedAt: date.addingTimeInterval(90)
        )
        let update = WatchLedgerMutation(ledgerID: ledgerID, kind: .saveEntry, record: updated, baseRecord: original)
        XCTAssertNil(try apply(update, in: container).rejection)
        XCTAssertEqual(try snapshot(in: container).records, [updated])

        let deletion = WatchLedgerMutation(ledgerID: ledgerID, kind: .deleteEntry, record: updated, baseRecord: updated)
        XCTAssertNil(try apply(deletion, in: container).rejection)
        let result = try snapshot(in: container)
        XCTAssertTrue(result.records.isEmpty)
        XCTAssertEqual(Set(result.receipts.map(\.id)), Set([create.id, update.id, deletion.id]))
        XCTAssertTrue(result.receipts.allSatisfy { $0.rejection == nil })
    }

    func testAcceptedCreateReplayDoesNotResurrectPhoneDeletion() throws {
        let container = try container()
        let mutation = WatchLedgerMutation(ledgerID: ledgerID, kind: .saveEntry, record: record())
        let receipt = try apply(mutation, in: container)
        let phoneContext = ModelContext(container)
        phoneContext.delete(try XCTUnwrap(phoneContext.fetch(FetchDescriptor<LedgerEntry>()).first))
        try phoneContext.save()

        XCTAssertEqual(try apply(mutation, in: container), receipt)
        let result = try snapshot(in: container)
        XCTAssertTrue(result.records.isEmpty)
        XCTAssertEqual(result.receipts, [receipt])
    }

    func testConflictingUpdateRemembersRejectionAfterPhoneRecordChangesAgain() throws {
        let original = record()
        let phoneRecord = record(id: original.id, amount: 800)
        let container = try container(records: [phoneRecord])
        let mutation = WatchLedgerMutation(
            ledgerID: ledgerID, kind: .saveEntry,
            record: record(id: original.id, amount: 900), baseRecord: original
        )
        let receipt = try apply(mutation, in: container)
        XCTAssertEqual(receipt, WatchMutationReceipt(id: mutation.id, rejection: .conflict))
        XCTAssertEqual(try snapshot(in: container).records, [phoneRecord])

        let phoneContext = ModelContext(container)
        let entry = try XCTUnwrap(phoneContext.fetch(FetchDescriptor<LedgerEntry>()).first)
        LedgerEntryMapper.apply(original, to: entry)
        try phoneContext.save()

        XCTAssertEqual(try apply(mutation, in: container), receipt)
        let result = try snapshot(in: container)
        XCTAssertEqual(result.records, [original])
        XCTAssertEqual(result.receipts, [receipt])
    }

    func testStaleUpdateCannotResurrectDeletedRecord() throws {
        let container = try container()
        let original = record()
        let mutation = WatchLedgerMutation(
            ledgerID: ledgerID, kind: .saveEntry,
            record: record(id: original.id, amount: 900), baseRecord: original
        )

        XCTAssertEqual(try apply(mutation, in: container).rejection, .conflict)
        XCTAssertTrue(try snapshot(in: container).records.isEmpty)
    }

    func testDifferentLedgerRejectsMutationAndPersistsConflictReceipt() throws {
        let container = try container()
        let mutation = WatchLedgerMutation(ledgerID: UUID(), kind: .saveEntry, record: record())

        let receipt = try apply(mutation, in: container)

        XCTAssertEqual(receipt, WatchMutationReceipt(id: mutation.id, rejection: .conflict))
        let result = try snapshot(in: container)
        XCTAssertTrue(result.records.isEmpty)
        XCTAssertEqual(result.receipts, [receipt])
    }

    func testDifferentLedgerRejectsEvenPreviouslyAcceptedMutation() throws {
        let container = try container()
        let mutation = WatchLedgerMutation(ledgerID: ledgerID, kind: .saveEntry, record: record())
        let accepted = try apply(mutation, in: container)

        let receipt = try WatchLedgerPhoneStore.apply(mutation, ledgerID: UUID(), in: container)

        XCTAssertEqual(receipt.rejection, .conflict)
        XCTAssertEqual(try snapshot(in: container).receipts, [accepted])
    }

    func testAccountCreateAndRenamePersistEveryField() throws {
        let container = try container()
        let original = account()
        let create = WatchLedgerMutation(ledgerID: ledgerID, kind: .saveAccount, account: original)
        XCTAssertNil(try apply(create, in: container).rejection)
        let updated = LedgerAccountRecord(
            id: original.id, name: "Renamed", createdAt: original.createdAt,
            updatedAt: date.addingTimeInterval(90)
        )
        let rename = WatchLedgerMutation(ledgerID: ledgerID, kind: .saveAccount, account: updated, baseAccount: original)

        XCTAssertNil(try apply(rename, in: container).rejection)

        let result = try snapshot(in: container)
        XCTAssertEqual(result.accounts.first { $0.id == original.id }, updated)
        XCTAssertEqual(result.accounts.count, 2)
        XCTAssertEqual(Set(result.receipts.map(\.id)), Set([create.id, rename.id]))
    }

    func testAccountDeletionCascadesOnlyItsEntries() throws {
        let removedAccount = account()
        let removedRecord = record(accountID: removedAccount.id)
        let retainedRecord = record()
        let container = try container(accounts: [.default, removedAccount], records: [removedRecord, retainedRecord])
        let mutation = WatchLedgerMutation(
            ledgerID: ledgerID, kind: .deleteAccount, account: removedAccount,
            baseAccount: removedAccount, accountEntries: [removedRecord]
        )

        let receipt = try apply(mutation, in: container)

        XCTAssertNil(receipt.rejection)
        let result = try snapshot(in: container)
        XCTAssertEqual(result.accounts, [.default])
        XCTAssertEqual(result.records, [retainedRecord])
        XCTAssertEqual(result.receipts, [receipt])
    }

    func testAccountDeletionConflictPreservesNewPhoneEntryAndAccount() throws {
        let removedAccount = account()
        let phoneRecord = record(accountID: removedAccount.id)
        let container = try container(accounts: [.default, removedAccount], records: [phoneRecord])
        let mutation = WatchLedgerMutation(
            ledgerID: ledgerID, kind: .deleteAccount, account: removedAccount,
            baseAccount: removedAccount, accountEntries: []
        )

        let receipt = try apply(mutation, in: container)

        XCTAssertEqual(receipt.rejection, .conflict)
        let result = try snapshot(in: container)
        XCTAssertEqual(result.accounts.count, 2)
        XCTAssertEqual(result.records, [phoneRecord])
        XCTAssertEqual(result.receipts, [receipt])
    }

    func testFailedEntryCommitRollsBackEntryAndReceiptTogether() throws {
        let container = try container()
        let mutation = WatchLedgerMutation(ledgerID: ledgerID, kind: .saveEntry, record: record())
        var commitCount = 0

        XCTAssertThrowsError(try WatchLedgerPhoneStore.apply(mutation, ledgerID: ledgerID, in: container) { context in
            commitCount += 1
            XCTAssertFalse(context.autosaveEnabled)
            XCTAssertEqual(try context.fetch(FetchDescriptor<LedgerEntry>()).map(LedgerEntryMapper.record), [mutation.record!])
            XCTAssertEqual(try context.fetch(FetchDescriptor<WatchMutationReceiptEntity>()).map(\.id), [mutation.id])
            throw CommitError.unavailable
        }) { error in
            XCTAssertTrue(error is CommitError)
        }

        XCTAssertEqual(commitCount, 1)
        let result = try snapshot(in: container)
        XCTAssertTrue(result.records.isEmpty)
        XCTAssertTrue(result.receipts.isEmpty)
        XCTAssertEqual(result.accounts, [.default])
        XCTAssertNil(try apply(mutation, in: container).rejection)
        XCTAssertEqual(try snapshot(in: container).records, [mutation.record!])
    }

    func testFailedCascadeCommitRollsBackAccountEntriesAndReceiptTogether() throws {
        let removedAccount = account()
        let removedRecord = record(accountID: removedAccount.id)
        let container = try container(accounts: [.default, removedAccount], records: [removedRecord])
        let mutation = WatchLedgerMutation(
            ledgerID: ledgerID, kind: .deleteAccount, account: removedAccount,
            baseAccount: removedAccount, accountEntries: [removedRecord]
        )

        XCTAssertThrowsError(try WatchLedgerPhoneStore.apply(mutation, ledgerID: ledgerID, in: container) { context in
            XCTAssertTrue(try context.fetch(FetchDescriptor<LedgerEntry>()).isEmpty)
            XCTAssertEqual(try context.fetch(FetchDescriptor<LedgerAccount>()).map(LedgerAccountMapper.record), [.default])
            XCTAssertEqual(try context.fetch(FetchDescriptor<WatchMutationReceiptEntity>()).map(\.id), [mutation.id])
            throw CommitError.unavailable
        }) { error in
            XCTAssertTrue(error is CommitError)
        }

        let result = try snapshot(in: container)
        XCTAssertEqual(result.accounts.count, 2)
        XCTAssertEqual(result.accounts.first { $0.id == removedAccount.id }, removedAccount)
        XCTAssertEqual(result.records, [removedRecord])
        XCTAssertTrue(result.receipts.isEmpty)
    }

    func testSnapshotPreservesMetadataMapsLegacyAccountAndSortsPayload() throws {
        let first = record(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
        let second = record(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!)
        let container = try container(records: [second, first])
        let context = ModelContext(container)
        let legacy = try XCTUnwrap(context.fetch(FetchDescriptor<LedgerEntry>()).first { $0.id == first.id })
        legacy.accountID = nil
        try context.save()
        let before = Date()

        let result = try WatchLedgerPhoneStore.snapshot(ledgerID: ledgerID, revision: 42, languageCode: "zh-Hans", in: container)

        XCTAssertEqual(result.schemaVersion, 1)
        XCTAssertEqual(result.ledgerID, ledgerID)
        XCTAssertEqual(result.revision, 42)
        XCTAssertEqual(result.languageCode, "zh-Hans")
        XCTAssertGreaterThanOrEqual(result.generatedAt, before)
        XCTAssertLessThanOrEqual(result.generatedAt, Date())
        XCTAssertEqual(result.records, [first, second])
        XCTAssertEqual(result.accounts, [.default])
    }

    func testExistingStoreMigratesReceiptSchemaAndAcceptsWatchMutationWithoutLosingData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("ledger.store")
        let originalAccount = account()
        let originalRecord = record(accountID: originalAccount.id)

        try autoreleasepool {
            let original = try ModelContainer(
                for: LedgerEntry.self, LedgerAccount.self,
                configurations: ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            )
            let context = ModelContext(original)
            context.autosaveEnabled = false
            context.insert(LedgerAccountMapper.account(from: originalAccount))
            context.insert(LedgerEntryMapper.entry(from: originalRecord))
            try context.save()
        }

        let migrated = try ModelContainer(
            for: LedgerEntry.self, LedgerAccount.self, WatchMutationReceiptEntity.self,
            configurations: ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        )
        let before = try snapshot(in: migrated)
        XCTAssertEqual(before.accounts, [originalAccount])
        XCTAssertEqual(before.records, [originalRecord])
        XCTAssertTrue(before.receipts.isEmpty)

        let addedRecord = record(accountID: originalAccount.id, amount: 990)
        let mutation = WatchLedgerMutation(ledgerID: ledgerID, kind: .saveEntry, record: addedRecord)
        let receipt = try apply(mutation, in: migrated)

        XCTAssertNil(receipt.rejection)
        let after = try snapshot(in: migrated)
        XCTAssertEqual(after.accounts, [originalAccount])
        XCTAssertEqual(after.records.count, 2)
        XCTAssertEqual(after.records.first { $0.id == originalRecord.id }, originalRecord)
        XCTAssertEqual(after.records.first { $0.id == addedRecord.id }, addedRecord)
        XCTAssertEqual(after.receipts, [receipt])
    }

    private enum CommitError: Error { case unavailable }

    private func container(accounts: [LedgerAccountRecord] = [.default], records: [LedgerRecord] = []) throws -> ModelContainer {
        let container = try ModelContainer(
            for: LedgerEntry.self, LedgerAccount.self, WatchMutationReceiptEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        for account in accounts { context.insert(LedgerAccountMapper.account(from: account)) }
        for record in records { context.insert(LedgerEntryMapper.entry(from: record)) }
        try context.save()
        return container
    }

    private func apply(_ mutation: WatchLedgerMutation, in container: ModelContainer) throws -> WatchMutationReceipt {
        try WatchLedgerPhoneStore.apply(mutation, ledgerID: ledgerID, in: container)
    }

    private func snapshot(in container: ModelContainer) throws -> WatchLedgerSnapshot {
        try WatchLedgerPhoneStore.snapshot(ledgerID: ledgerID, revision: 1, languageCode: "en", in: container)
    }

    private func account() -> LedgerAccountRecord {
        LedgerAccountRecord(id: UUID(), name: "Business", createdAt: date, updatedAt: date)
    }

    private func record(id: UUID = UUID(), accountID: UUID = LedgerAccountDefaults.id, amount: Int64 = 100) -> LedgerRecord {
        LedgerRecord(
            id: id, accountID: accountID, kind: .expense, amountCents: amount,
            projectName: "Coffee", note: nil, occurredAt: date,
            createdAt: date.addingTimeInterval(-10), updatedAt: date
        )
    }
}
