import Foundation
import Testing
@testable import MacFocusOSCore

@Suite("RuleEngine")
struct RuleEngineTests {

    private let engine = RuleEngine()
    private let goal = FocusGoal(title: "Learn system design")

    private func ctx(app: String = "Google Chrome", title: String?, site: String? = nil, browser: Browser? = nil) -> ActivityContext {
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

    @Test
    func testYouTubeLearningVideoMatchesGoal() {
        let c = engine.classify(
            ctx(title: "System Design Interview - Designing Netflix", site: "youtube", browser: .chrome),
            goal: goal,
            duration: 300
        )
        #expect(c.category == .learning)
        #expect(c.alignment == .aligned)
        #expect(c.xpPerMinute == 7)
    }

    @Test
    func testYouTubeEntertainmentIsMisaligned() {
        let c = engine.classify(
            ctx(title: "I ate 50 burgers in Kathmandu", site: "youtube", browser: .chrome),
            goal: goal,
            duration: 300
        )
        #expect(c.category == .entertainment)
        #expect(c.alignment == .misaligned)
        #expect(c.xpPerMinute == -8)
    }

    @Test
    func testXFeedScrollingIsMisaligned() {
        let c = engine.classify(
            ctx(title: "Home", site: "x", browser: .chrome),
            goal: goal,
            duration: 480
        )
        #expect(c.category == .social)
        #expect(c.alignment == .misaligned)
    }

    @Test
    func testGithubIsProductive() {
        let c = engine.classify(
            ctx(title: "system-design-primer", site: "github", browser: .chrome),
            goal: goal,
            duration: 600
        )
        #expect(c.category == .coding)
        #expect(c.alignment == .aligned)
    }

    @Test
    func testVSCodeIsDeepCoding() {
        let c = engine.classify(ctx(app: "Visual Studio Code", title: "server.swift"), goal: goal, duration: 900)
        #expect(c.category == .coding)
        #expect(c.xpPerMinute == 10)
    }

    @Test
    func testLinkedInShortCheckIsNeutral() {
        let c = engine.classify(
            ctx(title: "Feed", site: "linkedin", browser: .chrome),
            goal: goal,
            duration: 120
        )
        #expect(c.alignment == .neutral)
    }

    @Test
    func testLinkedInLongScrollIsMisaligned() {
        let c = engine.classify(
            ctx(title: "Feed", site: "linkedin", browser: .chrome),
            goal: goal,
            duration: 900
        )
        #expect(c.alignment == .misaligned)
    }

    @Test
    func testRedditGoalThreadIsAligned() {
        let c = engine.classify(
            ctx(title: "How load balancers work in distributed systems", site: "reddit", browser: .chrome),
            goal: goal,
            duration: 600
        )
        #expect(c.category == .reading)
        #expect(c.alignment == .aligned)
    }

    @Test
    func testTerminalIsAligned() {
        let c = engine.classify(ctx(app: "Terminal", title: "zsh"), goal: goal, duration: 300)
        #expect(c.alignment == .aligned)
    }

    @Test
    func testArxivIsResearch() {
        let c = engine.classify(
            ctx(title: "Designing Data-Intensive Applications", site: "arxiv", browser: .safari),
            goal: goal,
            duration: 1200
        )
        #expect(c.category == .research)
    }

    @Test
    func testNoGoalStillClassifies() {
        let c = engine.classify(
            ctx(title: "Funny moments", site: "youtube", browser: .chrome),
            goal: nil,
            duration: 60
        )
        #expect(c.alignment == .misaligned)
    }

    @Test
    func testGoalKeywordDerivation() {
        let g = FocusGoal(title: "Learn system design")
        #expect(g.keywords.contains("system design"))
        #expect(g.keywords.contains("distributed systems"))
        #expect(g.keywords.contains("microservices"))
    }

    @Test
    func testAmbiguity() {
        let c = ctx(title: "Some random site page", browser: .chrome)
        #expect(engine.isAmbiguous(c))
        let known = ctx(title: "Feed", site: "x", browser: .chrome)
        #expect(!engine.isAmbiguous(known))
    }
}

@Suite("WindowTitleParser")
struct WindowTitleParserTests {

    @Test
    func testChromeTitle() {
        let result = WindowTitleParser.parse(
            title: "System Design Interview - Designing Netflix - YouTube - Google Chrome",
            browser: .chrome
        )
        #expect(result.pageTitle == "System Design Interview - Designing Netflix")
        #expect(result.site == "youtube")
    }

    @Test
    func testSafariTitleWithEnDash() {
        let result = WindowTitleParser.parse(
            title: "Designing Uber – System Design – YouTube – Safari",
            browser: .safari
        )
        #expect(result.pageTitle == "Designing Uber - System Design")
        #expect(result.site == "youtube")
    }

