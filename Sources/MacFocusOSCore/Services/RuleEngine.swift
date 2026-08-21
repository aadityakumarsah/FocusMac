import Foundation

public struct RuleEngine {

    public init() {}

    public func isAmbiguous(_ ctx: ActivityContext) -> Bool {
        let title = ctx.windowTitle ?? ""
        guard !title.isEmpty else { return false }
        if ctx.isBrowser && ctx.site == nil { return true }
        if let site = ctx.site, Self.videoSites.contains(site) { return true }
        return false
    }

    public func isVideoSite(_ ctx: ActivityContext) -> Bool {
        guard let site = ctx.site, Self.videoSites.contains(site) else { return false }
        return true
    }

    public func classifyVideoWatch(site: String, title: String?, goal: FocusGoal?) -> Classification {
        if let title, !title.isEmpty, let goal, matches(title, goal) {
            return Classification(
                category: .learning, alignment: .aligned, xpPerMinute: 7,
                confidence: 0.92, reason: "\(site.capitalized) video matches your goal"
            )
        }
        if let title,
           Self.learningHints.contains(where: { title.lowercased().contains($0) }) {
            return Classification(
                category: .learning, alignment: .aligned, xpPerMinute: 7,
                confidence: 0.85, reason: "Educational video on \(site)"
            )
        }
        return Classification(
            category: .entertainment, alignment: .misaligned, xpPerMinute: -3,
            confidence: 0.85, reason: "Watching a non-study video on \(site)"
        )
    }

    public static let videoSites: Set<String> = [
        "youtube", "vimeo", "dailymotion", "bilibili", "netflix",
        "primevideo", "hulu", "disneyplus", "crunchyroll", "hbo", "twitch"
    ]

    public func classify(_ ctx: ActivityContext, goal: FocusGoal?, duration: TimeInterval) -> Classification {
        if !ctx.isBrowser {
            if let rule = RuleEngine.appRules[ctx.appName.lowercased()] {
                return appDecision(rule, appName: ctx.appName, goal: goal, duration: duration)
            }
            return Classification(
                category: .neutral, alignment: .neutral, xpPerMinute: 1,
                confidence: 0.5, reason: "Unclassified app — \(ctx.appName)"
            )
        }
        if let site = ctx.site {
            return siteDecision(site: site, goal: goal, ctx: ctx, duration: duration)
        }
        if let title = ctx.windowTitle, let goal = goal, matches(title, goal) {
            return Classification(
                category: .learning, alignment: .aligned, xpPerMinute: 5,
                confidence: 0.8, reason: "Tab title matches your goal: \(goal.title)"
            )
        }
        return Classification(
            category: .neutral, alignment: .neutral, xpPerMinute: 1,
            confidence: 0.55, reason: "Unknown browser activity"
        )
    }

    private func appDecision(_ rule: (ActivityCategory, Int, Alignment), appName: String, goal: FocusGoal?, duration: TimeInterval) -> Classification {
        let (category, xp, alignment) = rule
        if category == .communication && duration > 600 {
            return Classification(
                category: .social, alignment: .misaligned, xpPerMinute: -4,
                confidence: 0.8, reason: "Long chat session in \(appName)"
            )
        }
        if category == .entertainment {
            return Classification(
                category: .entertainment, alignment: .misaligned, xpPerMinute: xp,
                confidence: 0.9, reason: "Entertainment in \(appName)"
            )
        }
        return Classification(
            category: category, alignment: alignment, xpPerMinute: xp,
            confidence: 0.9, reason: "\(appName) — \(category.rawValue)"
        )
    }

