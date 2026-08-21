import SwiftUI
import MacFocusOSCore

struct SettingsView: View {
    @ObservedObject var manager: AppStateManager
    @Environment(\.colorScheme) private var scheme
    @State private var selectedProvider: ModelProviderKind = .ollama
    @State private var apiKey = ""
    @State private var modelName = ""
    @State private var visionEnabled = false
    @State private var visionModel = ""
    @State private var ollamaModels: [String] = []
    @State private var testing = false
    @State private var installing = false
    @State private var autoTestTask: Task<Void, Never>?
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var currentPassword = ""
    @State private var changeNewPassword = ""
    @State private var changeConfirmPassword = ""

    private var palette: AppPalette { AppPalette.current(scheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                providerCard
                if selectedProvider == .ollama {
                    ollamaCard
                }
                visionCard
                cameraCard
                passwordCard
                statusLine
            }
            .padding(20)
        }
        .frame(width: 520, height: 700)
        .background(palette.background)
        .onAppear {
            loadFromConfig()
            Task {
                await refreshOllamaStatus()
            }
        }
        .onDisappear {
            autoTestTask?.cancel()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Settings")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(palette.text)
            Text("Pick the AI that reads your activity — paste a key, everything else is automatic.")
                .font(.system(size: 11.5))
                .foregroundStyle(palette.secondary)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .kerning(1)
            .foregroundStyle(palette.secondary)
    }

