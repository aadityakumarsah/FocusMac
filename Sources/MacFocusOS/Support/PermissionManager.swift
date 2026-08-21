import AppKit
import AVFoundation
import CoreGraphics
import Foundation

enum PermissionManager {

    static var screenGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    static var cameraGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    /// Triggers the macOS Screen Recording prompt (or opens System Settings on
    /// newer versions where the dialog was removed).
    static func requestScreen() {
        _ = CGRequestScreenCaptureAccess()
    }

    static func requestCamera(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// Fires Apple Events at every running browser so macOS shows the
    /// Automation consent dialogs once, up front.
    static func primeAutomation() {
        BrowserTabScanner.primeAutomationPermissions()
    }

    static func openPrivacyPane(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Path of the running app bundle — shown so users can add it manually
    /// via the + button in System Settings.
    static var appPath: String {
        Bundle.main.bundleURL.path
    }

    /// Clears stale Screen Recording entries for this bundle id. Stale entries
    /// happen when the app was rebuilt (new signature) or renamed — macOS then
    /// keeps a dead row and never shows the prompt again.
    @discardableResult
    static func resetScreenPermission() -> Bool {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.focusmac.app"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        task.arguments = ["reset", "ScreenCapture", bundleID]
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    }
}
