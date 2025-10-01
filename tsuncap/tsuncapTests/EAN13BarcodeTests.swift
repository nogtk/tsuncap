import XCTest
@testable import tsuncap

final class EAN13BarcodeTests: XCTestCase {
    func testNormalizeRemovesSeparators() throws {
        let normalized = try EAN13Barcode.normalize("978-4-87311-758-4")
        XCTAssertEqual(normalized, "9784873117584")
    }

    func testValidateRejectsInvalidCharacters() {
        XCTAssertThrowsError(try EAN13Barcode.validate("9784873A17584")) { error in
            XCTAssertEqual(error as? EAN13ValidationError, .invalidCharacters)
        }
    }

    func testValidateRejectsInvalidLength() {
        XCTAssertThrowsError(try EAN13Barcode.validate("978487311758")) { error in
            XCTAssertEqual(error as? EAN13ValidationError, .invalidLength(expected: 13, actual: 12))
        }
    }

    func testValidateRejectsInvalidPrefix() {
        XCTAssertThrowsError(try EAN13Barcode.validate("9774873117584")) { error in
            XCTAssertEqual(error as? EAN13ValidationError, .invalidPrefix)
        }
    }

    func testValidateRejectsInvalidCheckDigit() {
        XCTAssertThrowsError(try EAN13Barcode.validate("9784873117585")) { error in
            XCTAssertEqual(error as? EAN13ValidationError, .invalidCheckDigit(expected: 4, actual: 5))
        }
    }

    func testComputeCheckDigit() {
        let digits = [9, 7, 8, 4, 8, 7, 3, 1, 1, 7, 5, 8]
        let checkDigit = EAN13Barcode.computeCheckDigit(for: digits)
        XCTAssertEqual(checkDigit, 4)
    }
}
