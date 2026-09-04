import Foundation

public enum DistractionPhase: String, Equatable {
    case focused
    case warning
    case blocked
}

public struct SessionSnapshot {
    public var activity: Activity?
    public var classification: Classification?
    public var phase: DistractionPhase
    public var session: FocusSession?
    public var day: DaySummary
    public var totalXP: Double
    public var timeline: [Activity]
    public var warningDuration: TimeInterval
    public var insight: String
    public var xpGain: Int
    public var scheduled: ScheduleBlock?

    public init(
        activity: Activity? = nil,
        classification: Classification? = nil,
        phase: DistractionPhase = .focused,
        session: FocusSession? = nil,
        day: DaySummary = DaySummary(),
        totalXP: Double = 0,
        timeline: [Activity] = [],
        warningDuration: TimeInterval = 0,
        insight: String = "",
        xpGain: Int = 0,
        scheduled: ScheduleBlock? = nil
    ) {
        self.activity = activity
        self.classification = classification
        self.phase = phase
        self.session = session
        self.day = day
        self.totalXP = totalXP
        self.timeline = timeline
        self.warningDuration = warningDuration
        self.insight = insight
        self.xpGain = xpGain
        self.scheduled = scheduled
    }
}

public final class FocusSessionManager {
    public let store: Store
    private let rules: RuleEngine
    private var lastAccrual: Date?
    private var lastXPDelta: Int = 0
    public private(set) var lastClassification: Classification?
    public private(set) var backgroundDistraction = false

    public func setBackgroundDistraction(_ on: Bool) {
        backgroundDistraction = on
    }

    public init(store: Store, rules: RuleEngine) {
        self.store = store
        self.rules = rules
        validateState()
    }

    private func validateState() {
        if !Calendar.current.isDateInToday(store.state.day.date) {
            store.state.day = DaySummary()
        }
        if let session = store.state.session, session.isActive {
            store.state.session?.endedAt = Date()
        }
        store.save()
    }

    public var goal: FocusGoal? { store.state.goal }
    public var session: FocusSession? { store.state.session }
    public var trackingEnabled: Bool {
        get { store.state.trackingEnabled }
        set { store.state.trackingEnabled = newValue; store.save() }
    }
    public var warnAfter: TimeInterval {
        get { store.state.warnAfter }
        set { store.state.warnAfter = newValue; store.save() }
    }
    public var blockAfter: TimeInterval {
        get { store.state.blockAfter }
        set { store.state.blockAfter = newValue; store.save() }
    }
    public var schedule: [ScheduleBlock] { store.state.schedule }

    // MARK: - Lifelines

    public static let maxLifelinesPerDay = 3
    public static let lifelineDuration: TimeInterval = 15 * 60

    private func normalizeLifelineDay(now: Date) {
        let calendar = Calendar.current
        if let stamp = store.state.lifelineDayStamp, calendar.isDateInToday(stamp) { return }
        store.state.lifelineUsedToday = 0
        store.state.lifelineDayStamp = now
        if store.state.lifelineDays.count > 365 {
            store.state.lifelineDays.removeFirst(store.state.lifelineDays.count - 365)
        }
    }

    public func lifelinesRemaining(now: Date = Date()) -> Int {
        normalizeLifelineDay(now: now)
        return max(0, Self.maxLifelinesPerDay - store.state.lifelineUsedToday)
    }

    public func isLifelineActive(now: Date = Date()) -> Bool {
        guard let end = store.state.lifelineEndsAt else { return false }
        return end > now
    }

    public func activeLifelineEnd() -> Date? {
        isLifelineActive() ? store.state.lifelineEndsAt : nil
    }

    @discardableResult
    public func useLifeline(now: Date = Date()) -> Bool {
        normalizeLifelineDay(now: now)
        guard !isLifelineActive(now: now),
              store.state.lifelineUsedToday < Self.maxLifelinesPerDay else { return false }
        store.state.lifelineEndsAt = now.addingTimeInterval(Self.lifelineDuration)
        store.state.lifelineUsedToday += 1
        let calendar = Calendar.current
        if let last = store.state.lifelineDays.last, calendar.isDateInToday(last.date) {
            store.state.lifelineDays[store.state.lifelineDays.count - 1].count = store.state.lifelineUsedToday
        } else {
            store.state.lifelineDays.append(LifelineDay(date: now, count: store.state.lifelineUsedToday))
        }
        store.save()
        return true
    }

    public struct LifelineStats {
        public let daysUsed: Int
        public let totalUses: Int
    }

    public func lifelineStats() -> LifelineStats {
        LifelineStats(
            daysUsed: store.state.lifelineDays.filter { $0.count > 0 }.count,
            totalUses: store.state.lifelineDays.reduce(0) { $0 + $1.count }
        )
    }

