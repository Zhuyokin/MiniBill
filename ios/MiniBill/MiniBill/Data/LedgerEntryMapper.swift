import Foundation

#if SWIFT_PACKAGE
import MiniBillCore
#endif

public enum LedgerEntryMapper {
    public static func entry(from record: LedgerRecord) -> LedgerEntry {
        LedgerEntry(
            id: record.id,
            accountID: record.accountID,
            kindRawValue: record.kind.rawValue,
            amountCents: record.amountCents,
            projectName: record.projectName,
            note: record.note,
            occurredAt: record.occurredAt,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    public static func record(from entry: LedgerEntry) -> LedgerRecord {
        LedgerRecord(
            id: entry.id,
            accountID: entry.resolvedAccountID,
            kind: entry.kind,
            amountCents: entry.amountCents,
            projectName: entry.projectName,
            note: entry.note,
            occurredAt: entry.occurredAt,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt
        )
    }

    public static func apply(_ record: LedgerRecord, to entry: LedgerEntry) {
        precondition(record.id == entry.id, "A ledger update cannot change its identifier.")
        entry.accountID = record.accountID
        entry.kindRawValue = record.kind.rawValue
        entry.amountCents = record.amountCents
        entry.projectName = record.projectName
        entry.note = record.note
        entry.occurredAt = record.occurredAt
        entry.createdAt = record.createdAt
        entry.updatedAt = record.updatedAt
    }
}
