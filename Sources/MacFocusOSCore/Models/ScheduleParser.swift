import Foundation

public struct ParsedSchedule {
    public let title: String
    public let startMinutes: Int
    public let endMinutes: Int
    public let days: Set<Int>
}

public enum ScheduleParser {

    private static let dayNames: [String: Int] = [
        "sun": 1, "sunday": 1,
        "mon": 2, "monday": 2,
        "tue": 3, "tues": 3, "tuesday": 3,
        "wed": 4, "wednesday": 4,
        "thu": 5, "thur": 5, "thurs": 5, "thursday": 5,
        "fri": 6, "friday": 6,
        "sat": 7, "saturday": 7
    ]

    private static let dayOrder: [Int] = [2, 3, 4, 5, 6, 7, 1]

    public static func parse(_ input: String) -> ParsedSchedule? {
        var original = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var text = original.lowercased()
        guard !text.isEmpty else { return nil }

        let (days, removedRanges) = extractDays(text)
        for range in removedRanges.sorted(by: { $0.location > $1.location }) {
            original = remove(range: range, from: original)
            text = remove(range: range, from: text)
        }

        let timePattern = #"(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*(?:-|–|—|to|till|until)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?"#
        let timeRange = firstMatch(timePattern, in: text)
        guard let timeRange else { return nil }
        text = remove(range: timeRange.range, from: text)
        original = remove(range: timeRange.range, from: original)

        let startHour = Int(timeRange.groups[1])!
        let startMinute = Int(timeRange.groups[2]) ?? 0
        let startMeridiem = timeRange.groups[3]
        let endHour = Int(timeRange.groups[4])!
        let endMinute = Int(timeRange.groups[5]) ?? 0
        let endMeridiem = timeRange.groups[6]

        let startMer = startMeridiem.isEmpty ? nil : startMeridiem
        let endMer = endMeridiem.isEmpty ? nil : endMeridiem
        let start = resolveTime(hour: startHour, minute: startMinute, ownMeridiem: startMer, otherMeridiem: endMer, otherHour: endHour, isStart: true)
        var end = resolveTime(hour: endHour, minute: endMinute, ownMeridiem: endMer, otherMeridiem: startMer, otherHour: startHour, isStart: false)
        if end <= start {
            if endMeridiem.isEmpty && endHour < 12 {
                end = to24h(hour: endHour, minute: endMinute, meridiem: "pm")
            }
            if end <= start {
                end += 24 * 60
            }
        }

        var title = cleanTitle(original)
        if title.isEmpty {
            title = "Block"
        }

        return ParsedSchedule(
            title: title,
            startMinutes: start,
            endMinutes: end,
            days: days.isEmpty ? [2, 3, 4, 5, 6] : days
        )
    }

    private static func extractDays(_ text: String) -> (Set<Int>, [NSRange]) {
        var days = Set<Int>()
        var ranges: [NSRange] = []

        func overlapsExisting(_ range: NSRange) -> Bool {
            ranges.contains { $0.location < NSMaxRange(range) && range.location < NSMaxRange($0) }
        }

        let rangePattern = #"(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)(?:\s*(?:-|–|—|to)\s*)(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)"#
        for match in allMatches(rangePattern, in: text) {
            if let from = dayNames[match.groups[1]], let to = dayNames[match.groups[2]] {
                let fromIndex = dayOrder.firstIndex(of: from) ?? 0
                let toIndex = dayOrder.firstIndex(of: to) ?? 0
                if fromIndex <= toIndex {
                    for i in fromIndex...toIndex {
                        days.insert(dayOrder[i])
                    }
                }
            }
            ranges.append(match.range)
        }

        let anyPattern = #"(every day|everyday|all days|daily|weekdays|weekday|weekends|weekend)"#
        for match in allMatches(anyPattern, in: text) where !overlapsExisting(match.range) {
            switch match.groups[1] {
            case "weekdays", "weekday":
                days = [2, 3, 4, 5, 6]
            case "weekends", "weekend":
                days = [1, 7]
            default:
                days = [1, 2, 3, 4, 5, 6, 7]
            }
            ranges.append(match.range)
        }

        let singlePattern = #"\b(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)\b"#
        for match in allMatches(singlePattern, in: text) where !overlapsExisting(match.range) {
            guard let day = dayNames[match.groups[1]] else { continue }
            days.insert(day)
            ranges.append(match.range)
        }

        return (days, ranges)
    }

