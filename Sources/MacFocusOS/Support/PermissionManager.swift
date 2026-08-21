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
}
