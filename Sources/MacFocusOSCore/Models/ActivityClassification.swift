import Foundation

public enum ActivityCategory: String, Codable, CaseIterable {
    case coding
    case learning
    case research
    case reading
    case work
    case ai
    case communication
    case neutral
    case social
    case entertainment
}

public enum Alignment: String, Codable {
    case aligned
    case neutral
    case misaligned
}

public struct Classification: Codable, Equatable {
    public let category: ActivityCategory
    public let alignment: Alignment
    public let xpPerMinute: Int
    public let confidence: Double
    public let reason: String

    public init(
        category: ActivityCategory,
        alignment: Alignment,
        xpPerMinute: Int,
        confidence: Double,
        reason: String
    ) {
        self.category = category
        self.alignment = alignment
        self.xpPerMinute = xpPerMinute
        self.confidence = confidence
        self.reason = reason
    }
}

public struct ActivityContext: Equatable {
    public let pid: Int
    public let appName: String
    public let bundleID: String?
    public let windowTitle: String?
    public let site: String?
    public let browser: Browser?
    public let isBrowser: Bool

    public init(
        pid: Int,
        appName: String,
        bundleID: String? = nil,
        windowTitle: String? = nil,
        site: String? = nil,
        browser: Browser? = nil,
        isBrowser: Bool = false
    ) {
        self.pid = pid
        self.appName = appName
        self.bundleID = bundleID
        self.windowTitle = windowTitle
        self.site = site
        self.browser = browser
        self.isBrowser = isBrowser
    }
}
