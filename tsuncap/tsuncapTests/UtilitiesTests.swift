import XCTest
@testable import tsuncap

final class DateFormattingTests: XCTestCase {
    func testISODateStringRespectsTimeZone() {
        var components = DateComponents()
        components.year = 2025
        components.month = 9
        components.day = 18
        components.hour = 18
        components.minute = 30
        components.timeZone = TimeZone(secondsFromGMT: -5 * 3600)

        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!

        let jst = TimeZone(secondsFromGMT: 9 * 3600)!
        let formatted = DateFormatting.isoDateString(from: date, timeZone: jst)

        XCTAssertEqual(formatted, "2025-09-19")
    }

    func testISODateStringHandlesLeapDay() {
        var components = DateComponents()
        components.year = 2024
        components.month = 2
        components.day = 29
        components.hour = 15
        components.minute = 45
        components.timeZone = TimeZone(secondsFromGMT: 0)

        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!

        let formatted = DateFormatting.isoDateString(from: date, timeZone: TimeZone(secondsFromGMT: -9 * 3600)!)

        XCTAssertEqual(formatted, "2024-02-29")
    }
}

final class SlugifierTests: XCTestCase {
    func testSlugConvertsWhitespaceAndLowercases() {
        let slug = Slugifier.makeSlug(from: "The Swift Programming Language")
        XCTAssertEqual(slug, "the-swift-programming-language")
    }

    func testSlugKeepsUnicodeAndStripsDangerousCharacters() {
        let slug = Slugifier.makeSlug(from: "  図書館 / Swift入門?  ")
        XCTAssertEqual(slug, "図書館-swift入門")
    }

    func testSlugFallbackWhenEmpty() {
        let slug = Slugifier.makeSlug(from: "    ")
        XCTAssertEqual(slug, "untitled")
    }

    func testSlugRespectsLowercaseFlag() {
        let slug = Slugifier.makeSlug(from: "Swift UI", lowercase: false)
        XCTAssertEqual(slug, "Swift-UI")
    }

    func testSlugStripsControlCharactersAndDiacritics() {
        let slug = Slugifier.makeSlug(from: "Crème\nBrûlée: Basics")
        XCTAssertEqual(slug, "creme-brulee-basics")
    }
}

final class BookMetadataTests: XCTestCase {
    func testInitializerDefaultsCollectionsToEmpty() {
        let metadata = BookMetadata(
            title: "Test",
            isbn13: "9781234567897",
            coverUrl: "https://example.com/cover.jpg"
        )

        XCTAssertTrue(metadata.authors.isEmpty)
        XCTAssertTrue(metadata.categories.isEmpty)
    }
}

