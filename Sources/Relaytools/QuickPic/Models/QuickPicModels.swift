import Foundation

enum QuickPicDifficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case easy, medium, hard
    var id: String { rawValue }
    var title: String {
        switch self {
        case .easy: "Terribly Laughable (Easy)"
        case .medium: "Surprisingly Tough (Medium)"
        case .hard: "Downright Nasty (Hard)"
        }
    }
    var baseXP: Int { switch self { case .easy: 50; case .medium: 100; case .hard: 150 } }
    var subtitle: String {
        switch self {
        case .easy: "Build your instincts with clear wins and recognisable mistakes."
        case .medium: "Spot the difference between acceptable and exceptional."
        case .hard: "Question persuasive promises, subtle omissions and competing priorities."
        }
    }
    var symbol: String { switch self { case .easy: "sparkle"; case .medium: "scope"; case .hard: "bolt.shield" } }
}

enum QuickPicRating: Int, CaseIterable, Codable, Identifiable, Sendable {
    case requiresImprovement, okay, perfect
    var id: Int { rawValue }
    var title: String {
        switch self { case .requiresImprovement: "Requires Improvement"; case .okay: "Okay"; case .perfect: "Perfect" }
    }
    var definition: String {
        switch self {
        case .requiresImprovement: "Inadequate, misleading, dismissive or fails to address the concern."
        case .okay: "Relevant, respectful and acceptable, with room for a more effective response."
        case .perfect: "Accurate, professional and exceptionally responsive to this customer's needs."
        }
    }
    var symbol: String { switch self { case .requiresImprovement: "arrow.up.right"; case .okay: "equal"; case .perfect: "checkmark.seal" } }
}

enum QuickPicTopic: String, CaseIterable, Codable, Sendable {
    case pricing = "Pricing and Value"
    case empathy = "Empathy and Professionalism"
    case claims = "Evidence and Honest Claims"
    case discovery = "Understanding Customer Needs"
    case uncertainty = "Handling Uncertainty"
    case negotiation = "Negotiation and Commitment"
}

struct QuickPicScenario: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let contextID: String
    let difficulty: QuickPicDifficulty
    let topic: QuickPicTopic
    let facts: String
    let customer: String
    let salesperson: String
    let rating: QuickPicRating
    let explanation: String
    let improvedResponse: String
}

enum QuickPicJudgement: String, Codable, Sendable {
    case correct = "Correct", partial = "Partially Correct", incorrect = "Incorrect"
}

struct QuickPicAnswer: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    let scenario: QuickPicScenario
    let chosen: QuickPicRating
    let responseTime: Double
    let appliedMultiplier: Int
    let xpHalfUnits: Int
    var judgement: QuickPicJudgement {
        switch abs(chosen.rawValue - scenario.rating.rawValue) {
        case 0: .correct
        case 1: .partial
        default: .incorrect
        }
    }
    var xp: Double { Double(xpHalfUnits) / 2 }
}

enum QuickPicScoring {
    static func halfUnits(baseXP: Int, chosen: QuickPicRating, correct: QuickPicRating, streak: Int) -> Int {
        switch abs(chosen.rawValue - correct.rawValue) {
        case 0: baseXP * 2 * min(10, max(1, streak + 1))
        case 1: baseXP / 2
        default: -(baseXP / 2)
        }
    }
}

struct QuickPicResult: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var date = Date()
    let difficulty: QuickPicDifficulty
    let answers: [QuickPicAnswer]
    let highestCombo: Int
    let previousBest: Double?
    var xp: Double { Double(answers.reduce(0) { $0 + $1.xpHalfUnits }) / 2 }
    var correct: Int { answers.filter { $0.judgement == .correct }.count }
    var partial: Int { answers.filter { $0.judgement == .partial }.count }
    var incorrect: Int { answers.filter { $0.judgement == .incorrect }.count }
    var accuracy: Double { answers.isEmpty ? 0 : Double(correct) / Double(answers.count) * 100 }
    var averageResponseTime: Double { answers.isEmpty ? 0 : answers.reduce(0) { $0 + $1.responseTime } / Double(answers.count) }
    var mistakes: [QuickPicAnswer] { answers.filter { $0.judgement != .correct } }
    var isNewPersonalBest: Bool { previousBest.map { xp > $0 } ?? true }
    var personalBest: Double { max(previousBest ?? xp, xp) }
}

enum QuickPicPhase { case setup, playing, finished }

enum QuickPicFormat {
    static func xp(_ value: Double, signed: Bool = false) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...1)))
        return signed && value > 0 ? "+" + number : number
    }
    static func time(_ remaining: Double) -> String {
        let seconds = max(0, Int(ceil(remaining)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
