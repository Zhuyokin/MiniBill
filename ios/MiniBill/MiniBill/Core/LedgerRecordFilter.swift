import Foundation

public enum LedgerRecordFilter {
    public static func records(
        forAccountID accountID: UUID,
        from records: [LedgerRecord]
    ) -> [LedgerRecord] {
        records
            .filter { $0.accountID == accountID }
            .sorted(by: newestFirst)
    }

    public static func records(
        on day: Date,
        from records: [LedgerRecord],
        calendar: Calendar
    ) -> [LedgerRecord] {
        guard let interval = calendar.dateInterval(of: .day, for: day) else { return [] }
        return records
            .filter { interval.start <= $0.occurredAt && $0.occurredAt < interval.end }
            .sorted(by: newestFirst)
    }

    public static func records(
        inMonth month: Date,
        from records: [LedgerRecord],
        calendar: Calendar
    ) -> [LedgerRecord] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        return records
            .filter { interval.start <= $0.occurredAt && $0.occurredAt < interval.end }
            .sorted(by: newestFirst)
    }

    public static func records(
        forProjectKey projectKey: String,
        kind: LedgerKind,
        inMonth month: Date,
        from records: [LedgerRecord],
        calendar: Calendar
    ) -> [LedgerRecord] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let normalizedKey = ProjectNameNormalizer.normalizedKey(projectKey)
        guard !normalizedKey.isEmpty else { return [] }

        return records
            .filter { record in
                interval.start <= record.occurredAt
                    && record.occurredAt < interval.end
                    && record.kind == kind
                    && ProjectNameNormalizer.normalizedKey(record.projectName) == normalizedKey
            }
            .sorted(by: newestFirst)
    }

    private static func newestFirst(_ lhs: LedgerRecord, _ rhs: LedgerRecord) -> Bool {
        if lhs.occurredAt == rhs.occurredAt {
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return lhs.occurredAt > rhs.occurredAt
    }
}
