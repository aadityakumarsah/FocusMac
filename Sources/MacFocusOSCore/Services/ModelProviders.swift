import Foundation

public enum ProviderError: Error, Equatable {
    case notConfigured
    case invalidResponse
    case serverNotRunning
    case httpStatus(Int, String)
}

public enum ClassificationParser {

    private struct Payload: Codable {
        let category: String
        let xp: Int
        let aligned: Bool
        let reason: String
    }

    public static func parse(_ text: String) -> Classification? {
        guard let start = text.range(of: "{"),
              let end = text.range(of: "}", options: .backwards),
              start.lowerBound < end.lowerBound else { return nil }
        let endExclusive = text.index(end.lowerBound, offsetBy: 1)
        guard let data = text[start.lowerBound..<endExclusive].data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return nil }
        let category = ActivityCategory(rawValue: payload.category.lowercased()) ?? .neutral
        let isLeisure = category == .social || category == .entertainment
        let alignment: Alignment
        if payload.aligned {
            alignment = isLeisure ? .misaligned : .aligned
        } else {
            alignment = isLeisure ? .misaligned : .neutral
        }
        return Classification(
            category: category,
            alignment: alignment,
            xpPerMinute: min(max(payload.xp, -10), 10),
            confidence: 0.92,
            reason: payload.reason
        )
    }
}

public enum Prompts {

    public static func textPrompt(title: String, goalTitle: String) -> String {
        """
        Classify this user's current activity against their goal.

        Goal: \(goalTitle)
        Activity (browser tab title): \(title)

        The tab may be from YouTube, Safari, Chrome, or another browser or video site —
        ignore the platform name and judge ONLY the topic of the title against the goal.
        Educational topics (tutorials, lectures, coding, math, physics, study content)
        are aligned or neutral. Entertainment, social media scrolling, and unrelated
        videos are misaligned.

        Reply with JSON only, no markdown:
        {"category":"one of [coding, learning, research, reading, work, ai, communication, neutral, social, entertainment]","xp":integer from -10 to 10,"aligned":true or false,"reason":"short 6-10 word reason"}
        """
    }

    public static func visionPrompt(goalTitle: String, context: String) -> String {
        """
        You are FocusMac, an attention manager. The user's goal is: \(goalTitle)
        Context: \(context)

        Look at the screenshot of what is on their screen and decide whether it helps that goal.
        Reply with JSON only, no markdown:
        {"category":"one of [coding, learning, research, reading, work, ai, communication, neutral, social, entertainment]","xp":integer from -10 to 10,"aligned":true or false,"reason":"short 6-10 word description of what is on screen"}
        """
    }
}

public protocol ModelProviding {
    var displayName: String { get }
    func testConnection() async throws -> String
    func classifyText(title: String, goalTitle: String) async throws -> Classification
    func classifyVision(imageBase64: String, goalTitle: String, context: String) async throws -> Classification
}

public enum ProviderFactory {

    public static func make(_ config: ModelConfig) -> ModelProviding? {
        guard config.isConfigured else { return nil }
        let key = config.trimmedKey
        switch config.provider {
        case .ollama:
            return OllamaProvider(
                modelName: config.resolvedModelName(),
                visionModel: config.resolvedVisionModelName()
            )
        case .anthropic:
            return AnthropicProvider(apiKey: key, model: config.resolvedModelName())
        case .openai:
            return OpenAIProvider(apiKey: key, model: config.resolvedModelName())
        case .openrouter:
            return OpenAIProvider(
                apiKey: key,
                model: config.resolvedModelName(),
                baseURL: URL(string: "https://openrouter.ai/api/v1")!,
                displayName: "OpenRouter",
                extraHeaders: [
                    "HTTP-Referer": "https://macfocusos.app",
                    "X-Title": "FocusMac"
                ]
            )
        case .opencode:
            return OpenAIProvider(
                apiKey: key,
                model: config.resolvedModelName(),
                baseURL: URL(string: "https://opencode.ai/zen/v1")!,
                displayName: "OpenCode"
            )
        case .kimi:
            return OpenAIProvider(
                apiKey: key,
                model: config.resolvedModelName(),
                baseURL: URL(string: "https://api.moonshot.ai/v1")!,
                displayName: "Kimi"
            )
        case .gemini:
            return GeminiProvider(apiKey: key, model: config.resolvedModelName())
        case .deepseek:
            return OpenAIProvider(
                apiKey: key,
                model: config.resolvedModelName(),
                baseURL: URL(string: "https://api.deepseek.com/v1")!,
                displayName: "DeepSeek"
            )
        case .groq:
            return OpenAIProvider(
                apiKey: key,
                model: config.resolvedModelName(),
                baseURL: URL(string: "https://api.groq.com/openai/v1")!,
                displayName: "Groq"
            )
        }
    }
}

