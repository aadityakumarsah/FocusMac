import Foundation
@testable import MacFocusOSCore

// Simple test harness since XCTest is unavailable (Command Line Tools only)
private var _passed = 0
private var _failed = 0

private func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition { _passed += 1 }
    else { _failed += 1; print("FAIL \(file):\(line): \(msg)") }
}

private func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "", file: String = #file, line: Int = #line) {
    if a == b { _passed += 1 } else { _failed += 1; print("FAIL \(file):\(line): expected \(b), got \(a) \(msg)") }
}

private func XCTAssertNil<T>(_ a: T?, _ msg: String = "", file: String = #file, line: Int = #line) {
    if a == nil { _passed += 1 } else { _failed += 1; print("FAIL \(file):\(line): expected nil, got \(String(describing: a)) \(msg)") }
}

private func XCTAssertNotNil<T>(_ a: T?, _ msg: String = "", file: String = #file, line: Int = #line) {
    if a != nil { _passed += 1 } else { _failed += 1; print("FAIL \(file):\(line): expected non-nil \(msg)") }
}

private func XCTAssertTrue(_ a: Bool, _ msg: String = "", file: String = #file, line: Int = #line) {
    if a { _passed += 1 } else { _failed += 1; print("FAIL \(file):\(line): expected true \(msg)") }
}

private func XCTAssertFalse(_ a: Bool, _ msg: String = "", file: String = #file, line: Int = #line) {
    if !a { _passed += 1 } else { _failed += 1; print("FAIL \(file):\(line): expected false \(msg)") }
}

// MARK: - RuleEngine Tests

