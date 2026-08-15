import XCTest
import SwiftData
@testable import MiniBillCore
@testable import MiniBillData

@MainActor
final class LedgerRestoreStoreTests: XCTestCase {
    func testReplaceUpdatesMatchingIdentifiersAndAddsAndDeletesInOneOperation() throws {
        let container = try inMemoryContainer()
        let context = ModelContext(container)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let retainedID = UUID(uuidString: "31F00AC2-8C09-4B28-8E81-D8838B334B14")!

        context.insert(LedgerEntryMapper.entry(from: record(
            id: retainedID,
            kind: .income,
            amount: 100,
            project: "Old name",
            note: "old",
            date: base
        )))
        context.insert(LedgerEntryMapper.entry(from: record(
            id: UUID(uuidString: "8A2CE46B-39B1-443D-A115-386E2604BDA2")!,
            kind: .expense,
            amount: 200,
            project: "Remove me",
            note: nil,
            date: base
        )))
        try context.save()

        let expected = [
            record(id: retainedID, kind: .expense, amount: 999, project: "Updated", note: "new", date: base.addingTimeInterval(60)),
            record(
                id: UUID(uuidString: "A3A0907F-F1A0-4D96-B648-33DB41FE81B7")!,
                kind: .income,
                amount: 450,
                project: "Added",
                note: nil,
                date: base.addingTimeInterval(120)
            ),
        ]
        let archive = BackupArchive(exportedAt: base, appVersion: "1", records: expected)

        try LedgerRestoreStore.replace(with: archive, in: container)

        let verificationContext = ModelContext(container)
        let restored = try verificationContext.fetch(FetchDescriptor<LedgerEntry>())
            .map(LedgerEntryMapper.record)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        XCTAssertEqual(restored, expected.sorted { $0.id.uuidString < $1.id.uuidString })

        let visibleFromOriginalContext = try context.fetch(FetchDescriptor<LedgerEntry>())
            .map(LedgerEntryMapper.record)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        XCTAssertEqual(
            visibleFromOriginalContext,
            expected.sorted { $0.id.uuidString < $1.id.uuidString },
            "The UI context must observe the committed replacement without relaunching."
        )
    }

    func testReplaceAcceptsEmptyBackupAndRemovesAllEntries() throws {
        let container = try inMemoryContainer()
        let context = ModelContext(container)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(LedgerEntryMapper.entry(from: record(id: UUID(), kind: .income, amount: 100, project: "Sale", note: nil, date: base)))
        try context.save()

        try LedgerRestoreStore.replace(
            with: BackupArchive(exportedAt: base, appVersion: "1", records: []),
            in: container
        )

        let verificationContext = ModelContext(container)
        XCTAssertEqual(try verificationContext.fetchCount(FetchDescriptor<LedgerEntry>()), 0)
    }

    func testReplaceRestoresAccountsAndKeepsEachRecordInItsAccount() throws {
        let container = try inMemoryContainer()
        let context = ModelContext(container)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(LedgerAccount(id: UUID(), name: "Remove me", createdAt: base, updatedAt: base))
        try context.save()

        let first = LedgerAccountRecord(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            name: "Main",
            createdAt: base,
            updatedAt: base
        )
        let second = LedgerAccountRecord(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            name: "Side Business",
            createdAt: base,
            updatedAt: base
        )
        let expectedRecord = LedgerRecord(
            id: UUID(),
            accountID: second.id,
            kind: .income,
            amountCents: 500,
            projectName: "Sale",
            note: nil,
            occurredAt: base,
            createdAt: base,
            updatedAt: base
        )
        let archive = BackupArchive(
            exportedAt: base,
            appVersion: "1.0.3",
            accounts: [first, second],
            selectedAccountID: second.id,
            records: [expectedRecord]
        )

        try LedgerRestoreStore.replace(with: archive, in: container)

        let verification = ModelContext(container)
        let accounts = try verification.fetch(FetchDescriptor<LedgerAccount>())
            .map(LedgerAccountMapper.record)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        XCTAssertEqual(accounts, [first, second])
        XCTAssertEqual(
            try verification.fetch(FetchDescriptor<LedgerEntry>()).map(LedgerEntryMapper.record),
            [expectedRecord]
        )
    }

    func testInvalidArchiveIsRejectedBeforeExistingLedgerChanges() throws {
        let container = try inMemoryContainer()
        let context = ModelContext(container)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let original = record(id: UUID(), kind: .income, amount: 100, project: "Original", note: "keep", date: base)
        context.insert(LedgerEntryMapper.entry(from: original))
        try context.save()

        let invalid = BackupArchive(
            exportedAt: base,
            appVersion: "1",
            recordCount: 2,
            records: [record(id: UUID(), kind: .expense, amount: 300, project: "Invalid", note: nil, date: base)]
        )

        XCTAssertThrowsError(try LedgerRestoreStore.replace(with: invalid, in: container))

        let verificationContext = ModelContext(container)
        let records = try verificationContext.fetch(FetchDescriptor<LedgerEntry>()).map(LedgerEntryMapper.record)
        XCTAssertEqual(records, [original])
    }

    func testSaveFailureLeavesPersistentLedgerUnchanged() throws {
        enum SimulatedCommitError: Error { case diskUnavailable }

        let container = try inMemoryContainer()
        let context = ModelContext(container)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let original = record(
            id: UUID(),
            kind: .income,
            amount: 100,
            project: "Original",
            note: "keep",
            date: base
        )
        context.insert(LedgerEntryMapper.entry(from: original))
        try context.save()

        let replacement = record(
            id: UUID(),
            kind: .expense,
            amount: 500,
            project: "Replacement",
            note: nil,
            date: base.addingTimeInterval(60)
        )
        XCTAssertThrowsError(try LedgerRestoreStore.replace(
            with: BackupArchive(exportedAt: base, appVersion: "1", records: [replacement]),
            in: container,
            commit: { _ in throw SimulatedCommitError.diskUnavailable }
        )) { error in
            XCTAssertTrue(error is SimulatedCommitError)
        }

        let verification = ModelContext(container)
        let records = try verification.fetch(FetchDescriptor<LedgerEntry>()).map(LedgerEntryMapper.record)
        XCTAssertEqual(records, [original])
    }

    private func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: LedgerEntry.self, LedgerAccount.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func record(
        id: UUID,
        kind: LedgerKind,
        amount: Int64,
        project: String,
        note: String?,
        date: Date
    ) -> LedgerRecord {
        LedgerRecord(
            id: id,
            kind: kind,
            amountCents: amount,
            projectName: project,
            note: note,
            occurredAt: date,
            createdAt: date.addingTimeInterval(-10),
            updatedAt: date.addingTimeInterval(10)
        )
    }
}
