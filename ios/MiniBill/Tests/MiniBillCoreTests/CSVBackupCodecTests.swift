import XCTest
@testable import MiniBillCore

final class CSVBackupCodecTests: XCTestCase {
    private let instant = Date(timeIntervalSince1970: 1_754_362_200)

    func testRoundTripPreservesAllAccountsAndRecordsWithQuotedUnicodeFields() throws {
        let accountID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let emptyAccountID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let archive = BackupArchive(
            exportedAt: instant,
            appVersion: "1.0.3",
            accounts: [
                LedgerAccountRecord(id: accountID, name: "小店,\"夜市\"", createdAt: instant, updatedAt: instant.addingTimeInterval(1)),
                LedgerAccountRecord(id: emptyAccountID, name: "空账本", createdAt: instant, updatedAt: instant),
            ],
            selectedAccountID: emptyAccountID,
            records: [
                LedgerRecord(id: UUID(), accountID: accountID, kind: .expense, amountCents: 1250,
                             projectName: "矿泉水,\"冰\" 🧊", note: "第一行\r\n第二行,\"三箱\"\n末行",
                             occurredAt: instant, createdAt: instant.addingTimeInterval(2), updatedAt: instant.addingTimeInterval(3)),
                LedgerRecord(id: UUID(), accountID: accountID, kind: .income, amountCents: 1,
                             projectName: "销售", note: nil, occurredAt: instant, createdAt: instant, updatedAt: instant),
                LedgerRecord(id: UUID(), accountID: accountID, kind: .income, amountCents: EntryValidator.maximumAmountCents,
                             projectName: "收入", note: "", occurredAt: instant, createdAt: instant, updatedAt: instant),
            ]
        )

        let data = try CSVBackupCodec.encode(archive)

        XCTAssertEqual(try CSVBackupCodec.decodeAndValidate(data), archive)
        let csv = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(csv.contains("\"矿泉水,\"\"冰\"\" 🧊\""))
        XCTAssertTrue(csv.contains(",12.50,"))
        XCTAssertTrue(csv.contains(",99999999.99,"))
    }

    func testEmptyArchiveRoundTrips() throws {
        let archive = BackupArchive(exportedAt: instant, appVersion: "1", records: [])
        XCTAssertEqual(try CSVBackupCodec.decodeAndValidate(CSVBackupCodec.encode(archive)), archive)
    }

    func testDecoderAcceptsBOMAndLFLineEndingsWithoutTrailingNewline() throws {
        let csv = "\u{FEFF}" + fixture
        let archive = try CSVBackupCodec.decodeAndValidate(Data(csv.utf8))

        XCTAssertEqual(archive.recordCount, 1)
        XCTAssertEqual(archive.accounts.map(\.name), ["小店"])
        XCTAssertEqual(archive.records.first?.amountCents, 1250)
        XCTAssertEqual(archive.records.first?.projectName, "茶,\"热\" 🍵")
        XCTAssertEqual(archive.records.first?.note, "第一行\n第二行")
    }

    func testDecoderRejectsMalformedCSV() {
        let malformed = [
            "not,a,backup",
            fixture + "\n\"unterminated",
            fixture.replacingOccurrences(of: "\"茶,\"\"热\"\" 🍵\"", with: "\"茶\"extra"),
            fixture.replacingOccurrences(of: "小店", with: "小\"店"),
            fixture.replacingOccurrences(of: "entry,", with: "unknown,"),
            fixture.replacingOccurrences(of: ",12.50,", with: ",12.50,extra,"),
        ]
        for csv in malformed {
            XCTAssertThrowsError(try CSVBackupCodec.decodeAndValidate(Data(csv.utf8)))
        }
        XCTAssertThrowsError(try CSVBackupCodec.decodeAndValidate(Data([0xFF, 0xFE])))
    }

    func testCSVImportUsesBackupValidationBeforeRestore() {
        let invalid: [(String, BackupValidationError)] = [
            (fixture.replacingOccurrences(of: "backup,com.minibill.backup,2,", with: "backup,com.minibill.backup,999,"), .schemaTooNew),
            (fixture.replacingOccurrences(of: ",CNY,1,", with: ",CNY,2,"), .countMismatch),
            (fixture.replacingOccurrences(of: ",CNY,", with: ",USD,"), .invalidCurrency),
            (fixture.replacingOccurrences(of: ",12.50,", with: ",0.00,"), .invalidRecord),
            (fixture.replacingOccurrences(of: ",expense,", with: ",other,"), .invalidRecord),
            (fixture.replacingOccurrences(of: "account,,,,,,,,AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", with: "account,,,,,,,,BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"), .invalidAccount),
        ]
        for (csv, expected) in invalid {
            XCTAssertThrowsError(try CSVBackupCodec.decodeAndValidate(Data(csv.utf8))) { error in
                XCTAssertEqual(error as? BackupValidationError, expected)
            }
        }
    }

    private var fixture: String {
        """
        rowType,format,schemaVersion,exportedAt,appVersion,currencyCode,recordCount,selectedAccountID,id,accountID,name,kind,amount,projectName,note,notePresent,occurredAt,createdAt,updatedAt
        backup,com.minibill.backup,2,2025-08-05T03:30:00Z,1.0.3,CNY,1,AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA,,,,,,,,,,,
        account,,,,,,,,AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA,,小店,,,,,,,2025-08-05T03:30:00Z,2025-08-05T03:30:00Z
        entry,,,,,,,,31F00AC2-8C09-4B28-8E81-D8838B334B14,AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA,,expense,12.50,"茶,""热"" 🍵","第一行
        第二行",1,2025-08-05T03:30:00Z,2025-08-05T03:30:00Z,2025-08-05T03:30:00Z
        """
    }
}
