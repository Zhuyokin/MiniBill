import XCTest
@testable import MiniBillCore

final class BackupArchiveTests: XCTestCase {
    private let formatter = ISO8601DateFormatter()

    func testArchiveJSONRoundTripsEveryRecordFieldExactly() throws {
        let instant = formatter.date(from: "2026-08-05T03:30:00Z")!.addingTimeInterval(0.123)
        let id = UUID(uuidString: "31F00AC2-8C09-4B28-8E81-D8838B334B14")!
        let archive = BackupArchive(exportedAt: instant, appVersion: "1.0.0", records: [
            LedgerRecord(id: id, kind: .expense, amountCents: 1_250, projectName: "矿泉水 🧊", note: "两箱", occurredAt: instant, createdAt: instant.addingTimeInterval(1), updatedAt: instant.addingTimeInterval(2)),
        ])

        let data = try BackupCodec.encode(archive)
        let decoded = try BackupCodec.decodeAndValidate(data)

        XCTAssertEqual(decoded, archive)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"amount\" : \"12.50\""))
    }

    func testValidatorRejectsUnsupportedOrInternallyInconsistentArchives() {
        let instant = formatter.date(from: "2026-08-05T03:30:00Z")!
        let record = LedgerRecord(id: UUID(), kind: .income, amountCents: 100, projectName: "Work", note: nil, occurredAt: instant, createdAt: instant, updatedAt: instant)

        XCTAssertThrowsError(try BackupValidator.validate(BackupArchive(format: "wrong", exportedAt: instant, appVersion: "1", records: [record])))
        XCTAssertThrowsError(try BackupValidator.validate(BackupArchive(schemaVersion: 2, exportedAt: instant, appVersion: "1", records: [record])))
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
}
