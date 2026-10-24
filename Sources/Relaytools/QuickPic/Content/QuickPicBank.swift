import Foundation

// Each authored context supplies one independently explained response per rating.
// Facts are shown on every card; there are no hidden product assumptions.
struct QuickPicContext {
    let topic: QuickPicTopic
    let facts: String
    let customer: String
    let responses: [String]
    let explanations: [String]
    init(_ topic: QuickPicTopic, _ facts: String, _ customer: String,
         _ poor: String, _ okay: String, _ perfect: String,
         _ poorReason: String, _ okayReason: String, _ perfectReason: String) {
        self.topic = topic; self.facts = facts; self.customer = customer
        responses = [poor, okay, perfect]
        explanations = [poorReason, okayReason, perfectReason]
    }
}

enum QuickPicBank {
    static func scenarios(for difficulty: QuickPicDifficulty) -> [QuickPicScenario] {
        let contexts: [QuickPicContext]
        switch difficulty {
        case .easy: contexts = QuickPicEasy.contexts
        case .medium: contexts = QuickPicMedium.contexts
        case .hard: contexts = QuickPicHard.contexts
        }
        return contexts.enumerated().flatMap { index, context in
            QuickPicRating.allCases.map { rating in
                let key = difficulty.rawValue + "-" + String(index + 1)
                return QuickPicScenario(id: key + "-" + String(rating.rawValue), contextID: key,
                    difficulty: difficulty, topic: context.topic, facts: context.facts,
                    customer: context.customer, salesperson: context.responses[rating.rawValue],
                    rating: rating, explanation: context.explanations[rating.rawValue],
                    improvedResponse: context.responses[QuickPicRating.perfect.rawValue])
            }
        }
    }
}
