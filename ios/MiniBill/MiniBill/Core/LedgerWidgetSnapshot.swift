import Foundation

public struct LedgerWidgetRecord: Codable, Equatable, Sendable {
    public let kind: LedgerKind
    public let amountCents: Int64
    public let occurredAt: Date

    public init(kind: LedgerKind, amountCents: Int64, occurredAt: Date) {
        self.kind = kind
        self.amountCents = amountCents
        self.occurredAt = occurredAt
    }
}

public struct LedgerWidgetTotals: Equatable, Sendable {
    public let incomeCents: Int64
    public let expenseCents: Int64
    public let recordCount: Int
    public var netCents: Int64 { incomeCents - expenseCents }
}

public struct LedgerWidgetSnapshot: Codable, Equatable, Sendable {
    public let accountID: UUID
    public let accountName: String
    public let languageCode: String
    public let records: [LedgerWidgetRecord]

    public init(accountID: UUID, accountName: String, languageCode: String, records: [LedgerWidgetRecord]) {
        self.accountID = accountID
        self.accountName = accountName
        self.languageCode = languageCode
        self.records = records
    }

    public init(records: [LedgerRecord], accounts: [LedgerAccountRecord], selectedAccountID: UUID, languageCode: String) {
        let account = accounts.first { $0.id == selectedAccountID }
            ?? accounts.min { $0.createdAt < $1.createdAt }
            ?? .default
        self.init(
            accountID: account.id,
            accountName: account.name,
            languageCode: languageCode,
            records: records
                .filter { $0.accountID == account.id }
                .sorted { $0.id.uuidString < $1.id.uuidString }
                .map { LedgerWidgetRecord(kind: $0.kind, amountCents: $0.amountCents, occurredAt: $0.occurredAt) }
        )
    }

    public func totals(in component: Calendar.Component, at date: Date, calendar: Calendar) -> LedgerWidgetTotals {
        guard let interval = calendar.dateInterval(of: component, for: date) else {
            return LedgerWidgetTotals(incomeCents: 0, expenseCents: 0, recordCount: 0)
        }
        var income: Int64 = 0
        var expense: Int64 = 0
        var count = 0
        for record in records where record.amountCents > 0
            && interval.start <= record.occurredAt && record.occurredAt < interval.end {
            switch record.kind {
            case .income:
                income = Self.addingClamped(income, record.amountCents)
            case .expense:
                expense = Self.addingClamped(expense, record.amountCents)
            }
            count += 1
        }
        return LedgerWidgetTotals(incomeCents: income, expenseCents: expense, recordCount: count)
    }

    private static func addingClamped(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int64.max : sum
    }
}

public enum LedgerWidgetStore {
    public static let appGroupID = "group.com.masdey.minibill"

    public static func load() -> LedgerWidgetSnapshot? {
        guard let url = try? snapshotURL(), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LedgerWidgetSnapshot.self, from: data)
    }

    public static func save(_ snapshot: LedgerWidgetSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: snapshotURL(), options: .atomic)
    }

    private static func snapshotURL() throws -> URL {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return container.appendingPathComponent("ledger-widget.json")
    }
}
