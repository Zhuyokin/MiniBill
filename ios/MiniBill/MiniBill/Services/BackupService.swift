import Foundation
import SwiftData

struct RestorePreview: Identifiable {
    let archive: BackupArchive
    let currentRecordCount: Int

    var id: Date { archive.exportedAt }
    var earliestDate: Date? { archive.records.map(\.occurredAt).min() }
    var latestDate: Date? { archive.records.map(\.occurredAt).max() }
}

enum BackupService {
    static func archive(
        entries: [LedgerEntry],
        accounts: [LedgerAccount],
        selectedAccountID: UUID,
        exportedAt: Date = Date()
    ) -> BackupArchive {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return BackupArchive(
            exportedAt: exportedAt,
            appVersion: appVersion,
            accounts: accounts.map(LedgerAccountMapper.record),
            selectedAccountID: selectedAccountID,
            records: entries.map(LedgerEntryMapper.record)
        )
    }

    static func document(entries: [LedgerEntry], accounts: [LedgerAccount], selectedAccountID: UUID) throws -> BackupDocument {
        BackupDocument(data: try BackupCodec.encode(archive(
            entries: entries,
            accounts: accounts,
            selectedAccountID: selectedAccountID
        )))
    }

    static func preview(data: Data, currentRecordCount: Int) throws -> RestorePreview {
        RestorePreview(archive: try BackupCodec.decodeAndValidate(data), currentRecordCount: currentRecordCount)
    }

    @MainActor
    static func replace(with archive: BackupArchive, in context: ModelContext) throws {
        if context.hasChanges {
            try context.save()
        }
        try LedgerRestoreStore.replace(with: archive, in: context.container)
    }

    static func filename(at date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "MiniBill-\(formatter.string(from: date))"
    }
}