    private static func to24h(hour: Int, minute: Int, meridiem: String?) -> Int {
        var h = hour
        if let meridiem {
            let pm = meridiem == "pm"
            if pm && h < 12 { h += 12 }
            if !pm && h == 12 { h = 0 }
        }
        return min(h, 23) * 60 + min(minute, 59)
    }

    private static func resolveTime(hour: Int, minute: Int, ownMeridiem: String?, otherMeridiem: String?, otherHour: Int, isStart: Bool) -> Int {
        if let own = ownMeridiem {
            return to24h(hour: hour, minute: minute, meridiem: own)
        }
        if let other = otherMeridiem {
            if other == "pm" {
                if hour >= 12 { return hour * 60 + minute }
                if hour >= 7 { return to24h(hour: hour, minute: minute, meridiem: "am") }
                return to24h(hour: hour, minute: minute, meridiem: "pm")
            }
            if other == "am" {
                return to24h(hour: hour, minute: minute, meridiem: hour <= otherHour ? "am" : "pm")
            }
        }
        if hour <= 6 { return to24h(hour: hour, minute: minute, meridiem: "pm") }
        if !isStart && hour < otherHour { return to24h(hour: hour, minute: minute, meridiem: "pm") }
        return hour * 60 + minute
    }

    private static func cleanTitle(_ text: String) -> String {
        var t = text
        for word in [" at ", " from ", " on ", " for ", " -", " and "] {
            t = t.replacingOccurrences(of: word, with: " ")
        }
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct Match {
        let range: NSRange
        let groups: [String]
    }

    private static func firstMatch(_ pattern: String, in text: String) -> Match? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        guard let result = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return match(from: result, text: text)
    }

    private static func allMatches(_ pattern: String, in text: String) -> [Match] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .map { match(from: $0, text: text) }
    }

    private static func match(from result: NSTextCheckingResult, text: String) -> Match {
        let groups = (0..<result.numberOfRanges).map { index -> String in
            let range = result.range(at: index)
            guard range.location != NSNotFound,
                  let swiftRange = Range(range, in: text) else { return "" }
            return String(text[swiftRange])
        }
        return Match(range: result.range, groups: groups)
    }

    private static func remove(range: NSRange, from text: String) -> String {
        guard let swiftRange = Range(range, in: text) else { return text }
        var t = text
        t.removeSubrange(swiftRange)
        return t
    }

    public static func presetBlocks() -> [ScheduleBlock] {
        [
            ScheduleBlock(title: "Study", type: .study, startMinutes: 9 * 60, endMinutes: 11 * 60, days: [2, 3, 4, 5, 6]),
            ScheduleBlock(title: "Deep work", type: .deepWork, startMinutes: 14 * 60, endMinutes: 16 * 60, days: [2, 3, 4, 5, 6]),
            ScheduleBlock(title: "Meetings", type: .meetings, startMinutes: 11 * 60, endMinutes: 12 * 60, days: [2, 3, 4, 5, 6]),
            ScheduleBlock(title: "Lunch", type: .eat, startMinutes: 12 * 60 + 30, endMinutes: 13 * 60 + 30, days: [2, 3, 4, 5, 6]),
            ScheduleBlock(title: "Break", type: .breakTime, startMinutes: 15 * 60, endMinutes: 15 * 60 + 30, days: [2, 3, 4, 5, 6]),
            ScheduleBlock(title: "Gym", type: .exercise, startMinutes: 18 * 60, endMinutes: 19 * 60, days: [2, 3, 4, 5, 6]),
            ScheduleBlock(title: "Free weekend", type: .free, startMinutes: 10 * 60, endMinutes: 20 * 60, days: [1, 7])
        ]
    }
}