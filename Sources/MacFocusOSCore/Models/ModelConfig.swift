import Foundation

public enum ModelProviderKind: String, Codable, CaseIterable, Identifiable {
    case ollama
    case anthropic
    case openai
    case openrouter
    case opencode
    case kimi
    case gemini
    case deepseek
    case groq

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .ollama: return "Local — Ollama"
        case .anthropic: return "Claude (Anthropic)"
        case .openai: return "OpenAI"
        case .openrouter: return "OpenRouter"
        case .opencode: return "OpenCode Zen"
        case .kimi: return "Kimi (Moonshot)"
        case .gemini: return "Gemini (Google)"
        case .deepseek: return "DeepSeek"
        case .groq: return "Groq"
        }
    }

    public var icon: String {
        switch self {
        case .ollama: return "desktopcomputer"
        case .anthropic: return "sparkle"
        case .openai: return "brain"
        case .openrouter: return "arrow.triangle.branch"
        case .opencode: return "chevron.left.forwardslash.chevron.right"
        case .kimi: return "moon.stars.fill"
        case .gemini: return "diamond.fill"
        case .deepseek: return "waveform.path"
        case .groq: return "bolt.fill"
        }
    }

    public var requiresKey: Bool { self != .ollama }

    public var keyPlaceholder: String {
        switch self {
        case .ollama: return ""
        case .anthropic: return "sk-ant-…"
        case .openai: return "sk-…"
        case .openrouter: return "sk-or-v1-…"
        case .opencode: return "Paste your OpenCode Zen key"
        case .kimi: return "sk-…  (from platform.kimi.ai)"
        case .gemini: return "AIza…"
        case .deepseek: return "sk-…"
        case .groq: return "gsk_…"
        }
    }

    public var keyHint: String {
        switch self {
        case .ollama: return "Runs on your Mac — no internet, no key, no cost."
        case .anthropic: return "console.anthropic.com → API Keys. Keys start with sk-ant-."
        case .openai: return "platform.openai.com → API Keys. Keys start with sk-."
        case .openrouter: return "openrouter.ai → Keys. One key, hundreds of models. Keys start with sk-or-."
        case .opencode: return "opencode.ai/auth → Keys. Includes free models like big-pickle."
        case .kimi: return "platform.kimi.ai → API Keys. Keys start with sk-. Needs a small top-up first."
        case .gemini: return "aistudio.google.com → Get API Key. Keys start with AIza."
        case .deepseek: return "platform.deepseek.com → API Keys. Keys start with sk-."
        case .groq: return "console.groq.com → API Keys. Very fast free tier. Keys start with gsk_."
        }
    }

    public var suggestedModels: [String] {
        switch self {
        case .ollama: return ["qwen2.5:7b", "llama3.2", "qwen2.5vl:7b"]
        case .anthropic: return ["claude-sonnet-4-20250514", "claude-haiku-4-20250414"]
        case .openai: return ["gpt-4o-mini", "gpt-4o"]
        case .openrouter: return ["moonshotai/kimi-k2", "anthropic/claude-sonnet-4", "google/gemini-2.0-flash-001"]
        case .opencode: return ["big-pickle", "kimi-k2.5", "qwen3-coder"]
        case .kimi: return ["kimi-k2.5", "kimi-k2.6", "moonshot-v1-8k"]
        case .gemini: return ["gemini-2.5-flash", "gemini-2.5-pro"]
        case .deepseek: return ["deepseek-chat", "deepseek-reasoner"]
        case .groq: return ["llama-3.3-70b-versatile", "llama-3.1-8b-instant"]
        }
    }

    public var suggestedVisionModels: [String] {
        switch self {
        case .ollama: return ["qwen2.5vl:7b", "llava"]
        case .anthropic: return ["claude-sonnet-4-20250514", "claude-haiku-4-20250414"]
        case .openai: return ["gpt-4o-mini", "gpt-4o"]
        case .openrouter: return ["google/gemini-2.0-flash-001", "openai/gpt-4o-mini"]
        case .opencode: return ["big-pickle", "kimi-k2.5"]
        case .kimi: return ["kimi-k2.5"]
        case .gemini: return ["gemini-2.5-flash", "gemini-2.5-pro"]
        case .deepseek: return ["deepseek-chat"]
        case .groq: return ["meta-llama/llama-4-scout-17b-16e-instruct"]
        }
    }

    /// Unambiguous provider detection from a pasted key. Returns nil when the
    /// prefix is shared by several providers (e.g. bare "sk-" keys) or empty.
    public static func detectProvider(for apiKey: String) -> ModelProviderKind? {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        if key.hasPrefix("sk-ant-") { return .anthropic }
        if key.hasPrefix("AIza") { return .gemini }
        if key.hasPrefix("sk-or-") { return .openrouter }
        if key.hasPrefix("gsk_") { return .groq }
        if key.hasPrefix("sk-") { return .openai }
        return nil
    }
}

public struct ModelConfig: Codable, Equatable {
    public var provider: ModelProviderKind
    public var apiKey: String
    public var modelName: String
    public var visionEnabled: Bool
    public var visionModel: String

    public init(
        provider: ModelProviderKind = .ollama,
        apiKey: String = "",
        modelName: String = "",
        visionEnabled: Bool = false,
        visionModel: String = ""
    ) {
        self.provider = provider
        self.apiKey = apiKey
        self.modelName = modelName
        self.visionEnabled = visionEnabled
        self.visionModel = visionModel
    }

    public static let defaultModels: [ModelProviderKind: String] =
        Dictionary(uniqueKeysWithValues: ModelProviderKind.allCases.map { ($0, $0.suggestedModels[0]) })

    public static let defaultVisionModels: [ModelProviderKind: String] =
        Dictionary(uniqueKeysWithValues: ModelProviderKind.allCases.map { ($0, $0.suggestedVisionModels[0]) })

    public func resolvedModelName() -> String {
        let name = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? (ModelConfig.defaultModels[provider] ?? "llama3.2") : name
    }

    public func resolvedVisionModelName() -> String {
        let name = visionModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? (ModelConfig.defaultVisionModels[provider] ?? "llama3.2-vision") : name
    }

    public var trimmedKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isConfigured: Bool {
        guard provider.requiresKey else { return true }
        return !trimmedKey.isEmpty
    }
}
