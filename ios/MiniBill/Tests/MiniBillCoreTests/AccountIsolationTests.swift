import XCTest
import SwiftData
@testable import MiniBillCore
@testable import MiniBillData

final class AccountIsolationTests: XCTestCase {
    func testAccountFilterReturnsOnlyTheSelectedAccountsRecords() {
        let firstAccount = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let secondAccount = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let instant = Date(timeIntervalSince1970: 1_700_000_000)
        let records = [
            record(accountID: firstAccount, amount: 100, date: instant),
            record(accountID: secondAccount, amount: 200, date: instant.addingTimeInterval(60)),
            record(accountID: firstAccount, amount: 300, date: instant.addingTimeInterval(120)),
        ]

        let filtered = LedgerRecordFilter.records(forAccountID: firstAccount, from: records)

        XCTAssertEqual(filtered.map(\.amountCents), [300, 100])
        XCTAssertTrue(filtered.allSatisfy { $0.accountID == firstAccount })
    }

    func testAccountNameValidationTrimsWhitespaceAndRejectsEmptyOrOverlongNames() throws {
        XCTAssertEqual(try LedgerAccountName.normalized("  Side Business  "), "Side Business")
        XCTAssertThrowsError(try LedgerAccountName.normalized("   "))
        XCTAssertThrowsError(try LedgerAccountName.normalized(String(repeating: "a", count: 31)))
    }

    @MainActor
    func testDefaultAccountMigrationMaterializesLegacyNilAccountIdentifiers() throws {
        let container = try ModelContainer(
            for: LedgerEntry.self, LedgerAccount.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let entry = LedgerEntry(
            kindRawValue: LedgerKind.income.rawValue,
            amountCents: 100,
            projectName: "Legacy",
            occurredAt: Date()
        )
        entry.accountID = nil
        context.insert(entry)
        try context.save()

        try LedgerAccountStore.ensureDefaultAccount(in: container)

        let verification = ModelContext(container)
        let accounts = try verification.fetch(FetchDescriptor<LedgerAccount>())
        let entries = try verification.fetch(FetchDescriptor<LedgerEntry>())
        XCTAssertEqual(accounts.map(\.id), [LedgerAccountDefaults.id])
        XCTAssertEqual(entries.map(\.accountID), [LedgerAccountDefaults.id])
    }

    private func record(accountID: UUID, amount: Int64, date: Date) -> LedgerRecord {
        LedgerRecord(
            id: UUID(),
            accountID: accountID,
            kind: .income,
            amountCents: amount,
            projectName: "Work",
            note: nil,
            occurredAt: date,
            createdAt: date,
            updatedAt: date
        )
    }
}
