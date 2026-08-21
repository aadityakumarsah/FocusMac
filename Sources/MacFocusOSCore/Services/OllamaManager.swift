import Foundation

public enum OllamaProgress: Equatable {
    case downloading(Double)
    case unzipping
    case launching
    case waitingForServer
    case pulling(Double, String?)
    case testing
    case done(String)
    case failed(String)
}

public final class OllamaManager {

    public let serverURL: URL
    private let appPath = "/Applications/Ollama.app"
    private let downloadURL = URL(string: "https://ollama.com/download/Ollama-darwin.zip")!

    public init(serverURL: URL = URL(string: "http://localhost:11434")!) {
        self.serverURL = serverURL
    }

    public static func isServerRunning(serverURL: URL = URL(string: "http://localhost:11434")!) async -> Bool {
        var request = URLRequest(url: serverURL.appendingPathComponent("/api/version"))
        request.timeoutInterval = 2
        return (try? await URLSession.shared.data(for: request)) != nil
    }

    public func listModels() async -> [String] {
        var request = URLRequest(url: serverURL.appendingPathComponent("/api/tags"))
        request.timeoutInterval = 5
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else { return [] }
        return models.compactMap { $0["name"] as? String }.sorted()
    }

    public func resolveVisionModel(preferred: String) async -> String? {
        let installed = await listModels()
        if installed.contains(preferred) { return preferred }
        let keywords = ["vision", "vl", "vlm", "llava", "moondream", "minicpm", "bakllava"]
        for model in installed {
            let lower = model.lowercased()
            if keywords.contains(where: { lower.contains($0) }) {
                return model
            }
        }
        return installed.first
    }

    public func isAppInstalled() -> Bool {
        FileManager.default.fileExists(atPath: appPath)
    }

    public func configure(model: String, progress: @escaping (OllamaProgress) -> Void) async throws {
        if await Self.isServerRunning(serverURL: serverURL) {
            try await pullIfMissing(model: model, progress: progress)
            return
        }
        if !isAppInstalled() {
            progress(.downloading(0))
            let archive = try await downloadApp { fraction in
                progress(.downloading(fraction))
            }
            progress(.unzipping)
            let extracted = try await extractApp(archive)
            progress(.launching)
            try moveToApplications(extracted)
        }
        try launchApp()
        progress(.waitingForServer)
        guard await waitForServer(timeout: 90) else {
            progress(.failed("Ollama server did not start. Open /Applications/Ollama.app and retry."))
            throw ProviderError.serverNotRunning
        }
        try await pullIfMissing(model: model, progress: progress)
    }

    public func testModel(model: String) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "stream": false,
            "prompt": "Reply with exactly: OK"
        ]
        var request = URLRequest(url: serverURL.appendingPathComponent("/api/generate"))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ProviderError.httpStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["response"] as? String else {
            throw ProviderError.invalidResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func pullIfMissing(model: String, progress: @escaping (OllamaProgress) -> Void) async throws {
        let installed = await listModels()
        if installed.contains(model) {
            progress(.testing)
            let result = try await testModel(model: model)
            progress(.done("Model ready: \(model) — \(result)"))
            return
        }
        progress(.pulling(0, "starting"))
        try await pull(model: model) { fraction, status in
            progress(.pulling(fraction, status))
        }
        progress(.testing)
        let result = try await testModel(model: model)
        progress(.done("Model ready: \(model) — \(result)"))
    }

    private func pull(model: String, onProgress: @escaping (Double, String?) -> Void) async throws {
        var request = URLRequest(url: serverURL.appendingPathComponent("/api/pull"))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["name": model])
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ProviderError.httpStatus(http.statusCode, "Pull failed")
        }
        var progressByDigest: [String: (completed: Double, total: Double)] = [:]
        var lastStatus: String?
        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let status = json["status"] as? String {
                lastStatus = status
            }
            if let digest = json["digest"] as? String,
               let total = json["total"] as? Double,
               let completed = json["completed"] as? Double {
                progressByDigest[digest] = (completed, total)
            }
            let sumCompleted = progressByDigest.values.reduce(0) { $0 + $1.completed }
            let sumTotal = progressByDigest.values.reduce(0) { $0 + $1.total }
            let fraction = sumTotal > 0 ? sumCompleted / sumTotal : 0
            onProgress(fraction, lastStatus)
        }
    }

    private func downloadApp(onProgress: @escaping (Double) -> Void) async throws -> URL {
        let delegate = DownloadDelegate(onProgress: onProgress)
        let request = URLRequest(url: downloadURL)
        let (url, response) = try await URLSession.shared.download(for: request, delegate: delegate)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ProviderError.httpStatus(http.statusCode, "Download failed")
        }
        return url
    }

    private func extractApp(_ archive: URL) async throws -> URL {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("MacFocusOS-Ollama", isDirectory: true)
        try? fileManager.removeItem(at: tempDir)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let zipPath = tempDir.appendingPathComponent("Ollama-darwin.zip")
        try fileManager.moveItem(at: archive, to: zipPath)
        let outputDir = tempDir.appendingPathComponent("extract", isDirectory: true)
        try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
        try runProcess("/usr/bin/unzip", ["-o", zipPath.path, "-d", outputDir.path])
        let app = outputDir.appendingPathComponent("Ollama.app")
        guard fileManager.fileExists(atPath: app.path) else {
            throw ProviderError.invalidResponse
        }
        return app
    }

    private func moveToApplications(_ app: URL) throws {
        let fileManager = FileManager.default
        let destination = URL(fileURLWithPath: appPath)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: app, to: destination)
    }

    private func launchApp() throws {
        try runProcess("/usr/bin/open", ["/Applications/Ollama.app"])
    }

    private func waitForServer(timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await Self.isServerRunning(serverURL: serverURL) { return true }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        return false
    }

    @discardableResult
    private func runProcess(_ path: String, _ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let onProgress: (Double) -> Void
    private var lastReported: Double = -1

    init(onProgress: @escaping (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        if fraction - lastReported > 0.01 || fraction >= 1 {
            lastReported = fraction
            onProgress(fraction)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {}
}