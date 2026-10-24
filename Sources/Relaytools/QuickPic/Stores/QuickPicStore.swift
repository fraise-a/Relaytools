import Foundation
import Observation

@MainActor @Observable
final class QuickPicStore {
    static let duration = 120.0
    static let feedbackDuration = 0.8
    var difficulty: QuickPicDifficulty?
    private(set) var activeDifficulty: QuickPicDifficulty = .easy
    private(set) var phase: QuickPicPhase = .setup
    private(set) var remaining = duration
    private(set) var scenario: QuickPicScenario?
    private(set) var answers: [QuickPicAnswer] = []
    private(set) var feedback: QuickPicAnswer?
    private(set) var streak = 0
    private(set) var highestCombo = 1
    private(set) var result: QuickPicResult?
    private(set) var isReviewingSavedResult = false
    private(set) var runID = UUID()
    @ObservationIgnored private let clock: @MainActor () -> TimeInterval
    @ObservationIgnored private let automaticTicks: Bool
    @ObservationIgnored private var deadline = 0.0
    @ObservationIgnored private var questionStartedAt = 0.0
    @ObservationIgnored private var advanceAt: Double?
    @ObservationIgnored private var deck = QuickPicDeck(scenarios: [])
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private weak var workspace: TrainingStore?
    @ObservationIgnored private var previousBest: Double?

    init(automaticTicks: Bool = true, clock: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.clock = clock
        self.automaticTicks = automaticTicks
    }
    var xp: Double { Double(answers.reduce(0) { $0 + $1.xpHalfUnits }) / 2 }
    var combo: Int { min(10, max(1, streak)) }
    var nextMultiplier: Int { min(10, streak + 1) }
    var canAnswer: Bool { phase == .playing && feedback == nil && scenario != nil && remaining > 0 }

    func start(workspace: TrainingStore) {
        guard phase != .playing, let difficulty else { return }
        let pool = QuickPicBank.scenarios(for: difficulty)
        guard !pool.isEmpty else { return }
        ticker?.cancel()
        self.workspace = workspace
        activeDifficulty = difficulty
        previousBest = workspace.quickPicBest(for: difficulty)
        deck = QuickPicDeck(scenarios: pool)
        scenario = deck.draw()
        answers = []
        feedback = nil
        result = nil
        isReviewingSavedResult = false
        streak = 0
        highestCombo = 1
        remaining = Self.duration
        runID = UUID()
        let now = clock()
        deadline = now + Self.duration
        questionStartedAt = now
        advanceAt = nil
        phase = .playing
        if automaticTicks {
            ticker = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
                    guard let self else { return }
                    self.tick()
                    if self.phase != .playing { return }
                }
            }
        }
    }

    func answer(_ chosen: QuickPicRating, scenarioID: String? = nil) {
        let presentedID = scenarioID ?? scenario?.id
        let wasShowingFeedback = feedback != nil
        tick()
        guard !wasShowingFeedback, canAnswer, let scenario, scenario.id == presentedID else { return }
        let now = clock()
        // The deadline is authoritative, even between timer updates.
        guard now < deadline else { finish(); return }
        let correct = chosen == scenario.rating
        let multiplier = correct ? min(10, streak + 1) : 1
        let recorded = QuickPicAnswer(scenario: scenario, chosen: chosen,
            responseTime: max(0, now - questionStartedAt), appliedMultiplier: multiplier,
            xpHalfUnits: QuickPicScoring.halfUnits(baseXP: activeDifficulty.baseXP, chosen: chosen, correct: scenario.rating, streak: streak))
        answers.append(recorded)
        feedback = recorded
        streak = correct ? streak + 1 : 0
        highestCombo = max(highestCombo, combo)
        advanceAt = now + Self.feedbackDuration
    }

    func tick() {
        guard phase == .playing else { return }
        let now = clock()
        remaining = max(0, deadline - now)
        if remaining <= 0 { finish(); return }
        if let advanceAt, now >= advanceAt {
            self.advanceAt = nil
            feedback = nil
            scenario = deck.draw()
            questionStartedAt = now
        }
    }

    private func finish() {
        guard phase == .playing else { return }
        phase = .finished
        remaining = 0
        ticker?.cancel()
        ticker = nil
        advanceAt = nil
        feedback = nil
        let completed = QuickPicResult(id: runID, difficulty: activeDifficulty, answers: answers,
            highestCombo: answers.isEmpty ? 0 : highestCombo, previousBest: previousBest)
        result = completed
        workspace?.recordQuickPic(completed)
    }

    @discardableResult
    func quit() -> Bool {
        tick()
        guard phase == .playing else { return false }
        ticker?.cancel()
        ticker = nil
        phase = .setup
        remaining = Self.duration
        scenario = nil
        feedback = nil
        answers = []
        streak = 0
        highestCombo = 1
        advanceAt = nil
        result = nil
        isReviewingSavedResult = false
        return true
    }

    func openResult(_ result: QuickPicResult) {
        guard phase != .playing else { return }
        difficulty = result.difficulty
        activeDifficulty = result.difficulty
        self.result = result
        isReviewingSavedResult = true
        phase = .finished
    }

    func changeDifficulty() {
        guard phase != .playing else { return }
        difficulty = nil
        result = nil
        isReviewingSavedResult = false
        phase = .setup
    }
}
