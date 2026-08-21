import AppKit
import Foundation
import MacFocusOSCore

final class MouseActivityMonitor {
    private var eventMonitor: Any?
    private var idleTimer: Timer?
    private var lastActivity = Date()
    private var idleStart: Date?
    private(set) var idleEvents: [MouseIdleEvent] = []
    var onIdleClosed: ((MouseIdleEvent) -> Void)?
    let idleThreshold: TimeInterval

    init(threshold: TimeInterval = 180) {
        self.idleThreshold = threshold
    }

    func start() {
        stop()
        lastActivity = Date()
        idleStart = nil
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .scrollWheel, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
        ]) { [weak self] _ in
            self?.registerActivity()
        }
        let t = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            self?.evaluate()
        }
        RunLoop.main.add(t, forMode: .common)
        idleTimer = t
    }

    func stop() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
        idleTimer?.invalidate()
        idleTimer = nil
    }

    private func registerActivity() {
        lastActivity = Date()
        if let idleStart {
            let duration = lastActivity.timeIntervalSince(idleStart)
            if duration >= idleThreshold {
                let event = MouseIdleEvent(start: idleStart, end: lastActivity, duration: duration)
                idleEvents.append(event)
                idleEvents = idleEvents.filter { $0.end > Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? $0.end }
                onIdleClosed?(event)
            }
            self.idleStart = nil
        }
    }

    private func evaluate() {
        let now = Date()
        if now.timeIntervalSince(lastActivity) > idleThreshold, idleStart == nil {
            idleStart = lastActivity
        }
    }
}