    private func siteDecision(site: String, goal: FocusGoal?, ctx: ActivityContext, duration: TimeInterval) -> Classification {
        switch site {
        case "youtube":
            if let title = ctx.windowTitle, let goal = goal, matches(title, goal) {
                return Classification(
                    category: .learning, alignment: .aligned, xpPerMinute: 7,
                    confidence: 0.92, reason: "YouTube video matches your goal"
                )
            }
            if let title = ctx.windowTitle,
               RuleEngine.learningHints.contains(where: { title.lowercased().contains($0) }) {
                return Classification(
                    category: .learning, alignment: .aligned, xpPerMinute: 7,
                    confidence: 0.85, reason: "Educational video on YouTube"
                )
            }
            return Classification(
                category: .entertainment, alignment: .neutral, xpPerMinute: 0,
                confidence: 0.6, reason: "Video on YouTube — letting the AI judge the content"
            )
        case "reddit":
            if let title = ctx.windowTitle, let goal = goal, matches(title, goal) {
                return Classification(
                    category: .reading, alignment: .aligned, xpPerMinute: 5,
                    confidence: 0.85, reason: "Reddit thread related to your goal"
                )
            }
            if duration > 120 {
                return Classification(
                    category: .social, alignment: .misaligned, xpPerMinute: -6,
                    confidence: 0.9, reason: "Reddit browsing beyond a short check"
                )
            }
            return Classification(
                category: .neutral, alignment: .neutral, xpPerMinute: 0,
                confidence: 0.8, reason: "Quick Reddit check"
            )
        case "x":
            if let title = ctx.windowTitle, let goal = goal, matches(title, goal) {
                return Classification(
                    category: .reading, alignment: .aligned, xpPerMinute: 4,
                    confidence: 0.85, reason: "X thread related to your goal"
                )
            }
            return Classification(
                category: .social, alignment: .misaligned, xpPerMinute: -5,
                confidence: 0.9, reason: "X feed scrolling"
            )
        case "linkedin":
            if duration > 240 {
                return Classification(
                    category: .social, alignment: .misaligned, xpPerMinute: -4,
                    confidence: 0.85, reason: "Long LinkedIn scrolling session"
                )
            }
            return Classification(
                category: .neutral, alignment: .neutral, xpPerMinute: 0,
                confidence: 0.85, reason: "LinkedIn — short check"
            )
        case "discord", "slack", "telegram", "whatsapp", "meet", "zoom", "teams":
            if duration > 600 {
                return Classification(
                    category: .social, alignment: .misaligned, xpPerMinute: -4,
                    confidence: 0.8, reason: "Long chat session on \(site)"
                )
            }
            return Classification(
                category: .communication, alignment: .neutral, xpPerMinute: 0,
                confidence: 0.9, reason: "Communication on \(site)"
            )
        default:
            break
        }

        if let rule = RuleEngine.siteRules[site] {
            if let title = ctx.windowTitle, let goal = goal, matches(title, goal) {
                return Classification(
                    category: .learning, alignment: .aligned,
                    xpPerMinute: max(rule.1, 5), confidence: 0.92,
                    reason: "\(site.capitalized) activity matches your goal"
                )
            }
            return Classification(
                category: rule.0, alignment: rule.2, xpPerMinute: rule.1,
                confidence: 0.9, reason: "\(site.capitalized) — \(rule.0.rawValue)"
            )
        }

        if let title = ctx.windowTitle, let goal = goal, matches(title, goal) {
            return Classification(
                category: .learning, alignment: .aligned, xpPerMinute: 5,
                confidence: 0.8, reason: "Tab title matches your goal"
            )
        }
        return Classification(
            category: .neutral, alignment: .neutral, xpPerMinute: 1,
            confidence: 0.55, reason: "Unknown site — \(site)"
        )
    }

    private func matches(_ title: String, _ goal: FocusGoal) -> Bool {
        let t = title.lowercased()
        if t.contains(goal.title.lowercased()) { return true }
        return goal.keywords.contains { !$0.isEmpty && t.contains($0.lowercased()) }
    }

    public static let learningHints: [String] = [
        "tutorial", "course", "lecture", "learn", "how to", "interview",
        "system design", "architecture", "deep dive", "explained", "crash course",
        "for beginners", "implementation", "guide", "walkthrough", "demo",
        "documentation", "design", "ux", "algorithm", "overview", "introduction",
        "masterclass", "workshop", "seminar", "syllabus", "review", "comparison",
        "physics", "chemistry", "biology", "math", "maths", "calculus", "algebra",
        "trigonometry", "geometry", "statistics", "probability", "python", "rust",
        "javascript", "typescript", "java", "golang", "swift", "kotlin", "sql",
        "docker", "kubernetes", "aws", "azure", "gcp", "machine learning",
        "deep learning", "neural network", "artificial intelligence", "llm",
        "data structure", "database", "operating system", "compiler", "networking",
        "cybersecurity", "cs50", "khan academy", "3blue1brown", "lesson", "exam",
        "study", "homework", "exercise", "practice problem", "problem solving",
        "coding", "programming", "computer science", "development", "debug",
        "mit", "stanford", "harvard", "university", "education", "learning",
        "school", "test prep", "sat", "gate", "jee", "neet", "upsc"
    ]

