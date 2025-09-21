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

        let rendered = BookNoteTemplate.render(metadata: metadata, now: date, timeZone: TimeZone(secondsFromGMT: 0)!)

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

        let rendered = BookNoteTemplate.render(metadata: metadata, now: Date(timeIntervalSince1970: 0), timeZone: TimeZone(secondsFromGMT: 0)!)

        XCTAssertTrue(rendered.contains("title: \"Swift \\\"Advanced\\\" Guide\""))
        XCTAssertTrue(rendered.contains("authors: [\"A\",\"B\"]"))
    }
}
