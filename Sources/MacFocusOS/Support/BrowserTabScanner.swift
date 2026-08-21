import AppKit
import MacFocusOSCore

enum BrowserTabScanner {

    private static let canonicalSiteMatches: [String: [String]] = [
        "instagram": ["instagram.com", "instagram"],
        "tiktok": ["tiktok.com", "tiktok"],
        "facebook": ["facebook.com", "fb.com", "facebook"],
        "x": ["x.com/", "twitter.com", "mobile.x.com"],
        "reddit": ["reddit.com", "reddit"],
        "snapchat": ["snapchat.com", "snapchat"],
        "threads": ["threads.net", "threads"],
        "pinterest": ["pinterest.com", "pinterest"],
        "linkedin": ["linkedin.com", "linkedin"],
        "discord": ["discord.com", "discordapp.com", "discord"],
        "tumblr": ["tumblr.com", "tumblr"],
        "9gag": ["9gag.com", "9gag"],
        "whatsapp": ["whatsapp.com", "web.whatsapp", "whatsapp"],
        "youtube": ["youtube.com", "youtu.be", "youtube"],
        "netflix": ["netflix.com", "netflix"]
    ]

    private static let browsers: [(bundle: String, name: String, script: String)] = [
        ("com.google.Chrome", "Google Chrome", "get {title, URL} of every tab of every window"),
        ("com.brave.Browser", "Brave Browser", "get {title, URL} of every tab of every window"),
        ("com.microsoft.edgemac", "Microsoft Edge", "get {title, URL} of every tab of every window"),
        ("com.apple.Safari", "Safari", "get {name, URL} of every tab of every window")
    ]

    private static func escapeForAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static let errAEEventNotPermitted = -1743

    struct CloseResult {
        var closedCount = 0
        var errorCode: Int?
        var automationDenied: Bool { errorCode == BrowserTabScanner.errAEEventNotPermitted }
    }

    static func closeTabs(appName: String, isSafari: Bool, needles: [String]) -> CloseResult {
        let titleProperty = isSafari ? "name" : "title"
        let clauses = needles
            .filter { !$0.isEmpty }
            .map { needle -> String in
                let escaped = escapeForAppleScript(needle)
                return "URL contains \"\(escaped)\" or \(titleProperty) contains \"\(escaped)\""
            }
            .joined(separator: " or ")
        guard !clauses.isEmpty else { return CloseResult() }
        let source = """
        tell application "\(appName)"
            set closedCount to 0
            set windowList to every window
            repeat with i from (count of windowList) to 1 by -1
                set w to item i of windowList
                try
                    set matchingTabs to (every tab of w whose \(clauses))
                    if (count of matchingTabs) > 0 then
                        close matchingTabs
                        set closedCount to closedCount + (count of matchingTabs)
                    end if
                end try
            end repeat
            return closedCount
        end tell
        """
        var err: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&err)
        if let err {
            let code = (err["NSAppleScriptErrorNumber"] as? Int)
                ?? (err["NSAppleScriptErrorNumber"] as? NSNumber)?.intValue
            return CloseResult(closedCount: 0, errorCode: code)
        }
        return CloseResult(closedCount: Int(result?.int32Value ?? 0), errorCode: nil)
    }

    static func goBack(appName: String, isSafari: Bool) -> Bool {
        let source: String
        if isSafari {
            source = """
            tell application "Safari"
                try
                    do JavaScript "history.back()" in current tab of front window
                    return true
                on error
                    try
                        tell application "System Events" to keystroke "[" using command down
                        return true
                    on error
                        return false
                    end try
                end try
            end tell
            """
        } else {
            source = """
            tell application "\(appName)"
                try
                    go back active tab of front window
                    return true
                on error
                    return false
                end try
            end tell
            """
        }
        var err: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&err), err == nil else {
            return false
        }
        return result.booleanValue
    }

    static func primeAutomationPermissions() {
        for browser in browsers {
            guard !NSRunningApplication.runningApplications(withBundleIdentifier: browser.bundle).isEmpty else { continue }
            let script = NSAppleScript(source: "tell application \"\(browser.name)\" to count windows")
            var err: NSDictionary?
            _ = script?.executeAndReturnError(&err)
        }
    }

    static func matchedSocialSites() -> [String] {
        var found: Set<String> = []
        for browser in browsers {
            guard !NSRunningApplication.runningApplications(withBundleIdentifier: browser.bundle).isEmpty else { continue }
            let source = "tell application \"\(browser.name)\" to \(browser.script)"
            let script = NSAppleScript(source: source)
            var err: NSDictionary?
            guard let result = script?.executeAndReturnError(&err), err == nil else { continue }
            for text in collectStrings(result) {
                let haystack = text.lowercased()
                for (canonical, needles) in canonicalSiteMatches where needles.contains(where: haystack.contains) {
                    if RuleEngine.videoSites.contains(canonical) { continue }
                    found.insert(canonical)
                }
            }
        }
        return Array(found)
    }

    private static func collectStrings(_ desc: NSAppleEventDescriptor) -> [String] {
        if let string = desc.stringValue {
            return [string]
        }
        guard desc.numberOfItems > 0 else { return [] }
        var out: [String] = []
        for i in 1...desc.numberOfItems {
            guard let child = desc.atIndex(i) else { continue }
            out.append(contentsOf: collectStrings(child))
        }
        return out
    }
}