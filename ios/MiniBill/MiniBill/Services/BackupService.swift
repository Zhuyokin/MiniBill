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
    static func archive(entries: [LedgerEntry], exportedAt: Date = Date()) -> BackupArchive {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return BackupArchive(exportedAt: exportedAt, appVersion: appVersion, records: entries.map(LedgerEntryMapper.record))
    }

    static func document(entries: [LedgerEntry]) throws -> BackupDocument {
        BackupDocument(data: try BackupCodec.encode(archive(entries: entries)))
    }

    static func preview(data: Data, currentRecordCount: Int) throws -> RestorePreview {
        RestorePreview(archive: try BackupCodec.decodeAndValidate(data), currentRecordCount: currentRecordCount)
    }

    static func replace(with archive: BackupArchive, in context: ModelContext) throws {
        try BackupValidator.validate(archive)
        do {
            try context.transaction {
                let current = try context.fetch(FetchDescriptor<LedgerEntry>())
                current.forEach(context.delete)
                archive.records.map(LedgerEntryMapper.entry).forEach(context.insert)
                try context.save()
                let count = try context.fetchCount(FetchDescriptor<LedgerEntry>())
                guard count == archive.recordCount else { throw BackupValidationError.countMismatch }
            }
        } catch {
            context.rollback()
            throw error
        }
    }

    static func filename(at date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "MiniBill-\(formatter.string(from: date))"
    }
}
