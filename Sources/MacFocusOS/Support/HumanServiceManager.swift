import Foundation

enum HumanServiceManager {
    static let serviceDir = "/Users/aadityasah/Desktop/prodtack/human-service"
    static let port = 8765

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

    static func ensureRunning() {
        guard !isRunning() else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/node")
        proc.arguments = ["server.cjs"]
        proc.currentDirectoryURL = URL(fileURLWithPath: serviceDir)
        try? proc.run()
    }
}