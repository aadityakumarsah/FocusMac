import Foundation

public enum ScheduleActivityType: String, Codable, CaseIterable {
    case work
    case study
    case deepWork
    case meetings
    case exercise
    case free
    case breakTime = "break"
    case eat
    case sleep
    case other

    public var isFreeTime: Bool {
        switch self {
        case .free, .breakTime, .eat: return true
        default: return false
        }
    }

    public var label: String {
        switch self {
        case .work: return "Work"
        case .study: return "Study"
        case .deepWork: return "Deep work"
        case .meetings: return "Meetings"
        case .exercise: return "Exercise"
        case .free: return "Free time"
        case .breakTime: return "Break"
        case .eat: return "Eating"
        case .sleep: return "Sleep"
        case .other: return "Other"
        }
    }

    public static func detect(from title: String) -> ScheduleActivityType {
        let t = title.lowercased()
        let keywords: [(ScheduleActivityType, [String])] = [
            (.sleep, ["sleep", "nap", "bed", "siesta"]),
            (.eat, ["lunch", "breakfast", "dinner", "eat", "meal", "snack", "brunch", "coffee", "tea"]),
            (.exercise, ["gym", "workout", "run", "running", "jog", "yoga", "exercise", "swim", "swimming", "bike", "cycling", "walk", "walking", "sport", "tennis", "football", "cricket", "basketball", "golf"]),
            (.free, ["free", "off", "fun", "hobby", "gaming", "game", "movie", "show"]),
            (.breakTime, ["break", "rest", "relax", "chill", "meditat", "pause"]),
            (.study, ["study", "learn", "lecture", "course", "class", "tutorial", "read", "reading", "book", "exam", "revision", "prepare"]),
            (.meetings, ["meeting", "standup", "stand-up", "sync", "call", "interview", "1:1", "one-on-one", "retro"]),
            (.deepWork, ["deep work", "deepwork", "sprint", "focus block", "blocked time"]),
            (.work, ["work", "office", "task", "email", "project", "report", "coding", "code", "dev", "design", "writing", "write", "job"])
        ]
        for (type, words) in keywords {
            if words.contains(where: { t.contains($0) }) {
                return type
            }
        }
        return .work
    }
}

public struct ScheduleBlock: Codable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var type: ScheduleActivityType
    public var startMinutes: Int
    public var endMinutes: Int
    public var days: Set<Int>

    public init(
        id: UUID = UUID(),
        title: String,
        type: ScheduleActivityType,
        startMinutes: Int,
        endMinutes: Int,
        days: Set<Int>
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.days = days
    }

    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let sameDayEnd = min(endMinutes, 24 * 60)
        if minutes >= startMinutes && minutes < sameDayEnd, days.contains(weekday) {
            return true
        }
        if endMinutes > 24 * 60 {
            let nextDayEnd = endMinutes - 24 * 60
            let previousWeekday = weekday == 1 ? 7 : weekday - 1
            if minutes < nextDayEnd, days.contains(previousWeekday) {
                return true
            }
        }
        return false
    }

    public var isStudy: Bool {
        type == .study || type == .deepWork
    }

    public func remainingDuration(at date: Date = Date(), calendar: Calendar = .current) -> TimeInterval {
        let minutesOfDay = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let seconds = calendar.component(.second, from: date)
        var remaining = Double(endMinutes - minutesOfDay) * 60 - Double(seconds)
        if remaining < 0 { remaining += 24 * 3600 }
        return max(0, remaining)
    }

    public var totalMinutes: Int { max(1, endMinutes - startMinutes) }

    public var startLabel: String { ScheduleBlock.timeLabel(minutes: startMinutes) }
    public var endLabel: String { ScheduleBlock.timeLabel(minutes: endMinutes) }

    public static func timeLabel(minutes: Int) -> String {
        let clamped = max(0, minutes)
        let effective = clamped % (24 * 60)
        let hour = effective / 60
        let minute = effective % 60
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return minute == 0
            ? "\(displayHour) \(period)"
            : String(format: "%d:%02d %@", displayHour, minute, period)
    }

    public static let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    public var daysLabel: String {
        let names = (1...7).compactMap { days.contains($0) ? Self.weekdayNames[$0 - 1] : nil }
        return names.isEmpty ? "No days" : names.joined(separator: " ")
    }
}