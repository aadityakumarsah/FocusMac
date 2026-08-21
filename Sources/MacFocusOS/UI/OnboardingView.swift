import SwiftUI
import MacFocusOSCore

struct OnboardingView: View {
    var onFinish: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var enabling = false
    @State private var screenAsked = false
    @State private var cameraAsked = false
    // Ticking state forces the computed permission checks to re-evaluate so
    // rows flip to green the moment a grant lands.
    @State private var statusTick = Date()

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var palette: AppPalette { AppPalette.current(scheme) }

    private var screenGranted: Bool { PermissionManager.screenGranted }
    private var cameraGranted: Bool { PermissionManager.cameraGranted }

    private var allGranted: Bool { screenGranted && cameraGranted }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to FocusMac")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(palette.text)
                Text("One click below enables everything — screen awareness, camera attendance and browser control. You'll never be asked again.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                enableEverything()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: enabling ? "hourglass" : "wand.and.stars")
                        .font(.system(size: 13, weight: .semibold))
                    Text(enabling ? "Enabling… answer the popups" : "Enable Everything — 1 Click")
                        .font(.system(size: 13, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
            }
            .buttonStyle(FocusActionStyle(filled: true, tint: palette.accent))
            .disabled(enabling || allGranted)

            permissionRow(
                icon: "rectangle.badge.record",
                title: "Screen Recording",
                detail: "Reads window titles so the AI can guard your focus. Nothing is ever recorded or stored.",
                granted: screenGranted,
                actionTitle: screenGranted ? nil : (screenAsked ? "Open Settings" : "Allow"),
                action: { requestScreen() }
            )
            permissionRow(
                icon: "video.fill",
                title: "Camera",
                detail: "Powers attendance — left desk, looking away, phone detected. Frames stay on your Mac.",
                granted: cameraGranted,
                actionTitle: cameraGranted ? nil : (cameraAsked ? "Open Settings" : "Allow"),
                action: { requestCamera() }
            )
            permissionRow(
                icon: "app.connected",
                title: "Browser Control",
                detail: "Lets the app close distracting tabs in Chrome, Safari, Edge, Arc and Brave.",
                granted: nil,
                actionTitle: "Prime now",
                action: { PermissionManager.primeAutomation() }
            )

            if screenAsked && !screenGranted {
                VStack(alignment: .leading, spacing: 3) {
                    Label("In System Settings → Privacy & Security → Screen Recording, switch ON “FocusMac”.", systemImage: "lightbulb")
                    Label("Not in the list? Click  +  and add FocusMac from Applications, then restart this app.", systemImage: "plus.circle")
                }
                .font(.system(size: 10))
                .foregroundStyle(palette.warn)
                .fixedSize(horizontal: false, vertical: true)
            }
            if screenGranted && !cameraGranted && cameraAsked {
                Label("Camera: allow access in Privacy & Security → Camera if the popup was dismissed.", systemImage: "lightbulb")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.warn)
            }

            HStack {
                Spacer()
                Button(allGranted ? "Continue" : "Skip for now") {
                    PermissionManager.primeAutomation()
                    onFinish()
                }
                .buttonStyle(FocusActionStyle(filled: allGranted, tint: allGranted ? palette.aligned : palette.secondary))
            }
        }
        .padding(22)
        .frame(width: 440)
        .background(palette.card.opacity(scheme == .dark ? 0.98 : 0.99))
        .onReceive(clock) { date in
            statusTick = date
        }
    }

    /// Fires every permission request back-to-back; macOS queues the dialogs.
    private func enableEverything() {
        enabling = true
        PermissionManager.requestScreen()
        screenAsked = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            requestCamera()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            PermissionManager.primeAutomation()
            enabling = false
        }
    }

    private func permissionRow(
        icon: String,
        title: String,
        detail: String,
        granted: Bool?,
        actionTitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(rowTint(granted).opacity(0.13))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(rowTint(granted))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(palette.text)
                    if granted == true {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(palette.aligned)
                    }
                }
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(palette.secondary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if let actionTitle {
                Button(actionTitle) { action() }
                    .buttonStyle(FocusActionStyle(filled: false, tint: palette.accent))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 11).fill(palette.background.opacity(0.45)))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(palette.border, lineWidth: 1))
    }

    private func rowTint(_ granted: Bool?) -> Color {
        switch granted {
        case .some(true): return palette.aligned
        case .some(false): return palette.misaligned
        case .none: return palette.accent
        }
    }

    private func requestScreen() {
        if screenAsked {
            PermissionManager.openPrivacyPane("Privacy_ScreenCapture")
        } else {
            PermissionManager.requestScreen()
            screenAsked = true
        }
    }

    private func requestCamera() {
        cameraAsked = true
        PermissionManager.requestCamera { granted in
            if !granted {
                PermissionManager.openPrivacyPane("Privacy_Camera")
            }
        }
    }
}
