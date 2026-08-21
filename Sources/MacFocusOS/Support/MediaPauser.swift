import Foundation

enum MediaPauser {

    struct NowPlayingInfo {
        let appBundleID: String?
        let title: String?
        let rate: Double
    }

    private typealias SendCommandFn = @convention(c) (Int32, CFTypeRef?) -> Bool
    private typealias GetNowPlayingFn = @convention(c) (DispatchQueue, @escaping @convention(block) (CFDictionary?) -> Void) -> Void

    private static let sendCommand: SendCommandFn? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY) else {
            return nil
        }
        guard let symbol = dlsym(handle, "MRMediaRemoteSendCommand") else {
            return nil
        }
        return unsafeBitCast(symbol, to: SendCommandFn.self)
    }()

    private static let getNowPlaying: GetNowPlayingFn? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY) else {
            return nil
        }
        guard let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else {
            return nil
        }
        return unsafeBitCast(symbol, to: GetNowPlayingFn.self)
    }()

    static func pauseAll() {
        _ = sendCommand?(1, nil)
    }

    static func nowPlayingInfo() -> NowPlayingInfo? {
        guard let fn = getNowPlaying else { return nil }
        var result: NowPlayingInfo?
        let sem = DispatchSemaphore(value: 0)
        fn(.global(qos: .userInitiated)) { info in
            let dict = info as? [String: Any]
            let app = dict?["kMRMediaRemoteNowPlayingInfoApplicationBundleIdentifier"] as? String
            let title = dict?["kMRMediaRemoteNowPlayingInfoTitle"] as? String
            let rate = (dict?["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?.doubleValue ?? 0
            result = NowPlayingInfo(appBundleID: app, title: title, rate: rate)
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 1.5)
        return result
    }

    static func isBackgroundMediaPlaying(frontmostBundleID: String?) -> Bool {
        guard let info = nowPlayingInfo() else { return false }
        guard info.rate > 0 else { return false }
        guard let mediaApp = info.appBundleID, mediaApp != frontmostBundleID else { return false }
        return true
    }

    static func pauseIfBackgroundMedia(frontmostBundleID: String?) {
        guard isBackgroundMediaPlaying(frontmostBundleID: frontmostBundleID) else { return }
        pauseAll()
    }
}