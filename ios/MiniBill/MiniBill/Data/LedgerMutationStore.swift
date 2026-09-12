import Foundation
import SwiftData

#if SWIFT_PACKAGE
import MiniBillCore
#endif

@MainActor
public enum LedgerMutationStore {
    public static func apply(_ mutation: WatchLedgerMutation, in container: ModelContainer) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let entries = try context.fetch(FetchDescriptor<LedgerEntry>())
            let storedAccounts = try context.fetch(FetchDescriptor<LedgerAccount>())
            var records = entries.map(LedgerEntryMapper.record)
            var accounts = storedAccounts.map(LedgerAccountMapper.record)
            if let rejection = WatchLedgerReducer.apply(mutation, records: &records, accounts: &accounts) {
                throw rejection
            }
            WatchLedgerPhoneStore.persist(
                records: records, accounts: accounts,
                existingEntries: entries, existingAccounts: storedAccounts, in: context
            )
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
