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

    func testAmountIsCappedAtSmallBusinessMaximum() throws {
        XCTAssertEqual(EntryValidator.maximumAmountCents, 9_999_999_999)
        XCTAssertEqual(try EntryValidator.amountCents(from: "99999999.99", decimalSeparator: "."), 9_999_999_999)
        XCTAssertThrowsError(try EntryValidator.amountCents(from: "100000000.00", decimalSeparator: ".")) { error in
            XCTAssertEqual(error as? EntryValidationError, .amountTooLarge)
        }
        XCTAssertThrowsError(try EntryValidator.validate(
            amountCents: EntryValidator.maximumAmountCents + 1,
            projectName: "Too large",
            note: nil
        )) { error in
            XCTAssertEqual(error as? EntryValidationError, .amountTooLarge)
        }
    }
}
