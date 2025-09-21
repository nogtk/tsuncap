import Foundation

enum Slugifier {
    private static let disallowedCharacters: CharacterSet = {
        var set = CharacterSet(charactersIn: "/\\?%*|\"<>:#")
        set.formUnion(.controlCharacters)
        set.formUnion(.newlines)
        return set
    }()

    static func makeSlug(from source: String, lowercase: Bool = true, fallback: String = "untitled") -> String {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }

        let whitespaceCollapsed = trimmed.replacingOccurrences(
            of: "\\s+",
            with: "-",
            options: .regularExpression
        )

        let filteredScalars = whitespaceCollapsed.unicodeScalars.compactMap { scalar -> UnicodeScalar? in
            if disallowedCharacters.contains(scalar) {
                return nil
            }
            return scalar
        }

        var slug = String(String.UnicodeScalarView(filteredScalars))
        if lowercase {
            slug = slug.lowercased(with: Locale(identifier: "en_US_POSIX"))
        }

        slug = slug.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        slug = slug.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        if slug.isEmpty {
            return fallback
        }

        return slug
    }
}
