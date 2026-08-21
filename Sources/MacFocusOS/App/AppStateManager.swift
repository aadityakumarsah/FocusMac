import Combine
import CryptoKit
import Foundation
import SwiftUI
import UserNotifications
import MacFocusOSCore

enum ModelStatus: Equatable {
    case idle
    case testing
    case success(String)
    case failed(String)
    case configuring(OllamaProgress)
}

extension ModelStatus {
    var isInstalling: Bool {
        if case .configuring = self {
            return true
        }
        return false
    }
}

struct CameraOverlayState {
    var checking = false
    var verdict: AttendanceVerdict?
    var image: NSImage?
    var at: Date?
}

final class AppStateManager: ObservableObject {

    @Published private(set) var sessionActive = false
    @Published private(set) var trackingEnabled = true
    @Published private(set) var currentActivity: Activity?
    @Published private(set) var classification: Classification?
    @Published private(set) var phase: DistractionPhase = .focused
    @Published private(set) var timeline: [Activity] = []
    @Published private(set) var xpToday = 0
    @Published private(set) var xpSession = 0
    @Published private(set) var totalXP = 0
    @Published private(set) var focusedToday: TimeInterval = 0
    @Published private(set) var distractedToday: TimeInterval = 0
    @Published private(set) var sessionDuration: TimeInterval = 0
    @Published private(set) var score = 0
    @Published private(set) var insight = ""
    @Published private(set) var lastXPGain = 0
    @Published private(set) var warningDuration: TimeInterval = 0
    @Published private(set) var blocked = false
    @Published private(set) var currentScheduleBlock: ScheduleBlock?
    @Published private(set) var screenPermissionGranted = true
    @Published private(set) var modelConfig: ModelConfig
    @Published private(set) var modelStatus: ModelStatus = .idle
    @Published private(set) var ollamaServerRunning = false
    @Published private(set) var distractionSummary = FocusSessionManager.DistractionSummary()
    @Published private(set) var attendanceStatus = "Camera check off"
    @Published private(set) var attendanceEnabled = false
    @Published private(set) var attendanceHistory: [String] = []
    @Published private(set) var lastAttendanceAt: Date?
    @Published private(set) var cameraOverlay = CameraOverlayState()
    @Published private(set) var liveVideoImage: NSImage?
    @Published private(set) var liveVerdict: AttendanceVerdict?
    @Published private(set) var attendanceLog: [AttendanceRecord] = []
    @Published private(set) var mouseIdleCount = 0
    @Published private(set) var mouseIdleMinutes: Double = 0
    @Published private(set) var mouseIdleEvents: [MouseIdleEvent] = []
    @Published private(set) var passwordSet = false
    @Published private(set) var passwordLocked = false
    @Published private(set) var cameraPanelDismissed = false
    @Published private(set) var lifelinesRemaining = FocusSessionManager.maxLifelinesPerDay
    @Published private(set) var lifelineEndsAt: Date?
    @Published private(set) var lifelineDaysUsed = 0
    @Published private(set) var lifelineTotalUses = 0
    @Published var passwordMessage = ""

    let sessionManager: FocusSessionManager
    let rules = RuleEngine()
    let ollamaManager = OllamaManager()
    private let monitor = ActivityMonitor()
    private let attendanceMonitor = AttendanceMonitor()
    private let liveVideo = LiveVideoMonitor()
    private let mouseMonitor = MouseActivityMonitor(threshold: 180)
    private var analysisTimer: Timer?
    private var lastProblem: String?
    private var lastAlarmAt: Date?
    private var latestLiveFrame: CGImage?
    private var analysisInFlight = false
    private var tickInFlight = false
    private var timer: Timer?
    private var semanticCache: [String: Classification] = [:]
    private var semanticInFlight = Set<String>()
    private var lastSemanticAttempt: Date?
    private var lastVisionAttempt: Date?
    private var lastPermissionCheck: Date?
    private var lastTabScan: Date?
    private var lastFrontmostKey: String?
    private var blockedStreak = 0
    private var cachedSocialTabs: [String] = []

    var onRequestDashboard: (() -> Void)?
    var onRequestSettings: (() -> Void)?
    var onRequestSetup: (() -> Void)?
    var onFreeTimeNotice: ((String, String) -> Void)?
    var onRequirePassword: ((String) -> Void)?
    private var lastScheduledType: ScheduleActivityType?

    init() {
        let store = Store()
        sessionManager = FocusSessionManager(store: store, rules: rules)
        modelConfig = store.state.model ?? ModelConfig()
        sanitizeCameraInterval()
        trimStoredLogs()
        screenPermissionGranted = ActivityMonitor.hasScreenCapturePermission
        apply(sessionManager.snapshot(), animateXP: false)
        refreshLifelineState()
        passwordSet = sessionManager.store.state.passwordHash != nil
        passwordLocked = passwordSet
        attendanceEnabled = sessionManager.store.state.cameraCheckEnabled
        if attendanceEnabled {
            setupAttendance()
        }
        // Focus mode is the whole point of the app: tracking is permanently on.
        // A session auto-starts only once setup is complete (password, schedule,
        // permissions, AI); otherwise the setup wizard walks the user through it.
        sessionManager.trackingEnabled = true
        if setupComplete {
            sessionManager.startSession()
        }
        Task { [weak self] in
            await self?.checkForUpdates()
        }
        let updateTimer = Timer(timeInterval: 4 * 3600, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.checkForUpdates() }
        }
        RunLoop.main.add(updateTimer, forMode: .common)
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    // MARK: - Camera attendance check

