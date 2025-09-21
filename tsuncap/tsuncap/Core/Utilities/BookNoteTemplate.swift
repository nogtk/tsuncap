import Foundation

struct BookMetadata {
    var title: String
    var authors: [String]
    var categories: [String]
    var isbn13: String
    var coverUrl: String

    init(
        title: String,
        authors: [String] = [],
        categories: [String] = [],
        isbn13: String,
        coverUrl: String
    ) {
        self.title = title
        self.authors = authors
        self.categories = categories
        self.isbn13 = isbn13
        self.coverUrl = coverUrl
    }
}

enum BookNoteTemplate {
    static let template: String = """
---
title: "{{title}}"
authors: [{{authors}}]
category: [{{categories}}]
isbn: {{isbn13}}
cover: {{coverUrl}}
status: unread
addedDate: {{DATE:YYYY-MM-DD}}
finishedDate:
---
"""

    static func render(metadata: BookMetadata, now: Date = Date(), timeZone: TimeZone = .current) -> String {
        let values: [String: TemplateValue] = [
            "title": .text(metadata.title),
            "authors": .stringArray(metadata.authors),
            "categories": .stringArray(metadata.categories),
            "isbn13": .text(metadata.isbn13),
            "coverUrl": .text(metadata.coverUrl)
        ]

        return YAMLTemplateRenderer.render(
            template: template,
            values: values,
            now: now,
            timeZone: timeZone
        )
    }
}
