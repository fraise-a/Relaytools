import Foundation

enum MazeDifficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case easy, medium, hard, expert
    var id: String { rawValue }
    var title: String {
        switch self {
        case .easy: "Follow the Leader"
        case .medium: "Merely Convincible"
        case .hard: "Uncomfortably Needy"
        case .expert: "Who's the Customer?"
        }
    }
    var description: String {
        switch self {
        case .easy: "Friendly buyers. Straightforward questions."
        case .medium: "Cautious buyers. Earn their reassurance."
        case .hard: "Sceptical buyers. Handle pressure and price."
        case .expert: "Demanding buyers. Prove value without overclaiming."
        }
    }
    var personalities: [String] {
        switch self {
        case .easy:
            ["Friendly, practical, and curious", "Warm, patient, and straightforward", "Encouraging and interested in a simple explanation"]
        case .medium:
            ["Cautious and practical", "Thoughtful and detail-oriented", "Reserved and looking for reassurance"]
        case .hard:
            ["Sceptical and direct", "Impatient and focused on practical results", "Price-conscious and resistant to vague benefits"]
        case .expert:
            ["Demanding and evidence-led", "Analytical and alert to unsupported claims", "Challenging and focused on tradeoffs and alternatives"]
        }
    }

    var xpBudget: Int {
        switch self { case .easy: 400; case .medium: 600; case .hard: 900; case .expert: 1200 }
    }
    var targetSeconds: Double {
        switch self { case .easy: 240; case .medium: 300; case .hard: 360; case .expert: 420 }
    }
    var direction: String {
        switch self {
        case .easy: "Friendly and curious. Ask a direct question about a documented feature or price."
        case .medium: "Cautious and thoughtful. Ask about switching, suitability, practical setup, or commitment."
        case .hard: "Sceptical, impatient, or budget-conscious. Raise a substantial value, cost, or adoption objection."
        case .expert: "Demanding and evidence-led. Challenge differentiation, proof, tradeoffs, or a credible alternative. Accept honest limits and valid alternative approaches."
        }
    }
}

struct MazePoint: Equatable, Codable, Sendable {
    var x: Double
    var z: Double
    func distance(to other: Self) -> Double { hypot(x - other.x, z - other.z) }
}

struct MazeCell: Hashable, Codable, Sendable {
    let x: Int
    let z: Int
}

struct MazeCustomer: Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
    let personality: String
    let cell: MazeCell
    var question: String
    var questions: [String]
    var passed = false
    var attempts = 0
    var cooldownUntil: TimeInterval = 0
    var needsNewQuestion = false
}

struct MazeEvaluation: Codable, Equatable, Sendable {
    let relevance: Int
    let persuasiveness: Int
    let accuracy: Int
    let clarity: Int
    let professionalism: Int
    let understanding: Int
    let seriousInaccuracy: Bool
    let misleading: Bool
    let reaction: String
    let feedback: String
    let improvement: String
    var score: Int {
        let parts = [(relevance, 22), (persuasiveness, 18), (accuracy, 24), (clarity, 12), (professionalism, 12), (understanding, 12)]
        return Int((parts.reduce(0.0) { $0 + Double(min(100, max(0, $1.0)) * $1.1) } / 100).rounded())
    }
    var passed: Bool { score >= 70 && !seriousInaccuracy && !misleading }
}

struct MazeAttempt: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    let customerID: Int
    let customerName: String
    let question: String
    let response: String
    let number: Int
    let evaluation: MazeEvaluation
}

struct MazeCoaching: Codable, Equatable, Sendable {
    let summary: String
    let strength: String
    let improvement: String
    let nextStep: String
}

struct MazeRunResult: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var date = Date()
    let difficulty: MazeDifficulty
    let productBrief: String
    let seconds: Double
    let customerCount: Int
    let attempts: [MazeAttempt]
    let performanceXP: Int
    let timeXP: Int
    let retryPenalty: Int
    let coaching: MazeCoaching
    let usedFallbackReview: Bool

    var xp: Int { performanceXP + timeXP - retryPenalty }
    var convinced: Int { Set(attempts.filter { $0.evaluation.passed }.map(\.customerID)).count }
    var firstPasses: Int { attempts.filter { $0.number == 1 && $0.evaluation.passed }.count }
    var firstPassRate: Int { customerCount > 0 ? Int((Double(firstPasses) / Double(customerCount) * 100).rounded()) : 0 }
    var score: Int { attempts.isEmpty ? 0 : Int((Double(attempts.reduce(0) { $0 + $1.evaluation.score }) / Double(attempts.count)).rounded()) }
}

enum MazePhase: Equatable { case setup, preparing, playing, finishing, finished }

enum MazeTime {
    static func display(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
