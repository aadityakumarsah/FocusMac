import Foundation

public struct FocusSession: Codable, Identifiable {
    public var id: UUID
    public var goal: FocusGoal
    public var startedAt: Date
    public var endedAt: Date?
    public var xp: Double
    public var focusedTime: TimeInterval
    public var distractionTime: TimeInterval
    public var neutralTime: TimeInterval
    public var paused: Bool

    public init(
        id: UUID = UUID(),
        goal: FocusGoal,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        xp: Double = 0,
        focusedTime: TimeInterval = 0,
        distractionTime: TimeInterval = 0,
        neutralTime: TimeInterval = 0,
        paused: Bool = false
    ) {
        self.id = id
        self.goal = goal
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.xp = xp
        self.focusedTime = focusedTime
        self.distractionTime = distractionTime
        self.neutralTime = neutralTime
        self.paused = paused
    }

    public var isActive: Bool { endedAt == nil }
    public var duration: TimeInterval { max(0, (endedAt ?? Date()).timeIntervalSince(startedAt)) }
}
