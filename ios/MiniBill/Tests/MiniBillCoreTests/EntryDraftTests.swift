import XCTest
@testable import MiniBillCore

final class EntryDraftTests: XCTestCase {
    func testDraftChangesDoNotMutateOriginalAndCommitPreservesIdentity() throws {
        let original = LedgerRecord(
            id: UUID(uuidString: "31F00AC2-8C09-4B28-8E81-D8838B334B14")!,
            kind: .income,
            amountCents: 1_250,
            projectName: "Old",
            note: "private",
            occurredAt: Date(timeIntervalSince1970: 100),
            createdAt: Date(timeIntervalSince1970: 50),
            updatedAt: Date(timeIntervalSince1970: 75)
        )
        var draft = EntryDraft(record: original, decimalSeparator: ".")

        draft.kind = .expense
        draft.amountText = "20.05"
        draft.projectName = "  New project  "
        draft.note = "  changed  "
        draft.occurredAt = Date(timeIntervalSince1970: 200)

        XCTAssertEqual(original.projectName, "Old")
        XCTAssertEqual(original.amountCents, 1_250)

        let committed = try draft.validatedRecord(
            updatedAt: Date(timeIntervalSince1970: 300),
            decimalSeparator: "."
        )
        XCTAssertEqual(committed.id, original.id)
        XCTAssertEqual(committed.createdAt, original.createdAt)
        XCTAssertEqual(committed.updatedAt, Date(timeIntervalSince1970: 300))
        XCTAssertEqual(committed.kind, .expense)
        XCTAssertEqual(committed.amountCents, 2_005)
        XCTAssertEqual(committed.projectName, "New project")
        XCTAssertEqual(committed.note, "changed")
        XCTAssertEqual(committed.occurredAt, Date(timeIntervalSince1970: 200))
    }

    func testAmountParserSupportsLocaleDecimalSeparatorWhileBackupDotRemainsValid() throws {
        XCTAssertEqual(try EntryValidator.amountCents(from: "12,50", decimalSeparator: ","), 1_250)
        XCTAssertEqual(try EntryValidator.amountCents(from: "12.50", decimalSeparator: ","), 1_250)
        XCTAssertEqual(try EntryValidator.amountCents(from: "12.50", decimalSeparator: "."), 1_250)
        XCTAssertThrowsError(try EntryValidator.amountCents(from: "12,50.1", decimalSeparator: ","))
        XCTAssertEqual(EntryValidator.amountText(cents: 1_205, decimalSeparator: ","), "12,05")
    }
}