    private func cardBackground() -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(palette.card.opacity(scheme == .dark ? 0.55 : 0.9))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(palette.border, lineWidth: 1))
    }

    private func fieldBackground() -> some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(palette.background.opacity(0.5))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(palette.border, lineWidth: 1))
    }

    // MARK: - Provider card

    private var providerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("AI MODEL")

            VStack(alignment: .leading, spacing: 6) {
                Text("PROVIDER").font(.system(size: 8.5, weight: .bold)).kerning(0.6).foregroundStyle(palette.secondary)
                Picker("", selection: $selectedProvider) {
                    ForEach(ModelProviderKind.allCases) { kind in
                        Label(kind.label, systemImage: kind.icon)
                            .tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: selectedProvider) { _ in switchProvider() }
                Text(selectedProvider.keyHint)
                    .font(.system(size: 10))
                    .foregroundStyle(palette.secondary.opacity(0.8))
            }

            if selectedProvider.requiresKey {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("API KEY").font(.system(size: 8.5, weight: .bold)).kerning(0.6).foregroundStyle(palette.secondary)
                        Spacer()
                        detectionHint
                    }
                    SecureField(selectedProvider.keyPlaceholder, text: $apiKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .padding(9)
                        .background(fieldBackground())
                        .onChange(of: apiKey) { _ in apiKeyChanged() }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("MODEL").font(.system(size: 8.5, weight: .bold)).kerning(0.6).foregroundStyle(palette.secondary)
                TextField("default: \(ModelConfig.defaultModels[selectedProvider] ?? "")", text: $modelName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(9)
                    .background(fieldBackground())
                    .onChange(of: modelName) { _ in push() }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(selectedProvider.suggestedModels, id: \.self) { suggestion in
                            Button {
                                modelName = suggestion
                                push()
                            } label: {
                                Text(suggestion)
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(modelName == suggestion ? Color.white : palette.accent)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(modelName == suggestion ? palette.accent : palette.accent.opacity(0.12)))
                                    .overlay(Capsule().stroke(modelName == suggestion ? palette.accent : palette.accent.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button(testing ? "Testing…" : "Test Connection") {
                    Task { await runTest() }
                }
                .buttonStyle(FocusActionStyle(filled: true, tint: palette.accent))
                .disabled(testing || installing || (selectedProvider.requiresKey && trimmedKey.isEmpty))
            }
            Text(testHint)
                .font(.system(size: 10))
                .foregroundStyle(palette.secondary.opacity(0.8))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    private var trimmedKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var testHint: String {
        if selectedProvider == .ollama {
            return "Local Ollama runs on your Mac — the key field is not needed."
        }
        if trimmedKey.isEmpty {
            return "Paste your \(selectedProvider.label) key — it's detected and tested automatically."
        }
        return "The connection is tested automatically once you stop typing, or press Test Connection."
    }

    /// Only distinctive prefixes trigger an auto-switch; a bare "sk-" key could
    /// belong to OpenAI, Kimi, DeepSeek or OpenCode, so the user's pick wins there.
    private var distinctDetection: ModelProviderKind? {
        let key = trimmedKey
        if key.hasPrefix("sk-ant-") { return .anthropic }
        if key.hasPrefix("sk-or-") { return .openrouter }
        if key.hasPrefix("AIza") { return .gemini }
        if key.hasPrefix("gsk_") { return .groq }
        return nil
    }

    @ViewBuilder
    private var detectionHint: some View {
        if let detected = ModelProviderKind.detectProvider(for: trimmedKey) {
            let matches = detected == selectedProvider
            Label(detected.label, systemImage: matches ? "checkmark.circle.fill" : "arrow.triangle.swap")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(matches ? palette.aligned : palette.warn)
        } else if !trimmedKey.isEmpty {
            Label("Custom key — using \(selectedProvider.label)", systemImage: "checkmark.circle")
                .font(.system(size: 10))
                .foregroundStyle(palette.secondary.opacity(0.8))
        }
    }

    // MARK: - Ollama card

    private var ollamaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("LOCAL — OLLAMA")
            HStack(spacing: 8) {
                Circle()
                    .fill(manager.ollamaServerRunning ? palette.aligned : palette.misaligned)
                    .frame(width: 7, height: 7)
                Text(manager.ollamaServerRunning ? "Server running on localhost:11434" : "Server not running")
                    .font(.system(size: 11.5))
                    .foregroundStyle(manager.ollamaServerRunning ? palette.text : palette.secondary)
                Spacer()
                Button("Refresh") {
                    Task { await refreshOllamaStatus() }
                }
                .buttonStyle(FocusActionStyle(filled: false, tint: palette.secondary))
            }
            if !manager.ollamaServerRunning {
                Button(installing ? "Installing…" : "Install & Configure Ollama") {
                    Task { await runInstall() }
                }
                .buttonStyle(FocusActionStyle(filled: true, tint: palette.accent))
                .disabled(installing)
                Text("One click: downloads the Ollama app, installs it in /Applications, launches it, pulls the model, and tests it.")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.secondary.opacity(0.8))
            } else if !ollamaModels.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("INSTALLED MODELS").font(.system(size: 8.5, weight: .bold)).kerning(0.6).foregroundStyle(palette.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(ollamaModels, id: \.self) { name in
                                ChipView(text: name, tint: palette.accent)
                            }
                        }
                    }
                }
                if !ollamaModels.contains(manager.modelConfig.resolvedModelName()) {
                    Button(installing ? "Working…" : "Pull model: \(manager.modelConfig.resolvedModelName())") {
                        Task { await runInstall() }
                    }
                    .buttonStyle(FocusActionStyle(filled: false, tint: palette.accent))
                    .disabled(installing)
                }
            }
            switch manager.modelStatus {
            case .configuring(let progress):
                ollamaProgressView(progress)
            default:
                EmptyView()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    @ViewBuilder
    private func ollamaProgressView(_ progress: OllamaProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch progress {
            case .downloading(let fraction):
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                Text("Downloading Ollama… \(Int(fraction * 100))%")
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.secondary)
            case .pulling(let fraction, let status):
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                Text("Pulling model… \(Int(fraction * 100))%  \(status ?? "")")
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.secondary)
            case .unzipping:
                ProgressView()
                    .controlSize(.small)
                Text("Extracting Ollama.app…")
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.secondary)
            case .launching:
                ProgressView()
                    .controlSize(.small)
                Text("Launching Ollama…")
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.secondary)
            case .waitingForServer:
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for the server to start…")
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.secondary)
            case .testing:
                ProgressView()
                    .controlSize(.small)
                Text("Testing the model…")
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.secondary)
            case .done(let message):
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.aligned)
            case .failed(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.misaligned)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(palette.background.opacity(0.45)))
    }

    // MARK: - Vision card

    private var visionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("SCREEN UNDERSTANDING")
            HStack {
                Toggle("Vision analysis — read what's on the screen", isOn: $visionEnabled)
                    .font(.system(size: 12.5))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: visionEnabled) { _ in push() }
                Spacer()
                Text(visionEnabled ? "ON" : "OFF")
                    .font(.system(size: 9, weight: .bold))
                    .kerning(0.8)
                    .foregroundStyle(visionEnabled ? palette.aligned : palette.secondary.opacity(0.6))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("VISION MODEL").font(.system(size: 8.5, weight: .bold)).kerning(0.6).foregroundStyle(palette.secondary)
                TextField("default: \(ModelConfig.defaultVisionModels[selectedProvider] ?? "")", text: $visionModel)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(9)
                    .background(fieldBackground())
                    .onChange(of: visionModel) { _ in push() }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(selectedProvider.suggestedVisionModels, id: \.self) { suggestion in
                            Button {
                                visionModel = suggestion
                                push()
                            } label: {
                                Text(suggestion)
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(visionModel == suggestion ? Color.white : palette.accent)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(visionModel == suggestion ? palette.accent : palette.accent.opacity(0.12)))
                                    .overlay(Capsule().stroke(visionModel == suggestion ? palette.accent : palette.accent.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            if visionEnabled {
                Text("Every ~60 seconds during a focus session, the app captures the frontmost window and asks the vision model to classify what you're actually consuming. If macOS asks for Screen Recording permission, allow it for FocusMac in System Settings → Privacy & Security → Screen Recording.")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.secondary.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    // MARK: - Camera card

    private var cameraCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("ATTENDANCE — CAMERA")
            HStack {
                Toggle("Camera check — are you really focused?", isOn: Binding(
                    get: { manager.attendanceEnabled },
                    set: { manager.setCameraCheckEnabled($0) }
                ))
                .font(.system(size: 12.5))
                .toggleStyle(.switch)
                .controlSize(.small)
                Spacer()
                Text(manager.attendanceEnabled ? "ON" : "OFF")
                    .font(.system(size: 9, weight: .bold))
                    .kerning(0.8)
                    .foregroundStyle(manager.attendanceEnabled ? palette.aligned : palette.secondary.opacity(0.6))
            }
            if manager.attendanceEnabled {
                HStack {
                    Text("Analyze live feed every")
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.secondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { manager.cameraCheckInterval },
                        set: { manager.setCameraCheckInterval($0) }
                    )) {
                        Text("1 min").tag(TimeInterval(60))
                        Text("3 min").tag(TimeInterval(180))
                        Text("6 min").tag(TimeInterval(360))
                        Text("10 min").tag(TimeInterval(600))
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .fixedSize()
                }
                Text("Check now")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .onTapGesture { manager.testCameraCheck() }
                Text(manager.attendanceStatus)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.text)
                Text("Streams live video from the camera into a floating panel on your screen: green = attentive, yellow = phone detected, orange = looking away, red = missing. Also tracks mouse idle — 3+ minutes without input is logged as not working. The alarm sounds from your speakers on any problem. Camera permission is requested the first time.")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.secondary.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    // MARK: - Password card

    private var passwordCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("PASSWORD LOCK")
            HStack(spacing: 8) {
                Circle()
                    .fill(manager.passwordSet ? palette.aligned : palette.misaligned)
                    .frame(width: 7, height: 7)
                Text(manager.passwordSet ? "Password set — app cannot be quit or focus mode turned off without it" : "No password set")
                    .font(.system(size: 11.5))
                    .foregroundStyle(manager.passwordSet ? palette.text : palette.secondary)
                Spacer()
            }
            if manager.passwordSet {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CURRENT PASSWORD").font(.system(size: 8.5, weight: .bold)).kerning(0.6).foregroundStyle(palette.secondary)
                    SecureField("Current password", text: $currentPassword)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .padding(9)
                        .background(fieldBackground())
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("NEW PASSWORD").font(.system(size: 8.5, weight: .bold)).kerning(0.6).foregroundStyle(palette.secondary)
                    SecureField("New password", text: $changeNewPassword)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .padding(9)
                        .background(fieldBackground())
                    SecureField("Confirm new password", text: $changeConfirmPassword)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .padding(9)
                        .background(fieldBackground())
                }
                HStack {
                    Button("Change Password") {
                        guard changeNewPassword == changeConfirmPassword else {
                            manager.passwordMessage = "New passwords do not match."
                            return
                        }
                        if manager.changePassword(current: currentPassword, new: changeNewPassword) {
                            currentPassword = ""
                            changeNewPassword = ""
                            changeConfirmPassword = ""
                        }
                    }
                    .buttonStyle(FocusActionStyle(filled: true, tint: palette.accent))
                    .disabled(currentPassword.isEmpty || changeNewPassword.isEmpty || changeConfirmPassword.isEmpty)
                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NEW PASSWORD").font(.system(size: 8.5, weight: .bold)).kerning(0.6).foregroundStyle(palette.secondary)
                    SecureField("Choose a password", text: $newPassword)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .padding(9)
                        .background(fieldBackground())
                    SecureField("Confirm password", text: $confirmPassword)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .padding(9)
                        .background(fieldBackground())
                }
                HStack {
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
                    Spacer()
                }
            }
            if !manager.passwordMessage.isEmpty {
                Text(manager.passwordMessage)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(passwordMessageIsError ? palette.misaligned : palette.aligned)
            }
            Text("Once a password is set it is stored forever and can never be removed — only changed with the current password. Quitting the app and disabling the camera check require it. There is no recovery: if you forget it, contact the developer.")
                .font(.system(size: 10))
                .foregroundStyle(palette.secondary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    @ViewBuilder
    private var statusLine: some View {
        Group {
            switch manager.modelStatus {
            case .testing:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Testing connection…").font(.system(size: 11)).foregroundStyle(palette.secondary)
                }
            case .success(let message):
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.aligned)
            case .failed(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.misaligned)
            case .idle:
                Text("Everything is saved automatically. Test your setup to verify.")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.secondary.opacity(0.8))
            case .configuring:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private var passwordMessageIsError: Bool {
        let message = manager.passwordMessage.lowercased()
        return message.contains("incorrect")
            || message.contains("do not match")
            || message.contains("cannot")
            || message.contains("failed")
    }

    private func loadFromConfig() {
        let config = manager.modelConfig
        selectedProvider = config.provider
        apiKey = config.provider == .ollama ? "" : config.trimmedKey
        modelName = config.modelName
        visionEnabled = config.visionEnabled
        visionModel = config.visionModel
    }

    private func switchProvider() {
        guard selectedProvider != manager.modelConfig.provider else { return }
        modelName = ""
        visionModel = ""
        manager.resetModelStatus()
        push()
        scheduleAutoTest()
    }

    private func apiKeyChanged() {
        push()
        if let detected = distinctDetection, detected != selectedProvider {
            selectedProvider = detected
            return
        }
        scheduleAutoTest()
    }

    private func scheduleAutoTest() {
        autoTestTask?.cancel()
        guard selectedProvider.requiresKey, !trimmedKey.isEmpty else { return }
        autoTestTask = Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            await runTest()
        }
    }

    private func push() {
        var config = manager.modelConfig
        config.provider = selectedProvider
        config.apiKey = trimmedKey
        config.modelName = modelName
        config.visionEnabled = visionEnabled
        config.visionModel = visionModel
        manager.updateModelConfig(config)
    }

    private func runTest() async {
        autoTestTask?.cancel()
        push()
        testing = true
        await manager.testConnection()
        testing = false
        if selectedProvider == .ollama {
            await refreshOllamaStatus()
        }
    }

    private func runInstall() async {
        push()
        installing = true
        do {
            try await manager.installOllama()
        } catch {
            print("Ollama installation failed: \(error)")
        }
        installing = false
        await refreshOllamaStatus()
    }

    private func refreshOllamaStatus() async {
        await manager.refreshOllamaStatus()
        if manager.ollamaServerRunning {
            ollamaModels = await manager.listOllamaModels()
        }
    }
}
