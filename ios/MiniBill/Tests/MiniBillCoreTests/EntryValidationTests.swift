import XCTest
@testable import MiniBillCore

final class EntryValidationTests: XCTestCase {
    func testAmountParserAcceptsAtMostTwoDecimalPlacesWithoutFloatingPoint() throws {
        XCTAssertEqual(try EntryValidator.amountCents(from: "12"), 1_200)
        XCTAssertEqual(try EntryValidator.amountCents(from: "12.5"), 1_250)
        XCTAssertEqual(try EntryValidator.amountCents(from: "12.05"), 1_205)
        XCTAssertThrowsError(try EntryValidator.amountCents(from: "0"))
        XCTAssertThrowsError(try EntryValidator.amountCents(from: "1.234"))
        XCTAssertThrowsError(try EntryValidator.amountCents(from: "abc"))
    }

    func testValidationRequiresPositiveCentsAndNonemptyNormalizedProject() {
        XCTAssertNoThrow(try EntryValidator.validate(amountCents: 1, projectName: " 🧋 ", note: String(repeating: "a", count: 200)))
        XCTAssertThrowsError(try EntryValidator.validate(amountCents: 0, projectName: "Valid", note: nil))
        XCTAssertThrowsError(try EntryValidator.validate(amountCents: 1, projectName: " \n\t ", note: nil))
        XCTAssertThrowsError(try EntryValidator.validate(amountCents: 1, projectName: "Valid", note: String(repeating: "a", count: 201)))
    }
}