final class YAMLTemplateRendererTests: XCTestCase {
    func testRendersBookTemplate() {
        let metadata = BookMetadata(
            title: "The Swift Programming Language",
            authors: ["Apple"],
            categories: ["Programming", "Swift"],
            isbn13: "9781234567897",
            coverUrl: "https://example.com/cover.jpg"
        )

        var components = DateComponents()
        components.year = 2025
        components.month = 9
        components.day = 18
        components.timeZone = TimeZone(secondsFromGMT: 0)
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let rendered = BookNoteTemplate.render(
            metadata: metadata,
            now: date,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        let expected = """
---
title: \"The Swift Programming Language\"
authors: [\"Apple\"]
category: [\"Programming\",\"Swift\"]
isbn: 9781234567897
cover: https://example.com/cover.jpg
status: unread
addedDate: 2025-09-18
finishedDate:
---
"""
        XCTAssertEqual(rendered, expected)
    }

    func testEscapesQuotesInsideTemplate() {
        let metadata = BookMetadata(
            title: "Swift \"Advanced\" Guide",
            authors: ["A", "B"],
            categories: [],
            isbn13: "123",
            coverUrl: "https://example.com"
        )

        let rendered = BookNoteTemplate.render(
            metadata: metadata,
            now: Date(timeIntervalSince1970: 0),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertTrue(rendered.contains("title: \"Swift \\\"Advanced\\\" Guide\""))
        XCTAssertTrue(rendered.contains("authors: [\"A\",\"B\"]"))
    }

    func testRendersCustomDatePattern() {
        let template = "Added: {{DATE:yyyy/MM/dd}}"
        let now = Date(timeIntervalSince1970: 0)
        let rendered = YAMLTemplateRenderer.render(
            template: template,
            values: [:],
            now: now,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(rendered, "Added: 1970/01/01")
    }

    func testUnknownTokenProducesEmptyString() {
        let template = "value={{unknown}}"
        let rendered = YAMLTemplateRenderer.render(
            template: template,
            values: [:],
            now: Date(),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(rendered, "value=")
    }

    func testEscapesNewlines() {
        let metadata = BookMetadata(
            title: "Line\nBreak",
            authors: ["A\nB"],
            categories: ["Multi\nLine"],
            isbn13: "9780000000000",
            coverUrl: "https://example.com"
        )

        let rendered = BookNoteTemplate.render(
            metadata: metadata,
            now: Date(timeIntervalSince1970: 0),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertTrue(rendered.contains("title: \"Line\\nBreak\""))
        XCTAssertTrue(rendered.contains("authors: [\"A\\nB\"]"))
        XCTAssertTrue(rendered.contains("category: [\"Multi\\nLine\"]"))
    }
}

final class TemplateRendererEscapingTests: XCTestCase {
    func testEscapesBackslashQuoteAndNewline() {
        let escaped = TemplateRendererEscaping.escape("\\\"\n")
        XCTAssertEqual(escaped, "\\\\\\\"\\n")
    }
}

final class OpenLibraryMappingTests: XCTestCase {
    func testMapsCompletePayload() throws {
        let book: OpenLibraryBook = try decodeJSON(
            from: """
            {
              "title": "Norwegian Wood",
              "subtitle": "Deluxe Edition",
              "authors": [
                {"key": "/authors/OL12345A"}
              ],
              "subjects": [
                "Japanese fiction",
                {"name": "Coming-of-age"},
                "Japanese fiction"
              ],
              "isbn_13": ["9780099448822", "9780000000000"]
            }
            """
        )

        let author: OpenLibraryAuthorDetails = try decodeJSON(
            from: """
            {
              "name": "Haruki Murakami"
            }
            """
        )

        let metadata = try BookMetadata(
            openLibraryBook: book,
            authorDetails: ["/authors/OL12345A": author]
        )

        XCTAssertEqual(metadata.title, "Norwegian Wood: Deluxe Edition")
        XCTAssertEqual(metadata.authors, ["Haruki Murakami"])
        XCTAssertEqual(metadata.categories, ["Japanese fiction", "Coming-of-age"])
        XCTAssertEqual(metadata.isbn13, "9780099448822")
        XCTAssertEqual(
            metadata.coverUrl,
            "https://covers.openlibrary.org/b/isbn/9780099448822-L.jpg"
        )
    }

    func testFallsBackToAuthorReferenceName() throws {
        let book: OpenLibraryBook = try decodeJSON(
            from: """
            {
              "title": "Test Title",
              "authors": [
                {"name": "Anonymous"}
              ],
              "subjects": [],
              "isbn_13": ["9781111111111"]
            }
            """
        )

        let metadata = try BookMetadata(openLibraryBook: book)

        XCTAssertEqual(metadata.authors, ["Anonymous"])
    }

    func testThrowsWhenIsbnMissing() throws {
        let book: OpenLibraryBook = try decodeJSON(
            from: """
            {
              "title": "Missing ISBN"
            }
            """
        )

        XCTAssertThrowsError(try BookMetadata(openLibraryBook: book)) { error in
            XCTAssertEqual(error as? BookMetadataMappingError, .missingISBN)
        }
    }
}

final class GoogleBooksMappingTests: XCTestCase {
    func testMapsPreferredVolumeInfo() throws {
        let volume: GoogleBooksVolume = try decodeJSON(
            from: """
            {
              "volumeInfo": {
                "title": "Norwegian Wood",
                "subtitle": "A Novel",
                "authors": ["Haruki Murakami", "Translator"],
                "categories": ["Fiction", "Japanese Fiction"],
                "industryIdentifiers": [
                  {"type": "ISBN_10", "identifier": "0099448823"},
                  {"type": "ISBN_13", "identifier": "9780099448822"}
                ],
                "imageLinks": {
                  "thumbnail": "http://books.google.com/thumbnail.jpg",
                  "large": "https://books.google.com/large.jpg"
                }
              }
            }
            """
        )

        let metadata = try BookMetadata(googleVolume: volume.volumeInfo)

        XCTAssertEqual(metadata.title, "Norwegian Wood: A Novel")
        XCTAssertEqual(metadata.authors, ["Haruki Murakami", "Translator"])
        XCTAssertEqual(metadata.categories, ["Fiction", "Japanese Fiction"])
        XCTAssertEqual(metadata.isbn13, "9780099448822")
        XCTAssertEqual(metadata.coverUrl, "https://books.google.com/large.jpg")
    }

    func testChoosesHttpsThumbnailWhenHigherResMissing() throws {
        let volume: GoogleBooksVolume = try decodeJSON(
            from: """
            {
              "volumeInfo": {
                "title": "Cover Test",
                "industryIdentifiers": [
                  {"type": "ISBN_13", "identifier": "9782222222222"}
                ],
                "imageLinks": {
                  "thumbnail": "http://example.com/thumb.jpg"
                }
              }
            }
            """
        )

        let metadata = try BookMetadata(googleVolume: volume.volumeInfo)

        XCTAssertEqual(metadata.coverUrl, "https://example.com/thumb.jpg")
    }

    func testThrowsWhenTitleMissing() throws {
        let volume: GoogleBooksVolume = try decodeJSON(
            from: """
            {
              "volumeInfo": {
                "industryIdentifiers": [
                  {"type": "ISBN_13", "identifier": "9783333333333"}
                ]
              }
            }
            """
        )

        XCTAssertThrowsError(try BookMetadata(googleVolume: volume.volumeInfo)) { error in
            XCTAssertEqual(error as? BookMetadataMappingError, .missingTitle)
        }
    }

    func testThrowsWhenIsbnMissing() throws {
        let volume: GoogleBooksVolume = try decodeJSON(
            from: """
            {
              "volumeInfo": {
                "title": "No ISBN"
              }
            }
            """
        )

        XCTAssertThrowsError(try BookMetadata(googleVolume: volume.volumeInfo)) { error in
            XCTAssertEqual(error as? BookMetadataMappingError, .missingISBN)
        }
    }
}

private func decodeJSON<T: Decodable>(from json: String) throws -> T {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .useDefaultKeys
    let data = Data(json.utf8)
    return try decoder.decode(T.self, from: data)
}
