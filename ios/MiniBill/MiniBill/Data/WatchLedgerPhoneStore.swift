import Foundation
import SwiftData

#if SWIFT_PACKAGE
import MiniBillCore
#endif

@Model
public final class WatchMutationReceiptEntity {
    @Attribute(.unique) public var id: UUID
    public var rejectionRawValue: String?

    public init(id: UUID, rejection: WatchSyncRejection? = nil) {
        self.id = id
        self.rejectionRawValue = rejection?.rawValue
    }
}

@MainActor
public enum WatchLedgerPhoneStore {
    public static func apply(
        _ mutation: WatchLedgerMutation,
        ledgerID: UUID,
        in container: ModelContainer
    ) throws -> WatchMutationReceipt {
        try apply(mutation, ledgerID: ledgerID, in: container) { context in
            try context.save()
        }
    }

    static func apply(
        _ mutation: WatchLedgerMutation,
        ledgerID: UUID,
        in container: ModelContainer,
        commit: (ModelContext) throws -> Void
    ) throws -> WatchMutationReceipt {
        let context = ModelContext(container)
        context.autosaveEnabled = false

        do {
            let ledgerMatches = mutation.ledgerID == ledgerID
            let mutationID = mutation.id
            var receiptDescriptor = FetchDescriptor<WatchMutationReceiptEntity>(
                predicate: #Predicate { $0.id == mutationID }
            )
            receiptDescriptor.fetchLimit = 1
            if let existing = try context.fetch(receiptDescriptor).first {
                return ledgerMatches
                    ? receipt(from: existing)
                    : WatchMutationReceipt(id: mutation.id, rejection: .conflict)
            }

            let rejection: WatchSyncRejection?
            if ledgerMatches {
                let existingEntries = try context.fetch(FetchDescriptor<LedgerEntry>())
                let existingAccounts = try context.fetch(FetchDescriptor<LedgerAccount>())
                var records = existingEntries.map(LedgerEntryMapper.record)
                var accounts = existingAccounts.map(LedgerAccountMapper.record)
                rejection = WatchLedgerReducer.apply(mutation, records: &records, accounts: &accounts)
                if rejection == nil {
                    persist(records: records, accounts: accounts,
                            existingEntries: existingEntries, existingAccounts: existingAccounts, in: context)
                }
            } else {
                rejection = .conflict
            }

            let result = WatchMutationReceipt(id: mutation.id, rejection: rejection)
            context.insert(WatchMutationReceiptEntity(id: result.id, rejection: result.rejection))
            try commit(context)
            return result
        } catch {
            context.rollback()
            throw error
        }
    }

    public static func snapshot(
        ledgerID: UUID,
        revision: Int64,
        languageCode: String,
        in container: ModelContainer
    ) throws -> WatchLedgerSnapshot {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let accounts = try context.fetch(FetchDescriptor<LedgerAccount>())
            .map(LedgerAccountMapper.record)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let records = try context.fetch(FetchDescriptor<LedgerEntry>())
            .map(LedgerEntryMapper.record)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let receipts = try context.fetch(FetchDescriptor<WatchMutationReceiptEntity>())
            .map(receipt)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        return WatchLedgerSnapshot(
            ledgerID: ledgerID, revision: revision, languageCode: languageCode,
            accounts: accounts, records: records, receipts: receipts
        )
    }

    private static func receipt(from entity: WatchMutationReceiptEntity) -> WatchMutationReceipt {
        WatchMutationReceipt(
            id: entity.id,
            rejection: entity.rejectionRawValue.map { WatchSyncRejection(rawValue: $0) ?? .invalidData }
        )
    }

    static func persist(
        records: [LedgerRecord],
        accounts: [LedgerAccountRecord],
        existingEntries: [LedgerEntry],
        existingAccounts: [LedgerAccount],
        in context: ModelContext
    ) {
        let entriesByID = Dictionary(uniqueKeysWithValues: existingEntries.map { ($0.id, $0) })
        let accountsByID = Dictionary(uniqueKeysWithValues: existingAccounts.map { ($0.id, $0) })
        for record in records {
            if let entry = entriesByID[record.id] {
                if LedgerEntryMapper.record(from: entry) != record {
                    LedgerEntryMapper.apply(record, to: entry)
                }
            } else {
                context.insert(LedgerEntryMapper.entry(from: record))
            }
        }
        for record in accounts {
            if let account = accountsByID[record.id] {
                if LedgerAccountMapper.record(from: account) != record {
                    LedgerAccountMapper.apply(record, to: account)
                }
            } else {
                context.insert(LedgerAccountMapper.account(from: record))
            }
        }

        let recordIDs = Set(records.map(\.id))
        for entry in existingEntries where !recordIDs.contains(entry.id) {
            context.delete(entry)
        }
        let accountIDs = Set(accounts.map(\.id))
        for account in existingAccounts where !accountIDs.contains(account.id) {
            context.delete(account)
        }
    }
}
