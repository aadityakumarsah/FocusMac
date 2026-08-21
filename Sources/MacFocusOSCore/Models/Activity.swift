import Foundation

public struct Activity: Codable, Identifiable, Equatable {
    public var id: UUID
    public var appName: String
    public var bundleID: String?
    public var windowTitle: String?
    public var site: String?
    public var alignment: Alignment?
    public var startedAt: Date
    public var lastSeenAt: Date

    public init(
        id: UUID = UUID(),
        appName: String,
        bundleID: String? = nil,
        windowTitle: String? = nil,
        site: String? = nil,
        alignment: Alignment? = nil,
        startedAt: Date = Date(),
        lastSeenAt: Date = Date()
    ) {
        self.id = id
        self.appName = appName
        self.bundleID = bundleID
        self.windowTitle = windowTitle
        self.site = site
        self.alignment = alignment
        self.startedAt = startedAt
        self.lastSeenAt = lastSeenAt
    }

    public var duration: TimeInterval {
        max(0, lastSeenAt.timeIntervalSince(startedAt))
    }

    public func sameAs(_ ctx: ActivityContext) -> Bool {
        guard appName == ctx.appName else { return false }
        switch (site, ctx.site) {
        case let (a?, b?): return a == b
        default: return true
        }
    }
}
