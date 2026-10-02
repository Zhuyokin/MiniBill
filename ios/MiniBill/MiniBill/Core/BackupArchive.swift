import Foundation

public enum BackupValidationError: Error, Equatable, LocalizedError {
    case invalidFormat
    case schemaTooNew
    case invalidCurrency
    case countMismatch
    case duplicateIdentifier
    case invalidAccount
    case invalidRecord
    case malformedData

    public var errorDescription: String? {
        switch self {
        case .invalidFormat: return "This is not a MiniBill backup."
        case .schemaTooNew: return "This backup requires a newer version of MiniBill."
        case .invalidCurrency: return "This backup uses an unsupported currency."
        case .countMismatch: return "The backup record count is inconsistent."
        case .duplicateIdentifier: return "The backup contains duplicate record identifiers."
        case .invalidAccount: return "The backup contains invalid account data."
        case .invalidRecord: return "The backup contains an invalid record."
        case .malformedData: return "The backup file is damaged or unreadable."
        }
    }
}

public struct BackupArchive: Equatable, Sendable {
    public static let currentSchemaVersion = 2
    public static let expectedFormat = "com.minibill.backup"

    public var format: String
    public var schemaVersion: Int
    public var exportedAt: Date
    public var appVersion: String
    public var currencyCode: String
    public var recordCount: Int
    public var accounts: [LedgerAccountRecord]
    public var selectedAccountID: UUID
    public var records: [LedgerRecord]

    public init(
        format: String = BackupArchive.expectedFormat,
        schemaVersion: Int = BackupArchive.currentSchemaVersion,
        exportedAt: Date,
        appVersion: String,
        currencyCode: String = "CNY",
        recordCount: Int? = nil,
        accounts: [LedgerAccountRecord] = [.default],
        selectedAccountID: UUID = LedgerAccountDefaults.id,
        records: [LedgerRecord]
    ) {
        self.format = format
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.currencyCode = currencyCode
        self.recordCount = recordCount ?? records.count
        self.accounts = accounts
        self.selectedAccountID = selectedAccountID
        self.records = records
    }
}

public enum BackupValidator {
    public static func validate(_ archive: BackupArchive) throws {
        guard archive.format == BackupArchive.expectedFormat else { throw BackupValidationError.invalidFormat }
        guard archive.schemaVersion <= BackupArchive.currentSchemaVersion else { throw BackupValidationError.schemaTooNew }
        guard archive.schemaVersion > 0 else { throw BackupValidationError.invalidFormat }
        guard archive.currencyCode == "CNY" else { throw BackupValidationError.invalidCurrency }
        guard archive.recordCount == archive.records.count else { throw BackupValidationError.countMismatch }

        var accountIdentifiers = Set<UUID>()
        for account in archive.accounts {
            guard accountIdentifiers.insert(account.id).inserted,
                  (try? LedgerAccountName.normalized(account.name)) == account.name else {
                throw BackupValidationError.invalidAccount
            }
        }
        guard !accountIdentifiers.isEmpty,
              accountIdentifiers.contains(archive.selectedAccountID) else {
            throw BackupValidationError.invalidAccount
        }

        var identifiers = Set<UUID>()
        for record in archive.records {
            guard identifiers.insert(record.id).inserted else { throw BackupValidationError.duplicateIdentifier }
            guard accountIdentifiers.contains(record.accountID) else { throw BackupValidationError.invalidAccount }
            do {
                try EntryValidator.validate(amountCents: record.amountCents, projectName: record.projectName, note: record.note)
            } catch {
                throw BackupValidationError.invalidRecord
            }
        }
    }
}

private struct BackupEnvelope: Codable {
    var format: String
    var schemaVersion: Int
    var exportedAt: Date
    var appVersion: String
    var currencyCode: String
    var recordCount: Int
    var accounts: [BackupAccount]?
    var selectedAccountID: UUID?
    var records: [BackupRecord]
}

private struct BackupAccount: Codable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    init(_ account: LedgerAccountRecord) {
        id = account.id
        name = account.name
        createdAt = account.createdAt
        updatedAt = account.updatedAt
    }

    func ledgerAccount() -> LedgerAccountRecord {
        LedgerAccountRecord(id: id, name: name, createdAt: createdAt, updatedAt: updatedAt)
    }
}

private struct BackupRecord: Codable {
    var id: UUID
    var accountID: UUID?
    var kind: LedgerKind
    var amount: String
    var projectName: String
    var note: String?
    var occurredAt: Date
    var createdAt: Date
    var updatedAt: Date

    init(_ record: LedgerRecord) {
        id = record.id
        accountID = record.accountID
        kind = record.kind
        amount = BackupCodec.amountString(cents: record.amountCents)
        projectName = record.projectName
        note = record.note
        occurredAt = record.occurredAt
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    func ledgerRecord(defaultAccountID: UUID) throws -> LedgerRecord {
        guard let cents = BackupCodec.cents(amount: amount) else { throw BackupValidationError.invalidRecord }
        return LedgerRecord(id: id, accountID: accountID ?? defaultAccountID, kind: kind, amountCents: cents, projectName: projectName, note: note, occurredAt: occurredAt, createdAt: createdAt, updatedAt: updatedAt)
    }
}

public enum BackupCodec {
    public static func encode(_ archive: BackupArchive) throws -> Data {
        try BackupValidator.validate(archive)
        let envelope = BackupEnvelope(
            format: archive.format,
            schemaVersion: archive.schemaVersion,
            exportedAt: archive.exportedAt,
            appVersion: archive.appVersion,
            currencyCode: archive.currencyCode,
            recordCount: archive.recordCount,
            accounts: archive.accounts.map(BackupAccount.init),
            selectedAccountID: archive.selectedAccountID,
            records: archive.records.map(BackupRecord.init)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601String(from: date))
        }
        return try encoder.encode(envelope)
    }

    public static func decodeAndValidate(_ data: Data) throws -> BackupArchive {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let string = try container.decode(String.self)
                guard let date = date(fromISO8601: string) else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
                }
                return date
            }
            let envelope = try decoder.decode(BackupEnvelope.self, from: data)
            if envelope.schemaVersion >= 2 {
                guard envelope.accounts != nil,
                      envelope.selectedAccountID != nil,
                      envelope.records.allSatisfy({ $0.accountID != nil }) else {
                    throw BackupValidationError.malformedData
                }
            }
            let accounts = envelope.accounts?.map { $0.ledgerAccount() } ?? [.default]
            let selectedAccountID = envelope.selectedAccountID ?? LedgerAccountDefaults.id
            let archive = BackupArchive(
                format: envelope.format,
                schemaVersion: envelope.schemaVersion,
                exportedAt: envelope.exportedAt,
                appVersion: envelope.appVersion,
                currencyCode: envelope.currencyCode,
                recordCount: envelope.recordCount,
                accounts: accounts,
                selectedAccountID: selectedAccountID,
                records: try envelope.records.map { try $0.ledgerRecord(defaultAccountID: LedgerAccountDefaults.id) }
            )
            try BackupValidator.validate(archive)
            return archive
        } catch let error as BackupValidationError {
            throw error
        } catch {
            throw BackupValidationError.malformedData
        }
    }

    static func amountString(cents: Int64) -> String {
        String(format: "%lld.%02lld", cents / 100, cents % 100)
    }

    static func cents(amount: String) -> Int64? {
        try? EntryValidator.amountCents(from: amount, decimalSeparator: ".")
    }

    static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    static func date(fromISO8601 value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }
}