    @Test
    func testNonBrowserTitleUntouched() {
        let result = WindowTitleParser.parse(title: "server.swift — Visual Studio Code", browser: nil)
        #expect(result.pageTitle == "server.swift — Visual Studio Code")
        #expect(result.site == nil)
    }

    @Test
    func testBrowserDetectionFromBundle() {
        #expect(Browser.from(bundleID: "com.google.Chrome") == .chrome)
        #expect(Browser.from(bundleID: "com.apple.Safari") == .safari)
        #expect(Browser.from(bundleID: "com.foo.bar") == nil)
    }

    @Test
    func testCanonicalSiteFallback() {
        #expect(WindowTitleParser.canonicalSite("GitHub") == "github")
        #expect(WindowTitleParser.canonicalSite("www.example.com") == "example")
        #expect(WindowTitleParser.canonicalSite("twitter.com") == "x")
    }
}

@Suite("ModelConfig & Providers")
struct ModelConfigTests {

    @Test
    func testProviderDetection() {
        #expect(ModelProviderKind.detectProvider(for: "sk-ant-api03-xxx") == .anthropic)
        #expect(ModelProviderKind.detectProvider(for: "AIzaSyXXX") == .gemini)
        #expect(ModelProviderKind.detectProvider(for: "sk-or-v1-xxx") == .openrouter)
        #expect(ModelProviderKind.detectProvider(for: "gsk_xxx") == .groq)
        #expect(ModelProviderKind.detectProvider(for: "sk-plainkey") == .openai)
        #expect(ModelProviderKind.detectProvider(for: "") == nil)
        #expect(ModelProviderKind.detectProvider(for: "   ") == nil)
    }

    @Test
    func testDetectionTrimsWhitespace() {
        #expect(ModelProviderKind.detectProvider(for: "  sk-ant-key \n") == .anthropic)
    }

    @Test
    func testAllProvidersHaveDefaultsAndSuggestions() {
        for kind in ModelProviderKind.allCases {
            #expect(ModelConfig.defaultModels[kind] != nil, "\(kind) missing default model")
            #expect(ModelConfig.defaultVisionModels[kind] != nil, "\(kind) missing default vision model")
            #expect(!kind.suggestedModels.isEmpty)
            #expect(!kind.suggestedVisionModels.isEmpty)
            #expect(!kind.keyHint.isEmpty)
        }
    }

    @Test
    func testConfigurationState() {
        var config = ModelConfig()
        #expect(config.isConfigured, "Ollama needs no key")

        config.provider = .anthropic
        config.apiKey = ""
        #expect(!config.isConfigured)

        config.apiKey = "  sk-ant-key  "
        #expect(config.isConfigured)
        #expect(config.trimmedKey == "sk-ant-key")
    }

    @Test
    func testResolvedModelNames() {
        let config = ModelConfig(provider: .kimi)
        #expect(config.resolvedModelName() == ModelConfig.defaultModels[.kimi])
        #expect(config.resolvedVisionModelName() == ModelConfig.defaultVisionModels[.kimi])

        var custom = ModelConfig(provider: .kimi, modelName: "  kimi-k2.6  ")
        #expect(custom.resolvedModelName() == "kimi-k2.6")
        custom.modelName = ""
        custom.visionModel = "custom"
        #expect(custom.resolvedVisionModelName() == "custom")
    }

    @Test
    func testCodableRoundTripPreservesNewProviders() throws {
        let config = ModelConfig(provider: .opencode, apiKey: "oc-test", modelName: "big-pickle", visionEnabled: true, visionModel: "kimi-k2.5")
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ModelConfig.self, from: data)
        #expect(decoded == config)

        let legacyJSON = #"{"provider":"anthropic","apiKey":"sk-ant-x","modelName":"claude","visionEnabled":false,"visionModel":""}"#
        let legacy = try JSONDecoder().decode(ModelConfig.self, from: Data(legacyJSON.utf8))
        #expect(legacy.provider == .anthropic)
    }

    @Test
    func testFactoryCreatesEveryProvider() {
        for kind in ModelProviderKind.allCases {
            var config = ModelConfig(provider: kind)
            if kind.requiresKey { config.apiKey = "test-key" }
            #expect(ProviderFactory.make(config) != nil, "factory returned nil for \(kind)")
        }
        #expect(ProviderFactory.make(ModelConfig(provider: .anthropic, apiKey: "")) == nil, "missing key must yield nil provider")
    }

    @Test
    func testClassificationParserToleratesMarkdownFences() {
        let text = """
        Here you go:
        ```json
        {"category":"coding","xp":8,"aligned":true,"reason":"writing Swift code"}
        ```
        """
        let result = ClassificationParser.parse(text)
        #expect(result != nil)
        #expect(result?.category == .coding)
        #expect(result?.alignment == .aligned)
    }

    @Test
    func testClassificationParserRejectsGarbage() {
        #expect(ClassificationParser.parse("no json here") == nil)
        #expect(ClassificationParser.parse("{broken json") == nil)
    }
}
