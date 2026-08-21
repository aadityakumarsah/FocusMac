import Foundation

public struct FocusGoal: Codable, Equatable {
    public var title: String
    public var keywords: [String]
    public var createdAt: Date

    public init(title: String, keywords: [String]? = nil, createdAt: Date = Date()) {
        self.title = title
        self.keywords = keywords ?? FocusGoal.deriveKeywords(from: title)
        self.createdAt = createdAt
    }

    private static let stopwords: Set<String> = [
        "a", "an", "the", "to", "of", "for", "in", "on", "with", "and", "or", "but",
        "at", "by", "from", "into", "up", "down", "as", "be", "so", "is", "am", "are",
        "was", "were", "it", "its", "i", "my", "me", "we", "our", "us", "you", "your",
        "do", "does", "did", "have", "has", "had", "will", "would", "can", "could",
        "should", "this", "that", "these", "those", "there", "here", "all", "any",
        "some", "more", "most", "what", "which", "who", "whom", "how", "when", "where",
        "why", "learn", "learning", "study", "studying", "master", "masters", "become",
        "becoming", "getting", "get", "want", "wants", "build", "building", "start",
        "starting", "improve", "improving", "improved", "about", "into", "out", "over",
        "under", "again", "once", "too", "very", "just", "then", "now", "than", "if",
        "while", "each", "few", "own", "same", "such", "other", "both", "each", "new",
        "good", "better", "best"
    ]

    private static let synonyms: [String: [String]] = [
        "system": [
            "system design", "system-design", "systemdesign", "distributed systems",
            "distributed system", "microservices", "microservice", "architecture",
            "scalability", "load balancing", "load balancer", "database design",
            "caching", "message queues", "consistency", "netflix"
        ],
        "design": [
            "system design", "design interview", "ui design", "ux design", "wireframe",
            "prototype", "design thinking"
        ],
        "backend": [
            "backend", "back end", "back-end", "api", "rest api", "fastapi", "flask",
            "django", "postgres", "postgresql", "mysql", "sql", "redis", "mongodb",
            "docker", "kubernetes", "node", "nodejs", "server", "database", "databases",
            "grpc", "websocket", "serialization"
        ],
        "frontend": [
            "frontend", "front end", "front-end", "react", "typescript", "javascript",
            "css", "html", "nextjs", "tailwind", "swiftui"
        ],
        "leetcode": [
            "leetcode", "algorithms", "algorithm", "data structures", "data structure",
            "coding interview", "interview", "hackerrank", "time complexity", "big o"
        ],
        "devops": [
            "devops", "ci/cd", "docker", "kubernetes", "terraform", "ansible", "aws",
            "azure", "gcp", "deployment", "linux", "grafana", "prometheus", "nginx"
        ],
        "english": [
            "english", "grammar", "vocabulary", "ielts", "toefl", "speaking",
            "pronunciation", "writing"
        ],
        "machine": [
            "machine learning", "deep learning", "neural networks", "neural network",
            "tensorflow", "pytorch", "nlp", "data science", "llm", "transformer",
            "attention", "fine-tuning", "rag", "gradient descent"
        ],
        "product": [
            "product management", "product manager", "roadmap", "spec", "prd",
            "product strategy", "user research"
        ],
        "security": [
            "security", "cybersecurity", "penetration", "owasp", "cryptography",
            "zero trust", "threat model"
        ]
    ]

    public static func deriveKeywords(from title: String) -> [String] {
        let tokens = title.lowercased().split { !$0.isLetter && $0 != "-" }.map(String.init)
        var result: [String] = []
        var seen = Set<String>()

        func add(_ raw: String) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces).lowercased()
            guard !trimmed.isEmpty else { return }
            let key = trimmed.replacingOccurrences(of: " ", with: "")
            if seen.insert(key).inserted {
                result.append(trimmed)
            }
        }

        for token in tokens {
            if stopwords.contains(token) { continue }
            if let expanded = synonyms[token] {
                expanded.forEach(add)
            } else {
                add(token)
            }
        }
        return result
    }
}
