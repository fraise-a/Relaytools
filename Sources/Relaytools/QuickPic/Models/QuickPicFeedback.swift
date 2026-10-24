import Foundation

struct QuickPicFeedback {
    let result: QuickPicResult

    var assessment: String {
        guard !result.answers.isEmpty else { return "No responses judged this time. Try another round when you are ready." }
        let consistent = result.highestCombo >= 5
        if result.accuracy >= 85 {
            return result.difficulty == .hard && consistent ? "Excellent judgement under pressure." : "Strong sales instincts, backed by accurate decisions."
        }
        if result.accuracy >= 65 {
            return consistent ? "Good judgement with a promising run of consistent decisions." : "A solid foundation. Build consistency before chasing speed."
        }
        return "Keep practising the distinctions. Accurate judgement matters more than answering quickly."
    }

    var strength: String {
        let groups = Dictionary(grouping: result.answers, by: { $0.scenario.topic })
        let ranked = groups.map { topic, answers in
            (topic: topic, correct: answers.filter { $0.judgement == .correct }.count, total: answers.count)
        }.filter { $0.correct > 0 }
            .sorted {
                let lhs = Double($0.correct) / Double($0.total), rhs = Double($1.correct) / Double($1.total)
                return lhs == rhs ? ($0.correct == $1.correct ? $0.topic.rawValue < $1.topic.rawValue : $0.correct > $1.correct) : lhs > rhs
            }
        guard let best = ranked.first else {
            return result.answers.isEmpty ? "There is no answer evidence to assess yet." : "You completed \(result.answers.count) judgements. Review a few explanations before trying again."
        }
        return "Your strongest area was \(best.topic.rawValue.lowercased()): \(best.correct) of \(best.total) exactly correct. Your highest combo was \(result.highestCombo)×."
    }

    var improvement: String {
        let misleading = result.mistakes.filter { $0.chosen == .perfect && $0.scenario.rating == .requiresImprovement }
        if let example = misleading.first {
            return "You rated \(misleading.count) inadequate response\(misleading.count == 1 ? "" : "s") as Perfect. For example: " + example.scenario.explanation + " Check the product facts before rewarding confident wording."
        }
        let groups = Dictionary(grouping: result.mistakes, by: { $0.scenario.topic })
        if let weakest = groups.sorted(by: { $0.value.count == $1.value.count ? $0.key.rawValue < $1.key.rawValue : $0.value.count > $1.value.count }).first,
           let example = weakest.value.first {
            return "Focus on \(weakest.key.rawValue.lowercased()), where \(weakest.value.count) judgement\(weakest.value.count == 1 ? "" : "s") missed the exact rating. " + example.scenario.explanation
        }
        return result.answers.isEmpty ? "Start by checking whether the reply actually answers the customer's concern." : "Every judgement was exactly correct. Try a higher difficulty or sustain your accuracy across another full round."
    }

    var nextStep: String {
        let groups = Dictionary(grouping: result.mistakes, by: { $0.scenario.rating })
        let mostMissed = QuickPicRating.allCases.sorted {
            let left = groups[$0]?.count ?? 0, right = groups[$1]?.count ?? 0
            return left == right ? $0.rawValue < $1.rawValue : left > right
        }.first
        if let mostMissed, !(groups[mostMissed] ?? []).isEmpty {
            switch mostMissed {
            case .requiresImprovement:
                return "Check for ignored requirements, dismissive language and unsupported claims before rewarding a confident tone. Compare those replies with the stronger examples in your mistake review."
            case .okay:
                return "Distinguish acceptable from exceptional: an Okay reply answers respectfully and accurately, but may lack detail, empathy or a useful next step. Missing an opportunity does not always make it inadequate."
            case .perfect:
                return "Look for the evidence of an excellent reply: accurate facts, a direct answer and an appropriate customer-focused next step. Use your review to see why these responses deserved Perfect."
            }
        }
        if result.answers.isEmpty {
            return "Try a round at your own pace. Read the product facts, check the concern, then judge whether the reply addresses it."
        }
        return result.difficulty == .hard ? "Keep the same evidence standard on another shuffled round. Aim for consistency as well as speed." : "Try the next difficulty when you feel ready, keeping accuracy ahead of speed."
    }
}
