import Foundation

#if SWIFT_PACKAGE
import MiniBillCore
#endif

public enum LedgerEntryMapper {
    public static func entry(from record: LedgerRecord) -> LedgerEntry {
        LedgerEntry(
            id: record.id,
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
            kind: entry.kind,
            amountCents: entry.amountCents,
            projectName: entry.projectName,
            note: entry.note,
            occurredAt: entry.occurredAt,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt
        )
    }
}
