import Foundation
import SwiftData

#if SWIFT_PACKAGE
import MiniBillCore
#endif

@Model
public final class LedgerAccount {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum LedgerAccountMapper {
    public static func account(from record: LedgerAccountRecord) -> LedgerAccount {
        LedgerAccount(id: record.id, name: record.name, createdAt: record.createdAt, updatedAt: record.updatedAt)
    }

    public static func record(from account: LedgerAccount) -> LedgerAccountRecord {
        LedgerAccountRecord(id: account.id, name: account.name, createdAt: account.createdAt, updatedAt: account.updatedAt)
    }

    public static func apply(_ record: LedgerAccountRecord, to account: LedgerAccount) {
        precondition(record.id == account.id, "An account update cannot change its identifier.")
        account.name = record.name
        account.createdAt = record.createdAt
        account.updatedAt = record.updatedAt
    }
}

@MainActor
public enum LedgerAccountStore {
    public static func ensureDefaultAccount(in container: ModelContainer) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let accounts = try context.fetch(FetchDescriptor<LedgerAccount>())
        let legacyEntries = try context.fetch(FetchDescriptor<LedgerEntry>())
            .filter { $0.accountID == nil }
        if (accounts.isEmpty || !legacyEntries.isEmpty),
           !accounts.contains(where: { $0.id == LedgerAccountDefaults.id }) {
            context.insert(LedgerAccountMapper.account(from: .default))
        }

        for entry in legacyEntries {
            entry.accountID = LedgerAccountDefaults.id
        }

        if context.hasChanges {
            try context.save()
        }
    }
}
