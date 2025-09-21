import Foundation

enum TemplateValue {
    case text(String)
    case stringArray([String])

    var rendered: String {
        switch self {
        case let .text(value):
            return TemplateRendererEscaping.escape(value)
        case let .stringArray(values):
            return values
                .map { "\"" + TemplateRendererEscaping.escape($0) + "\"" }
                .joined(separator: ",")
        }
    }
}

enum YAMLTemplateRenderer {
    static func render(
        template: String,
        values: [String: TemplateValue],
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        var output = ""
        var currentIndex = template.startIndex

        while currentIndex < template.endIndex {
            guard let openRange = template[currentIndex...].range(of: "{{") else {
                output.append(contentsOf: template[currentIndex...])
                break
            }

            output.append(contentsOf: template[currentIndex..<openRange.lowerBound])

            let searchStart = openRange.upperBound
            guard let closeRange = template[searchStart...].range(of: "}}") else {
                output.append(contentsOf: template[openRange.lowerBound...])
                break
            }

            let token = template[searchStart..<closeRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let replacement = resolve(token: token, values: values, now: now, timeZone: timeZone)
            output.append(replacement)

            currentIndex = closeRange.upperBound
        }

        return output
    }

    private static func resolve(
        token: String,
        values: [String: TemplateValue],
        now: Date,
        timeZone: TimeZone
    ) -> String {
        if token.uppercased().hasPrefix("DATE:") {
            let pattern = token.dropFirst("DATE:".count)
            return renderDate(pattern: String(pattern), date: now, timeZone: timeZone)
        }

        if let value = values[token] {
            return value.rendered
        }

        return ""
    }

    private static func renderDate(pattern: String, date: Date, timeZone: TimeZone) -> String {
        switch pattern {
        case "YYYY-MM-DD":
            return DateFormatting.isoDateString(from: date, timeZone: timeZone)
        default:
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = pattern
            return formatter.string(from: date)
        }
    }
}

enum TemplateRendererEscaping {
    static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
