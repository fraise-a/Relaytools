// Regressions for deadline and presentation races found during code review.

@Test @MainActor func quickPicLateClicksCannotJudgeAnUnseenOrStaleCard() throws {
    let clock = QuickPicTestClock()
    let game = QuickPicStore(automaticTicks: false, clock: { clock.now })
    let workspace = TrainingStore(persist: false)
    game.difficulty = .easy
    game.start(workspace: workspace)
    let first = try #require(game.scenario)
    game.answer(first.rating, scenarioID: first.id)
    clock.now += QuickPicStore.feedbackDuration + 0.01
    // The ticker has not yet advanced the displayed feedback.
    game.answer(.okay, scenarioID: first.id)
    #expect(game.answers.count == 1)
    #expect(game.feedback == nil)
    let second = try #require(game.scenario)
    #expect(second.id != first.id)
    clock.now += 0.1
    // An event already queued by the old view must also be ignored.
    game.answer(second.rating, scenarioID: first.id)
    #expect(game.answers.count == 1)
    game.answer(second.rating, scenarioID: second.id)
    #expect(game.answers.count == 2)
    #expect(game.xp == 150)
    #expect(game.combo == 2)
}

@Test @MainActor func quickPicQuittingAtTheDeadlineFinishesAndBanksTheCompletedScore() throws {
    let clock = QuickPicTestClock()
    let workspace = TrainingStore(persist: false)
    let before = workspace.totalXP
    let game = QuickPicStore(automaticTicks: false, clock: { clock.now })
    game.difficulty = .easy
    game.start(workspace: workspace)
    clock.now += 1
    game.answer(try #require(game.scenario).rating)
    clock.now = 1120
    let abandoned = game.quit()
    #expect(!abandoned)
    #expect(game.phase == .finished)
    #expect(game.result?.answers.count == 1)
    #expect(workspace.totalXP == before + 50)
    #expect(workspace.quickPicRuns.count == 1)
    #expect(!game.quit())
    #expect(workspace.quickPicRuns.count == 1)
}

@Test @MainActor func quickPicReopeningOldResultsDoesNotCelebrateOrAwardThemAgain() {
    let workspace = TrainingStore(persist: false)
    let older = quickPicResult()
    let newer = quickPicResult(answers: [quickPicAnswer(correct: .perfect, chosen: .perfect)], previousBest: older.xp)
    workspace.recordQuickPic(older)
    workspace.recordQuickPic(newer)
    let before = workspace.totalXP
    let game = QuickPicStore(automaticTicks: false)
    game.openResult(older)
    #expect(game.isReviewingSavedResult)
    #expect(game.result == older)
    #expect(workspace.quickPicBest(for: .easy) == newer.xp)
    #expect(workspace.totalXP == before)
    game.start(workspace: workspace)
    #expect(!game.isReviewingSavedResult)
    #expect(game.phase == .playing)
    #expect(workspace.totalXP == before)
    game.quit()
}

@Test func quickPicNextRoundAdviceMatchesTheCategoryThePlayerMisjudged() {
    let missedExcellent = quickPicResult(answers: [quickPicAnswer(correct: .perfect, chosen: .requiresImprovement)])
    #expect(QuickPicFeedback(result: missedExcellent).nextStep.contains("deserved Perfect"))
    let missedPoor = quickPicResult(answers: [quickPicAnswer(correct: .requiresImprovement, chosen: .okay)])
    #expect(QuickPicFeedback(result: missedPoor).nextStep.contains("unsupported claims"))
    let missedOkay = quickPicResult(answers: [quickPicAnswer(correct: .okay, chosen: .perfect)])
    #expect(QuickPicFeedback(result: missedOkay).nextStep.contains("acceptable from exceptional"))
    let empty = quickPicResult(answers: [])
    #expect(QuickPicFeedback(result: empty).nextStep.contains("own pace"))
}

import Foundation
import Testing
@testable import Relaytools

@MainActor private final class QuickPicTestClock {
    var now = 1000.0
}

private func quickPicAnswer(_ difficulty: QuickPicDifficulty = .easy, correct: QuickPicRating = .requiresImprovement,
                            chosen: QuickPicRating = .okay, seconds: Double = 2) -> QuickPicAnswer {
    let scenario = QuickPicBank.scenarios(for: difficulty).first { $0.rating == correct }!
    return .init(scenario: scenario, chosen: chosen, responseTime: seconds, appliedMultiplier: 1,
                 xpHalfUnits: QuickPicScoring.halfUnits(baseXP: difficulty.baseXP, chosen: chosen, correct: correct, streak: 0))
}

private func quickPicResult(_ difficulty: QuickPicDifficulty = .easy, answers: [QuickPicAnswer]? = nil, previousBest: Double? = nil) -> QuickPicResult {
    .init(id: UUID(), difficulty: difficulty, answers: answers ?? [quickPicAnswer(difficulty)],
          highestCombo: 1, previousBest: previousBest)
}

@Test func quickPicBankHasBalancedExplainedCardsWithExplicitFactsAtEveryDifficulty() {
    for difficulty in QuickPicDifficulty.allCases {
        let cards = QuickPicBank.scenarios(for: difficulty)
        #expect(cards.count == 60)
        #expect(Set(cards.map(\.id)).count == cards.count)
        #expect(Set(cards.map(\.topic)).count == 6)
        for rating in QuickPicRating.allCases {
            #expect(cards.filter { $0.rating == rating }.count == 20)
        }
        for card in cards {
            #expect(!card.facts.isEmpty && !card.customer.isEmpty && !card.salesperson.isEmpty)
            #expect(!card.explanation.isEmpty && !card.improvedResponse.isEmpty)
            if card.rating == .perfect { #expect(card.improvedResponse == card.salesperson) }
            #expect(card.difficulty == difficulty)
        }
    }
}

@Test func quickPicDeckExhaustsEveryCardBeforeRepeating() throws {
    let cards = QuickPicBank.scenarios(for: .hard)
    var deck = QuickPicDeck(scenarios: cards)
    var ids: [String] = []
    for _ in 0..<cards.count {
        let drawn = deck.draw()
        ids.append(try #require(drawn).id)
    }
    #expect(Set(ids).count == cards.count)
    let drawn = deck.draw()
    let next = try #require(drawn)
    #expect(cards.contains(next))
    #expect(next.id != ids.last)
}

@Test func quickPicScoringHonoursAllRatingDistancesAndCapsTheCombo() {
    for difficulty in QuickPicDifficulty.allCases {
        let base = difficulty.baseXP
        for correct in QuickPicRating.allCases {
            for chosen in QuickPicRating.allCases {
                let distance = abs(correct.rawValue - chosen.rawValue)
                let expected = distance == 0 ? base * 20 : distance == 1 ? base / 2 : -(base / 2)
                #expect(QuickPicScoring.halfUnits(baseXP: base, chosen: chosen, correct: correct, streak: 99) == expected)
            }
        }
    }
    #expect(quickPicAnswer(.easy).xp == 12.5)
    #expect(quickPicAnswer(.hard).xp == 37.5)
    #expect(quickPicAnswer(.easy, correct: .requiresImprovement, chosen: .perfect).xp == -12.5)
}

@Test @MainActor func quickPicComboUsesOneThroughTenThenResetsWithoutMultiplyingPartialCredit() throws {
    let clock = QuickPicTestClock()
    let game = QuickPicStore(automaticTicks: false, clock: { clock.now })
    let workspace = TrainingStore(persist: false)
    game.difficulty = .easy
    game.start(workspace: workspace)
    for number in 1...12 {
        let correct = try #require(game.scenario).rating
        game.answer(correct)
        #expect(game.feedback?.xp == Double(50 * min(10, number)))
        #expect(game.combo == min(10, number))
        clock.now += 0.81
        game.tick()
    }
    #expect(game.highestCombo == 10)
    let correct = try #require(game.scenario).rating
    let adjacent: QuickPicRating = correct == .okay ? .requiresImprovement : .okay
    game.answer(adjacent)
    #expect(game.feedback?.judgement == .partial)
    #expect(game.feedback?.xp == 12.5)
    #expect(game.combo == 1)
    #expect(game.streak == 0)
    clock.now += 0.81
    game.tick()
    game.answer(try #require(game.scenario).rating)
    #expect(game.feedback?.xp == 50)
    #expect(game.highestCombo == 10)
}

@Test @MainActor func quickPicNeverResetsItsDeadlineBetweenQuestionsOrFeedback() throws {
    let clock = QuickPicTestClock()
    let game = QuickPicStore(automaticTicks: false, clock: { clock.now })
    game.difficulty = .medium
    game.start(workspace: TrainingStore(persist: false))
    #expect(game.remaining == 120)
    #expect(QuickPicFormat.time(game.remaining) == "02:00")
    clock.now += 3
    game.answer(try #require(game.scenario).rating)
    #expect(game.remaining == 117)
    clock.now += 0.4
    game.tick()
    #expect(game.feedback != nil)
    #expect(abs(game.remaining - 116.6) < 0.001)
    clock.now += 0.5
    game.tick()
    #expect(game.feedback == nil)
    #expect(abs(game.remaining - 116.1) < 0.001)
    #expect(game.phase == .playing)
}

@Test @MainActor func quickPicBlocksDoubleSubmissionAndRejectsAnswersAtTheExactDeadline() throws {
    let clock = QuickPicTestClock()
    let game = QuickPicStore(automaticTicks: false, clock: { clock.now })
    let workspace = TrainingStore(persist: false)
    let before = workspace.totalXP
    game.difficulty = .easy
    game.start(workspace: workspace)
    clock.now += 119.9
    game.answer(try #require(game.scenario).rating)
    game.answer(.okay)
    #expect(game.answers.count == 1)
    #expect(workspace.totalXP == before)
    clock.now = 1120
    game.answer(.perfect)
    let result = try #require(game.result)
    #expect(game.phase == .finished)
    #expect(game.remaining == 0)
    #expect(QuickPicFormat.time(game.remaining) == "00:00")
    #expect(result.answers.count == 1)
    #expect(result.xp == 50)
    #expect(workspace.totalXP == before + 50)
    game.tick()
    workspace.recordQuickPic(result)
    #expect(workspace.quickPicRuns.count == 1)
    #expect(workspace.totalXP == before + 50)
}

@Test @MainActor func quickPicUnansweredExpiryAndQuittingAwardNoXp() throws {
    let clock = QuickPicTestClock()
    let workspace = TrainingStore(persist: false)
    let before = workspace.totalXP
    let game = QuickPicStore(automaticTicks: false, clock: { clock.now })
    game.difficulty = .hard
    game.start(workspace: workspace)
    clock.now += 120
    game.tick()
    let result = try #require(game.result)
    #expect(result.answers.isEmpty)
    #expect(result.xp == 0 && result.accuracy == 0 && result.averageResponseTime == 0 && result.highestCombo == 0)
    game.start(workspace: workspace)
    game.answer(try #require(game.scenario).rating)
    #expect(game.xp == 150)
    game.quit()
    clock.now += 200
    game.tick()
    #expect(game.phase == .setup)
    #expect(game.result == nil)
    #expect(workspace.quickPicRuns.count == 1)
    #expect(workspace.totalXP == before)
}

@Test func quickPicAccuracyAndReviewDoNotCountPartialCreditAsCorrect() {
    let answers = [
        quickPicAnswer(correct: .perfect, chosen: .perfect, seconds: 1),
        quickPicAnswer(correct: .perfect, chosen: .okay, seconds: 2),
        quickPicAnswer(correct: .requiresImprovement, chosen: .okay, seconds: 3),
        quickPicAnswer(correct: .requiresImprovement, chosen: .perfect, seconds: 4)
    ]
    let result = quickPicResult(answers: answers)
    #expect(result.correct == 1 && result.partial == 2 && result.incorrect == 1)
    #expect(result.accuracy == 25)
    #expect(result.averageResponseTime == 2.5)
    #expect(result.mistakes == Array(answers.dropFirst()))
    #expect(result.mistakes[0].scenario.improvedResponse == result.mistakes[0].scenario.salesperson)
    #expect(QuickPicFeedback(result: result).improvement.contains("rated 1 inadequate response as Perfect"))
}

@Test @MainActor func quickPicHalfPointScoresAndSeparateBestsSurviveRelaunchWithoutDuplicateXp() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let url = directory.appendingPathComponent("training.json")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try Data(#"{"employeeName":"Existing Employee","prompts":[],"sessions":[]}"#.utf8).write(to: url)
    let workspace = TrainingStore(fileURL: url)
    #expect(workspace.quickPicRuns.isEmpty)
    let easy = quickPicResult()
    let medium = quickPicResult(.medium)
    workspace.recordQuickPic(easy)
    workspace.recordQuickPic(easy)
    workspace.recordQuickPic(medium)
    #expect(workspace.totalXP == 37.5)
    #expect(workspace.quickPicBest(for: .easy) == 12.5)
    #expect(workspace.quickPicBest(for: .medium) == 25)
    #expect(workspace.quickPicBest(for: .hard) == nil)
    #expect(workspace.isQuickPicSaved(easy))
    let reopened = TrainingStore(fileURL: url)
    #expect(reopened.employeeName == "Existing Employee")
    #expect(reopened.quickPicRuns.count == 2)
    #expect(reopened.recentXP == 37.5)
    #expect(reopened.levelRemainder == 37.5)
    #expect(reopened.leaderboard.first { $0.isYou }?.xp == 37.5)
    #expect(quickPicResult(previousBest: 12.5).isNewPersonalBest == false)
    #expect(quickPicResult(previousBest: 10).isNewPersonalBest)
}

@Test @MainActor func quickPicRequiresDifficultyAndCanReplayOrChangeIt() {
    let clock = QuickPicTestClock()
    let game = QuickPicStore(automaticTicks: false, clock: { clock.now })
    let workspace = TrainingStore(persist: false)
    game.start(workspace: workspace)
    #expect(game.phase == .setup)
    game.difficulty = .medium
    game.start(workspace: workspace)
    let firstID = game.runID
    clock.now += 120
    game.tick()
    game.start(workspace: workspace)
    #expect(game.runID != firstID)
    #expect(game.activeDifficulty == .medium)
    #expect(game.remaining == 120)
    #expect(game.answers.isEmpty)
    game.quit()
    game.changeDifficulty()
    #expect(game.difficulty == nil)
    #expect(game.phase == .setup)
}
