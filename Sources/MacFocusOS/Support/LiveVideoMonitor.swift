import AppKit
import CoreGraphics
import Foundation

final class LiveVideoMonitor {
    /// Keep the input resolution used by the local phone/face models.  The
    /// preview is deliberately lower-rate, not lower-resolution, so a phone
    /// near the face stays detectable without making the dashboard janky.
    let width = 640
    let height = 480
    private let previewFramesPerSecond = 6
    private var process: Process?
    private var running = false
    private var stopping = false
    private var retryTimer: Timer?
    private var failureCount = 0
    private var buffer = Data()
    private var lastDeliveredFrameAt = Date.distantPast
    var onFrame: ((CGImage) -> Void)?
    var onFailure: (() -> Void)?

    private var frameSize: Int { width * height * 3 }

    func start() {
        guard !running else { return }
        running = true
        stopping = false
        retryTimer?.invalidate()
        retryTimer = nil
        killStaleFFmpeg()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        proc.arguments = [
            "-loglevel", "error",
            "-f", "avfoundation",
            // Publishing 30 uncompressed 640×480 frames every second costs
            // needless CPU and forces 30 SwiftUI redraws. Six frames is still
            // comfortably live in the floating preview, while the latest one
            // is always ready for an on-demand attendance check.
            "-framerate", "\(previewFramesPerSecond)",
            "-video_size", "\(width)x\(height)",
            "-pix_fmt", "nv12",
            "-i", "0",
            "-f", "rawvideo",
            "-pix_fmt", "rgb24",
            "-"
        ]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
        } catch {
            running = false
            onFailure?()
            scheduleRetry()
            return
        }
        process = proc
        buffer.removeAll()
        lastDeliveredFrameAt = .distantPast
        let fh = pipe.fileHandleForReading
        fh.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else {
                handle.readabilityHandler = nil
                DispatchQueue.main.async {
                    self?.handleProcessExit()
                }
                return
            }
            guard let self else { return }
            self.buffer.append(chunk)
            while self.buffer.count >= self.frameSize {
                let frameData = self.buffer.prefix(self.frameSize)
                self.buffer.removeFirst(self.frameSize)
                let now = Date()
                guard now.timeIntervalSince(self.lastDeliveredFrameAt) >= 1.0 / Double(self.previewFramesPerSecond) else {
                    continue
                }
                self.lastDeliveredFrameAt = now
                if let image = Self.image(from: frameData, width: self.width, height: self.height) {
                    DispatchQueue.main.async {
                        // A queued frame from a process that has already
                        // stopped must not revive an old preview.
                        guard self.running else { return }
                        self.onFrame?(image)
                    }
                }
            }
        }
    }

    func stop() {
        stopping = true
        running = false
        retryTimer?.invalidate()
        retryTimer = nil
        process?.terminate()
        process = nil
    }

    private func killStaleFFmpeg() {
        let marker = "avfoundation -framerate \(previewFramesPerSecond) -video_size \(width)x\(height)"
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-eo", "pid=,ppid=,command="]
        let pipe = Pipe()
        ps.standardOutput = pipe
        ps.standardError = FileHandle.nullDevice
        try? ps.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        ps.waitUntilExit()
        guard let out = String(data: data, encoding: .utf8) else { return }
        for line in out.components(separatedBy: "\n") {
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count >= 3,
                  let pid = Int32(parts[0]),
                  let ppid = Int32(parts[1]),
                  ppid == 1,
                  parts[2].contains(marker) else { continue }
            kill(pid, SIGKILL)
        }
    }

    private func handleProcessExit() {
        running = false
        process = nil
        guard !stopping else { return }
        onFailure?()
        scheduleRetry()
    }

    private func scheduleRetry() {
        guard retryTimer == nil else { return }
        let delay = min(2.0 * pow(2.0, Double(failureCount)), 30.0)
        failureCount += 1
        retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.retryTimer = nil
            self?.start()
        }
    }

    private static func image(from rgb: Data, width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: rgb as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 24,
            bytesPerRow: width * 3,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