func testRuleEngine() {
    let engine = RuleEngine()
    let goal = FocusGoal(title: "Learn system design")

    func ctx(app: String = "Google Chrome", title: String?, site: String? = nil, browser: Browser? = nil) -> ActivityContext {
        ActivityContext(
            pid: 1,
            appName: app,
            bundleID: browser == .chrome ? "com.google.Chrome" : nil,
            windowTitle: title,
            site: site,
            browser: browser,
            isBrowser: browser != nil
        )
    }

    // testYouTubeLearningVideoMatchesGoal
    do {
        let c = engine.classify(
            ctx(title: "System Design Interview - Designing Netflix", site: "youtube", browser: .chrome),
            goal: goal,
            duration: 300
        )
        XCTAssertEqual(c.category, .learning)
        XCTAssertEqual(c.alignment, .aligned)
        XCTAssertEqual(c.xpPerMinute, 7)
    }

    // testYouTubeEntertainmentIsMisaligned
    do {
        let c = engine.classify(
            ctx(title: "I ate 50 burgers in Kathmandu", site: "youtube", browser: .chrome),
            goal: goal,
            duration: 300
        )
        XCTAssertEqual(c.category, .entertainment)
        XCTAssertEqual(c.alignment, .misaligned)
        XCTAssertEqual(c.xpPerMinute, -8)
    }

    // testXFeedScrollingIsMisaligned
    do {
        let c = engine.classify(
            ctx(title: "Home", site: "x", browser: .chrome),
            goal: goal,
            duration: 480
        )
        XCTAssertEqual(c.category, .social)
        XCTAssertEqual(c.alignment, .misaligned)
    }

    // testGithubIsProductive
    // Title "system-design-primer" matches goal keywords so it returns .learning
    do {
        let c = engine.classify(
            ctx(title: "system-design-primer", site: "github", browser: .chrome),
            goal: goal,
            duration: 600
        )
        XCTAssertEqual(c.alignment, .aligned)
    }
    // testGithubNonGoalRepoIsCoding
    do {
        let c = engine.classify(
            ctx(title: "redis-server", site: "github", browser: .chrome),
            goal: goal,
            duration: 600
        )
        XCTAssertEqual(c.category, .coding)
        XCTAssertEqual(c.alignment, .aligned)
    }

    // testVSCodeIsDeepCoding
    do {
        let c = engine.classify(ctx(app: "Visual Studio Code", title: "server.swift"), goal: goal, duration: 900)
        XCTAssertEqual(c.category, .coding)
        XCTAssertEqual(c.xpPerMinute, 10)
    }

    // testLinkedInShortCheckIsNeutral
    do {
        let c = engine.classify(
            ctx(title: "Feed", site: "linkedin", browser: .chrome),
            goal: goal,
            duration: 120
        )
        XCTAssertEqual(c.alignment, .neutral)
    }

    // testLinkedInLongScrollIsMisaligned
    do {
        let c = engine.classify(
            ctx(title: "Feed", site: "linkedin", browser: .chrome),
            goal: goal,
            duration: 900
        )
        XCTAssertEqual(c.alignment, .misaligned)
    }

    // testRedditGoalThreadIsAligned
    do {
        let c = engine.classify(
            ctx(title: "How load balancers work in distributed systems", site: "reddit", browser: .chrome),
            goal: goal,
            duration: 600
        )
        XCTAssertEqual(c.category, .reading)
        XCTAssertEqual(c.alignment, .aligned)
    }

    // testTerminalIsAligned
    do {
        let c = engine.classify(ctx(app: "Terminal", title: "zsh"), goal: goal, duration: 300)
        XCTAssertEqual(c.alignment, .aligned)
    }

    // testArxivIsResearch
    do {
        let c = engine.classify(
            ctx(title: "Designing Data-Intensive Applications", site: "arxiv", browser: .safari),
            goal: goal,
            duration: 1200
        )
        XCTAssertEqual(c.category, .research)
    }

    // testNoGoalStillClassifies
    do {
        let c = engine.classify(
            ctx(title: "Funny moments", site: "youtube", browser: .chrome),
            goal: nil,
            duration: 60
        )
        XCTAssertEqual(c.alignment, .misaligned)
    }

    // testGoalKeywordDerivation
    do {
        let g = FocusGoal(title: "Learn system design")
        XCTAssertTrue(g.keywords.contains("system design"))
        XCTAssertTrue(g.keywords.contains("distributed systems"))
        XCTAssertTrue(g.keywords.contains("microservices"))
    }

    // testAmbiguity
    do {
        let c = ctx(title: "Some random site page", browser: .chrome)
        XCTAssertTrue(engine.isAmbiguous(c))
        let known = ctx(title: "Feed", site: "x", browser: .chrome)
        XCTAssertFalse(engine.isAmbiguous(known))
    }

    // testEntertainmentContentDetection
    do {
        XCTAssertTrue(engine.isEntertainmentContent("Daily Vlog - My Life"))
        XCTAssertTrue(engine.isEntertainmentContent("Comedy Special 2024"))
        XCTAssertTrue(engine.isEntertainmentContent("Movie Review: Latest Blockbuster"))
        XCTAssertFalse(engine.isEntertainmentContent("System Design Tutorial"))
        XCTAssertFalse(engine.isEntertainmentContent("Learning Python"))
    }
}

// MARK: - WindowTitleParser Tests

func testWindowTitleParser() {
    // testChromeTitle
    do {
        let result = WindowTitleParser.parse(
            title: "System Design Interview - Designing Netflix - YouTube - Google Chrome",
            browser: .chrome
        )
        XCTAssertEqual(result.pageTitle, "System Design Interview - Designing Netflix")
        XCTAssertEqual(result.site, "youtube")
    }

    // testSafariTitleWithEnDash
    do {
        let result = WindowTitleParser.parse(
            title: "Designing Uber – System Design – YouTube – Safari",
            browser: .safari
        )
        XCTAssertEqual(result.pageTitle, "Designing Uber - System Design")
        XCTAssertEqual(result.site, "youtube")
    }

    // testNonBrowserTitleUntouched
    do {
        let result = WindowTitleParser.parse(title: "server.swift — Visual Studio Code", browser: nil)
        XCTAssertEqual(result.pageTitle, "server.swift — Visual Studio Code")
        XCTAssertNil(result.site)
    }

    // testBrowserDetectionFromBundle
    do {
        XCTAssertEqual(Browser.from(bundleID: "com.google.Chrome"), .chrome)
        XCTAssertEqual(Browser.from(bundleID: "com.apple.Safari"), .safari)
        XCTAssertNil(Browser.from(bundleID: "com.foo.bar"))
    }

    // testCanonicalSiteFallback
    do {
        XCTAssertEqual(WindowTitleParser.canonicalSite("GitHub"), "github")
        XCTAssertEqual(WindowTitleParser.canonicalSite("www.example.com"), "example")
        XCTAssertEqual(WindowTitleParser.canonicalSite("twitter.com"), "x")
    }
}