    public func scheduledBlock(for date: Date = Date(), calendar: Calendar = .current) -> ScheduleBlock? {
        store.state.schedule.first { $0.contains(date, calendar: calendar) }
    }

    public func addScheduleBlock(_ block: ScheduleBlock) {
        store.state.schedule.append(block)
        store.save()
    }

    public func updateScheduleBlock(_ block: ScheduleBlock) {
        if let index = store.state.schedule.firstIndex(where: { $0.id == block.id }) {
            store.state.schedule[index] = block
            store.save()
        }
    }

    public func removeScheduleBlock(id: UUID) {
        store.state.schedule.removeAll { $0.id == id }
        store.save()
    }

    public func setGoal(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.state.goal = FocusGoal(title: trimmed)
        store.save()
    }

    public func startSession() {
        guard store.state.session?.isActive != true else { return }
        let planTitle = scheduledBlock(for: Date())?.title ?? "Your scheduled plan"
        let plan = FocusGoal(title: planTitle)
        store.state.goal = plan
        store.state.session = FocusSession(goal: plan, startedAt: Date())
        lastAccrual = Date()
        store.save()
    }

    public func endSession() {
        guard var session = store.state.session, session.isActive else { return }
        session.endedAt = Date()
        store.state.session = session
        store.save()
    }

    public func scheduleAllowsSite(_ site: String, scheduledTitle: String) -> Bool {
        let title = scheduledTitle.lowercased()
        // Default behavior: sites are NOT allowed unless explicitly mentioned in schedule
        // This ensures the tracker properly restricts content
        switch site {
        case "x":
            return title.contains("x.com") || title.contains("twitter")
        case "linkedin":
            return title.contains("linkedin") || title.contains("job") || title.contains("apply") || title.contains("applicat")
        case "youtube":
            // YouTube is only allowed if the schedule explicitly mentions it
            // By default, it's treated as entertainment and should be blocked
            return title.contains("youtube") || title.contains("video")
        case "reddit":
            return title.contains("reddit")
        case "instagram":
            return title.contains("instagram")
        case "facebook":
            return title.contains("facebook")
        case "tiktok":
            return title.contains("tiktok")
        case "netflix":
            return title.contains("netflix") || title.contains("movie") || title.contains("show")
        case "spotify":
            return title.contains("spotify") || title.contains("music")
        case "vlogs", "comedy", "movies":
            // These are entertainment categories that should be blocked unless explicitly allowed
            return title.contains(site) || title.contains("entertainment")
        default:
            // Default to restrictive: only allow if explicitly mentioned
            return title.contains(site)
        }
    }

    private func scheduleAllows(_ scheduled: ScheduleBlock, ctx: ActivityContext) -> Bool {
        guard let site = ctx.site else { return false }
        return scheduleAllowsSite(site, scheduledTitle: scheduled.title)
    }

