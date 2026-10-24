import Foundation

struct MazeRewardBreakdown: Equatable {
    let performance: Int
    let time: Int
    let penalty: Int
    var total: Int { performance + time - penalty }
}

enum MazeRewards {
    static func calculate(difficulty: MazeDifficulty, attempts: [MazeAttempt], customerCount: Int, seconds: Double) -> MazeRewardBreakdown {
        guard customerCount > 0 else { return .init(performance: 0, time: 0, penalty: 0) }
        let passed = Set(attempts.filter { $0.evaluation.passed }.map(\.customerID)).count
        let firstPasses = attempts.filter { $0.evaluation.passed && $0.number == 1 }.count
        let average = attempts.isEmpty ? 0 : Double(attempts.reduce(0) { $0 + $1.evaluation.score }) / Double(attempts.count)
        let quality = 0.85 * average / 100 + 0.15 * Double(firstPasses) / Double(max(1, passed))
        let progress = min(1, Double(passed) / Double(customerCount))
        let performance = Int((Double(difficulty.xpBudget) * 0.8 * quality * progress).rounded())
        let timeFactor = min(1, max(-1, 2 - seconds / difficulty.targetSeconds))
        let time = Int((Double(difficulty.xpBudget) * 0.2 * timeFactor).rounded())
        let failures = attempts.filter { !$0.evaluation.passed }.count
        let penalty = failures * Int((Double(difficulty.xpBudget) * 0.035).rounded())
        return .init(performance: performance, time: time, penalty: penalty)
    }
}

struct MazeTimeEntry: Identifiable {
    let id: String
    let name: String
    let seconds: Double
    let isYou: Bool
}
