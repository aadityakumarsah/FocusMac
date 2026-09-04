import Foundation

public enum Browser: String, Codable {
    case chrome
    case safari
    case arc
    case firefox
    case edge

    public static func from(bundleID: String?) -> Browser? {
        switch bundleID {
        case "com.google.Chrome": return .chrome
        case "com.apple.Safari": return .safari
        case "company.thebrowser.Browser": return .arc
        case "org.mozilla.firefox": return .firefox
        case "com.microsoft.edgemac": return .edge
        default: return nil
        }
    }

    public static func from(windowTitle: String?) -> Browser? {
        guard let normalized = windowTitle?.replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-") else { return nil }
        let t = normalized.lowercased()
        if t.hasSuffix("- google chrome") { return .chrome }
        if t.hasSuffix("- safari") { return .safari }
        if t.hasSuffix("- arc") { return .arc }
        if t.hasSuffix("- mozilla firefox") { return .firefox }
        if t.hasSuffix("- microsoft edge") { return .edge }
        return nil
    }
}

public enum WindowTitleParser {

    public static func parse(title: String?, browser: Browser?) -> (pageTitle: String?, site: String?) {
        guard let raw = title, let browser = browser else { return (title, nil) }
        var t = raw.replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .trimmingCharacters(in: .whitespaces)
        let tLower = t.lowercased()
        // Sort by length descending so "- Google Chrome" is tried before "Google Chrome"
        let sortedSuffixes = (BrowserSuffixes[browser] ?? []).sorted { $0.count > $1.count }
        for suffix in sortedSuffixes {
            if tLower.hasSuffix(suffix.lowercased()) {
                t = String(t.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        // Clean up trailing " - " left over from suffix removal
        while t.hasSuffix(" -") || t.hasSuffix(" –") || t.hasSuffix(" —") {
            t = String(t.dropLast(2)).trimmingCharacters(in: .whitespaces)
        }
        guard !t.isEmpty else { return (nil, nil) }
        var parts = t.components(separatedBy: " - ")
        guard parts.count > 1 else { return (t, nil) }
        let label = parts.removeLast().trimmingCharacters(in: .whitespaces)
        let page = parts.joined(separator: " - ").trimmingCharacters(in: .whitespaces)
        return (page.isEmpty ? nil : page, canonicalSite(label))
    }

    private static let BrowserSuffixes: [Browser: [String]] = [
        .chrome: ["Google Chrome", "- Google Chrome"],
        .safari: ["Safari", "- Safari"],
        .arc: ["Arc", "- Arc"],
        .firefox: ["Mozilla Firefox", "- Mozilla Firefox"],
        .edge: ["Microsoft Edge", "- Microsoft Edge"]
    ]

    public static func canonicalSite(_ label: String) -> String? {
        var l = label.lowercased().trimmingCharacters(in: .whitespaces)
        guard !l.isEmpty else { return nil }
        while let last = l.last, !(last.isLetter || last.isNumber || last == "." || last == " " || last == "-") {
            l = String(l.dropLast())
        }
        l = l.trimmingCharacters(in: .whitespaces)
        guard !l.isEmpty else { return nil }
        if let mapped = labelMap[l] { return mapped }
        let noWww = l.hasPrefix("www.") ? String(l.dropFirst(4)) : l
        let components = noWww.split(separator: ".")
        if components.count >= 2, let first = components.first, !first.isEmpty {
            if let mapped = labelMap[String(first)] { return mapped }
            return String(first)
        }
        return l
    }

    public static let labelMap: [String: String] = [
        "youtube": "youtube",
        "netflix": "netflix",
        "prime video": "primevideo",
        "prime": "primevideo",
        "hulu": "hulu",
        "hbo": "hbo",
        "disney+": "disneyplus",
        "disneyplus": "disneyplus",
        "crunchyroll": "crunchyroll",
        "github": "github",
        "gitlab": "gitlab",
        "bitbucket": "bitbucket",
        "stack overflow": "stackoverflow",
        "stackexchange": "stackexchange",
        "leetcode": "leetcode",
        "hackerrank": "hackerrank",
        "codewars": "codewars",
        "codeforces": "codeforces",
        "exercism": "exercism",
        "geeksforgeeks": "geeksforgeeks",
        "w3schools": "w3schools",
        "arxiv": "arxiv",
        "google scholar": "scholar",
        "pubmed": "pubmed",
        "nature": "nature",
        "sciencedirect": "sciencedirect",
        "ieee": "ieee",
        "researchgate": "researchgate",
        "springer": "springer",
        "coursera": "coursera",
        "udemy": "udemy",
        "khan academy": "khanacademy",
        "edx": "edx",
        "brilliant": "brilliant",
        "datacamp": "datacamp",
        "pluralsight": "pluralsight",
        "skillshare": "skillshare",
        "medium": "medium",
        "substack": "substack",
        "dev.to": "devto",
        "hashnode": "hashnode",
        "overleaf": "overleaf",
        "wikipedia": "wikipedia",
        "notion": "notion",
        "linear": "linear",
        "figma": "figma",
        "trello": "trello",
        "asana": "asana",
        "jira": "jira",
        "confluence": "confluence",
        "gmail": "gmail",
        "calendar": "calendar",
        "google calendar": "calendar",
        "google docs": "gdocs",
        "docs.google.com": "gdocs",
        "outlook": "outlook",
        "linkedin": "linkedin",
        "facebook": "facebook",
        "instagram": "instagram",
        "tiktok": "tiktok",
        "snapchat": "snapchat",
        "threads": "threads",
        "pinterest": "pinterest",
        "9gag": "9gag",
        "quora": "quora",
        "reddit": "reddit",
        "discord": "discord",
        "slack": "slack",
        "telegram": "telegram",
        "whatsapp": "whatsapp",
        "x": "x",
        "twitter": "x",
        "tumblr": "tumblr",
        "twitch": "twitch",
        "steam": "steam",
        "spotify": "spotify",
        "openai": "openai",
        "chatgpt": "openai",
        "codex": "openai",
        "anthropic": "anthropic",
        "claude": "claude",
        "gemini": "gemini",
        "perplexity": "perplexity",
        "deepseek": "deepseek",
        "google": "google",
        "bing": "bing",
        "duckduckgo": "duckduckgo",
        "yahoo": "yahoo",
        "google meet": "meet",
        "meet": "meet",
        "zoom": "zoom",
        "microsoft teams": "teams",
        "teams": "teams",
        "news": "news",
        "hacker news": "hackernews",
        "product hunt": "producthunt",
        "chess": "chess",
        "chess.com": "chess"
    ]
}