    @discardableResult
    public func ingest(ctx: ActivityContext, now: Date, classificationOverride: Classification? = nil, forceNeutral: Bool = false) -> SessionSnapshot {
        var activity: Activity?
        if store.state.timeline.last?.sameAs(ctx) == true {
            store.state.timeline[store.state.timeline.count - 1].lastSeenAt = now
            if let title = ctx.windowTitle, !title.isEmpty {
                store.state.timeline[store.state.timeline.count - 1].windowTitle = title
            }
            store.state.timeline[store.state.timeline.count - 1].alignment = classificationOverride?.alignment ?? lastClassification?.alignment
            activity = store.state.timeline.last
        } else {
            let a = Activity(
                appName: ctx.appName,
                bundleID: ctx.bundleID,
                windowTitle: ctx.windowTitle,
                site: ctx.site,
                startedAt: now,
                lastSeenAt: now
            )
            store.state.timeline.append(a)
            if store.state.timeline.count > 60 {
                store.state.timeline.removeFirst(store.state.timeline.count - 60)
            }
            activity = store.state.timeline.last
        }

        // Edge case: handle nil context gracefully
        guard activity != nil else {
            return buildSnapshot(now: now)
        }

        lastClassification = classificationOverride ?? rules.classify(
            ctx, goal: store.state.goal, duration: activity?.duration ?? 0
        )

        if let scheduled = scheduledBlock(for: now), let base = lastClassification {
            if scheduled.type.isFreeTime {
                if base.alignment != .aligned {
                    lastClassification = Classification(
                        category: base.category,
                        alignment: .neutral,
                        xpPerMinute: 0,
                        confidence: base.confidence,
                        reason: base.reason + " — scheduled free time"
                    )
                }
            } else if base.confidence >= 0.8,
                  (base.category == .social || base.category == .entertainment || base.category == .communication),
                  base.alignment != .aligned {
                if scheduleAllows(scheduled, ctx: ctx) {
                    lastClassification = Classification(
                        category: base.category,
                        alignment: .aligned,
                        xpPerMinute: 3,
                        confidence: base.confidence,
                        reason: "On the schedule: \(scheduled.title)"
                    )
                } else {
                    lastClassification = Classification(
                        category: base.category,
                        alignment: .misaligned,
                        xpPerMinute: min(base.xpPerMinute, -3),
                        confidence: base.confidence,
                        reason: "\(base.reason) — not part of \(scheduled.title)"
                    )
                }
            }
        }

        if forceNeutral {
            lastClassification = Classification(
                category: lastClassification?.category ?? .neutral,
                alignment: .neutral,
                xpPerMinute: 1,
                confidence: 0.5,
                reason: "Browsing/searching — not actively watching"
            )
        }

        if isLifelineActive(now: now), let base = lastClassification {
            lastClassification = Classification(
                category: base.category,
                alignment: .neutral,
                xpPerMinute: 0,
                confidence: base.confidence,
                reason: base.reason + " — lifeline active"
            )
        }

        updateDistractionLog(ctx: ctx, now: now)

        lastXPDelta = 0
        if let session = store.state.session, session.isActive {
            let delta = min(now.timeIntervalSince(lastAccrual ?? now), 120)
            lastAccrual = now
            if store.state.trackingEnabled, let classification = lastClassification {
                let scheduled = scheduledBlock(for: now)
                let permittedFreeTime = scheduled.map { $0.type.isFreeTime } ?? false
                let effectiveAlignment: Alignment =
                    (classification.alignment == .misaligned && permittedFreeTime) ? .neutral : classification.alignment
                let effectiveXP = (classification.alignment == .misaligned && permittedFreeTime)
                    ? 0 : classification.xpPerMinute
                let minutes = delta / 60
                var updated = session
                updated.xp += Double(effectiveXP) * minutes
                switch effectiveAlignment {
                case .aligned: updated.focusedTime += delta
                case .neutral: updated.neutralTime += delta
                case .misaligned: updated.distractionTime += delta
                }
                store.state.session = updated
                store.state.day.xp = max(0, store.state.day.xp + updated.xp - session.xp)
                store.state.totalXP = max(0, store.state.totalXP + updated.xp - session.xp)
                lastXPDelta = Int(updated.xp - session.xp)
            }
        }
        if store.state.timeline.last != nil, let classification = lastClassification {
            store.state.timeline[store.state.timeline.count - 1].alignment = classification.alignment
        }
        store.save()
        return buildSnapshot(now: now)
    }

    private func updateDistractionLog(ctx: ActivityContext, now: Date) {
        let misaligned = lastClassification?.alignment == .misaligned
        if !misaligned {
            if var last = store.state.distractionLog.last, last.endedAt == nil {
                last.endedAt = now
                last.duration = now.timeIntervalSince(last.startedAt)
                store.state.distractionLog[store.state.distractionLog.count - 1] = last
            }
            return
        }
        let key = "\(ctx.appName)|\(ctx.site ?? "")|\(ctx.windowTitle ?? "")"
        if var last = store.state.distractionLog.last, last.endedAt == nil {
            if last.key == key {
                last.duration = now.timeIntervalSince(last.startedAt)
                store.state.distractionLog[store.state.distractionLog.count - 1] = last
                return
            }
            last.endedAt = now
            last.duration = now.timeIntervalSince(last.startedAt)
            store.state.distractionLog[store.state.distractionLog.count - 1] = last
        }
        store.state.distractionLog.append(DistractionEvent(
            startedAt: now,
            appName: ctx.appName,
            site: ctx.site,
            title: ctx.windowTitle,
            category: lastClassification?.category.rawValue ?? "",
            reason: lastClassification?.reason ?? ""
        ))
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        store.state.distractionLog.removeAll { ($0.endedAt ?? $0.startedAt) < cutoff }
    }

    public struct DistractionSummary {
        public let count: Int
        public let totalMinutes: Double
        public let bySite: [(label: String, count: Int, minutes: Double)]
        public let byHour: [(hour: Int, count: Int, minutes: Double)]
        public let events: [DistractionEvent]

        public init(
            count: Int = 0,
            totalMinutes: Double = 0,
            bySite: [(label: String, count: Int, minutes: Double)] = [],
            byHour: [(hour: Int, count: Int, minutes: Double)] = [],
            events: [DistractionEvent] = []
        ) {
            self.count = count
            self.totalMinutes = totalMinutes
            self.bySite = bySite
            self.byHour = byHour
            self.events = events
        }
    }