    private static let allowedIntervals: [TimeInterval] = [60, 180, 360, 600]

    private func sanitizeCameraInterval() {
        let current = sessionManager.store.state.cameraCheckInterval
        guard !Self.allowedIntervals.contains(current) else { return }
        sessionManager.store.state.cameraCheckInterval = 360
        sessionManager.store.save()
    }

    private func trimStoredLogs() {
        var changed = false
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let trimmedIdle = sessionManager.store.state.mouseIdleEvents
            .filter { $0.end >= cutoff }
            .suffix(200)
        if trimmedIdle.count != sessionManager.store.state.mouseIdleEvents.count {
            sessionManager.store.state.mouseIdleEvents = Array(trimmedIdle)
            changed = true
        }
        if sessionManager.store.state.attendanceLog.count > 2000 {
            sessionManager.store.state.attendanceLog.removeFirst(sessionManager.store.state.attendanceLog.count - 2000)
            changed = true
        }
        if changed {
            sessionManager.store.save()
        }
    }

    func dismissCameraPanel() {
        cameraPanelDismissed = true
    }

    func setCameraCheckEnabled(_ on: Bool) {
        guard on || passwordSet else {
            sessionManager.store.state.cameraCheckEnabled = on
            sessionManager.store.save()
            attendanceEnabled = on
            if !on { disableAttendancePipeline() } else { setupAttendance() }
            return
        }
        performProtected("You need the password to turn the camera check off.") {
            self.sessionManager.store.state.cameraCheckEnabled = on
            self.sessionManager.store.save()
            self.attendanceEnabled = on
            if !on { self.disableAttendancePipeline() } else { self.setupAttendance() }
        }
    }

    private func disableAttendancePipeline() {
        attendanceMonitor.stop()
        analysisTimer?.invalidate()
        analysisTimer = nil
        liveVideo.stop()
        mouseMonitor.stop()
        attendanceStatus = "Camera check off"
        cameraOverlay = CameraOverlayState()
        cameraPanelDismissed = false
    }

