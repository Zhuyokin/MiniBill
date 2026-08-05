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
                let isNewer = record.occurredAt > existing.occurredAt
                let winsTie = record.occurredAt == existing.occurredAt
                    && record.id.uuidString < existing.id.uuidString
                if isNewer || winsTie {
                    newestByKey[key] = record
                }
            } else {
                newestByKey[key] = record
            }
        }

        var ranked: [(key: String, record: LedgerRecord)] = []
        ranked.reserveCapacity(newestByKey.count)
        for (key, record) in newestByKey {
            ranked.append((key: key, record: record))
        }
        ranked.sort { left, right in
            if left.record.occurredAt == right.record.occurredAt {
                return left.key < right.key
            }
            return left.record.occurredAt > right.record.occurredAt
        }

        var result: [String] = []
        result.reserveCapacity(min(limit, ranked.count))
        for item in ranked.prefix(limit) {
            result.append(item.record.projectName.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return result
    }
}
