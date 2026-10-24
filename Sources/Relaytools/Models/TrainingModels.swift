import Foundation

enum Destination: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard", pitch = "Pitch it!", maze = "A-maze-ing!", quickPic = "QuickPic!", leaderboard = "Leaderboard", history = "Practice History"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .pitch: "bubble.left.and.bubble.right"
        case .maze: "cube.transparent"
        case .quickPic: "bolt.fill"
        case .leaderboard: "trophy"
        case .history: "clock.arrow.circlepath"
        }
    }
}

struct ChatMessage: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    let isCustomer: Bool
    let text: String
}

struct CustomerPersona: Codable, Equatable, Sendable {
    let name: String
    let budget: String
    let personality: String
    let experience: String
    let priority: String
    var initials: String { name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined() }

    static let budgets = ["Tight budget", "Moderate budget", "Flexible budget"]
    static let personalities = ["Warm & curious", "Sceptical & direct", "Busy & impatient", "Careful & analytical"]
    static let experiences = ["First-time buyer", "Occasional buyer", "Experienced buyer"]
    static let priorities = ["Value for money", "Saving time", "Reliability", "Ease of use"]

    static func make(budget: String, personality: String, experience: String, priority: String) -> Self {
        .init(name: ["Morgan Ellis", "Jamie Chen", "Alex Bennett", "Sam Patel", "Taylor Reed", "Jordan Brooks", "Casey Williams", "Robin Clarke", "Charlie Hughes", "Avery Wilson"].randomElement()!,
              budget: budgets.contains(budget) ? budget : budgets.randomElement()!,
              personality: personalities.contains(personality) ? personality : personalities.randomElement()!,
              experience: experiences.contains(experience) ? experience : experiences.randomElement()!,
              priority: priorities.contains(priority) ? priority : priorities.randomElement()!)
    }
}

struct CustomerSignals: Codable, Equatable, Sendable {
    var conviction = 20
    var comfort = 45
    var readiness = 10
    var average: Int { (conviction + comfort + readiness) / 3 }
    func clamped() -> Self {
        .init(conviction: min(100, max(0, conviction)), comfort: min(100, max(0, comfort)), readiness: min(100, max(0, readiness)))
    }
}

enum PracticeOutcome: String, Codable, Sendable {
    case won, lost, ongoing, ended
    var title: String {
        switch self {
        case .won: "Customer Convinced"
        case .lost: "Customer Walked Away"
        case .ongoing: "In Progress"
        case .ended: "Session Completed"
        }
    }
}

struct SessionResult: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var date = Date()
    let customer: String
    let product: String
    let outcome: PracticeOutcome
    let signals: CustomerSignals
    let score: Int
    let xp: Int
    let feedback: String
    let strength: String
    let improvement: String
    var messages: [ChatMessage] = []
    var isDemo = false
    var engine: String = "On-device AI"
}

extension SessionResult {
    static let unassessedStrength = "You prepared a brief and met a practice customer. No sales responses were assessed."
    static let unassessedImprovement = "Begin with an open question about the customer's needs, then respond to what they tell you."
    // A completed exchange always earns or loses XP under the current scoring rules.
    // Preserve honest feedback when reopening older zero-exchange saved sessions too.
    var hasNoAssessedResponses: Bool { !isDemo && score == 0 && xp == 0 }
    var displayStrength: String { hasNoAssessedResponses ? Self.unassessedStrength : strength }
    var displayImprovement: String { hasNoAssessedResponses ? Self.unassessedImprovement : improvement }
}

struct RecentPrompt: Codable, Equatable, Identifiable {
    var id = UUID()
    let text: String
    var lastUsed = Date()
    var title: String { String(text.split(separator: "\n").first.map(String.init)?.prefix(65) ?? "Product brief") }
}

struct LeaderboardEntry: Identifiable {
    let id: String
    let name: String
    let role: String
    let xp: Double
    var isYou = false
}

struct WorkspaceData: Codable {
    var employeeName: String
    var prompts: [RecentPrompt]
    var sessions: [SessionResult]
    var mazeRuns: [MazeRunResult]? = nil
    var quickPicRuns: [QuickPicResult]? = nil
}

enum Scoring {
    static func score(_ signals: CustomerSignals) -> Int {
        Int((Double(signals.conviction) * 0.35 + Double(signals.comfort) * 0.25 + Double(signals.readiness) * 0.4).rounded())
    }
    static func xp(score: Int, outcome: PracticeOutcome, turns: Int) -> Int {
        guard turns > 0 else { return 0 }
        if outcome == .lost { return -60 }
        if outcome == .won { return 100 + score }
        if score < 35 { return -30 }
        if score < 50 { return -10 }
        return 20 + score / 2
    }
}
