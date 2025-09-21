import Foundation

enum DateFormatting {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    static func isoDateString(from date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Self.calendar
        calendar.timeZone = timeZone

        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            return ISO8601DateFormatter().string(from: date)
        }

        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
