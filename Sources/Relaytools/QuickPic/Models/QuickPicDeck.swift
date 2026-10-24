import Foundation

struct QuickPicDeck {
    private let pool: [QuickPicScenario]
    private var remaining: [QuickPicScenario] = []
    private var previousContext: String?
    private var recentRatings: [QuickPicRating] = []

    init(scenarios: [QuickPicScenario]) { pool = scenarios }
    mutating func draw() -> QuickPicScenario? {
        if remaining.isEmpty { remaining = pool.shuffled() }
        guard !remaining.isEmpty else { return nil }
        let avoidRating = recentRatings.count == 2 && recentRatings[0] == recentRatings[1] ? recentRatings[0] : nil
        let index = remaining.firstIndex { $0.contextID != previousContext && $0.rating != avoidRating }
            ?? remaining.firstIndex { $0.contextID != previousContext }
            ?? 0
        let card = remaining.remove(at: index)
        previousContext = card.contextID
        recentRatings = Array((recentRatings + [card.rating]).suffix(2))
        return card
    }
}