    func setCameraCheckInterval(_ seconds: TimeInterval) {
        sessionManager.store.state.cameraCheckInterval = seconds
        sessionManager.store.save()
        if attendanceEnabled {
            analysisTimer?.invalidate()
            analysisTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
                self?.analyzeLatestFrame()
            }
        }
    }

    var cameraCheckInterval: TimeInterval { sessionManager.store.state.cameraCheckInterval }

    func testCameraCheck() {
        guard attendanceEnabled else { return }
        analyzeLatestFrame()
    }

    private func setupAttendance() {
        // Starting the local vision process can take a few seconds on its
        // first launch. Never make the setup wizard or dashboard wait for it.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let started = HumanServiceManager.ensureRunning()
            guard !started else { return }
            DispatchQueue.main.async {
                guard let self, self.attendanceEnabled else { return }
                self.attendanceStatus = "⚠ Phone detection service unavailable"
            }
        }
        attendanceLog = sessionManager.store.state.attendanceLog
        mouseIdleEvents = sessionManager.store.state.mouseIdleEvents
        refreshMouseStats()

        mouseMonitor.onIdleClosed = { [weak self] event in
            guard let self else { return }
            self.sessionManager.store.state.mouseIdleEvents.append(event)
            if self.sessionManager.store.state.mouseIdleEvents.count > 200 {
                self.sessionManager.store.state.mouseIdleEvents.removeFirst(self.sessionManager.store.state.mouseIdleEvents.count - 200)
            }
            self.sessionManager.store.save()
            self.refreshMouseStats()
        }
        mouseMonitor.start()

        liveVideo.onFrame = { [weak self] image in
            guard let self else { return }
            self.latestLiveFrame = image
            self.liveVideoImage = NSImage(cgImage: image, size: .zero)
            if self.liveVerdict == nil && !self.analysisInFlight {
                self.analyzeLatestFrame()
            }
        }
        liveVideo.onFailure = { [weak self] in
            self?.attendanceStatus = "⚠ Camera unavailable"
        }
        liveVideo.start()

        cameraOverlay = CameraOverlayState(checking: false, at: Date())
        cameraPanelDismissed = false
        analysisTimer = Timer.scheduledTimer(withTimeInterval: sessionManager.store.state.cameraCheckInterval, repeats: true) { [weak self] _ in
            self?.analyzeLatestFrame()
        }
        analyzeLatestFrame()
    }

    private func analyzeLatestFrame() {
        guard attendanceEnabled, !analysisInFlight, let frame = latestLiveFrame else { return }
        analysisInFlight = true
        cameraOverlay.checking = true
        cameraOverlay.at = Date()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let jpeg = Self.jpegData(from: frame)
            let verdict = jpeg.flatMap { AttendanceMonitor.analyze(jpeg: $0) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.analysisInFlight = false
                self.cameraOverlay.checking = false
                self.cameraOverlay.at = Date()
                guard let verdict else {
                    self.attendanceStatus = "⚠ Analysis failed"
                    return
                }
                self.cameraOverlay.verdict = verdict
                if let jpeg {
                    self.cameraOverlay.image = NSImage(data: jpeg)
                }
                self.liveVerdict = verdict
                self.handleAttendance(verdict)
            }
        }
    }

    private static func jpegData(from image: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.6])
    }

    private func refreshMouseStats() {
        mouseIdleEvents = sessionManager.store.state.mouseIdleEvents
        let today = mouseIdleEvents.filter { Calendar.current.isDateInToday($0.start) }
        mouseIdleCount = today.count
        mouseIdleMinutes = today.reduce(0) { $0 + $1.duration } / 60
    }

    private func handleAttendance(_ verdict: AttendanceVerdict) {
        let time = Date().formatted(date: .omitted, time: .shortened)
        let record = AttendanceRecord(
            at: Date(),
            person: verdict.person,
            lookingAway: verdict.lookingAway,
            phoneUse: verdict.phoneUse,
            pose: verdict.pose,
            similarity: verdict.similarity
        )
        sessionManager.store.state.attendanceLog.append(record)
        if sessionManager.store.state.attendanceLog.count > 2000 {
            sessionManager.store.state.attendanceLog.removeFirst(sessionManager.store.state.attendanceLog.count - 2000)
        }
        sessionManager.store.save()
        attendanceLog = sessionManager.store.state.attendanceLog
        lastAttendanceAt = Date()

        var problem: String?
        if !verdict.person {
            problem = "You left the desk"
        } else if verdict.phoneUse {
            problem = "Looks like you're on your phone"
        } else if verdict.lookingAway {
            problem = "Looking away from the screen"
        }
        let quietNow = inQuietBlockNow
        if let problem {
            if quietNow {
                attendanceStatus = "🌙 \(problem) — free time, staying quiet (\(time))"
            } else {
                attendanceStatus = "⚠️ \(problem) (\(time))"
                if problem != lastProblem {
                    playAlarm()
                    lastAlarmAt = Date()
                } else if let lastAlarm = lastAlarmAt, Date().timeIntervalSince(lastAlarm) >= 10 {
                    playAlarm()
                    lastAlarmAt = Date()
                }
            }
            lastProblem = problem
        } else {
            var sim = ""
            if let s = verdict.similarity {
                sim = String(format: " — face match %.0f%%", s * 100)
            }
            attendanceStatus = "✔ Attentive\(sim) · \(verdict.pose) · \(time)"
            lastProblem = nil
            lastAlarmAt = nil
        }
        attendanceHistory.insert(attendanceStatus, at: 0)
        if attendanceHistory.count > 8 { attendanceHistory.removeLast(attendanceHistory.count - 8) }
        lastAttendanceAt = attendanceMonitor.lastCheck
    }

    private var alarmInFlight = false

    private func playAlarm() {
        guard !alarmInFlight else { return }
        alarmInFlight = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let end = Date().addingTimeInterval(10)
            while Date() < end {
                if let sound = NSSound(named: "Sosumi") {
                    sound.play()
                } else {
                    NSSound.beep()
                }
                Thread.sleep(forTimeInterval: 0.8)
            }
            DispatchQueue.main.async {
                self?.alarmInFlight = false
            }
        }
    }

    func tick() {
        guard trackingEnabled, !tickInFlight else { return }
        refreshPermissionIfNeeded()
        guard let ctx = monitor.snapshot() else { return }
        tickInFlight = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let nowPlaying = MediaPauser.nowPlayingInfo()
            DispatchQueue.main.async {
                defer { self?.tickInFlight = false }
                self?.finishTick(ctx: ctx, nowPlaying: nowPlaying)
            }
        }
    }
    
    // Add edge case handling for when the app is terminated unexpectedly
    func cleanup() {
        analysisTimer?.invalidate()
        analysisTimer = nil
        disableAttendancePipeline()
        liveVideo.stop()
        mouseMonitor.stop()
    }

    private func finishTick(ctx: ActivityContext, nowPlaying: MediaPauser.NowPlayingInfo?) {
        currentIsBrowser = ctx.isBrowser
        let key = "\(ctx.appName)|\(ctx.windowTitle ?? "")"
        let isWatchingVideo = rules.isVideoSite(ctx)
            && (nowPlaying?.rate ?? 0) > 0
            && nowPlaying?.appBundleID == ctx.bundleID
        let title = ctx.windowTitle ?? ""
        let isShorts = rules.isVideoSite(ctx)
            && title.lowercased().contains("shorts")
        let override: Classification? = isShorts
            ? Classification(
                category: .entertainment,
                alignment: .misaligned,
                xpPerMinute: -3,
                confidence: 0.95,
                reason: "YouTube Shorts — short-form distraction"
            )
            : isWatchingVideo
            ? (semanticCache[key] ?? rules.classifyVideoWatch(
                site: ctx.site ?? "video",
                title: ctx.windowTitle,
                goal: sessionManager.goal
            ))
            : semanticCache[key]
        let snap = sessionManager.ingest(
            ctx: ctx,
            now: Date(),
            classificationOverride: override,
            forceNeutral: rules.isVideoSite(ctx) && !isWatchingVideo && !isShorts
        )
        apply(snap, animateXP: true)
        notifyFreeTimeTransitions(scheduled: snap.scheduled)
        distractionSummary = sessionManager.distractionSummary()
        #if DEBUG
        let line = "\(Date().formatted(date: .omitted, time: .standard)) | app=\(ctx.appName) site=\(ctx.site ?? "-") title=\(ctx.windowTitle ?? "-") | \(snap.classification?.category.rawValue ?? "-")/\(snap.classification?.alignment.rawValue ?? "-") c=\(snap.classification?.confidence ?? 0) | phase=\(snap.phase.rawValue) dur=\(Int(snap.activity?.duration ?? 0))s tabs=\(cachedSocialTabs.joined(separator: ",")) bgMedia=\(MediaPauser.isBackgroundMediaPlaying(frontmostBundleID: ctx.bundleID))"
        if let handle = FileHandle(forWritingAtPath: "/tmp/macfocus-debug.log") {
            handle.seekToEndOfFile()
            handle.write(line.appending("\n").data(using: .utf8) ?? Data())
            try? handle.close()
        } else {
            try? line.appending("\n").data(using: .utf8)?.write(to: URL(fileURLWithPath: "/tmp/macfocus-debug.log"))
        }
        #endif
        if semanticCache[key] == nil,
           rules.isAmbiguous(ctx),
           let provider = currentProvider() {
            fetchSemanticIfNeeded(ctx, key: key, provider: provider)
        }
        if modelConfig.visionEnabled,
           sessionActive,
           trackingEnabled,
           semanticCache[key] == nil {
            visionCheck(ctx: ctx, key: key)
        }
        let frontmostKey = "\(ctx.appName)|\(ctx.windowTitle ?? "")"
        let contextChanged = frontmostKey != lastFrontmostKey
        lastFrontmostKey = frontmostKey
        if contextChanged || Date().timeIntervalSince(lastTabScan ?? .distantPast) >= 3 {
            lastTabScan = Date()
            cachedSocialTabs = BrowserTabScanner.matchedSocialSites()
        }
        let scheduled = sessionManager.scheduledBlock()
        let quietBlock = scheduled.map { Self.isQuietBlock($0) } ?? false
        let tabDistracting: Bool
        if quietBlock {
            tabDistracting = false
        } else if let scheduled {
            tabDistracting = cachedSocialTabs.contains {
                !sessionManager.scheduleAllowsSite($0, scheduledTitle: scheduled.title)
            }
        } else {
            tabDistracting = !cachedSocialTabs.isEmpty
        }
        let background = !quietBlock && MediaPauser.isBackgroundMediaPlaying(frontmostBundleID: ctx.bundleID)
        let distracting = background || tabDistracting
        sessionManager.setBackgroundDistraction(distracting)
        if distracting {
            MediaPauser.pauseAll()
        }
        
        // Special handling for YouTube: block only when watching videos, not scrolling
        if ctx.site == "youtube" && isWatchingVideo && snap.classification?.alignment == .misaligned {
            // User is watching a non-educational video - trigger blocking
            if !quietBlock {
                blocked = true
            }
        }
    }

    private static func isQuietBlock(_ block: ScheduleBlock) -> Bool {
        block.type.isFreeTime || block.type == .sleep
    }

    private var inQuietBlockNow: Bool {
        sessionManager.scheduledBlock().map { Self.isQuietBlock($0) } ?? false
    }

    private func notifyFreeTimeTransitions(scheduled: ScheduleBlock?) {
        guard scheduled?.type != lastScheduledType else { return }
        let previous = lastScheduledType
        lastScheduledType = scheduled?.type
        guard previous != nil else { return }
        if let scheduled, scheduled.type.isFreeTime {
            let minutes = Int((scheduled.endMinutes - scheduled.startMinutes) / 60)
            onFreeTimeNotice?(
                "Free time started",
                "\(scheduled.type.label) — everything is allowed until \(scheduled.endLabel) (\(minutes) min). Enjoy it!"
            )
            // Also trigger system notification
            sendSystemNotification(title: "Free time started", body: "\(scheduled.type.label) — everything is allowed until \(scheduled.endLabel)")
        } else if let previous, previous.isFreeTime {
            let next = scheduled.map { "Back to: \($0.title)" } ?? "No scheduled block"
            onFreeTimeNotice?("Free time over", next)
            // Also trigger system notification
            sendSystemNotification(title: "Free time over", body: next)
        } else if let scheduled {
            // Notify when starting a new work/study block
            onFreeTimeNotice?("Time to focus", "Starting: \(scheduled.title)")
            sendSystemNotification(title: "Time to focus", body: "Starting: \(scheduled.title)")
        }
    }
    
    private func sendSystemNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }

    // MARK: - Screen recording permission

    func refreshPermission() {
        let granted = ActivityMonitor.hasScreenCapturePermission
        if screenPermissionGranted != granted {
            screenPermissionGranted = granted
        }
        lastPermissionCheck = Date()
    }

    private func refreshPermissionIfNeeded() {
        if let last = lastPermissionCheck, Date().timeIntervalSince(last) < 15 { return }
        refreshPermission()
    }

    // MARK: - Lifelines

    func refreshLifelineState() {
        lifelinesRemaining = sessionManager.lifelinesRemaining()
        lifelineEndsAt = sessionManager.activeLifelineEnd()
        let stats = sessionManager.lifelineStats()
        lifelineDaysUsed = stats.daysUsed
        lifelineTotalUses = stats.totalUses
    }

    var isLifelineActive: Bool { lifelineEndsAt != nil }

    func useLifeline() {
        guard sessionManager.useLifeline() else { return }
        refreshLifelineState()
        apply(sessionManager.snapshot(), animateXP: false)
    }

    // MARK: - First-launch permissions

    var needsPermissionOnboarding: Bool {
        !sessionManager.store.state.permissionsRequested
    }

    func markPermissionsRequested() {
        guard !sessionManager.store.state.permissionsRequested else { return }
        sessionManager.store.state.permissionsRequested = true
        sessionManager.store.save()
    }

    // MARK: - Password lock

    private static func hash(_ password: String) -> String {
        let digest = SHA256.hash(data: Data(password.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private var pendingProtectedAction: (() -> Void)?

    private func performProtected(_ message: String, _ action: @escaping () -> Void) {
        guard passwordSet, passwordLocked else {
            action()
            return
        }
        pendingProtectedAction = action
        onRequirePassword?(message)
    }

    func retryPendingProtectedAction() {
        let action = pendingProtectedAction
        pendingProtectedAction = nil
        action?()
        passwordLocked = passwordSet
    }

    func cancelPendingProtectedAction() {
        pendingProtectedAction = nil
        passwordMessage = ""
    }

    func setPassword(_ password: String) -> Bool {
        guard !password.isEmpty, !passwordSet else { return false }
        sessionManager.store.state.passwordHash = Self.hash(password)
        sessionManager.store.save()
        passwordSet = true
        passwordLocked = true
        passwordMessage = ""
        return true
    }

    func changePassword(current: String, new: String) -> Bool {
        guard let stored = sessionManager.store.state.passwordHash else { return false }
        guard Self.hash(current) == stored else {
            passwordMessage = "Current password is incorrect."
            return false
        }
        guard !new.isEmpty else {
            passwordMessage = "New password cannot be empty."
            return false
        }
        sessionManager.store.state.passwordHash = Self.hash(new)
        sessionManager.store.save()
        passwordMessage = "Password changed."
        return true
    }

    func verifyPassword(_ password: String) -> Bool {
        guard let stored = sessionManager.store.state.passwordHash else { return true }
        let ok = Self.hash(password) == stored
        if ok {
            passwordLocked = false
            passwordMessage = ""
        } else {
            passwordMessage = "Incorrect password."
        }
        return ok
    }

    // MARK: - Setup gate

    /// Everything the user must complete before a session can start:
    /// password lock, at least one schedule block, screen + camera permission,
    /// and a working AI configuration.
    var setupComplete: Bool {
        passwordSet
            && !sessionManager.schedule.isEmpty
            && ActivityMonitor.hasScreenCapturePermission
            && PermissionManager.cameraGranted
            && modelConfig.isConfigured
    }

    var scheduleCount: Int { sessionManager.schedule.count }

    // MARK: - Focus session

    func startSession() {
        guard setupComplete else { return }
        sessionManager.startSession()
        apply(sessionManager.snapshot(), animateXP: false)
    }

    /// Focus mode is always on — the schedule drives enforcement. Kept only so
    /// legacy state can't leave tracking disabled.
    func ensureTrackingOn() {
        if !sessionManager.trackingEnabled {
            sessionManager.trackingEnabled = true
            apply(sessionManager.snapshot(), animateXP: false)
        }
    }

    func setWarn(_ t: TimeInterval) {
        sessionManager.warnAfter = t
    }

    func setBlock(_ t: TimeInterval) {
        sessionManager.blockAfter = t
    }

    var warnAfter: TimeInterval { sessionManager.warnAfter }
    var blockAfter: TimeInterval { sessionManager.blockAfter }

    var planTitle: String {
        currentScheduleBlock?.title ?? "Your scheduled plan"
    }

    var schedule: [ScheduleBlock] { sessionManager.schedule }

    func addScheduleBlock(_ block: ScheduleBlock) {
        sessionManager.addScheduleBlock(block)
        apply(sessionManager.snapshot(), animateXP: false)
    }

    func updateScheduleBlock(_ block: ScheduleBlock) {
        sessionManager.updateScheduleBlock(block)
        apply(sessionManager.snapshot(), animateXP: false)
    }

    func removeScheduleBlock(id: UUID) {
        sessionManager.removeScheduleBlock(id: id)
        apply(sessionManager.snapshot(), animateXP: false)
    }

    @Published private(set) var lastCloseFeedback: String?
    @Published private(set) var closeNeedsAutomationPermission = false
    @Published private(set) var currentIsBrowser = false

    private static let closeableBrowsers: [String: String] = [
        "com.google.Chrome": "Google Chrome",
        "com.brave.Browser": "Brave Browser",
        "company.thebrowser.Browser": "Arc",
        "com.microsoft.edgemac": "Microsoft Edge",
        "com.apple.Safari": "Safari"
    ]

    private static let closeDomainHints = ["x": "x.com"]

    private static func closeNeedles(site: String?, windowTitle: String?) -> [String] {
        var needles: [String] = []
        if let site, !site.isEmpty {
            needles.append(closeDomainHints[site] ?? site)
        }
        if var title = windowTitle {
            title = title.replacingOccurrences(of: "–", with: "-")
                .replacingOccurrences(of: "—", with: "-")
                .trimmingCharacters(in: .whitespaces)
            let suffixes = ["- Google Chrome", "- Brave Browser", "- Arc",
                            "- Microsoft Edge", "- Safari", "- Mozilla Firefox"]
            if let suffix = suffixes.first(where: { title.lowercased().hasSuffix($0.lowercased()) }) {
                title = String(title.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            }
            for part in title.components(separatedBy: " - ") {
                let p = part.trimmingCharacters(in: .whitespaces)
                if p.count >= 4 { needles.append(p) }
            }
        }
        var seen = Set<String>()
        return needles.filter { seen.insert($0.lowercased()).inserted }
    }

    private func invalidateDistractionCaches() {
        lastTabScan = nil
        lastFrontmostKey = nil
    }

    func closeCurrentDistraction() {
        guard let ctx = monitor.snapshot() else { return }
        if let bundleID = ctx.bundleID, let appName = Self.closeableBrowsers[bundleID] {
            let needles = Self.closeNeedles(site: ctx.site, windowTitle: ctx.windowTitle)
            let result = BrowserTabScanner.closeTabs(
                appName: appName,
                isSafari: bundleID == "com.apple.Safari",
                needles: needles
            )
            if result.closedCount > 0 {
                closeNeedsAutomationPermission = false
                lastCloseFeedback = "Closed \(result.closedCount) tab\(result.closedCount == 1 ? "" : "s")."
                blocked = false // Clear blocked state after successful close
            } else if result.automationDenied {
                closeNeedsAutomationPermission = true
                lastCloseFeedback = "Need Automation permission for \(appName) — click “Open Settings”, allow FocusMac, then try again."
            } else {
                closeNeedsAutomationPermission = false
                quitApp(pid: pid_t(ctx.pid), name: appName, reason: "Couldn't match the tab — asked \(appName) to quit.")
            }
            invalidateDistractionCaches()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.tick() }
        } else {
            quitApp(pid: pid_t(ctx.pid), name: ctx.appName, reason: nil)
            invalidateDistractionCaches()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.tick() }
        }
    }

    private func quitApp(pid: pid_t, name: String, reason: String?) {
        let app = NSRunningApplication(processIdentifier: pid)
        if let app = app {
            app.terminate()
            lastCloseFeedback = reason ?? "Asked \(name) to quit."
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + 1.2,
                execute: DispatchWorkItem {
                    if !app.isTerminated { 
                        app.forceTerminate()
                        DispatchQueue.main.async {
                            self.lastCloseFeedback = "Force quit \(name)."
                        }
                    }
                }
            )
        } else {
            lastCloseFeedback = "Couldn't reach \(name)."
        }
    }

    func goBackFromDistraction() {
        guard let ctx = monitor.snapshot(), ctx.isBrowser,
              let bundleID = ctx.bundleID,
              let appName = Self.closeableBrowsers[bundleID] else {
            lastCloseFeedback = "Go back works only in Chrome, Brave, Arc, Edge and Safari."
            return
        }
        let ok = BrowserTabScanner.goBack(appName: appName, isSafari: bundleID == "com.apple.Safari")
        if ok {
            closeNeedsAutomationPermission = false
            lastCloseFeedback = "Went back — now get to \(planTitle)."
            blocked = false // Clear blocked state after successful navigation
        } else if bundleID != "com.apple.Safari" {
            closeNeedsAutomationPermission = true
            lastCloseFeedback = "Need Automation permission for \(appName) — click “Open Settings”, allow FocusMac, then try again."
        } else {
            lastCloseFeedback = "Safari needs “Allow JavaScript from Apple Events” (Develop menu) to go back."
        }
        invalidateDistractionCaches()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.tick() }
    }

    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Model configuration

    func currentProvider() -> ModelProviding? {
        ProviderFactory.make(modelConfig)
    }

    func resetModelStatus() {
        modelStatus = .idle
    }

    func updateModelConfig(_ config: ModelConfig) {
        let visionChanged = config.resolvedVisionModelName() != modelConfig.resolvedVisionModelName()
        modelConfig = config
        sessionManager.store.state.model = config
        sessionManager.store.save()
        semanticCache.removeAll()
        if visionChanged {
            resolvedVisionModel = nil
        }
    }

    func testConnection() async {
        modelStatus = .testing
        guard modelConfig.isConfigured else {
            modelStatus = .failed("Enter your \(modelConfig.provider.label) API key first.")
            return
        }
        guard let provider = currentProvider() else {
            modelStatus = .failed("Enter an API key for the selected provider first.")
            return
        }
        do {
            let result = try await provider.testConnection()
            modelStatus = .success(result)
        } catch ProviderError.serverNotRunning {
            modelStatus = .failed("Ollama is not running. Install it below or launch the Ollama app.")
        } catch ProviderError.httpStatus(_, let message) {
            modelStatus = .failed("Connection failed: \(message)")
        } catch {
            modelStatus = .failed("Connection failed: \(error.localizedDescription)")
        }
    }

    func refreshOllamaStatus() async {
        let running = await OllamaManager.isServerRunning()
        ollamaServerRunning = running
        guard running, modelConfig.provider == .ollama, modelStatus == .idle else { return }
        let models = await ollamaManager.listModels()
        if !models.contains(modelConfig.resolvedModelName()) {
            modelStatus = .failed("Model '\(modelConfig.resolvedModelName())' is not installed. Configure below.")
        }
    }

    func listOllamaModels() async -> [String] {
        await ollamaManager.listModels()
    }

    func installOllama() async throws {
        modelStatus = .configuring(.downloading(0))
        try await ollamaManager.configure(model: modelConfig.resolvedModelName()) { progress in
            self.modelStatus = .configuring(progress)
        }
        ollamaServerRunning = true
    }

    // MARK: - Semantic classification

    private func fetchSemanticIfNeeded(_ ctx: ActivityContext, key: String, provider: ModelProviding) {
        if let last = lastSemanticAttempt, Date().timeIntervalSince(last) < 10 { return }
        guard !semanticInFlight.contains(key) else { return }
        semanticInFlight.insert(key)
        lastSemanticAttempt = Date()
        Task {
            let result = try? await provider.classifyText(
                title: ctx.windowTitle ?? "",
                goalTitle: self.planTitle
            )
            await MainActor.run {
                if let result = result {
                    self.storeClassification(result, for: key)
                }
                semanticInFlight.remove(key)
            }
        }
    }

    private func storeClassification(_ classification: Classification, for key: String) {
        if semanticCache.count >= 500 {
            semanticCache.removeAll(keepingCapacity: false)
        }
        semanticCache[key] = classification
    }

    private func visionCheck(ctx: ActivityContext, key: String) {
        guard sessionActive,
              let provider = currentProvider() else { return }
        guard semanticCache[key] == nil else { return }
        if let last = lastVisionAttempt, Date().timeIntervalSince(last) < 60 { return }
        lastVisionAttempt = Date()
        Task {
            guard let visionProvider = await self.visionProvider(base: provider) else { return }
            guard let base64 = ScreenCapture.captureFrontmostWindowBase64(forPID: ctx.pid) else { return }
            let result = try? await visionProvider.classifyVision(
                imageBase64: base64,
                goalTitle: self.planTitle,
                context: "App: \(ctx.appName)\(ctx.windowTitle.map { ", title: \($0)" } ?? "")"
            )
            await MainActor.run {
                if let result = result, semanticCache[key] == nil {
                    self.storeClassification(result, for: key)
                }
            }
        }
    }

    private var resolvedVisionModel: String?

    private func visionProvider(base: ModelProviding) async -> ModelProviding? {
        guard let ollama = base as? OllamaProvider else { return base }
        let desired = modelConfig.resolvedVisionModelName()
        if ollama.visionModel == desired || resolvedVisionModel == ollama.visionModel {
            return base
        }
        guard let resolved = await ollamaManager.resolveVisionModel(preferred: desired) else { return nil }
        resolvedVisionModel = resolved
        return OllamaProvider(modelName: ollama.modelName, visionModel: resolved)
    }

    // MARK: - Updates

    @Published private(set) var latestVersion: String?
    @Published private(set) var updateAssetURL: URL?
    @Published private(set) var checkingUpdate = false
    @Published private(set) var installingUpdate = false
    /// Set right before the auto-update relaunches the app so the quit path
    /// skips the password gate.
    var skipPasswordForNextQuit = false

    static let releasesURL = URL(string: "https://api.github.com/repos/aadityakumarsah/FocusMac/releases/latest")!
    static let releasesPageURL = URL(string: "https://github.com/aadityakumarsah/FocusMac/releases")!

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var updateAvailable: Bool { latestVersion != nil }

    func checkForUpdates() async {
        guard !checkingUpdate, !installingUpdate else { return }
        checkingUpdate = true
        defer { checkingUpdate = false }
        do {
            var request = URLRequest(url: Self.releasesURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 15
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let release = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = release["tag_name"] as? String else { return }
            let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            guard Self.isVersion(version, newerThan: currentVersion) else {
                latestVersion = nil
                return
            }
            // Prefer a full app zip; fall back to DMG. Avoid tiny stub assets.
            var best: URL?
            if let assets = release["assets"] as? [[String: Any]] {
                for asset in assets {
                    guard let name = asset["name"] as? String,
                          let urlStr = asset["browser_download_url"] as? String,
                          let url = URL(string: urlStr) else { continue }
                    let lower = name.lowercased()
                    if lower == "focusmac.zip" || (lower.hasPrefix("focusmac") && lower.hasSuffix(".zip")) {
                        best = url
                        break
                    }
                    if best == nil, lower == "focusmac.dmg" || lower.hasSuffix(".dmg") {
                        best = url
                    }
                }
            }
            updateAssetURL = best
            latestVersion = version
        } catch {
            // Offline or rate-limited — silently retry on the next poll.
        }
    }

    /// Downloads the release app, swaps /Applications/FocusMac.app in place and
    /// relaunches. Quarantine is cleared so Gatekeeper won’t false-flag the update.
    func installUpdate() async {
        guard let url = updateAssetURL, !installingUpdate else { return }
        installingUpdate = true
        defer { installingUpdate = false }
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("FocusMacUpdate", isDirectory: true)
        let isDMG = url.pathExtension.lowercased() == "dmg"
        let packageURL = tmpDir.appendingPathComponent(isDMG ? "FocusMac-update.dmg" : "FocusMac-update.zip")
        let extractDir = tmpDir.appendingPathComponent("extracted")
        do {
            try? FileManager.default.removeItem(at: tmpDir)
            try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
            let (data, _) = try await URLSession.shared.data(from: url)
            try data.write(to: packageURL)
            try? runProcess("/usr/bin/xattr", ["-cr", packageURL.path])

            let srcApp: String
            if isDMG {
                let mount = "/Volumes/FocusMacUpdate"
                try? runProcess("/usr/bin/hdiutil", ["detach", mount, "-quiet"])
                try runProcess("/usr/bin/hdiutil", [
                    "attach", packageURL.path, "-nobrowse", "-quiet", "-mountpoint", mount
                ])
                defer { try? runProcess("/usr/bin/hdiutil", ["detach", mount, "-quiet"]) }
                srcApp = "\(mount)/FocusMac.app"
                guard FileManager.default.fileExists(atPath: srcApp) else { return }
            } else {
                try runProcess("/usr/bin/ditto", ["-x", "-k", packageURL.path, extractDir.path])
                guard let newApp = (try? FileManager.default.contentsOfDirectory(atPath: extractDir.path))?
                    .first(where: { $0.hasSuffix(".app") }) else { return }
                srcApp = extractDir.appendingPathComponent(newApp).path
            }

            let dst = "/Applications/FocusMac.app"
            let old = "/Applications/FocusMac.old"
            try? runProcess("/bin/rm", ["-rf", old])
            if FileManager.default.fileExists(atPath: dst) {
                try runProcess("/bin/mv", [dst, old])
            }
            try runProcess("/usr/bin/ditto", [srcApp, dst])
            try? runProcess("/usr/bin/xattr", ["-cr", dst])
            try? runProcess("/bin/rm", ["-rf", old])
            skipPasswordForNextQuit = true
            try runProcess("/usr/bin/open", [dst])
            exit(0)
        } catch {
            passwordMessage = "Update failed: \(error.localizedDescription)"
        }
    }

    private func runProcess(_ path: String, _ args: [String]) throws -> Void {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw NSError(domain: "FocusMacUpdate", code: Int(proc.terminationStatus))
        }
    }

    private static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let pa = a.split(separator: ".").compactMap { Int($0) }
        let pb = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    // MARK: - State mirroring

    private func apply(_ snap: SessionSnapshot, animateXP: Bool) {
        sessionActive = snap.session?.isActive == true
        trackingEnabled = sessionManager.trackingEnabled
        currentActivity = snap.activity
        classification = snap.classification
        let effectivePhase: DistractionPhase
        if !sessionActive {
            // Before the user starts a session (setup phase) the app only
            // monitors — nothing is blocked and no alarms fire.
            effectivePhase = .focused
        } else if snap.phase == .blocked && blockedStreak < 2 {
            effectivePhase = .focused
        } else {
            effectivePhase = snap.phase
        }
        blockedStreak = snap.phase == .blocked && sessionActive ? blockedStreak + 1 : 0
        phase = effectivePhase
        if effectivePhase != .blocked {
            lastCloseFeedback = nil
            closeNeedsAutomationPermission = false
            blocked = false
        } else {
            blocked = true
        }
        timeline = snap.timeline
        xpToday = Int(snap.day.xp)
        xpSession = Int(snap.session?.xp ?? 0)
        totalXP = Int(snap.totalXP)
        focusedToday = snap.day.focusedTime
        distractedToday = snap.day.distractionTime
        sessionDuration = snap.session?.duration ?? 0
        insight = snap.insight
        warningDuration = snap.warningDuration
        currentScheduleBlock = snap.scheduled
        if snap.xpGain != 0, animateXP {
            lastXPGain = snap.xpGain
            clearXPGainSoon()
        }
        score = computeScore(snap)
        refreshLifelineState()
    }

    private func clearXPGainSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.lastXPGain != 0 else { return }
            self.lastXPGain = 0
        }
    }

    private func computeScore(_ snap: SessionSnapshot) -> Int {
        let focused = snap.day.focusedTime
        let distracted = snap.day.distractionTime
        guard focused + distracted > 90 else { return 0 }
        let ratio = focused / max(focused + distracted, 1)
        var score = Int(40 + 60 * ratio)
        if ratio > 0.8 {
            score += min(10, Int(focused / 900))
        }
        return min(100, score)
    }
}
