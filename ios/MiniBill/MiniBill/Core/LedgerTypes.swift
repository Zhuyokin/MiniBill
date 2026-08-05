import Foundation

public enum LedgerKind: String, Codable, CaseIterable, Sendable {
    case income
    case expense
}

public struct LedgerRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: LedgerKind
    public var amountCents: Int64
    public var projectName: String
    public var note: String?
    public var occurredAt: Date
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        kind: LedgerKind,
        amountCents: Int64,
        projectName: String,
        note: String?,
        occurredAt: Date,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.amountCents = amountCents
        self.projectName = projectName
        self.note = note
        self.occurredAt = occurredAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ProjectTotal: Codable, Equatable, Sendable, Identifiable {
    public let normalizedKey: String
    public let displayName: String
    public let totalCents: Int64
    public let recordCount: Int

    public var id: String { normalizedKey }
}

public struct DailyTotal: Codable, Equatable, Sendable, Identifiable {
    public let date: Date
    public let netCents: Int64

    public var id: Date { date }
}

public struct MonthlySummary: Equatable, Sendable, Identifiable {
    public let month: Date
    public let incomeCents: Int64
    public let expenseCents: Int64
    public let netCents: Int64
    public let recordCount: Int
    public let dailyNet: [DailyTotal]
    public let incomeProjects: [ProjectTotal]
    public let expenseProjects: [ProjectTotal]

    public var id: Date { month }
}

public enum EntryValidationError: Error, Equatable, LocalizedError {
    case invalidAmount
    case emptyProjectName
    case noteTooLong

    public var errorDescription: String? {
        switch self {
        case .invalidAmount: return "Amount must be greater than zero with at most two decimal places."
        case .emptyProjectName: return "Project name is required."
        case .noteTooLong: return "Note must be 200 characters or fewer."
        }
    }
}

public enum EntryValidator {
    public static func amountCents(from input: String) throws -> Int64 {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let pieces = value.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count <= 2,
              let wholeText = pieces.first,
              !wholeText.isEmpty,
              wholeText.allSatisfy(\.isNumber),
              let whole = Int64(wholeText) else {
            throw EntryValidationError.invalidAmount
        }

        let fractionalText = pieces.count == 2 ? pieces[1] : Substring()
        guard fractionalText.count <= 2,
              fractionalText.allSatisfy(\.isNumber) else {
            throw EntryValidationError.invalidAmount
        }
        let paddedFraction = fractionalText + String(repeating: "0", count: 2 - fractionalText.count)
        guard let fraction = Int64(paddedFraction),
              whole <= (Int64.max - fraction) / 100 else {
            throw EntryValidationError.invalidAmount
        }
        let cents = whole * 100 + fraction
        guard cents > 0 else { throw EntryValidationError.invalidAmount }
        return cents
    }

    public static func validate(amountCents: Int64, projectName: String, note: String?) throws {
        guard amountCents > 0 else { throw EntryValidationError.invalidAmount }
        guard !ProjectNameNormalizer.normalizedKey(projectName).isEmpty else {
            throw EntryValidationError.emptyProjectName
        }
        guard (note?.count ?? 0) <= 200 else { throw EntryValidationError.noteTooLong }
    }
}

public struct EntrySharePayload: Codable, Equatable, Sendable {
    public let kind: LedgerKind
    public let amountCents: Int64
    public let projectName: String
    public let occurredAt: Date

    public init(record: LedgerRecord) {
        kind = record.kind
        amountCents = record.amountCents
        projectName = record.projectName
        occurredAt = record.occurredAt
    }
}

public struct MonthlySharePayload: Codable, Equatable, Sendable {
    public let month: Date
    public let netCents: Int64
    public let incomeCents: Int64
    public let expenseCents: Int64
    public let recordCount: Int
    public let dailyNet: [DailyTotal]
    public let topIncomeProject: ProjectTotal?
    public let topExpenseProject: ProjectTotal?

    public init(summary: MonthlySummary) {
        month = summary.month
        netCents = summary.netCents
        incomeCents = summary.incomeCents
        expenseCents = summary.expenseCents
        recordCount = summary.recordCount
        dailyNet = summary.dailyNet
        topIncomeProject = summary.incomeProjects.first
        topExpenseProject = summary.expenseProjects.first
    }
}