// MARK: - ModelConfig Tests

func testModelConfig() {
    // testProviderDetection
    do {
        XCTAssertEqual(ModelProviderKind.detectProvider(for: "sk-ant-api03-xxx"), .anthropic)
        XCTAssertEqual(ModelProviderKind.detectProvider(for: "AIzaSyXXX"), .gemini)
        XCTAssertEqual(ModelProviderKind.detectProvider(for: "sk-or-v1-xxx"), .openrouter)
        XCTAssertEqual(ModelProviderKind.detectProvider(for: "gsk_xxx"), .groq)
        XCTAssertEqual(ModelProviderKind.detectProvider(for: "sk-plainkey"), .openai)
        XCTAssertNil(ModelProviderKind.detectProvider(for: ""))
        XCTAssertNil(ModelProviderKind.detectProvider(for: "   "))
    }

    // testDetectionTrimsWhitespace
    do {
        XCTAssertEqual(ModelProviderKind.detectProvider(for: "  sk-ant-key \n"), .anthropic)
    }

    // testAllProvidersHaveDefaultsAndSuggestions
    do {
        for kind in ModelProviderKind.allCases {
            XCTAssertNotNil(ModelConfig.defaultModels[kind], "\(kind) missing default model")
            XCTAssertNotNil(ModelConfig.defaultVisionModels[kind], "\(kind) missing default vision model")
            XCTAssertFalse(kind.suggestedModels.isEmpty)
            XCTAssertFalse(kind.suggestedVisionModels.isEmpty)
            XCTAssertFalse(kind.keyHint.isEmpty)
        }
    }

    // testConfigurationState
    do {
        var config = ModelConfig()
        XCTAssertTrue(config.isConfigured, "Ollama needs no key")

        config.provider = .anthropic
        config.apiKey = ""
        XCTAssertFalse(config.isConfigured)

        config.apiKey = "  sk-ant-key  "
        XCTAssertTrue(config.isConfigured)
        XCTAssertEqual(config.trimmedKey, "sk-ant-key")
    }

    // testResolvedModelNames
    do {
        let config = ModelConfig(provider: .kimi)
        XCTAssertEqual(config.resolvedModelName(), ModelConfig.defaultModels[.kimi])
        XCTAssertEqual(config.resolvedVisionModelName(), ModelConfig.defaultVisionModels[.kimi])

        var custom = ModelConfig(provider: .kimi, modelName: "  kimi-k2.6  ")
        XCTAssertEqual(custom.resolvedModelName(), "kimi-k2.6")
        custom.modelName = ""
        custom.visionModel = "custom"
        XCTAssertEqual(custom.resolvedVisionModelName(), "custom")
    }

    // testCodableRoundTripPreservesNewProviders
    do {
        let config = ModelConfig(provider: .opencode, apiKey: "oc-test", modelName: "big-pickle", visionEnabled: true, visionModel: "kimi-k2.5")
        guard let data = try? JSONEncoder().encode(config) else { _failed += 1; print("FAIL: encoding failed"); return }
        guard let decoded = try? JSONDecoder().decode(ModelConfig.self, from: data) else { _failed += 1; print("FAIL: decoding failed"); return }
        XCTAssertEqual(decoded, config)

        let legacyJSON = #"{"provider":"anthropic","apiKey":"sk-ant-x","modelName":"claude","visionEnabled":false,"visionModel":""}"#
        guard let legacy = try? JSONDecoder().decode(ModelConfig.self, from: Data(legacyJSON.utf8)) else { _failed += 1; print("FAIL: legacy decoding failed"); return }
        XCTAssertEqual(legacy.provider, .anthropic)
    }

    // testFactoryCreatesEveryProvider
    do {
        for kind in ModelProviderKind.allCases {
            var config = ModelConfig(provider: kind)
            if kind.requiresKey { config.apiKey = "test-key" }
            XCTAssertNotNil(ProviderFactory.make(config), "factory returned nil for \(kind)")
        }
        XCTAssertNil(ProviderFactory.make(ModelConfig(provider: .anthropic, apiKey: "")), "missing key must yield nil provider")
    }

    // testClassificationParserToleratesMarkdownFences
    do {
        let text = """
        Here you go:
        ```json
        {"category":"coding","xp":8,"aligned":true,"reason":"writing Swift code"}
        ```
        """
        let result = ClassificationParser.parse(text)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.category, .coding)
        XCTAssertEqual(result?.alignment, .aligned)
    }

    // testClassificationParserRejectsGarbage
    do {
        XCTAssertNil(ClassificationParser.parse("no json here"))
        XCTAssertNil(ClassificationParser.parse("{broken json"))
    }
}