public final class OllamaProvider: ModelProviding {
    public let baseURL: URL
    public let modelName: String
    public let visionModel: String

    public init(
        baseURL: URL = URL(string: "http://localhost:11434")!,
        modelName: String,
        visionModel: String
    ) {
        self.baseURL = baseURL
        self.modelName = modelName
        self.visionModel = visionModel
    }

    public var displayName: String { "Ollama — \(modelName)" }

    public func testConnection() async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/version"))
        request.timeoutInterval = 5
        guard let (data, _) = try? await URLSession.shared.data(for: request) else {
            throw ProviderError.serverNotRunning
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["version"] as? String else {
            throw ProviderError.invalidResponse
        }
        return "Ollama \(version) — \(modelName)"
    }

    public func classifyText(title: String, goalTitle: String) async throws -> Classification {
        let text = try await complete(prompt: Prompts.textPrompt(title: title, goalTitle: goalTitle), imageBase64: nil, model: modelName)
        guard let classification = ClassificationParser.parse(text) else { throw ProviderError.invalidResponse }
        return classification
    }

    public func classifyVision(imageBase64: String, goalTitle: String, context: String) async throws -> Classification {
        let text = try await complete(prompt: Prompts.visionPrompt(goalTitle: goalTitle, context: context), imageBase64: imageBase64, model: visionModel)
        guard let classification = ClassificationParser.parse(text) else { throw ProviderError.invalidResponse }
        return classification
    }

    private func complete(prompt: String, imageBase64: String?, model: String) async throws -> String {
        var message: [String: Any] = ["role": "user", "content": prompt]
        if let image = imageBase64 {
            message["images"] = [image]
        }
        let body: [String: Any] = ["model": model, "stream": false, "messages": [message]]
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/chat"))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ProviderError.httpStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messageObj = json["message"] as? [String: Any],
              let content = messageObj["content"] as? String, !content.isEmpty else {
            throw ProviderError.invalidResponse
        }
        return content
    }
}

public final class AnthropicProvider: ModelProviding {
    private let apiKey: String
    private let model: String

    public init(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model
    }

    public var displayName: String { "Claude — \(model)" }

    public func testConnection() async throws -> String {
        let text = try await complete(messages: [["role": "user", "content": "Reply with exactly: OK"]])
        return "Claude \(model) — \(text.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    public func classifyText(title: String, goalTitle: String) async throws -> Classification {
        let text = try await complete(messages: [["role": "user", "content": Prompts.textPrompt(title: title, goalTitle: goalTitle)]])
        guard let classification = ClassificationParser.parse(text) else { throw ProviderError.invalidResponse }
        return classification
    }

    public func classifyVision(imageBase64: String, goalTitle: String, context: String) async throws -> Classification {
        let content: [[String: Any]] = [
            ["type": "text", "text": Prompts.visionPrompt(goalTitle: goalTitle, context: context)],
            ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": imageBase64]]
        ]
        let text = try await complete(messages: [["role": "user", "content": content]])
        guard let classification = ClassificationParser.parse(text) else { throw ProviderError.invalidResponse }
        return classification
    }