    public static let siteRules: [String: (ActivityCategory, Int, Alignment)] = [
        "github": (.coding, 9, .aligned),
        "gitlab": (.coding, 9, .aligned),
        "bitbucket": (.coding, 9, .aligned),
        "code": (.coding, 9, .aligned),
        "stackoverflow": (.coding, 8, .aligned),
        "stackexchange": (.coding, 8, .aligned),
        "leetcode": (.coding, 8, .aligned),
        "hackerrank": (.coding, 8, .aligned),
        "codewars": (.coding, 8, .aligned),
        "codeforces": (.coding, 8, .aligned),
        "exercism": (.coding, 8, .aligned),
        "geeksforgeeks": (.learning, 6, .aligned),
        "w3schools": (.learning, 6, .aligned),
        "arxiv": (.research, 8, .aligned),
        "scholar": (.research, 8, .aligned),
        "pubmed": (.research, 8, .aligned),
        "nature": (.research, 8, .aligned),
        "sciencedirect": (.research, 8, .aligned),
        "ieee": (.research, 8, .aligned),
        "researchgate": (.research, 8, .aligned),
        "springer": (.research, 8, .aligned),
        "coursera": (.learning, 7, .aligned),
        "udemy": (.learning, 7, .aligned),
        "khanacademy": (.learning, 7, .aligned),
        "edx": (.learning, 7, .aligned),
        "brilliant": (.learning, 7, .aligned),
        "datacamp": (.learning, 7, .aligned),
        "pluralsight": (.learning, 7, .aligned),
        "skillshare": (.learning, 6, .aligned),
        "medium": (.reading, 5, .aligned),
        "substack": (.reading, 5, .aligned),
        "devto": (.reading, 5, .aligned),
        "hashnode": (.reading, 5, .aligned),
        "overleaf": (.reading, 5, .aligned),
        "wikipedia": (.reading, 4, .aligned),
        "notion": (.work, 6, .aligned),
        "linear": (.work, 6, .aligned),
        "figma": (.work, 6, .aligned),
        "trello": (.work, 5, .aligned),
        "asana": (.work, 5, .aligned),
        "jira": (.work, 5, .aligned),
        "confluence": (.work, 5, .aligned),
        "gdocs": (.work, 5, .aligned),
        "gmail": (.work, 3, .aligned),
        "calendar": (.work, 3, .aligned),
        "outlook": (.work, 3, .aligned),
        "openai": (.ai, 7, .aligned),
        "anthropic": (.ai, 7, .aligned),
        "claude": (.ai, 7, .aligned),
        "gemini": (.ai, 7, .aligned),
        "perplexity": (.ai, 7, .aligned),
        "deepseek": (.ai, 7, .aligned),
        "google": (.neutral, 1, .neutral),
        "bing": (.neutral, 1, .neutral),
        "duckduckgo": (.neutral, 1, .neutral),
        "yahoo": (.neutral, 1, .neutral),
        "facebook": (.social, -5, .misaligned),
        "instagram": (.social, -5, .misaligned),
        "tiktok": (.social, -5, .misaligned),
        "snapchat": (.social, -5, .misaligned),
        "threads": (.social, -5, .misaligned),
        "pinterest": (.social, -5, .misaligned),
        "9gag": (.social, -5, .misaligned),
        "quora": (.social, -4, .misaligned),
        "tumblr": (.social, -4, .misaligned),
        "youtube": (.entertainment, -8, .misaligned),
        "netflix": (.entertainment, -8, .misaligned),
        "primevideo": (.entertainment, -8, .misaligned),
        "hulu": (.entertainment, -8, .misaligned),
        "hbo": (.entertainment, -8, .misaligned),
        "disneyplus": (.entertainment, -8, .misaligned),
        "crunchyroll": (.entertainment, -8, .misaligned),
        "twitch": (.entertainment, -8, .misaligned),
        "steam": (.entertainment, -8, .misaligned),
        "spotify": (.entertainment, -8, .misaligned),
        "news": (.neutral, 0, .neutral),
        "hackernews": (.reading, 4, .aligned),
        "producthunt": (.neutral, 0, .neutral),
        "chess": (.neutral, 1, .neutral)
    ]

