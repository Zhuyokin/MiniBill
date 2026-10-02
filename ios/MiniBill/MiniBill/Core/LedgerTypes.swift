import Foundation

public enum LedgerKind: String, Codable, CaseIterable, Sendable {
    case income
    case expense
}

public enum LedgerAccountDefaults {
    public static let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    public static let name = "Default"
    public static let selectionStorageKey = "selectedLedgerAccountID"
}

public enum LedgerAccountNameError: Error, Equatable {
    case empty
    case tooLong
}

public enum LedgerAccountName {
    public static let maximumLength = 30

    public static func normalized(_ value: String) throws -> String {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw LedgerAccountNameError.empty }
        guard name.count <= maximumLength else { throw LedgerAccountNameError.tooLong }
        return name
    }
}

public struct LedgerAccountRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, name: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static let `default` = LedgerAccountRecord(
        id: LedgerAccountDefaults.id,
        name: LedgerAccountDefaults.name,
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0)
    )
}

public struct LedgerRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var accountID: UUID
    public var kind: LedgerKind
    public var amountCents: Int64
    public var projectName: String
    public var note: String?
    public var occurredAt: Date
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        accountID: UUID = LedgerAccountDefaults.id,
        kind: LedgerKind,
        amountCents: Int64,
        projectName: String,
        note: String?,
        occurredAt: Date,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.accountID = accountID
        self.kind = kind
        self.amountCents = amountCents
        self.projectName = projectName
        self.note = note
        self.occurredAt = occurredAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct MonthlyLedgerTotal: Codable, Equatable, Sendable, Identifiable {
    public let month: Date
    public let incomeCents: Int64
    public let expenseCents: Int64
    public let netCents: Int64
    public let recordCount: Int

    public var id: Date { month }
}

public struct LedgerKindTotal: Equatable, Sendable, Identifiable {
    public let kind: LedgerKind
    public let totalCents: Int64
    public let recordCount: Int

    public var id: LedgerKind { kind }

    public init(kind: LedgerKind, totalCents: Int64, recordCount: Int) {
        self.kind = kind
        self.totalCents = totalCents
        self.recordCount = recordCount
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
    case amountTooLarge
    case emptyProjectName
    case noteTooLong

    public var errorDescription: String? {
        switch self {
        case .invalidAmount: return "Amount must be greater than zero with at most two decimal places."
        case .amountTooLarge: return "Amount exceeds MiniBill's per-entry limit."
        case .emptyProjectName: return "Project name is required."
        case .noteTooLong: return "Note must be 200 characters or fewer."
        }
    }
}

public enum EntryValidator {
    /// A single entry is capped at CNY 99,999,999.99. This keeps the UI and
    /// aggregate calculations inside the product's small-business scope.
    public static let maximumAmountCents: Int64 = 9_999_999_999

    public static func amountCents(
        from input: String,
        decimalSeparator: String = Locale.current.decimalSeparator ?? "."
    ) throws -> Int64 {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = decimalSeparator.isEmpty ? "." : decimalSeparator
        if separator != ".", value.contains(separator), value.contains(".") {
            throw EntryValidationError.invalidAmount
        }
        let canonical = separator == "."
            ? value
            : value.replacingOccurrences(of: separator, with: ".")
        let pieces = canonical.split(separator: ".", omittingEmptySubsequences: false)
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
        guard cents <= maximumAmountCents else { throw EntryValidationError.amountTooLarge }
        return cents
    }

    public static func amountText(
        cents: Int64,
        decimalSeparator: String = Locale.current.decimalSeparator ?? "."
    ) -> String {
        let separator = decimalSeparator.isEmpty ? "." : decimalSeparator
        let fraction = String(format: "%02lld", cents % 100)
        return "\(cents / 100)\(separator)\(fraction)"
    }

