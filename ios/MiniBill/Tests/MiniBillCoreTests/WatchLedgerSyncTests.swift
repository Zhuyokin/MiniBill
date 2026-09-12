import XCTest
@testable import MiniBillCore

final class WatchLedgerSyncTests: XCTestCase {
    private let ledgerID = UUID()
    private let date = Date(timeIntervalSince1970: 1_750_000_000)

    private func record() -> LedgerRecord {
        LedgerRecord(id: UUID(), kind: .income, amountCents: 2500, projectName: "Sale", note: nil,
                     occurredAt: date, createdAt: date, updatedAt: date)
    }

    func testOfflineEditsRemainVisibleUntilTheirReceiptArrives() throws {
        let original = record()
        var edited = original
        edited.amountCents = 3900
        edited.updatedAt = date.addingTimeInterval(10)
        var state = WatchLedgerState()
        state.receive(WatchLedgerSnapshot(ledgerID: ledgerID, revision: 1, languageCode: "en",
                                         accounts: [.default], records: [original]))
        let mutation = WatchLedgerMutation(ledgerID: ledgerID, kind: .saveEntry, record: edited, baseRecord: original)
        try state.enqueue(mutation)
        state.receive(WatchLedgerSnapshot(ledgerID: ledgerID, revision: 2, languageCode: "en",
                                         accounts: [.default], records: [original]))
        XCTAssertEqual(state.records, [edited])
        XCTAssertEqual(state.pending.count, 1)
        state.receive(WatchLedgerSnapshot(ledgerID: ledgerID, revision: 3, languageCode: "en",
                                         accounts: [.default], records: [edited],
                                         receipts: [.init(id: mutation.id)]))
        XCTAssertTrue(state.pending.isEmpty)
        XCTAssertEqual(state.records, [edited])
    }

    func testConcurrentEditIsRejectedAndDraftIsPreservedAcrossEncoding() throws {
        let original = record()
        var phoneEdit = original
        phoneEdit.note = "Phone"
        var watchEdit = original
        watchEdit.amountCents = 4800
        let mutation = WatchLedgerMutation(ledgerID: ledgerID, kind: .saveEntry, record: watchEdit, baseRecord: original)
        var records = [phoneEdit]
        var accounts = [LedgerAccountRecord.default]
        XCTAssertEqual(WatchLedgerReducer.apply(mutation, records: &records, accounts: &accounts), .conflict)
        XCTAssertEqual(records, [phoneEdit])
        var state = WatchLedgerState()
        state.receive(WatchLedgerSnapshot(ledgerID: ledgerID, revision: 1, languageCode: "en", accounts: accounts, records: [original]))
        try state.enqueue(mutation)
        state.receive(WatchLedgerSnapshot(ledgerID: ledgerID, revision: 2, languageCode: "en", accounts: accounts,
                                         records: records, receipts: [.init(id: mutation.id, rejection: .conflict)]))
        let restored = try JSONDecoder().decode(WatchLedgerState.self, from: JSONEncoder().encode(state))
        XCTAssertTrue(restored.pending.isEmpty)
        XCTAssertEqual(restored.failedChanges.first?.mutation.record, watchEdit)
        XCTAssertEqual(restored.records, [phoneEdit])
    }

    func testOldSnapshotsCannotResurrectDeletedRecords() throws {
        let entry = record()
        var state = WatchLedgerState()
        state.receive(WatchLedgerSnapshot(ledgerID: ledgerID, revision: 3, languageCode: "en", accounts: [.default], records: []))
        state.receive(WatchLedgerSnapshot(ledgerID: ledgerID, revision: 2, languageCode: "en", accounts: [.default], records: [entry]))
        XCTAssertTrue(state.records.isEmpty)
        var records: [LedgerRecord] = []
        var accounts = [LedgerAccountRecord.default]
        let edit = WatchLedgerMutation(ledgerID: ledgerID, kind: .saveEntry, record: entry, baseRecord: entry)
        XCTAssertEqual(WatchLedgerReducer.apply(edit, records: &records, accounts: &accounts), .conflict)
        XCTAssertTrue(records.isEmpty)
    }

    func testAccountDeletionProtectsUnseenEntriesAndTheLastAccount() {
        let entry = record()
        var records = [entry]
        var accounts = [LedgerAccountRecord.default]
        let deletion = WatchLedgerMutation(ledgerID: ledgerID, kind: .deleteAccount, account: .default,
                                           baseAccount: .default, accountEntries: [])
        XCTAssertEqual(WatchLedgerReducer.apply(deletion, records: &records, accounts: &accounts), .lastAccount)
        accounts.append(.init(id: UUID(), name: "Other", createdAt: date, updatedAt: date))
        XCTAssertEqual(WatchLedgerReducer.apply(deletion, records: &records, accounts: &accounts), .conflict)
        XCTAssertEqual(records, [entry])
        let confirmed = WatchLedgerMutation(ledgerID: ledgerID, kind: .deleteAccount, account: .default,
                                            baseAccount: .default, accountEntries: records)
        XCTAssertNil(WatchLedgerReducer.apply(confirmed, records: &records, accounts: &accounts))
        XCTAssertTrue(records.isEmpty)
        XCTAssertEqual(accounts.count, 1)
    }

    func testMissingAccountAndInvalidAmountsCannotBeQueued() {
        var entry = record()
        entry.accountID = UUID()
        var records: [LedgerRecord] = []
        var accounts = [LedgerAccountRecord.default]
        XCTAssertEqual(WatchLedgerReducer.apply(.init(ledgerID: ledgerID, kind: .saveEntry, record: entry),
                                                records: &records, accounts: &accounts), .accountMissing)
        entry.accountID = LedgerAccountDefaults.id
        entry.amountCents = 0
        XCTAssertEqual(WatchLedgerReducer.apply(.init(ledgerID: ledgerID, kind: .saveEntry, record: entry),
                                                records: &records, accounts: &accounts), .invalidData)
        XCTAssertTrue(records.isEmpty)
    }

    func testPhoneIdentityChangePreservesPendingDraftAsFailure() throws {
        var state = WatchLedgerState()
        state.receive(WatchLedgerSnapshot(ledgerID: ledgerID, revision: 20, languageCode: "en", accounts: [.default], records: []))
        let draft = record()
        try state.enqueue(.init(ledgerID: ledgerID, kind: .saveEntry, record: draft))
        let newLedgerID = UUID()
        state.receive(WatchLedgerSnapshot(ledgerID: newLedgerID, revision: 1, languageCode: "en", accounts: [.default], records: []))
        XCTAssertTrue(state.pending.isEmpty)
        XCTAssertEqual(state.failedChanges.first?.mutation.record, draft)
        XCTAssertTrue(state.records.isEmpty)
        let newDraft = record()
        try state.enqueue(.init(ledgerID: newLedgerID, kind: .saveEntry, record: newDraft))
        var restored = try JSONDecoder().decode(WatchLedgerState.self, from: JSONEncoder().encode(state))
        restored.receive(WatchLedgerSnapshot(ledgerID: ledgerID, revision: 99, languageCode: "en", accounts: [.default], records: [draft]))
        XCTAssertEqual(restored.snapshot?.ledgerID, newLedgerID)
        XCTAssertEqual(restored.pending.count, 1)
        XCTAssertEqual(restored.records, [newDraft], "A delayed transfer from the previous phone must not replace the new ledger.")
    }
}