    public func distractionSummary(for date: Date = Date()) -> DistractionSummary {
        let calendar = Calendar.current
        let events = store.state.distractionLog.filter {
            calendar.isDate($0.startedAt, inSameDayAs: date)
        }
        let resolved = events.map { event -> DistractionEvent in
            var e = event
            if e.endedAt == nil {
                e.endedAt = Date()
                e.duration = Date().timeIntervalSince(e.startedAt)
            }
            return e
        }
        let total = resolved.reduce(0) { $0 + $1.duration } / 60
        var siteBuckets: [String: (Int, Double)] = [:]
        var hourBuckets: [Int: (Int, Double)] = [:]
        for e in resolved {
            let label = e.site ?? e.appName
            siteBuckets[label, default: (0, 0)].0 += 1
            siteBuckets[label, default: (0, 0)].1 += e.duration / 60
            let hour = calendar.component(.hour, from: e.startedAt)
            hourBuckets[hour, default: (0, 0)].0 += 1
            hourBuckets[hour, default: (0, 0)].1 += e.duration / 60
        }
        let bySite = siteBuckets
            .map { (label: $0.key, count: $0.value.0, minutes: $0.value.1) }
            .sorted { $0.minutes > $1.minutes }
        let byHour = hourBuckets
            .map { (hour: $0.key, count: $0.value.0, minutes: $0.value.1) }
            .sorted { $0.hour < $1.hour }
        return DistractionSummary(
            count: resolved.count,
            totalMinutes: total,
            bySite: bySite,
            byHour: byHour,
            events: resolved.sorted { $0.startedAt < $1.startedAt }
        )
    }

    public func snapshot(now: Date = Date()) -> SessionSnapshot {
        buildSnapshot(now: now)
    }

    private func buildSnapshot(now: Date) -> SessionSnapshot {
        let activity = store.state.timeline.last
        let phase = computePhase(activity: activity, now: now)
        let scheduled = scheduledBlock(for: now)
        return SessionSnapshot(
            activity: activity,
            classification: lastClassification,
            phase: phase,
            session: store.state.session,
            day: store.state.day,
            totalXP: store.state.totalXP,
            timeline: Array(store.state.timeline.suffix(20)),
            warningDuration: activity?.duration ?? 0,
            insight: InsightGenerator.insight(
                goal: store.state.goal,
                session: store.state.session,
                phase: phase,
                day: store.state.day,
                scheduled: scheduled,
                currentIsMisaligned: lastClassification?.alignment == .misaligned
            ),
            xpGain: lastXPDelta,
            scheduled: scheduled
        )
    }

    private func computePhase(activity: Activity?, now: Date) -> DistractionPhase {
        guard store.state.trackingEnabled else { return .focused }
        if isLifelineActive(now: now) { return .focused }
        let scheduled = scheduledBlock(for: now)

        if backgroundDistraction {
            if let scheduled, scheduled.type.isFreeTime { return .focused }
            return .blocked
        }

        guard let classification = lastClassification,
              classification.alignment == .misaligned else { return .focused }

        if let scheduled, scheduled.type.isFreeTime {
            return .focused
        }
        return .blocked
    }
}

public enum InsightGenerator {

    public static func insight(
        goal: FocusGoal?,
        session: FocusSession?,
        phase: DistractionPhase,
        day: DaySummary,
        scheduled: ScheduleBlock?,
        currentIsMisaligned: Bool
    ) -> String {
        if let scheduled = scheduled, scheduled.type.isFreeTime, currentIsMisaligned {
            return "Planned \(scheduled.type.label.lowercased()) — enjoy it. It's on your schedule."
        }
        switch phase {
        case .warning:
            return "This activity doesn't appear related to your plan."
        case .blocked:
            if let scheduled, !scheduled.type.isFreeTime {
                return "Scheduled: \(scheduled.title) · \(scheduled.startLabel)–\(scheduled.endLabel). This activity doesn't match — get back to it."
            }
            return "Focus mode is active — this activity doesn't match your plan."
        case .focused:
            break
        }
        guard let session = session, session.isActive else {
            if currentIsMisaligned {
                return "Monitoring — this activity doesn't match your plan. It will be blocked instantly during scheduled blocks."
            }
            return "Start a focus session — the AI judges activity against your schedule."
        }
        if let scheduled = scheduled {
            return "On schedule: \(scheduled.title) · \(scheduled.startLabel)–\(scheduled.endLabel)"
        }
        let total = day.focusedTime + day.distractionTime
        guard total > 30 else { return "Session started — stay aligned to earn XP." }
        let ratio = day.focusedTime / total
        if ratio >= 0.85 {
            return "You're on a strong focus streak. Keep going."
        }
        if ratio >= 0.6 {
            return "Solid progress. One more deep block and you're set."
        }
        if day.distractionTime > day.focusedTime {
            return "Attention drifted today — restart with a 25-minute sprint."
        }
        return "Balanced session. Planned breaks keep you sharp."
    }
}
