import SwiftUI
import MacFocusOSCore

/// First-run setup wizard. The user must complete every step before the
/// session can start:
///   1. Password lock        2. Weekly schedule
///   3. One-click permissions 4. AI provider key
/// After finishing, sessions auto-start on every launch and permissions are
/// never requested again.
struct OnboardingView: View {
    var onFinish: () -> Void
    @ObservedObject var manager: AppStateManager
    @Environment(\.colorScheme) private var scheme

    @State private var step = 0
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var quickAdd = ""
    @State private var scheduleFeedback = ""
    @State private var screenAsked = false
    @State private var cameraAsked = false
    @State private var selectedProvider: ModelProviderKind = .ollama
    @State private var apiKey = ""
    @State private var testing = false
    @State private var autoTestTask: Task<Void, Never>?
    // Ticking state forces permission checks to re-evaluate live.
    @State private var statusTick = Date()

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let steps = ["Password", "Schedule", "Permissions", "AI Key", "Start"]

    private var palette: AppPalette { AppPalette.current(scheme) }

    private var passwordDone: Bool { manager.passwordSet }
    private var scheduleDone: Bool { manager.scheduleCount > 0 }
    private var screenGranted: Bool { PermissionManager.screenGranted }
    private var cameraGranted: Bool { PermissionManager.cameraGranted }
    private var permissionsDone: Bool { screenGranted && cameraGranted }

