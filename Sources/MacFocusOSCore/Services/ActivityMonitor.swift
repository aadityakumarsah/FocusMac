import AppKit
import CoreGraphics
import Foundation

public final class ActivityMonitor {
    private var frontmost: (pid: pid_t, app: String, bundle: String?)?

    public static var hasScreenCapturePermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    public init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        frontmost = (app.processIdentifier, app.localizedName ?? "Unknown", app.bundleIdentifier)
    }

    public func snapshot() -> ActivityContext? {
        var app = frontmost
        if app == nil || appIsStillFrontmost(app!.pid) == false {
            if let running = NSWorkspace.shared.runningApplications.first(where: { $0.isActive }) {
                app = (running.processIdentifier, running.localizedName ?? "Unknown", running.bundleIdentifier)
                frontmost = app
            }
        }
        guard let app = app, Int(app.pid) != ProcessInfo.processInfo.processIdentifier else { return nil }
        let title = windowTitle(forPID: Int(app.pid))
        let browser = Browser.from(bundleID: app.bundle) ?? Browser.from(windowTitle: title)
        let parsed = WindowTitleParser.parse(title: title, browser: browser)
        return ActivityContext(
            pid: Int(app.pid),
            appName: app.app,
            bundleID: app.bundle,
            windowTitle: parsed.pageTitle ?? title,
            site: parsed.site,
            browser: browser,
            isBrowser: browser != nil
        )
    }

    private func appIsStillFrontmost(_ pid: pid_t) -> Bool {
        NSWorkspace.shared.runningApplications.first(where: { $0.isActive })?.processIdentifier == pid
    }

    private func windowTitle(forPID pid: Int) -> String? {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        var best: (String, Double)?
        for window in list {
            guard (window[kCGWindowOwnerPID as String] as? Int) == pid,
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let name = window[kCGWindowName as String] as? String,
                  !name.isEmpty else { continue }
            let bounds = window[kCGWindowBounds as String] as? [String: Any]
            let width = (bounds?["Width"] as? NSNumber)?.doubleValue ?? 0
            let height = (bounds?["Height"] as? NSNumber)?.doubleValue ?? 0
            let area = width * height
            if let existing = best {
                if area > existing.1 { best = (name, area) }
            } else {
                best = (name, area)
            }
        }
        return best?.0
    }
}
