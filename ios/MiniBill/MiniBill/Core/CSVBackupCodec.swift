import Foundation

public enum CSVBackupCodec {
    private enum Column: String, CaseIterable {
        case rowType, format, schemaVersion, exportedAt, appVersion, currencyCode, recordCount, selectedAccountID
        case id, accountID, name, kind, amount, projectName, note, notePresent, occurredAt, createdAt, updatedAt
    }

    public static func encode(_ archive: BackupArchive) throws -> Data {
        try BackupValidator.validate(archive)
        var rows = [Column.allCases.map(\.rawValue)]
        rows.append(row([
            .rowType: "backup", .format: archive.format, .schemaVersion: String(archive.schemaVersion),
            .exportedAt: BackupCodec.iso8601String(from: archive.exportedAt), .appVersion: archive.appVersion,
            .currencyCode: archive.currencyCode, .recordCount: String(archive.recordCount),
            .selectedAccountID: archive.selectedAccountID.uuidString,
        ]))
        for account in archive.accounts {
            rows.append(row([
                .rowType: "account", .id: account.id.uuidString, .name: account.name,
                .createdAt: BackupCodec.iso8601String(from: account.createdAt),
                .updatedAt: BackupCodec.iso8601String(from: account.updatedAt),
            ]))
        }
        for record in archive.records {
            rows.append(row([
                .rowType: "entry", .id: record.id.uuidString, .accountID: record.accountID.uuidString,
                .kind: record.kind.rawValue, .amount: BackupCodec.amountString(cents: record.amountCents),
                .projectName: record.projectName, .note: record.note ?? "", .notePresent: record.note == nil ? "0" : "1",
                .occurredAt: BackupCodec.iso8601String(from: record.occurredAt),
                .createdAt: BackupCodec.iso8601String(from: record.createdAt),
                .updatedAt: BackupCodec.iso8601String(from: record.updatedAt),
            ]))
        }
        let csv = rows.map { $0.map(escaped).joined(separator: ",") }.joined(separator: "\r\n")
        return Data(("\u{FEFF}" + csv + "\r\n").utf8)
    }

    public static func decodeAndValidate(_ data: Data) throws -> BackupArchive {
        guard var text = String(data: data, encoding: .utf8) else { throw BackupValidationError.malformedData }
        if text.first == "\u{FEFF}" { text.removeFirst() }
        let rows = try parse(text)
        guard rows.first == Column.allCases.map(\.rawValue) else { throw BackupValidationError.invalidFormat }

        var metadata: [Column: String]?
        var accounts: [LedgerAccountRecord] = []
        var records: [LedgerRecord] = []
        for values in rows.dropFirst() {
            guard values.count == Column.allCases.count else { throw BackupValidationError.malformedData }
            let fields = Dictionary(uniqueKeysWithValues: zip(Column.allCases, values))
            func value(_ column: Column) -> String { fields[column]! }
            func date(_ column: Column) throws -> Date {
                guard let date = BackupCodec.date(fromISO8601: value(column)) else { throw BackupValidationError.malformedData }
                return date
            }

            switch value(.rowType) {
            case "backup":
                guard metadata == nil else { throw BackupValidationError.malformedData }
                metadata = fields
            case "account":
                guard let id = UUID(uuidString: value(.id)) else { throw BackupValidationError.invalidAccount }
                accounts.append(LedgerAccountRecord(
                    id: id, name: value(.name), createdAt: try date(.createdAt), updatedAt: try date(.updatedAt)
                ))
            case "entry":
                guard let id = UUID(uuidString: value(.id)),
                      let accountID = UUID(uuidString: value(.accountID)),
                      let kind = LedgerKind(rawValue: value(.kind)),
                      let amount = BackupCodec.cents(amount: value(.amount)),
                      ["0", "1"].contains(value(.notePresent)),
                      value(.notePresent) == "1" || value(.note).isEmpty else {
                    throw BackupValidationError.invalidRecord
                }
                records.append(LedgerRecord(
                    id: id, accountID: accountID, kind: kind, amountCents: amount,
                    projectName: value(.projectName), note: value(.notePresent) == "1" ? value(.note) : nil,
                    occurredAt: try date(.occurredAt), createdAt: try date(.createdAt), updatedAt: try date(.updatedAt)
                ))
            default:
                throw BackupValidationError.malformedData
            }
        }

        guard let metadata,
              let schemaVersion = Int(metadata[.schemaVersion]!),
              let exportedAt = BackupCodec.date(fromISO8601: metadata[.exportedAt]!),
              let recordCount = Int(metadata[.recordCount]!),
              let selectedAccountID = UUID(uuidString: metadata[.selectedAccountID]!) else {
            throw BackupValidationError.malformedData
        }
        let archive = BackupArchive(
            format: metadata[.format]!, schemaVersion: schemaVersion, exportedAt: exportedAt,
            appVersion: metadata[.appVersion]!, currencyCode: metadata[.currencyCode]!, recordCount: recordCount,
            accounts: accounts, selectedAccountID: selectedAccountID, records: records
        )
        try BackupValidator.validate(archive)
        return archive
    }

    private static func row(_ fields: [Column: String]) -> [String] {
        Column.allCases.map { fields[$0] ?? "" }
    }

    private static func escaped(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func parse(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var fields: [String] = []
        var field = ""
        var quoted = false
        var closedQuote = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)
            if quoted {
                if character == "\"" {
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        index = text.index(after: next)
                        continue
                    }
                    quoted = false
                    closedQuote = true
                } else {
                    field.append(character)
                }
            } else if character == "," {
                fields.append(field)
                field = ""
                closedQuote = false
            } else if character == "\n" || character == "\r" || character == "\r\n" {
                fields.append(field)
                rows.append(fields)
                fields = []
                field = ""
                closedQuote = false
            } else if character == "\"", field.isEmpty, !closedQuote {
                quoted = true
            } else {
                guard !closedQuote, character != "\"" else { throw BackupValidationError.malformedData }
                field.append(character)
            }
            index = next
        }
        guard !quoted else { throw BackupValidationError.malformedData }
        if !fields.isEmpty || !field.isEmpty || closedQuote {
            fields.append(field)
            rows.append(fields)
        }
        return rows
    }
}
