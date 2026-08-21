import AppKit
import Combine
import Dispatch
import SwiftUI
import UserNotifications
import MacFocusOSCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    let manager = AppStateManager()

    private var blockPanel: NSPanel?
    private var dashboardWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private var toastWindow: NSWindow?
    private var toastTimer: Timer?
    private var cameraPanel: NSPanel?
    private var cameraPanelTimer: Timer?
    private var panelVisible = false
    private var passwordPanel: NSPanel?
    private var passwordPromptMessage = ""
    private var quitApproved = false
    private var quitRequested = false
    private var onboardingWindow: NSWindow?

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .aqua)
        setupBlockOverlay()
        setupStatusItem()
        requestNotificationPermission()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.manager.ensureTrackingOn()
        }

        manager.onRequestDashboard = { [weak self] in
            self?.showDashboard()
        }

        manager.onRequestSettings = { [weak self] in
            self?.showSettings()
        }

        manager.onRequestSetup = { [weak self] in
            self?.showOnboarding()
        }

        manager.onFreeTimeNotice = { [weak self] title, message in
            self?.showToast(title: title, message: message)
        }

        manager.onRequirePassword = { [weak self] message in
            self?.showPasswordPrompt(message: message)
        }

        manager.$phase
            .sink { [weak self] phase in
                guard let self else { return }
                if phase == .blocked {
                    self.showBlockOverlay()
                } else {
                    self.blockPanel?.orderOut(nil)
                    self.blockPanel?.contentView = nil
                }
            }
            .store(in: &cancellables)

        manager.$cameraOverlay
            .sink { [weak self] overlay in
                guard let self else { return }
                if overlay.checking {
                    self.showCameraPanelIfNeeded()
                }
            }
            .store(in: &cancellables)

        manager.$attendanceEnabled
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    self.showCameraPanelIfNeeded()
                } else {
                    self.hideCameraPanel()
                }
            }
            .store(in: &cancellables)

        manager.$passwordSet
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshOnboardingClosable()
            }
            .store(in: &cancellables)

        // First launch: force the setup wizard (password first) before anything else.
        if !manager.setupComplete {
            DispatchQueue.main.async { [weak self] in
                self?.showOnboarding()
            }
        }

        setupSignalHandling()
    }

    /// Terminal kills (`kill <pid>`, Ctrl-C) must go through the same password
    /// gate as menu quits. Routing SIGTERM/SIGINT into NSApp.terminate makes
    /// applicationShouldTerminate run first; only SIGKILL is unstoppable.
    private func setupSignalHandling() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                NSApp.terminate(nil)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    private var signalSources: [DispatchSourceProtocol] = []

    private func showOnboarding() {
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        // Until a password exists, the window can’t be closed — fresh users must set one.
        var mask: NSWindow.StyleMask = [.titled]
        if manager.passwordSet {
            mask.insert(.closable)
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 470, height: 480),
            styleMask: mask,
            backing: .buffered,
            defer: false
        )
        window.title = manager.passwordSet ? "Welcome to FocusMac" : "Set your FocusMac password"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: OnboardingView(
            onFinish: { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
                self?.showDashboard()
            },
            manager: manager
        ))
        window.center()
        window.level = .floating
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// After the password is set, allow closing the wizard (other steps can resume later).
    private func refreshOnboardingClosable() {
        guard let window = onboardingWindow else { return }
        if manager.passwordSet {
            window.styleMask.insert(.closable)
            window.title = "Welcome to FocusMac"
        }
    }

    private func showCameraPanelIfNeeded() {
        guard !panelVisible, !manager.cameraPanelDismissed else { return }
        panelVisible = true
        let panel = cameraPanel ?? {
            let p = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 376, height: 320),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            p.level = .floating
            p.backgroundColor = .clear
            p.isOpaque = false
            p.hasShadow = false
            p.isReleasedWhenClosed = false
            p.hidesOnDeactivate = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            cameraPanel = p
            return p
        }()
        panel.contentView = NSHostingView(rootView: AttendanceLivePanelView(
            manager: manager,
            onClose: { [weak self] in
                self?.manager.dismissCameraPanel()
                self?.hideCameraPanel()
            }
        ))
        if let screen = NSScreen.main {
            let width: CGFloat = 376
            let height: CGFloat = 330
            panel.setContentSize(NSSize(width: width, height: height))
            panel.setFrameOrigin(NSPoint(
                x: screen.frame.maxX - width - 14,
                y: screen.frame.maxY - (screen.frame.height > 800 ? 30 : 10) - height
            ))
        }
        panel.orderFrontRegardless()
    }

    private func hideCameraPanel() {
        panelVisible = false
        cameraPanel?.orderOut(nil)
        cameraPanelTimer?.invalidate()
    }

    private func showToast(title: String, message: String) {
        let width: CGFloat = 430
        let height: CGFloat = 76
        let win = toastWindow ?? {
            let w = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            w.level = .floating
            w.backgroundColor = .clear
            w.isOpaque = false
            w.hasShadow = true
            w.isReleasedWhenClosed = false
            w.hidesOnDeactivate = false
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            toastWindow = w
            return w
        }()
        win.contentView = NSHostingView(rootView: FreeTimeToastView(title: title, message: message))
        win.setContentSize(NSSize(width: width, height: height))
        guard let screen = NSScreen.main else { return }
        win.setFrameOrigin(NSPoint(
            x: screen.frame.minX + (screen.frame.width - width) / 2,
            y: screen.frame.maxY - height - 10
        ))
        win.orderFrontRegardless()
        toastTimer?.invalidate()
        toastTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            self?.toastWindow?.orderOut(nil)
        }
    }

    private func setupBlockOverlay() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let panel = NSPanel(
            contentRect: screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        blockPanel = panel
    }

    private func showBlockOverlay() {
        guard let panel = blockPanel else { return }
        if let screen = NSScreen.main {
            panel.setFrame(screen.frame, display: true)
        }
        panel.contentView = NSHostingView(rootView: BlockingOverlayView(manager: manager))
        panel.orderFrontRegardless()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = Self.statusBarIcon()
            button.imagePosition = .imageOnly
        }
        let menu = NSMenu()
        let header = NSMenuItem(title: "FocusMac", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "d"))
        menu.items.last?.keyEquivalentModifierMask = [.command]
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem(title: "Check for Updates…", action: #selector(checkUpdates), keyEquivalent: "u"))
        menu.items.last?.keyEquivalentModifierMask = [.command]
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit FocusMac", action: #selector(quitApp), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    /// Menu-bar icon from the app logo. Rendered as a template image so macOS
    /// automatically paints it black on a light menu bar and white on a dark
    /// one (and highlights correctly when the menu opens).
    private static func statusBarIcon() -> NSImage? {
        guard let url = Bundle.module.url(forResource: "StatusIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return NSImage(systemSymbolName: "target", accessibilityDescription: "FocusMac")
        }
        let size = NSSize(width: 18, height: 18)
        let icon = NSImage(size: size, flipped: false) { rect in
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
            return true
        }
        icon.isTemplate = true
        icon.accessibilityDescription = "FocusMac"
        return icon
    }

    private func showDashboard() {
        // Fresh install: password first — don't open the dashboard yet.
        if !manager.passwordSet {
            showOnboarding()
            return
        }
        if let window = dashboardWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FocusMac"
        window.minSize = NSSize(width: 640, height: 560)
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.contentView = NSHostingView(rootView: DashboardView(manager: manager))
        window.center()
        window.setFrameAutosaveName("MacFocusOS.MainWindow")
        dashboardWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showSettings() {
        if !manager.passwordSet {
            showOnboarding()
            return
        }
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.minSize = NSSize(width: 480, height: 620)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(manager: manager))
        window.center()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if quitApproved || manager.skipPasswordForNextQuit {
            // Clean up resources before terminating
            manager.cleanup()
            return .terminateNow
        }
        if manager.passwordSet, manager.passwordLocked {
            quitRequested = true
            showPasswordPrompt(message: "FocusMac is locked — enter your password to quit.")
            return .terminateCancel
        }
        // Clean up resources before terminating
        manager.cleanup()
        return .terminateNow
    }

    private func showPasswordPrompt(message: String) {
        passwordPromptMessage = message
        if passwordPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 170),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            panel.title = "FocusMac — Password Required"
            panel.isReleasedWhenClosed = false
            panel.center()
            passwordPanel = panel
        }
        guard let panel = passwordPanel else { return }
        panel.delegate = self
        let hosting = NSHostingView(rootView: PasswordPromptView(
            message: passwordPromptMessage,
            onSubmit: { [weak self] password in
                guard let self else { return }
                if password.isEmpty {
                    self.quitRequested = false
                    self.manager.cancelPendingProtectedAction()
                    self.passwordPanel?.orderOut(nil)
                    return
                }
                if self.manager.verifyPassword(password) {
                    self.passwordPanel?.orderOut(nil)
                    let wasQuit = self.quitRequested
                    self.quitRequested = false
                    if wasQuit {
                        self.quitApproved = true
                        NSApp.terminate(nil)
                    } else {
                        self.manager.retryPendingProtectedAction()
                    }
                } else {
                    NSSound.beep()
                }
            }
        ))
        panel.contentView = hosting
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openDashboard() {
        showDashboard()
    }

    @objc private func openSettings() {
        showSettings()
    }

    @objc private func checkUpdates() {
        Task {
            await manager.checkForUpdates()
            if manager.updateAvailable {
                showDashboard()
            }
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - NSWindowDelegate

    /// Block closing the setup wizard until a password exists.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let onboardingWindow, sender == onboardingWindow, !manager.passwordSet {
            NSSound.beep()
            sender.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return false
        }
        return true
    }

    /// Closing the password prompt with the ✕ button must cancel whatever was
    /// pending (including a quit request) — otherwise a later successful unlock
    /// could terminate the app during an unrelated action. Closing the setup
    /// wizard early keeps setup incomplete so it reopens on next launch.
    func windowWillClose(_ notification: Notification) {
        guard let panel = notification.object as? NSWindow else { return }
        if let passwordPanel, panel == passwordPanel {
            quitRequested = false
            manager.cancelPendingProtectedAction()
        }
        if let onboardingWindow, panel == onboardingWindow {
            self.onboardingWindow = nil
        }
    }
}
