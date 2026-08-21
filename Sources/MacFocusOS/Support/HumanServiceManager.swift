import Foundation

enum HumanServiceManager {
    static let port = 8765

    private static var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("MacFocusOS", isDirectory: true)
    }

    private static var installedServiceDirectory: URL {
        appSupportDirectory.appendingPathComponent("human-service", isDirectory: true)
    }

    private static var installedVersionURL: URL {
        appSupportDirectory.appendingPathComponent("human-service-version")
    }

    private static var bundledServiceArchive: URL? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let archive = resourceURL.appendingPathComponent("human-service.tar")
        return FileManager.default.fileExists(atPath: archive.path) ? archive : nil
    }

    private static var serviceVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "development"
    }

    /// The release bundle carries the local models as one archive. Expand it
    /// only when camera attendance is enabled, and only once per app version.
    /// `ensureRunning` calls this from a utility queue, so first-run extraction
    /// cannot stall the dashboard.
    private static func installBundledServiceIfNeeded() -> URL? {
        let fileManager = FileManager.default
        let installedServer = installedServiceDirectory.appendingPathComponent("server.cjs")
        let installedVersion = try? String(contentsOf: installedVersionURL, encoding: .utf8)
        if fileManager.fileExists(atPath: installedServer.path), installedVersion == serviceVersion {
            return installedServiceDirectory
        }
        guard let archive = bundledServiceArchive else { return nil }
        do {
            try fileManager.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: installedServiceDirectory.path) {
                try fileManager.removeItem(at: installedServiceDirectory)
            }
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            task.arguments = ["-xf", archive.path, "-C", appSupportDirectory.path]
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0,
                  fileManager.fileExists(atPath: installedServer.path) else {
                return nil
            }
            try serviceVersion.write(to: installedVersionURL, atomically: true, encoding: .utf8)
            return installedServiceDirectory
        } catch {
            return nil
        }
    }

    /// The service is expanded from the app bundle in release builds. The
    /// bundled-directory and working-directory fallbacks keep existing builds
    /// and `swift run` convenient for contributors.
    private static func serviceDirectory() -> URL? {
        if let installed = installBundledServiceIfNeeded() { return installed }
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("human-service", isDirectory: true),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("human-service", isDirectory: true)
        ].compactMap { $0 }
        return candidates.first {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("server.cjs").path)
        }
    }

    /// Homebrew does not always create `/opt/homebrew/bin/node`, so include
    /// its versioned location as well. `FOCUSMAC_NODE` lets a packaged build
    /// use a managed Node runtime without changing the app.
    private static var nodeExecutable: URL? {
        let environmentNode = ProcessInfo.processInfo.environment["FOCUSMAC_NODE"]
        let candidates = [
            environmentNode,
            "/opt/homebrew/bin/node",
            "/opt/homebrew/opt/node/bin/node",
            "/opt/homebrew/opt/node@20/bin/node",
            "/usr/local/bin/node",
            "/usr/local/opt/node/bin/node",
            "/usr/bin/node"
        ].compactMap { $0 }
        return candidates.lazy.map(URL.init(fileURLWithPath:)).first {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }
    }

    static func isRunning() -> Bool {
        let sem = DispatchSemaphore(value: 0)
        var ok = false
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/health")!)
        request.timeoutInterval = 3
        URLSession.shared.dataTask(with: request) { _, resp, _ in
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 { ok = true }
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + 4)
        return ok
    }

    @discardableResult
    static func ensureRunning() -> Bool {
        guard !isRunning() else { return true }
        guard let serviceDir = serviceDirectory(), let nodeExecutable else { return false }
        let proc = Process()
        proc.executableURL = nodeExecutable
        proc.arguments = ["server.cjs"]
        proc.currentDirectoryURL = serviceDir
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            return true
        } catch {
            return false
        }
    }
}