    private var aiDone: Bool {
        if selectedProvider == .ollama { return manager.ollamaServerRunning }
        return !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var allDone: Bool { passwordDone && scheduleDone && permissionsDone && aiDone }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            stepBar
            Group {
                switch step {
                case 0: passwordStep
                case 1: scheduleStep
                case 2: permissionsStep
                case 3: aiStep
                default: startStep
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            navButtons
        }
        .padding(22)
        .frame(width: 470)
        .background(palette.card.opacity(scheme == .dark ? 0.98 : 0.99))
        .onReceive(clock) { _ in statusTick = Date() }
        .onAppear { loadConfig() }
        .onDisappear { autoTestTask?.cancel() }
    }

    // MARK: - Chrome

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Welcome to FocusMac")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(palette.text)
            Text("Five quick steps, once. After this the app guards you forever — no coming back without your password.")
                .font(.system(size: 11))
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stepBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<steps.count, id: \.self) { i in
                HStack(spacing: 5) {
                    Circle()
                        .fill(i < step ? palette.aligned : (i == step ? palette.accent : palette.secondary.opacity(0.3)))
                        .frame(width: 8, height: 8)
                    if i == step {
                        Text(steps[i])
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(palette.text)
                    }
                }
                if i < steps.count - 1 {
                    Rectangle().fill(palette.border).frame(height: 1).frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var navButtons: some View {
        HStack {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(FocusActionStyle(filled: false, tint: palette.secondary))
            }
            Spacer()
            if step < steps.count - 1 {
                Button("Continue") { step += 1 }
                    .buttonStyle(FocusActionStyle(filled: true, tint: palette.accent))
            }
        }
    }

    // MARK: - Step 1: Password

    private var passwordStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepTitle("Set your lock password",
                      "Quitting FocusMac, disabling checks — everything requires this. It can never be removed or recovered; only changed while unlocked. Forget it and only the developer can help.")
            if passwordDone {
                doneRow("Password set — stored forever")
            } else {
                SecureField("Choose a password", text: $newPassword).fieldStyle(palette)
                SecureField("Confirm password", text: $confirmPassword).fieldStyle(palette)
                Button("Set Password") {
                    guard newPassword == confirmPassword else {
                        manager.passwordMessage = "Passwords do not match."
                        return
                    }
                    if manager.setPassword(newPassword) {
                        newPassword = ""
                        confirmPassword = ""
                    }
                }
                .buttonStyle(FocusActionStyle(filled: true, tint: palette.accent))
                .disabled(newPassword.isEmpty || confirmPassword.isEmpty)
                if !manager.passwordMessage.isEmpty {
                    Text(manager.passwordMessage)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(manager.passwordMessage.contains("match") ? palette.misaligned : palette.aligned)
                }
            }
        }
    }

    // MARK: - Step 2: Schedule

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepTitle("Add your weekly schedule",
                      "FocusMac analyses all blocks and enforces focus during work/study automatically — and stays out of the way during free time, breaks and meals.")
            HStack(spacing: 8) {
                TextField("e.g. Study system design 9am-1pm mon-fri", text: $quickAdd)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(9)
                    .background(fieldBackground(palette))
                    .onSubmit(addQuickBlock)
                Button("Add") { addQuickBlock() }
                    .buttonStyle(FocusActionStyle(filled: true, tint: palette.accent))
                    .disabled(quickAdd.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ScheduleParser.presetBlocks(), id: \.title) { preset in
                        let exists = manager.schedule.contains { $0.title == preset.title }
                        Button {
                            manager.addScheduleBlock(preset)
                            scheduleFeedback = ""
                        } label: {
                            Text("+ \(preset.title)")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(exists ? palette.aligned : palette.accent)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill((exists ? palette.aligned : palette.accent).opacity(0.12)))
                                .overlay(Capsule().stroke((exists ? palette.aligned : palette.accent).opacity(0.35), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !scheduleFeedback.isEmpty {
                Text(scheduleFeedback)
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.misaligned)
            }
            doneRow(scheduleDone ? "\(manager.scheduleCount) block\(manager.scheduleCount == 1 ? "" : "s") on your schedule" : "Add at least one block to continue")
        }
    }

    private func addQuickBlock() {
        let text = quickAdd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = ScheduleParser.parse(text) else {
            scheduleFeedback = "Couldn't read that — try e.g. “Study 9am-1pm mon-fri”."
            return
        }
        let detected = ScheduleActivityType.detect(from: parsed.title)
        let block = ScheduleBlock(
            title: parsed.title,
            type: detected,
            startMinutes: parsed.startMinutes,
            endMinutes: parsed.endMinutes,
            days: parsed.days
        )
        manager.addScheduleBlock(block)
        quickAdd = ""
        scheduleFeedback = ""
    }

    // MARK: - Step 3: Permissions

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepTitle("Enable everything — one click",
                      "FocusMac requests Screen Recording, Camera and Browser Automation back-to-back. macOS shows each popup once; approve them and you'll never be asked again.")
            Button {
                enableEverything()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Enable Everything — 1 Click")
                        .font(.system(size: 12.5, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
            }
            .buttonStyle(FocusActionStyle(filled: true, tint: palette.accent))
            .disabled(permissionsDone)

            permRow(icon: "rectangle.badge.record", title: "Screen Recording",
                    granted: screenGranted, palette: palette)
            permRow(icon: "video.fill", title: "Camera",
                    granted: cameraGranted, palette: palette)
            permRow(icon: "app.connected", title: "Browser Control",
                    granted: nil, palette: palette)

            if screenAsked && !screenGranted {
                VStack(alignment: .leading, spacing: 3) {
                    Label("In System Settings → Privacy & Security → Screen Recording, switch ON “FocusMac”.", systemImage: "lightbulb")
                    Label("Not listed? Click  +  and add it from Applications.", systemImage: "plus.circle")
                    Button("Reset & re-request") {
                        PermissionManager.resetScreenPermission()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            PermissionManager.requestScreen()
                        }
                    }
                    .buttonStyle(FocusActionStyle(filled: false, tint: palette.warn))
                }
                .font(.system(size: 10))
                .foregroundStyle(palette.warn)
            }
            Button("Open System Settings") {
                PermissionManager.openPrivacyPane("Privacy_ScreenCapture")
            }
            .buttonStyle(FocusActionStyle(filled: false, tint: palette.secondary))
            .font(.system(size: 11))
        }
    }

    private func enableEverything() {
        PermissionManager.requestScreen()
        screenAsked = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            cameraAsked = true
            PermissionManager.requestCamera { granted in
                if !granted { PermissionManager.openPrivacyPane("Privacy_Camera") }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            PermissionManager.primeAutomation()
        }
    }

    // MARK: - Step 4: AI key

    private var aiStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepTitle("Pick the AI that reads your activity",
                      "Paste an API key for any provider — it's detected and tested automatically. Or run fully local with Ollama, no key needed.")
            Picker("", selection: $selectedProvider) {
                ForEach(ModelProviderKind.allCases) { kind in
                    Label(kind.label, systemImage: kind.icon).tag(kind)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedProvider) { _ in pushConfig() }
            if selectedProvider.requiresKey {
                SecureField(selectedProvider.keyPlaceholder, text: $apiKey)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(9)
                    .background(fieldBackground(palette))
                    .onChange(of: apiKey) { _ in
                        pushConfig()
                        if let detected = distinctDetection, detected != selectedProvider {
                            selectedProvider = detected
                            return
                        }
                        scheduleAutoTest()
                    }
                Text(selectedProvider.keyHint)
                    .font(.system(size: 10))
                    .foregroundStyle(palette.secondary.opacity(0.85))
            }
            if selectedProvider == .ollama {
                HStack(spacing: 8) {
                    Circle()
                        .fill(manager.ollamaServerRunning ? palette.aligned : palette.misaligned)
                        .frame(width: 7, height: 7)
                    Text(manager.ollamaServerRunning ? "Ollama running locally" : "Ollama not running")
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.secondary)
                    Spacer()
                    Button(manager.modelStatus.isInstalling ? "Installing…" : "Install Ollama") {
                        Task { await manager.installOllama() }
                    }
                    .buttonStyle(FocusActionStyle(filled: true, tint: palette.accent))
                    .disabled(manager.modelStatus.isInstalling || manager.ollamaServerRunning)
                }
            }
            HStack {
                Spacer()
                Button(testing ? "Testing…" : "Test Connection") {
                    Task { await runTest() }
                }
                .buttonStyle(FocusActionStyle(filled: true, tint: palette.accent))
                .disabled(testing)
            }
            statusLine
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch manager.modelStatus {
        case .testing:
            Label("Testing connection…", systemImage: "hourglass").font(.system(size: 11)).foregroundStyle(palette.secondary)
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(palette.aligned)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill").font(.system(size: 11)).foregroundStyle(palette.misaligned)
        default:
            EmptyView()
        }
    }

    private var distinctDetection: ModelProviderKind? {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.hasPrefix("sk-ant-") { return .anthropic }
        if key.hasPrefix("sk-or-") { return .openrouter }
        if key.hasPrefix("AIza") { return .gemini }
        if key.hasPrefix("gsk_") { return .groq }
        return nil
    }

    private func scheduleAutoTest() {
        autoTestTask?.cancel()
        guard selectedProvider.requiresKey, !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        autoTestTask = Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            await runTest()
        }
    }

    private func loadConfig() {
        selectedProvider = manager.modelConfig.provider
        apiKey = manager.modelConfig.trimmedKey
    }

    private func pushConfig() {
        var config = manager.modelConfig
        config.provider = selectedProvider
        config.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        manager.updateModelConfig(config)
    }

    private func runTest() async {
        autoTestTask?.cancel()
        pushConfig()
        testing = true
        await manager.testConnection()
        testing = false
    }

    // MARK: - Step 5: Start

    private var startStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepTitle("You're set.",
                      "Once you press Start, FocusMac locks in: quitting needs your password, focus enforcement follows your schedule, and the camera keeps you honest. There is no off switch.")
            checklistRow("Password lock", passwordDone, palette: palette)
            checklistRow("Weekly schedule (\(manager.scheduleCount) blocks)", scheduleDone, palette: palette)
            checklistRow("Screen Recording", screenGranted, palette: palette)
            checklistRow("Camera", cameraGranted, palette: palette)
            checklistRow("AI configured", aiDone, palette: palette)
            Button {
                PermissionManager.primeAutomation()
                manager.markPermissionsRequested()
                manager.startSession()
                onFinish()
            } label: {
                Text("Start Session — No Coming Back")
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(FocusActionStyle(filled: true, tint: palette.misaligned))
            .disabled(!allDone)
            if !allDone {
                Text("Complete every step above to unlock the start button.")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.secondary.opacity(0.8))
            }
        }
    }

    // MARK: - Small pieces

    private func stepTitle(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14.5, weight: .bold))
                .foregroundStyle(palette.text)
            Text(detail)
                .font(.system(size: 10.5))
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func doneRow(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(palette.aligned)
    }

    private func checklistRow(_ text: String, _ done: Bool, palette: AppPalette) -> some View {
        HStack(spacing: 7) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 11))
                .foregroundStyle(done ? palette.aligned : palette.secondary.opacity(0.5))
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(done ? palette.text : palette.secondary)
        }
    }

    private func permRow(icon: String, title: String, granted: Bool?, palette: AppPalette) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(granted == true ? palette.aligned : palette.accent)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.text)
            Spacer()
            if granted == true {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.aligned)
            } else if granted == false {
                Text("pending")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(palette.warn)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 9).fill(palette.background.opacity(0.45)))
    }

    private func fieldBackground(_ palette: AppPalette) -> some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(palette.background.opacity(0.5))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(palette.border, lineWidth: 1))
    }
}

extension ModelStatus {
    var isInstalling: Bool {
        if case .configuring = self { return true }
        return false
    }
}

private extension View {
    func fieldStyle(_ palette: AppPalette) -> some View {
        self
            .textFieldStyle(.plain)
            .font(.system(size: 12.5))
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(palette.background.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(palette.border, lineWidth: 1))
            )
    }
}
