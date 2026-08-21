import Foundation

struct AttendanceVerdict: Decodable {
    let person: Bool
    let faces: Int
    let hands: Int
    let bodies: Int
    let yaw: Double
    let pitch: Double
    let roll: Double
    let lookingAway: Bool
    let phoneUse: Bool
    let pose: String
    let similarity: Double?
    let embeddingSeen: Bool
}

final class AttendanceMonitor {
    private var timer: Timer?
    private(set) var lastCheck: Date?
    private(set) var lastVerdict: AttendanceVerdict?
    private(set) var lastFrame: Data?
    var onStarted: (() -> Void)?
    var onResult: ((AttendanceVerdict, Data?) -> Void)?

    func start(interval: TimeInterval) {
        stop()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.runCheck()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func runCheck() {
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= 7 && hour < 23 else { return }
        onStarted?()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let jpeg = Self.captureFrame() else { return }
            guard let verdict = Self.analyze(jpeg: jpeg) else { return }
            DispatchQueue.main.async {
                self?.lastCheck = Date()
                self?.lastVerdict = verdict
                self?.lastFrame = jpeg
                self?.onResult?(verdict, jpeg)
            }
        }
    }

    static func captureFrame() -> Data? {
        let path = "/tmp/mf-cam-frame.jpg"
        try? FileManager.default.removeItem(atPath: path)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        proc.arguments = [
            "-loglevel", "error",
            "-f", "avfoundation",
            "-framerate", "30",
            "-i", "0",
            "-frames:v", "1",
            "-update", "1",
            "-y", path
        ]
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return nil
        }
        return FileManager.default.contents(atPath: path)
    }

    static func analyze(jpeg: Data) -> AttendanceVerdict? {
        let body: [String: Any] = ["image": jpeg.base64EncodedString()]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        var request = URLRequest(url: URL(string: "http://127.0.0.1:8765/analyze")!)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90
        let sem = DispatchSemaphore(value: 0)
        var verdict: AttendanceVerdict?
        URLSession.shared.dataTask(with: request) { resp, _, _ in
            if let resp,
               let obj = try? JSONSerialization.jsonObject(with: resp) as? [String: Any],
               let v = obj["verdict"],
               let data = try? JSONSerialization.data(withJSONObject: v) {
                verdict = try? JSONDecoder().decode(AttendanceVerdict.self, from: data)
            }
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + 100)
        return verdict
    }
}