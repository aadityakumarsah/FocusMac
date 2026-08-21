import Foundation

public struct DaySummary: Codable, Equatable {
    public var date: Date
    public var xp: Double
    public var focusedTime: TimeInterval
    public var distractionTime: TimeInterval
    public var neutralTime: TimeInterval

    public init(
        date: Date = Date(),
        xp: Double = 0,
        focusedTime: TimeInterval = 0,
        distractionTime: TimeInterval = 0,
        neutralTime: TimeInterval = 0
    ) {
        self.date = date
        self.xp = xp
        self.focusedTime = focusedTime
        self.distractionTime = distractionTime
        self.neutralTime = neutralTime
    }
}

public struct DistractionEvent: Codable, Equatable, Identifiable {
    public let id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var duration: TimeInterval
    public var appName: String
    public var site: String?
    public var title: String?
    public var category: String
    public var reason: String
    public var key: String

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        duration: TimeInterval = 0,
        appName: String,
        site: String? = nil,
        title: String? = nil,
        category: String,
        reason: String = ""
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
        self.appName = appName
        self.site = site
        self.title = title
        self.category = category
        self.reason = reason
        self.key = "\(appName)|\(site ?? "")|\(title ?? "")"
    }
}

public struct AttendanceRecord: Codable, Equatable, Identifiable {
    public let id: UUID
    public var at: Date
    public var person: Bool
    public var lookingAway: Bool
    public var phoneUse: Bool
    public var pose: String
    public var similarity: Double?

    public init(
        id: UUID = UUID(),
        at: Date,
        person: Bool,
        lookingAway: Bool,
        phoneUse: Bool,
        pose: String,
        similarity: Double? = nil
    ) {
        self.id = id
        self.at = at
        self.person = person
        self.lookingAway = lookingAway
        self.phoneUse = phoneUse
        self.pose = pose
        self.similarity = similarity
    }
}

public struct MouseIdleEvent: Codable, Equatable, Identifiable {
    public let id: UUID
    public var start: Date
    public var end: Date
    public var duration: TimeInterval

    public init(id: UUID = UUID(), start: Date, end: Date, duration: TimeInterval) {
        self.id = id
        self.start = start
        self.end = end
        self.duration = duration
    }
}

public struct LifelineDay: Codable, Equatable {
    public var date: Date
    public var count: Int

    public init(date: Date, count: Int) {
        self.date = date
        self.count = count
    }
}

public struct AppState: Codable {
    public var goal: FocusGoal?
    public var warnAfter: TimeInterval
    public var blockAfter: TimeInterval
    public var trackingEnabled: Bool
    public var totalXP: Double
    public var day: DaySummary
    public var timeline: [Activity]
    public var session: FocusSession?
    public var schedule: [ScheduleBlock]
    public var model: ModelConfig?
    public var distractionLog: [DistractionEvent]
    public var cameraCheckEnabled: Bool
    public var cameraCheckInterval: TimeInterval
    public var attendanceLog: [AttendanceRecord]
    public var mouseIdleEvents: [MouseIdleEvent]
    public var passwordHash: String?
    public var lifelineUsedToday: Int
    public var lifelineDayStamp: Date?
    public var lifelineEndsAt: Date?
    public var lifelineDays: [LifelineDay]

    public init(
        goal: FocusGoal? = nil,
        warnAfter: TimeInterval = 120,
        blockAfter: TimeInterval = 300,
        trackingEnabled: Bool = true,
        totalXP: Double = 0,
        day: DaySummary = DaySummary(),
        timeline: [Activity] = [],
        session: FocusSession? = nil,
        schedule: [ScheduleBlock] = [],
        model: ModelConfig? = nil,
        distractionLog: [DistractionEvent] = [],
        cameraCheckEnabled: Bool = false,
        cameraCheckInterval: TimeInterval = 3,
        attendanceLog: [AttendanceRecord] = [],
        mouseIdleEvents: [MouseIdleEvent] = [],
        passwordHash: String? = nil,
        lifelineUsedToday: Int = 0,
        lifelineDayStamp: Date? = nil,
        lifelineEndsAt: Date? = nil,
        lifelineDays: [LifelineDay] = []
    ) {
        self.goal = goal
        self.warnAfter = warnAfter
        self.blockAfter = blockAfter
        self.trackingEnabled = trackingEnabled
        self.totalXP = totalXP
        self.day = day
        self.timeline = timeline
        self.session = session
        self.schedule = schedule
        self.model = model
        self.distractionLog = distractionLog
        self.cameraCheckEnabled = cameraCheckEnabled
        self.cameraCheckInterval = cameraCheckInterval
        self.attendanceLog = attendanceLog
        self.mouseIdleEvents = mouseIdleEvents
        self.passwordHash = passwordHash
        self.lifelineUsedToday = lifelineUsedToday
        self.lifelineDayStamp = lifelineDayStamp
        self.lifelineEndsAt = lifelineEndsAt
        self.lifelineDays = lifelineDays
    }