// MARK: - Schedule Parser Tests

func testScheduleParser() {
    do {
        let result = ScheduleParser.parse("Study system design 9am-1pm mon-fri")
        XCTAssertNotNil(result, "Should parse study schedule")
    }
    do {
        let result = ScheduleParser.parse("Gym 6-7pm daily")
        XCTAssertNotNil(result, "Should parse gym schedule")
    }
    do {
        let result = ScheduleParser.parse("")
        XCTAssertNil(result, "Empty string should not parse")
    }
}

// MARK: - Persistence Round-Trip Tests

func testPersistenceRoundTrip() {
    do {
        var state = AppState()
        state.screenPermissionGranted = true
        state.cameraPermissionGranted = true
        state.permissionsRequested = true
        state.passwordHash = "abc123"
        state.trackingEnabled = true
        state.totalXP = 42.5
        state.cameraCheckEnabled = true
        state.cameraCheckInterval = 180

        guard let data = try? JSONEncoder().encode(state) else { _failed += 1; print("FAIL: encoding failed"); return }
        guard let decoded = try? JSONDecoder().decode(AppState.self, from: data) else { _failed += 1; print("FAIL: decoding failed"); return }

        XCTAssertTrue(decoded.screenPermissionGranted, "screen permission should persist")
        XCTAssertTrue(decoded.cameraPermissionGranted, "camera permission should persist")
        XCTAssertTrue(decoded.permissionsRequested, "permissions requested should persist")
        XCTAssertEqual(decoded.passwordHash, "abc123", "password hash should persist")
        XCTAssertTrue(decoded.trackingEnabled, "tracking should persist")
        XCTAssertEqual(decoded.totalXP, 42.5, "XP should persist")
        XCTAssertTrue(decoded.cameraCheckEnabled, "camera check enabled should persist")
        XCTAssertEqual(decoded.cameraCheckInterval, 180, "camera interval should persist")
    }

    // Test backward compatibility - old data without new fields
    do {
        let legacyJSON = #"{"warnAfter":120,"blockAfter":300,"trackingEnabled":true,"totalXP":0,"day":{"date":0,"xp":0,"focusedTime":0,"distractionTime":0,"neutralTime":0},"timeline":[],"schedule":[],"distractionLog":[],"cameraCheckEnabled":false,"cameraCheckInterval":3,"attendanceLog":[],"mouseIdleEvents":[],"lifelineUsedToday":0,"lifelineDays":[]}"#
        guard let decoded = try? JSONDecoder().decode(AppState.self, from: Data(legacyJSON.utf8)) else { _failed += 1; print("FAIL: legacy decoding failed"); return }
        XCTAssertFalse(decoded.screenPermissionGranted, "legacy should default to false")
        XCTAssertFalse(decoded.cameraPermissionGranted, "legacy should default to false")
        XCTAssertFalse(decoded.permissionsRequested, "legacy should default to false")
    }
}

// MARK: - Run All

print("=== Running Unit Tests ===")
print("")

print("--- RuleEngine ---")
testRuleEngine()

print("--- WindowTitleParser ---")
testWindowTitleParser()

print("--- ModelConfig ---")
testModelConfig()

print("--- ScheduleParser ---")
testScheduleParser()

print("--- Persistence ---")
testPersistenceRoundTrip()

print("")
print("=== Results: \(_passed) passed, \(_failed) failed ===")

if _failed > 0 {
    exit(1)
} else {
    print("All tests passed!")
}
