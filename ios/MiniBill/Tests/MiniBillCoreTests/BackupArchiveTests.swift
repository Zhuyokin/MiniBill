import XCTest
@testable import MiniBillCore

final class BackupArchiveTests: XCTestCase {
    private let formatter = ISO8601DateFormatter()

    func testArchiveJSONRoundTripsEveryRecordFieldWithinISO8601Precision() throws {
        let instant = formatter.date(from: "2026-08-05T03:30:00Z")!.addingTimeInterval(0.123)
        let id = UUID(uuidString: "31F00AC2-8C09-4B28-8E81-D8838B334B14")!
        let accountID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let account = LedgerAccountRecord(id: accountID, name: "Night Market", createdAt: instant, updatedAt: instant)
        let archive = BackupArchive(exportedAt: instant, appVersion: "1.0.3", accounts: [account], selectedAccountID: accountID, records: [
            LedgerRecord(id: id, accountID: accountID, kind: .expense, amountCents: 1_250, projectName: "矿泉水 🧊", note: "两箱", occurredAt: instant, createdAt: instant.addingTimeInterval(1), updatedAt: instant.addingTimeInterval(2)),
        ])

        let data = try BackupCodec.encode(archive)
        let decoded = try BackupCodec.decodeAndValidate(data)

        XCTAssertEqual(decoded.format, archive.format)
        XCTAssertEqual(decoded.schemaVersion, archive.schemaVersion)
        XCTAssertEqual(decoded.appVersion, archive.appVersion)
        XCTAssertEqual(decoded.currencyCode, archive.currencyCode)
        XCTAssertEqual(decoded.recordCount, archive.recordCount)
        let decodedAccount = try XCTUnwrap(decoded.accounts.first)
        XCTAssertEqual(decodedAccount.id, account.id)
        XCTAssertEqual(decodedAccount.name, account.name)
        XCTAssertEqual(decodedAccount.createdAt.timeIntervalSince1970, account.createdAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decodedAccount.updatedAt.timeIntervalSince1970, account.updatedAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decoded.selectedAccountID, accountID)
        XCTAssertEqual(decoded.exportedAt.timeIntervalSince1970, archive.exportedAt.timeIntervalSince1970, accuracy: 0.001)

        let decodedRecord = try XCTUnwrap(decoded.records.first)
        let originalRecord = try XCTUnwrap(archive.records.first)
        XCTAssertEqual(decodedRecord.id, originalRecord.id)
        XCTAssertEqual(decodedRecord.accountID, accountID)
        XCTAssertEqual(decodedRecord.kind, originalRecord.kind)
        XCTAssertEqual(decodedRecord.amountCents, originalRecord.amountCents)
        XCTAssertEqual(decodedRecord.projectName, originalRecord.projectName)
        XCTAssertEqual(decodedRecord.note, originalRecord.note)
        XCTAssertEqual(decodedRecord.occurredAt.timeIntervalSince1970, originalRecord.occurredAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decodedRecord.createdAt.timeIntervalSince1970, originalRecord.createdAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decodedRecord.updatedAt.timeIntervalSince1970, originalRecord.updatedAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"amount\" : \"12.50\""))
    }

    func testLegacyVersionOneBackupMigratesEveryRecordToTheDefaultAccount() throws {
        let json = """
        {"format":"com.minibill.backup","schemaVersion":1,"exportedAt":"2026-08-05T03:30:00Z","appVersion":"1.0.1","currencyCode":"CNY","recordCount":1,"records":[{"id":"31F00AC2-8C09-4B28-8E81-D8838B334B14","kind":"income","amount":"12.50","projectName":"Legacy","occurredAt":"2026-08-05T03:30:00Z","createdAt":"2026-08-05T03:30:00Z","updatedAt":"2026-08-05T03:30:00Z"}]}
        """

        let archive = try BackupCodec.decodeAndValidate(Data(json.utf8))

        XCTAssertEqual(archive.schemaVersion, 1)
        XCTAssertEqual(archive.accounts, [.default])
        XCTAssertEqual(archive.selectedAccountID, LedgerAccountDefaults.id)
        XCTAssertEqual(archive.records.map(\.accountID), [LedgerAccountDefaults.id])
    }

    func testValidatorRejectsRecordsWhoseAccountIsMissing() {
        let instant = formatter.date(from: "2026-08-05T03:30:00Z")!
        let missingAccountID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let record = LedgerRecord(id: UUID(), accountID: missingAccountID, kind: .income, amountCents: 100, projectName: "Work", note: nil, occurredAt: instant, createdAt: instant, updatedAt: instant)

        XCTAssertThrowsError(try BackupValidator.validate(
            BackupArchive(exportedAt: instant, appVersion: "1.0.3", accounts: [.default], records: [record])
        ))
    }

    func testValidatorRejectsUnsupportedOrInternallyInconsistentArchives() {
        let instant = formatter.date(from: "2026-08-05T03:30:00Z")!
        let record = LedgerRecord(id: UUID(), kind: .income, amountCents: 100, projectName: "Work", note: nil, occurredAt: instant, createdAt: instant, updatedAt: instant)

        XCTAssertThrowsError(try BackupValidator.validate(BackupArchive(format: "wrong", exportedAt: instant, appVersion: "1", records: [record])))
        XCTAssertThrowsError(try BackupValidator.validate(BackupArchive(schemaVersion: BackupArchive.currentSchemaVersion + 1, exportedAt: instant, appVersion: "1", records: [record])))
        XCTAssertThrowsError(try BackupValidator.validate(BackupArchive(exportedAt: instant, appVersion: "1", recordCount: 2, records: [record])))
        XCTAssertThrowsError(try BackupValidator.validate(BackupArchive(exportedAt: instant, appVersion: "1", records: [record, record])))
        XCTAssertThrowsError(try BackupValidator.validate(BackupArchive(exportedAt: instant, appVersion: "1", records: [LedgerRecord(id: UUID(), kind: .income, amountCents: 0, projectName: "Work", note: nil, occurredAt: instant, createdAt: instant, updatedAt: instant)])))
        XCTAssertThrowsError(try BackupValidator.validate(BackupArchive(exportedAt: instant, appVersion: "1", records: [LedgerRecord(id: UUID(), kind: .income, amountCents: 100, projectName: "  ", note: nil, occurredAt: instant, createdAt: instant, updatedAt: instant)])))
    }

    func testDecoderRejectsMalformedJSONAndUnknownKind() {
        XCTAssertThrowsError(try BackupCodec.decodeAndValidate(Data("not-json".utf8)))
        let json = """
        {"format":"com.minibill.backup","schemaVersion":1,"exportedAt":"2026-08-05T03:30:00Z","appVersion":"1","currencyCode":"CNY","recordCount":1,"records":[{"id":"31F00AC2-8C09-4B28-8E81-D8838B334B14","kind":"other","amount":"1.00","projectName":"Work","occurredAt":"2026-08-05T03:30:00Z","createdAt":"2026-08-05T03:30:00Z","updatedAt":"2026-08-05T03:30:00Z"}]}
        """
        XCTAssertThrowsError(try BackupCodec.decodeAndValidate(Data(json.utf8)))
    }

    func testBackupAmountsUseASCIIDecimalPointAndEnforceEntryLimit() throws {
        let instant = formatter.date(from: "2026-08-05T03:30:00Z")!
        let maximum = LedgerRecord(
            id: UUID(),
            kind: .income,
            amountCents: EntryValidator.maximumAmountCents,
            projectName: "Maximum",
            note: nil,
            occurredAt: instant,
            createdAt: instant,
            updatedAt: instant
        )
        let data = try BackupCodec.encode(
            BackupArchive(exportedAt: instant, appVersion: "1", records: [maximum])
        )
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"amount\" : \"99999999.99\""))

        let commaDecimal = json.replacingOccurrences(of: "99999999.99", with: "99999999,99")
        XCTAssertThrowsError(try BackupCodec.decodeAndValidate(Data(commaDecimal.utf8)))

        var tooLarge = maximum
        tooLarge.amountCents += 1
        XCTAssertThrowsError(try BackupCodec.encode(
            BackupArchive(exportedAt: instant, appVersion: "1", records: [tooLarge])
        ))
    }
}