    public static func limitedAmountText(
        _ input: String,
        decimalSeparator: String = Locale.current.decimalSeparator ?? "."
    ) -> String {
        let separator = decimalSeparator.isEmpty ? "." : decimalSeparator
        var output = ""
        var hasSeparator = false
        var fractionalDigits = 0

        for character in input {
            if character.isNumber {
                guard !hasSeparator || fractionalDigits < 2 else { continue }
                output.append(character)
                if hasSeparator { fractionalDigits += 1 }
            } else if String(character) == separator || character == "." {
                guard !hasSeparator else { continue }
                if output.isEmpty { output = "0" }
                output.append(separator)
                hasSeparator = true
            }
        }
        return output
    }

    public static func fixedAmountText(
        _ input: String,
        decimalSeparator: String = Locale.current.decimalSeparator ?? "."
    ) -> String {
        let separator = decimalSeparator.isEmpty ? "." : decimalSeparator
        let limited = limitedAmountText(input, decimalSeparator: separator)
        guard !limited.isEmpty else { return "" }

        let pieces = limited.components(separatedBy: separator)
        let rawWhole = pieces.first ?? "0"
        let trimmedWhole = rawWhole.drop(while: { $0 == "0" })
        let whole = trimmedWhole.isEmpty ? "0" : String(trimmedWhole)
        let rawFraction = pieces.count > 1 ? pieces[1] : ""
        let fraction = rawFraction + String(repeating: "0", count: 2 - rawFraction.count)
        return "\(whole)\(separator)\(fraction)"
    }

    public static func validate(amountCents: Int64, projectName: String, note: String?) throws {
        guard amountCents > 0 else { throw EntryValidationError.invalidAmount }
        guard amountCents <= maximumAmountCents else { throw EntryValidationError.amountTooLarge }
        guard !ProjectNameNormalizer.normalizedKey(projectName).isEmpty else {
            throw EntryValidationError.emptyProjectName
        }
        guard (note?.count ?? 0) <= 200 else { throw EntryValidationError.noteTooLong }
    }
}

public struct EntryDraft: Equatable, Sendable {
    public var kind: LedgerKind
    public var amountText: String
    public var projectName: String
    public var note: String
    public var occurredAt: Date

    private let id: UUID
    private let accountID: UUID
    private let createdAt: Date

    public init(
        record: LedgerRecord,
        decimalSeparator: String = Locale.current.decimalSeparator ?? "."
    ) {
        id = record.id
        accountID = record.accountID
        createdAt = record.createdAt
        kind = record.kind
        amountText = EntryValidator.amountText(cents: record.amountCents, decimalSeparator: decimalSeparator)
        projectName = record.projectName
        note = record.note ?? ""
        occurredAt = record.occurredAt
    }

    public func validatedRecord(
        updatedAt: Date = Date(),
        decimalSeparator: String = Locale.current.decimalSeparator ?? "."
    ) throws -> LedgerRecord {
        let cents = try EntryValidator.amountCents(from: amountText, decimalSeparator: decimalSeparator)
        let trimmedProject = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        try EntryValidator.validate(
            amountCents: cents,
            projectName: trimmedProject,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
        return LedgerRecord(
            id: id,
            accountID: accountID,
            kind: kind,
            amountCents: cents,
            projectName: trimmedProject,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            occurredAt: occurredAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
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

public struct YearlySharePayload: Codable, Equatable, Sendable {
    public let year: Date
    public let incomeCents: Int64
    public let expenseCents: Int64
    public let netCents: Int64
    public let recordCount: Int
    public let months: [MonthlyLedgerTotal]

    public init(months: [MonthlyLedgerTotal], year: Date) {
        self.year = year
        self.months = months
        incomeCents = Self.clampedSum(months.map(\.incomeCents))
        expenseCents = Self.clampedSum(months.map(\.expenseCents))
        netCents = incomeCents - expenseCents
        recordCount = months.reduce(0) { $0 + $1.recordCount }
    }

    private static func clampedSum(_ amounts: [Int64]) -> Int64 {
        amounts.reduce(0) { partial, amount in
            let (sum, overflow) = partial.addingReportingOverflow(amount)
            return overflow ? Int64.max : sum
        }
    }
}
