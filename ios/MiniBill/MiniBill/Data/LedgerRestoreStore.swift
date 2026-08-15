import Foundation
import SwiftData

#if SWIFT_PACKAGE
import MiniBillCore
#endif

public enum LedgerRestoreError: Error, Equatable {
    case duplicateExistingIdentifier
    case duplicateExistingAccountIdentifier
    case stagedCountMismatch
    case stagedRecordMismatch
    case stagedAccountMismatch
}

@MainActor
public enum LedgerRestoreStore {
    public static func replace(with archive: BackupArchive, in container: ModelContainer) throws {
        try replace(with: archive, in: container) { context in
            try context.save()
        }
    }

    static func replace(
        with archive: BackupArchive,
        in container: ModelContainer,
        commit: (ModelContext) throws -> Void
    ) throws {
        try BackupValidator.validate(archive)

        let restoreContext = ModelContext(container)
        restoreContext.autosaveEnabled = false

        do {
            let existingEntries = try restoreContext.fetch(FetchDescriptor<LedgerEntry>())
            let existingAccounts = try restoreContext.fetch(FetchDescriptor<LedgerAccount>())
            var existingByID: [UUID: LedgerEntry] = [:]
            existingByID.reserveCapacity(existingEntries.count)
            for entry in existingEntries {
                guard existingByID.updateValue(entry, forKey: entry.id) == nil else {
                    throw LedgerRestoreError.duplicateExistingIdentifier
                }
            }

            var existingAccountsByID: [UUID: LedgerAccount] = [:]
            existingAccountsByID.reserveCapacity(existingAccounts.count)
            for account in existingAccounts {
                guard existingAccountsByID.updateValue(account, forKey: account.id) == nil else {
                    throw LedgerRestoreError.duplicateExistingAccountIdentifier
                }
            }

            let desiredAccountIDs = Set(archive.accounts.map(\.id))
            var stagedAccounts: [LedgerAccount] = []
            stagedAccounts.reserveCapacity(archive.accounts.count)
            for accountRecord in archive.accounts {
                let account: LedgerAccount
                if let existing = existingAccountsByID[accountRecord.id] {
                    LedgerAccountMapper.apply(accountRecord, to: existing)
                    account = existing
                } else {
                    account = LedgerAccountMapper.account(from: accountRecord)
                    restoreContext.insert(account)
                }
                stagedAccounts.append(account)
            }
            for account in existingAccounts where !desiredAccountIDs.contains(account.id) {
                restoreContext.delete(account)
            }

            let desiredIDs = Set(archive.records.map(\.id))
            var stagedEntries: [LedgerEntry] = []
            stagedEntries.reserveCapacity(archive.records.count)

            for record in archive.records {
                let entry: LedgerEntry
                if let existing = existingByID[record.id] {
                    LedgerEntryMapper.apply(record, to: existing)
                    entry = existing
                } else {
                    entry = LedgerEntryMapper.entry(from: record)
                    restoreContext.insert(entry)
                }
                stagedEntries.append(entry)
            }

            for entry in existingEntries where !desiredIDs.contains(entry.id) {
                restoreContext.delete(entry)
            }

            guard stagedEntries.count == archive.recordCount else {
                throw LedgerRestoreError.stagedCountMismatch
            }
            for (entry, expected) in zip(stagedEntries, archive.records) {
                guard LedgerEntryMapper.record(from: entry) == expected else {
                    throw LedgerRestoreError.stagedRecordMismatch
                }
            }
            for (account, expected) in zip(stagedAccounts, archive.accounts) {
                guard LedgerAccountMapper.record(from: account) == expected else {
                    throw LedgerRestoreError.stagedAccountMismatch
                }
            }

            // Exactly one explicit commit occurs after every validation has passed.
            try commit(restoreContext)
        } catch {
            restoreContext.rollback()
            throw error
        }
    }

}
