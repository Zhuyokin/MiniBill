import XCTest
@testable import MiniBillCore

final class ProjectNameTests: XCTestCase {
    func testNormalizationTrimsCollapsesWhitespaceAndFoldsLatinCase() {
        XCTAssertEqual(ProjectNameNormalizer.normalizedKey("  ICE\t\n Cream  "), "ice cream")
        XCTAssertEqual(ProjectNameNormalizer.normalizedKey(" 矿泉水  A "), "矿泉水 a")
    }

    func testNormalizationDoesNotFuzzilyMergeDistinctNames() {
        XCTAssertNotEqual(ProjectNameNormalizer.normalizedKey("ice-cream"), ProjectNameNormalizer.normalizedKey("ice cream"))
        XCTAssertNotEqual(ProjectNameNormalizer.normalizedKey("摊位费"), ProjectNameNormalizer.normalizedKey("场地费"))
    }

    func testRecentCandidatesDeduplicateByKeyUseNewestDisplayAndLimitSix() {
        let base = ISO8601DateFormatter().date(from: "2026-08-05T00:00:00Z")!
        let names = ["One", "Two", "Three", "Four", "Five", "Six", "Seven"]
        var records = names.enumerated().map { index, name in
            LedgerRecord(id: UUID(), kind: .income, amountCents: 100, projectName: name, note: nil, occurredAt: base.addingTimeInterval(Double(index)), createdAt: base, updatedAt: base)
        }
        records.append(LedgerRecord(id: UUID(), kind: .expense, amountCents: 200, projectName: "  one ", note: nil, occurredAt: base.addingTimeInterval(20), createdAt: base, updatedAt: base))

        XCTAssertEqual(ProjectSuggestionService.candidates(from: records), ["one", "Seven", "Six", "Five", "Four", "Three"])
    }

    func testRecentCandidatesUseOccurrenceTimeRatherThanEditTimestamp() {
        let base = ISO8601DateFormatter().date(from: "2026-08-05T00:00:00Z")!
        let olderButEdited = LedgerRecord(id: UUID(), kind: .income, amountCents: 100, projectName: "Older", note: nil, occurredAt: base, createdAt: base, updatedAt: base.addingTimeInterval(1_000))
        let recentlyUsed = LedgerRecord(id: UUID(), kind: .income, amountCents: 100, projectName: "Recent", note: nil, occurredAt: base.addingTimeInterval(10), createdAt: base, updatedAt: base.addingTimeInterval(10))

        XCTAssertEqual(ProjectSuggestionService.candidates(from: [olderButEdited, recentlyUsed]), ["Recent", "Older"])
    }
}
