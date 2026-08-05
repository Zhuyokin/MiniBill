import Foundation

public enum ProjectNameNormalizer {
    private static let comparisonLocale = Locale(identifier: "en_US_POSIX")

    public static func normalizedKey(_ value: String) -> String {
        value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .lowercased(with: comparisonLocale)
    }
}

public enum ProjectSuggestionService {
    public static func candidates(from records: [LedgerRecord], limit: Int = 6) -> [String] {
        guard limit > 0 else { return [] }
        var newestByKey: [String: LedgerRecord] = [:]
        for record in records {
            let key = ProjectNameNormalizer.normalizedKey(record.projectName)
            guard !key.isEmpty else { continue }
            if let existing = newestByKey[key] {
                if record.occurredAt > existing.occurredAt || (record.occurredAt == existing.occurredAt && record.id.uuidString < existing.id.uuidString) {
                    newestByKey[key] = record
                }
            } else {
                newestByKey[key] = record
            }
        }

        return newestByKey
            .map { (key: $0.key, record: $0.value) }
            .sorted {
                $0.record.occurredAt == $1.record.occurredAt
                    ? $0.key < $1.key
                    : $0.record.occurredAt > $1.record.occurredAt
            }
            .prefix(limit)
            .map { $0.record.projectName.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