    private func complete(messages: [[String: Any]]) async throws -> String {
        let body: [String: Any] = ["model": model, "max_tokens": 250, "messages": messages]
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = errorMessage(from: data)
            throw ProviderError.httpStatus(http.statusCode, message)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw ProviderError.invalidResponse
        }
        let text = content.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else { throw ProviderError.invalidResponse }
        return text
    }

    private func errorMessage(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else { return "" }
        return message
    }
}

public final class OpenAIProvider: ModelProviding {
    private let apiKey: String
    private let model: String
    private let baseURL: URL
    private let label: String
    private let extraHeaders: [String: String]

    public init(
        apiKey: String,
        model: String,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        displayName: String = "OpenAI",
        extraHeaders: [String: String] = [:]
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.label = displayName
        self.extraHeaders = extraHeaders
    }

    public var displayName: String { "\(label) — \(model)" }

    public func testConnection() async throws -> String {
        let text = try await complete(content: [["type": "text", "text": "Reply with exactly: OK"]])
        return "\(label) \(model) — \(text.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    public func classifyText(title: String, goalTitle: String) async throws -> Classification {
        let text = try await complete(content: [["type": "text", "text": Prompts.textPrompt(title: title, goalTitle: goalTitle)]])
        guard let classification = ClassificationParser.parse(text) else { throw ProviderError.invalidResponse }
        return classification
    }

    public func classifyVision(imageBase64: String, goalTitle: String, context: String) async throws -> Classification {
        let content: [[String: Any]] = [
            ["type": "text", "text": Prompts.visionPrompt(goalTitle: goalTitle, context: context)],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(imageBase64)"]]
        ]
        let text = try await complete(content: content)
        guard let classification = ClassificationParser.parse(text) else { throw ProviderError.invalidResponse }
        return classification
    }

    private func complete(content: [[String: Any]]) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 250,
            "messages": [
                ["role": "system", "content": "You are FocusMac, an attention manager."],
                ["role": "user", "content": content]
            ]
        ]
        var request = URLRequest(url: baseURL.appendingPathComponent("/chat/completions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        for (header, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = errorMessage(from: data)
            throw ProviderError.httpStatus(http.statusCode, message)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String, !content.isEmpty else {
            throw ProviderError.invalidResponse
        }
        return content
    }

    private func errorMessage(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else { return "" }
        return message
    }
}

public final class GeminiProvider: ModelProviding {
    private let apiKey: String
    private let model: String

    public init(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model
    }

    public var displayName: String { "Gemini — \(model)" }

    public func testConnection() async throws -> String {
        let text = try await generateContent(parts: [["text": "Reply with exactly: OK"]])
        return "Gemini \(model) — \(text.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    public func classifyText(title: String, goalTitle: String) async throws -> Classification {
        let text = try await generateContent(parts: [["text": Prompts.textPrompt(title: title, goalTitle: goalTitle)]])
        guard let classification = ClassificationParser.parse(text) else { throw ProviderError.invalidResponse }
        return classification
    }

    public func classifyVision(imageBase64: String, goalTitle: String, context: String) async throws -> Classification {
        let parts: [[String: Any]] = [
            ["text": Prompts.visionPrompt(goalTitle: goalTitle, context: context)],
            ["inline_data": ["mime_type": "image/jpeg", "data": imageBase64]]
        ]
        let text = try await generateContent(parts: parts)
        guard let classification = ClassificationParser.parse(text) else { throw ProviderError.invalidResponse }
        return classification
    }

    private func generateContent(parts: [[String: Any]]) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        let body: [String: Any] = ["contents": [["parts": parts]]]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = errorMessage(from: data)
            throw ProviderError.httpStatus(http.statusCode, message)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw ProviderError.invalidResponse
        }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else { throw ProviderError.invalidResponse }
        return text
    }

    private func errorMessage(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else { return "" }
        return message
    }
}