    private static let appRules: [String: (ActivityCategory, Int, Alignment)] = [
        "xcode": (.coding, 10, .aligned),
        "visual studio code": (.coding, 10, .aligned),
        "code": (.coding, 10, .aligned),
        "cursor": (.coding, 10, .aligned),
        "zed": (.coding, 10, .aligned),
        "neovim": (.coding, 10, .aligned),
        "vim": (.coding, 10, .aligned),
        "emacs": (.coding, 10, .aligned),
        "intellij idea": (.coding, 10, .aligned),
        "pycharm": (.coding, 10, .aligned),
        "webstorm": (.coding, 10, .aligned),
        "goland": (.coding, 10, .aligned),
        "android studio": (.coding, 10, .aligned),
        "claude": (.coding, 8, .aligned),
        "github desktop": (.coding, 8, .aligned),
        "sourcetree": (.coding, 8, .aligned),
        "terminal": (.coding, 8, .aligned),
        "iterm2": (.coding, 8, .aligned),
        "warp": (.coding, 8, .aligned),
        "ghostty": (.coding, 8, .aligned),
        "alacritty": (.coding, 8, .aligned),
        "kitty": (.coding, 8, .aligned),
        "hyper": (.coding, 8, .aligned),
        "docker desktop": (.coding, 8, .aligned),
        "postman": (.coding, 7, .aligned),
        "tableplus": (.coding, 7, .aligned),
        "mysql workbench": (.coding, 7, .aligned),
        "db browser for sqlite": (.coding, 7, .aligned),
        "preview": (.research, 8, .aligned),
        "pdf expert": (.research, 8, .aligned),
        "adobe acrobat": (.research, 8, .aligned),
        "acrobat reader": (.research, 8, .aligned),
        "apple books": (.research, 8, .aligned),
        "zotero": (.research, 8, .aligned),
        "papers": (.research, 8, .aligned),
        "marginnote": (.research, 8, .aligned),
        "goodnotes": (.research, 7, .aligned),
        "obsidian": (.work, 6, .aligned),
        "notion": (.work, 6, .aligned),
        "notes": (.work, 5, .aligned),
        "bear": (.work, 5, .aligned),
        "craft": (.work, 5, .aligned),
        "typora": (.work, 5, .aligned),
        "microsoft word": (.work, 5, .aligned),
        "pages": (.work, 5, .aligned),
        "things": (.work, 5, .aligned),
        "todoist": (.work, 5, .aligned),
        "linear": (.work, 6, .aligned),
        "reminders": (.work, 4, .aligned),
        "calendar": (.work, 4, .aligned),
        "mail": (.work, 3, .aligned),
        "outlook": (.work, 3, .aligned),
        "spark": (.work, 3, .aligned),
        "slack": (.communication, 0, .neutral),
        "discord": (.communication, 0, .neutral),
        "messages": (.communication, 0, .neutral),
        "whatsapp": (.communication, 0, .neutral),
        "telegram": (.communication, 0, .neutral),
        "signal": (.communication, 0, .neutral),
        "microsoft teams": (.communication, 0, .neutral),
        "zoom": (.communication, 0, .neutral),
        "spotify": (.entertainment, -8, .misaligned),
        "music": (.entertainment, -8, .misaligned),
        "apple tv": (.entertainment, -8, .misaligned),
        "vlc": (.entertainment, 0, .neutral),
        "iina": (.entertainment, 0, .neutral),
        "quicktime player": (.entertainment, 0, .neutral),
        "steam": (.entertainment, -8, .misaligned),
        "tiktok": (.social, -7, .misaligned),
        "instagram": (.social, -6, .misaligned),
        "x": (.social, -6, .misaligned),
        "twitter": (.social, -6, .misaligned),
        "facebook": (.social, -6, .misaligned),
        "reddit": (.social, -5, .misaligned),
        "snapchat": (.social, -6, .misaligned),
        "threads": (.social, -6, .misaligned),
        "pinterest": (.social, -5, .misaligned),
        "youtube": (.entertainment, -8, .misaligned),
        "netflix": (.entertainment, -8, .misaligned),
        "prime video": (.entertainment, -8, .misaligned),
        "disney+": (.entertainment, -8, .misaligned),
        "photos": (.entertainment, -4, .misaligned),
        "finder": (.neutral, 1, .neutral),
        "system settings": (.neutral, 1, .neutral)
    ]
}
