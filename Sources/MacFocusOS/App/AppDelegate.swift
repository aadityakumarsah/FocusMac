import AppKit
import Combine
import SwiftUI
import MacFocusOSCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    let manager = AppStateManager()

    private var blockPanel: NSPanel?
    private var dashboardWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private var startMenuItem: NSMenuItem?
    private var toastWindow: NSWindow?
    private var toastTimer: Timer?
    private var cameraPanel: NSPanel?
    private var cameraPanelTimer: Timer?
    private var panelVisible = false
    private var passwordPanel: NSPanel?
    private var passwordPromptMessage = ""
    private var quitApproved = false
    private var quitRequested = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupBlockOverlay()
        setupStatusItem()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            BrowserTabScanner.primeAutomationPermissions()
        }

        manager.onRequestDashboard = { [weak self] in
            self?.showDashboard()
        }

        manager.onRequestSettings = { [weak self] in
            self?.showSettings()
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

        manager.$sessionActive
            .sink { [weak self] active in
                guard let self else { return }
                self.startMenuItem?.title = active ? "End Focus Session" : "Start Focus Session"
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
            button.image = NSImage(systemSymbolName: "target", accessibilityDescription: "Mac Focus OS")
            button.imagePosition = .imageOnly
        }
        let menu = NSMenu()
        let header = NSMenuItem(title: "Mac Focus OS", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "d"))
        menu.items.last?.keyEquivalentModifierMask = [.command]
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(settingsItem)
        startMenuItem = NSMenuItem(title: "Start Focus Session", action: #selector(toggleSession), keyEquivalent: "s")
        menu.addItem(startMenuItem!)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Mac Focus OS", action: #selector(quitApp), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func showDashboard() {
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
        window.title = "Mac Focus OS"
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
        if quitApproved {
            return .terminateNow
        }
        if manager.passwordSet, manager.passwordLocked {
            quitRequested = true
            showPasswordPrompt(message: "Enter your password to quit Mac Focus OS.")
            return .terminateCancel
        }
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
            panel.title = "Mac Focus OS — Password Required"
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

    @objc private func toggleSession() {
        if manager.sessionActive {
            manager.endSession()
        } else {
            manager.startSession()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - NSWindowDelegate

    /// Closing the password prompt with the ✕ button must cancel whatever was
    /// pending (including a quit request) — otherwise a later successful unlock
    /// could terminate the app during an unrelated action.
    func windowWillClose(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel, panel == passwordPanel else { return }
        quitRequested = false
        manager.cancelPendingProtectedAction()
    }
}
