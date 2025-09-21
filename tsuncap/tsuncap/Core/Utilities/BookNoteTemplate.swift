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

enum BookMetadataMappingError: Error, Equatable {
    case missingTitle
    case missingISBN
}

struct OpenLibraryBook: Decodable {
    struct AuthorReference: Decodable {
        let key: String?
        let name: String?
        let personalName: String?

        enum CodingKeys: String, CodingKey {
            case key
            case name
            case personalName = "personal_name"
        }

        var displayName: String? {
            name?.trimmedOrNil ?? personalName?.trimmedOrNil
        }
    }

    struct Subject: Decodable {
        let value: String

        init(from decoder: Decoder) throws {
            if let single = try? decoder.singleValueContainer().decode(String.self) {
                value = single
                return
            }

            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try container.decodeIfPresent(String.self, forKey: .name)
                ?? container.decodeIfPresent(String.self, forKey: .key)
                ?? ""
        }

        enum CodingKeys: String, CodingKey {
            case name
            case key
        }
    }

    let title: String?
    let subtitle: String?
    let byStatement: String?
    let authors: [AuthorReference]?
    let subjects: [Subject]?
    let isbn13: [String]?

    enum CodingKeys: String, CodingKey {
        case title
        case subtitle
        case byStatement = "by_statement"
        case authors
        case subjects
        case isbn13 = "isbn_13"
    }
}

struct OpenLibraryAuthorDetails: Decodable {
    let name: String?
    let personalName: String?

    enum CodingKeys: String, CodingKey {
        case name
        case personalName = "personal_name"
    }

    var displayName: String? {
        name?.trimmedOrNil ?? personalName?.trimmedOrNil
    }
}

extension BookMetadata {
    init(
        openLibraryBook: OpenLibraryBook,
        authorDetails: [String: OpenLibraryAuthorDetails] = [:],
        coverSize: String = "L"
    ) throws {
        guard let resolvedTitle = Self.resolveTitle(
            primary: openLibraryBook.title,
            subtitle: openLibraryBook.subtitle,
            fallback: openLibraryBook.byStatement
        ) else {
            throw BookMetadataMappingError.missingTitle
        }

        guard let isbn = openLibraryBook.isbn13?.compactMap({ $0.trimmedOrNil }).first else {
            throw BookMetadataMappingError.missingISBN
        }

        let authors = (openLibraryBook.authors ?? []).compactMap { reference -> String? in
            if let key = reference.key, let details = authorDetails[key], let name = details.displayName {
                return name
            }
            return reference.displayName
        }

        let categories = Self.deduplicate(
            (openLibraryBook.subjects ?? []).compactMap { $0.value.trimmedOrNil }
        )

        let coverUrl = "https://covers.openlibrary.org/b/isbn/\(isbn)-\(coverSize).jpg"

        self.init(
            title: resolvedTitle,
            authors: authors,
            categories: Array(categories.prefix(3)),
            isbn13: isbn,
            coverUrl: coverUrl
        )
    }
}

struct GoogleBooksVolume: Decodable {
    struct VolumeInfo: Decodable {
        struct IndustryIdentifier: Decodable {
            let type: String
            let identifier: String
        }

        struct ImageLinks: Decodable {
            let extraLarge: String?
            let large: String?
            let medium: String?
            let small: String?
            let thumbnail: String?
            let smallThumbnail: String?

            func preferredLink() -> String? {
                let preferredOrder = [
                    extraLarge,
                    large,
                    medium,
                    small,
                    thumbnail,
                    smallThumbnail
                ]

                return preferredOrder.compactMap { $0?.trimmedOrNil }
                    .map { link -> String in
                        if link.hasPrefix("http://") {
                            return "https://" + link.dropFirst("http://".count)
                        }
                        return link
                    }
                    .first
            }
        }

        let title: String?
        let subtitle: String?
        let authors: [String]?
        let categories: [String]?
        let industryIdentifiers: [IndustryIdentifier]?
        let imageLinks: ImageLinks?
    }

    let volumeInfo: VolumeInfo
}

extension BookMetadata {
    init(googleVolume: GoogleBooksVolume.VolumeInfo) throws {
        guard let resolvedTitle = Self.resolveTitle(
            primary: googleVolume.title,
            subtitle: googleVolume.subtitle,
            fallback: nil
        ) else {
            throw BookMetadataMappingError.missingTitle
        }

        guard let isbn = googleVolume.industryIdentifiers?
            .first(where: { $0.type.uppercased() == "ISBN_13" })?
            .identifier.trimmedOrNil else {
            throw BookMetadataMappingError.missingISBN
        }

        let authors = (googleVolume.authors ?? []).compactMap { $0.trimmedOrNil }
        let categories = Self.deduplicate((googleVolume.categories ?? []).compactMap { $0.trimmedOrNil })
        let coverUrl = googleVolume.imageLinks?.preferredLink() ?? ""

        self.init(
            title: resolvedTitle,
            authors: authors,
            categories: Array(categories.prefix(3)),
            isbn13: isbn,
            coverUrl: coverUrl
        )
    }
}

private extension BookMetadata {
    static func resolveTitle(primary: String?, subtitle: String?, fallback: String?) -> String? {
        if let primary = primary?.trimmedOrNil {
            if let subtitle = subtitle?.trimmedOrNil {
                return "\(primary): \(subtitle)"
            }
            return primary
        }

        return fallback?.trimmedOrNil
    }

    static func deduplicate(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []

        for value in values {
            let lowered = value.lowercased()
            if seen.insert(lowered).inserted {
                ordered.append(value)
            }
        }

        return ordered
    }
}

private extension String {
    var trimmedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
