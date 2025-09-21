import Foundation

enum EAN13ValidationError: Error, Equatable, LocalizedError {
    case invalidCharacters
    case invalidLength(expected: Int, actual: Int)
    case invalidPrefix
    case invalidCheckDigit(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .invalidCharacters:
            return "EAN-13には数字のみを入力してください。"
        case let .invalidLength(expected, actual):
            return "EAN-13は\(expected)桁ですが、\(actual)桁が入力されました。"
        case .invalidPrefix:
            return "サポート対象は978/979で始まるISBN-13のみです。"
        case let .invalidCheckDigit(expected, actual):
            return "チェックデジットが不正です (期待値: \(expected), 入力: \(actual))。"
        }
    }
}

struct EAN13Barcode: Equatable {
    static let supportedPrefixes = ["978", "979"]

    let value: String

    init(rawValue: String) throws {
        self.value = try Self.normalize(rawValue)
    }

    static func normalize(_ rawValue: String) throws -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EAN13ValidationError.invalidLength(expected: 13, actual: 0)
        }

        var digits: [Character] = []
        digits.reserveCapacity(trimmed.count)

        for character in trimmed {
            if character.isWholeNumber {
                digits.append(character)
            } else if character == "-" || character == " " {
                continue
            } else {
                throw EAN13ValidationError.invalidCharacters
            }
        }

        guard digits.count == 13 else {
            throw EAN13ValidationError.invalidLength(expected: 13, actual: digits.count)
        }

        let prefix = String(digits.prefix(3))
        guard supportedPrefixes.contains(prefix) else {
            throw EAN13ValidationError.invalidPrefix
        }

        let intDigits = digits.compactMap { $0.wholeNumberValue }
        let expectedCheckDigit = computeCheckDigit(for: intDigits.prefix(12))
        let actualCheckDigit = intDigits[12]

        guard expectedCheckDigit == actualCheckDigit else {
            throw EAN13ValidationError.invalidCheckDigit(
                expected: expectedCheckDigit,
                actual: actualCheckDigit
            )
        }

        return String(digits)
    }

    static func validate(_ rawValue: String) throws -> String {
        try normalize(rawValue)
    }

    static func computeCheckDigit<S: Sequence>(for digits: S) -> Int where S.Element == Int {
        var index = 0
        var sum = 0
        for digit in digits {
            if index % 2 == 0 {
                sum += digit
            } else {
                sum += digit * 3
            }
            index += 1
        }

        let modulo = sum % 10
        return modulo == 0 ? 0 : 10 - modulo
    }

    static func isValid(_ rawValue: String) -> Bool {
        (try? normalize(rawValue)) != nil
    }
}