    private enum CodingKeys: String, CodingKey {
        case goal, warnAfter, blockAfter, trackingEnabled, totalXP, day, timeline, session, schedule, model
        case distractionLog, cameraCheckEnabled, cameraCheckInterval, attendanceLog, mouseIdleEvents, passwordHash
        case lifelineUsedToday, lifelineDayStamp, lifelineEndsAt, lifelineDays
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        goal = try c.decodeIfPresent(FocusGoal.self, forKey: .goal)
        warnAfter = try c.decodeIfPresent(TimeInterval.self, forKey: .warnAfter) ?? 120
        blockAfter = try c.decodeIfPresent(TimeInterval.self, forKey: .blockAfter) ?? 300
        trackingEnabled = try c.decodeIfPresent(Bool.self, forKey: .trackingEnabled) ?? true
        totalXP = try c.decodeIfPresent(Double.self, forKey: .totalXP) ?? 0
        day = try c.decodeIfPresent(DaySummary.self, forKey: .day) ?? DaySummary()
        timeline = try c.decodeIfPresent([Activity].self, forKey: .timeline) ?? []
        session = try c.decodeIfPresent(FocusSession.self, forKey: .session)
        schedule = try c.decodeIfPresent([ScheduleBlock].self, forKey: .schedule) ?? []
        model = try c.decodeIfPresent(ModelConfig.self, forKey: .model)
        distractionLog = try c.decodeIfPresent([DistractionEvent].self, forKey: .distractionLog) ?? []
        cameraCheckEnabled = try c.decodeIfPresent(Bool.self, forKey: .cameraCheckEnabled) ?? false
        cameraCheckInterval = try c.decodeIfPresent(TimeInterval.self, forKey: .cameraCheckInterval) ?? 3
        attendanceLog = try c.decodeIfPresent([AttendanceRecord].self, forKey: .attendanceLog) ?? []
        mouseIdleEvents = try c.decodeIfPresent([MouseIdleEvent].self, forKey: .mouseIdleEvents) ?? []
        passwordHash = try c.decodeIfPresent(String.self, forKey: .passwordHash)
        lifelineUsedToday = try c.decodeIfPresent(Int.self, forKey: .lifelineUsedToday) ?? 0
        lifelineDayStamp = try c.decodeIfPresent(Date.self, forKey: .lifelineDayStamp)
        lifelineEndsAt = try c.decodeIfPresent(Date.self, forKey: .lifelineEndsAt)
        lifelineDays = try c.decodeIfPresent([LifelineDay].self, forKey: .lifelineDays) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(goal, forKey: .goal)
        try c.encode(warnAfter, forKey: .warnAfter)
        try c.encode(blockAfter, forKey: .blockAfter)
        try c.encode(trackingEnabled, forKey: .trackingEnabled)
        try c.encode(totalXP, forKey: .totalXP)
        try c.encode(day, forKey: .day)
        try c.encode(timeline, forKey: .timeline)
        try c.encodeIfPresent(session, forKey: .session)
        try c.encode(schedule, forKey: .schedule)
        try c.encodeIfPresent(model, forKey: .model)
        try c.encode(distractionLog, forKey: .distractionLog)
        try c.encode(cameraCheckEnabled, forKey: .cameraCheckEnabled)
        try c.encode(cameraCheckInterval, forKey: .cameraCheckInterval)
        try c.encode(attendanceLog, forKey: .attendanceLog)
        try c.encode(mouseIdleEvents, forKey: .mouseIdleEvents)
        try c.encodeIfPresent(passwordHash, forKey: .passwordHash)
        try c.encode(lifelineUsedToday, forKey: .lifelineUsedToday)
        try c.encodeIfPresent(lifelineDayStamp, forKey: .lifelineDayStamp)
        try c.encodeIfPresent(lifelineEndsAt, forKey: .lifelineEndsAt)
        try c.encode(lifelineDays, forKey: .lifelineDays)
    }
}
