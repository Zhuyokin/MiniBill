import Foundation
import SwiftData

#if SWIFT_PACKAGE
import MiniBillCore
#endif

public enum LedgerRestoreError: Error, Equatable {
    case duplicateExistingIdentifier
    case stagedCountMismatch
    case stagedRecordMismatch
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
            var existingByID: [UUID: LedgerEntry] = [:]
            existingByID.reserveCapacity(existingEntries.count)
            for entry in existingEntries {
                guard existingByID.updateValue(entry, forKey: entry.id) == nil else {
                    throw LedgerRestoreError.duplicateExistingIdentifier
                }
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

            // Exactly one explicit commit occurs after every validation has passed.
            try commit(restoreContext)
        } catch {
            restoreContext.rollback()
            throw error
        }
    }

}
