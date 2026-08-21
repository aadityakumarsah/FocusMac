import SwiftUI
import MacFocusOSCore

struct BlockingOverlayView: View {
    @ObservedObject var manager: AppStateManager
    @Environment(\.colorScheme) private var scheme
    @State private var nagCount = 0
    @State private var nagMessage = "Close this window and get back to your plan."
    @State private var now = Date()

    private var palette: AppPalette { AppPalette.current(scheme) }

    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var countdown: String {
        guard let block = manager.currentScheduleBlock else { return "" }
        let remaining = block.remainingDuration(at: now)
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }

    private static let templates: [(format: String, pausesMedia: Bool)] = [
        ("Close %1$@ and get back to %2$@.", false),
        ("Still on %1$@? Close it now.", false),
        ("We paused your media. Get back to %2$@.", true),
        ("%1$@ is stealing your focus. Close it.", true),
        ("Every 3 seconds on %1$@ costs you focus. Close it.", true),
        ("Your plan: %2$@. %1$@ can wait.", true),
        ("Stop scrolling. Close %1$@ now.", true)
    ]

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(scheme == .dark ? 0.5 : 0.28))
            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(palette.warn)
                Text("Focus mode is active")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(nagMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut(duration: 0.25), value: nagMessage)
                Text("Plan: \(manager.planTitle)")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(palette.text.opacity(0.8))
                if manager.currentScheduleBlock != nil {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.warn)
                        Text("Block ends in \(countdown)")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(palette.warn)
                    }
                }
                if nagCount > 1 {
                    Text("Warning #\(nagCount) — media paused")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(palette.warn)
                }
                HStack(spacing: 10) {
                    if manager.currentIsBrowser {
                        Button("Go Back") {
                            manager.goBackFromDistraction()
                        }
                        .buttonStyle(FocusActionStyle(filled: false, tint: palette.secondary))
                    }
                    Button("Close Tab / Quit App") {
                        manager.closeCurrentDistraction()
                    }
                    .buttonStyle(FocusActionStyle(filled: true, tint: palette.accent))
                }
                if manager.lifelinesRemaining > 0 {
                    Button("Use a Lifeline — 15 min free (\(manager.lifelinesRemaining) left today)") {
                        manager.useLifeline()
                    }
                    .buttonStyle(FocusActionStyle(filled: false, tint: palette.warn))
                } else {
                    Text("No lifelines left today — they reset tomorrow.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(palette.secondary.opacity(0.8))
                }
                if manager.closeNeedsAutomationPermission {
                    Button("Open Automation Settings") {
                        manager.openAutomationSettings()
                    }
                    .buttonStyle(FocusActionStyle(filled: true, tint: palette.warn))
                }
                Text(manager.lastCloseFeedback ?? "Only closes when you close it — no timer, no bypass.")
                    .font(.system(size: 10))
                    .foregroundStyle(
                        manager.lastCloseFeedback == nil
                            ? palette.secondary.opacity(0.8)
                            : palette.warn
                    )
            }
            .padding(28)
            .frame(width: 400)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(palette.background.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 30, y: 14)
        }
        .onReceive(timer) { _ in
            tick()
        }
        .onReceive(clock) { date in
            now = date
        }
    }

    private func tick() {
        guard manager.blocked else { return }
        nagCount += 1
        let template = Self.templates[(nagCount - 1) % Self.templates.count]
        let app = manager.currentActivity?.appName ?? "This app"
        nagMessage = String(format: template.format, app, manager.planTitle)
        if template.pausesMedia {
            MediaPauser.pauseAll()
        }
    }
}