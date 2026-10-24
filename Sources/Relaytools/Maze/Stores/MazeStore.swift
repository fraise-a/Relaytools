import Foundation
import Observation

@MainActor
struct MazeServices {
    var prepare: (String, MazeDifficulty) async throws -> [String]
    var nextQuestion: (String, MazeDifficulty, MazeCustomer) async throws -> String
    var evaluate: (String, MazeDifficulty, MazeCustomer, String) async throws -> MazeEvaluation
    var coach: (String, [MazeAttempt], MazeDifficulty) async throws -> MazeCoaching

    static var live: Self {
        .init(prepare: { try await MazeAI.prepare(brief: $0, difficulty: $1) },
              nextQuestion: { try await MazeAI.nextQuestion(brief: $0, difficulty: $1, customer: $2) },
              evaluate: { try await MazeAI.evaluate(brief: $0, difficulty: $1, customer: $2, response: $3) },
              coach: { try await MazeAI.coach(brief: $0, attempts: $1, difficulty: $2) })
    }
}

@MainActor @Observable
final class MazeStore {
    var brief = ""
    var difficulty: MazeDifficulty = .medium
    private(set) var activeDifficulty: MazeDifficulty = .medium
    private(set) var activeBrief = ""
    private(set) var phase: MazePhase = .setup
    private(set) var runID = UUID()
    private(set) var layout = MazeLayout(seed: 42)
    private(set) var customers: [MazeCustomer] = []
    private(set) var attempts: [MazeAttempt] = []
    private(set) var player = MazePoint(x: 3.4, z: 3.4)
    private(set) var yaw = 0.0
    private(set) var pitch = 0.0
    private(set) var elapsed = 0.0
    private(set) var hasStartedMoving = false
    private(set) var isCaptured = false
    var wantsCapture = false
    private(set) var encounterID: Int?
    private(set) var feedback: MazeEvaluation?
    private(set) var isBusy = false
    private(set) var currentTime = 0.0
    private(set) var result: MazeRunResult?
    var answer = ""
    var error: String?
    var showProductFacts = false
    var soundEnabled = true

    @ObservationIgnored private let services: MazeServices
    @ObservationIgnored private let clock: @MainActor () -> TimeInterval
    @ObservationIgnored private var operationID = UUID()
    @ObservationIgnored private var startedAt: TimeInterval?
    @ObservationIgnored private var lastApproachedID: Int?
    @ObservationIgnored private var commit: (@MainActor (MazeRunResult) -> Void)?

    init(services: MazeServices? = nil, clock: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.services = services ?? .live
        self.clock = clock
    }

    var activeCustomer: MazeCustomer? { customers.first { $0.id == encounterID } }
    var passedCount: Int { customers.filter(\.passed).count }
    var closedGates: Set<MazeCell> { Set(customers.filter { !$0.passed }.map(\.cell)) }
    var cooldownRemaining: Int { max(0, Int(ceil((activeCustomer?.cooldownUntil ?? 0) - currentTime))) }
    var rewards: MazeRewardBreakdown {
        MazeRewards.calculate(difficulty: activeDifficulty, attempts: attempts, customerCount: customers.count, seconds: elapsed)
    }
    var nextCustomer: MazeCustomer? { customers.first { !$0.passed } }
    var objective: String { nextCustomer.map { "Convince " + $0.name } ?? "All clear. Find the illuminated exit." }
    var objectiveDistance: Int {
        Int(player.distance(to: layout.world(nextCustomer?.cell ?? layout.exit)))
    }

    func begin(workspace: TrainingStore, seed: UInt64? = nil) async {
        guard phase == .setup, !isBusy else { return }
        let text = brief.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 4000 else { return }
        phase = .preparing
        isBusy = true
        error = nil
        let selectedDifficulty = difficulty
        let operationID = self.operationID
        defer { if self.operationID == operationID { isBusy = false } }
        do {
            let questions = try await services.prepare(text, selectedDifficulty)
            guard self.operationID == operationID else { return }
            guard questions.count == 3, questions.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw MazeAIError.invalidQuestion }
            let newLayout = MazeLayout(seed: seed ?? UInt64.random(in: 1...UInt64.max))
            guard newLayout.gates.count == 3 else { throw MazeAIError.invalidQuestion }
            let names = ["Amelia Brooks", "Noah Chen", "Riley Patel", "Morgan Ellis", "Sasha Bennett", "Jamie Clarke"].shuffled()
            let personalities = selectedDifficulty.personalities
            layout = newLayout
            activeDifficulty = selectedDifficulty
            activeBrief = text
            runID = UUID()
            customers = (0..<3).map { .init(id: $0, name: names[$0], personality: personalities[$0], cell: newLayout.gates[$0], question: questions[$0], questions: [questions[$0]]) }
            player = layout.world(layout.start)
            let next = layout.world(layout.path[1])
            yaw = atan2(-(next.x - player.x), -(next.z - player.z))
            pitch = 0
            elapsed = 0
            startedAt = nil
            currentTime = clock()
            hasStartedMoving = false
            attempts = []
            result = nil
            encounterID = nil
            lastApproachedID = nil
            feedback = nil
            answer = ""
            commit = { [weak workspace] result in workspace?.recordMaze(result) }
            workspace.remember(text)
            phase = .playing
            wantsCapture = false
        } catch {
            guard self.operationID == operationID else { return }
            self.error = error.localizedDescription
            phase = .setup
        }
    }

    func requestControls() {
        guard phase == .playing, encounterID == nil else { return }
        wantsCapture = true
    }
    func setCaptured(_ captured: Bool) { isCaptured = captured }
    func releaseControls() { wantsCapture = false; isCaptured = false }

    func look(horizontal: Double, vertical: Double) {
        guard phase == .playing, encounterID == nil, isCaptured else { return }
        yaw = (yaw + horizontal).truncatingRemainder(dividingBy: .pi * 2)
        pitch = min(0.95, max(-0.95, pitch + vertical))
    }

    func step(delta: Double, forward: Double, strafe: Double) {
        let now = clock()
        currentTime = now
        if phase == .playing, let startedAt, now - startedAt - elapsed >= 0.08 { elapsed = max(0, now - startedAt) }
        guard phase == .playing, encounterID == nil, isCaptured else { return }
        let length = hypot(forward, strafe)
        guard length > 0 else { return }
        let distance = 3.9 * min(0.05, max(0, delta))
        let f = forward / max(1, length)
        let s = strafe / max(1, length)
        let dx = (-sin(yaw) * f + cos(yaw) * s) * distance
        let dz = (-cos(yaw) * f - sin(yaw) * s) * distance
        var next = player
        let xCandidate = MazePoint(x: player.x + dx, z: player.z)
        if layout.canOccupy(xCandidate, closedGates: closedGates) { next.x = xCandidate.x }
        let zCandidate = MazePoint(x: next.x, z: player.z + dz)
        if layout.canOccupy(zCandidate, closedGates: closedGates) { next.z = zCandidate.z }
        if next != player {
            if startedAt == nil { startedAt = now; hasStartedMoving = true }
            player = next
        }
        if let lastApproachedID, let previous = customers.first(where: { $0.id == lastApproachedID }),
           player.distance(to: layout.world(previous.cell)) > 4.3 { self.lastApproachedID = nil }
        checkExit()
    }

    func approachNearest(force: Bool = false) async {
        guard phase == .playing, encounterID == nil, !isBusy,
              let customer = customers.first(where: { !$0.passed && player.distance(to: layout.world($0.cell)) < 3.15 }),
              force || lastApproachedID != customer.id else { return }
        encounterID = customer.id
        lastApproachedID = customer.id
        wantsCapture = false
        feedback = nil
        answer = ""
        error = nil
        currentTime = clock()
        if customer.needsNewQuestion, customer.cooldownUntil <= currentTime { await prepareRetry() }
    }

    func submit() async {
        guard let index = customers.firstIndex(where: { $0.id == encounterID }),
              !customers[index].passed, !customers[index].needsNewQuestion, !isBusy,
              customers[index].cooldownUntil <= clock(), phase == .playing else { return }
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 2500 else { return }
        isBusy = true
        error = nil
        let operationID = self.operationID
        defer { if self.operationID == operationID { isBusy = false } }
        do {
            let evaluation = try await services.evaluate(activeBrief, activeDifficulty, customers[index], text)
            guard self.operationID == operationID else { return }
            customers[index].attempts += 1
            attempts.append(.init(customerID: customers[index].id, customerName: customers[index].name,
                question: customers[index].question, response: text, number: customers[index].attempts, evaluation: evaluation))
            feedback = evaluation
            if evaluation.passed {
                customers[index].passed = true
            } else {
                customers[index].cooldownUntil = clock() + 5
                customers[index].needsNewQuestion = true
            }
            currentTime = clock()
        } catch {
            guard self.operationID == operationID else { return }
            self.error = error.localizedDescription
        }
    }

    func prepareRetry() async {
        guard let index = customers.firstIndex(where: { $0.id == encounterID }),
              customers[index].needsNewQuestion, !customers[index].passed, !isBusy,
              customers[index].cooldownUntil <= clock(), phase == .playing else { return }
        isBusy = true
        error = nil
        let operationID = self.operationID
        defer { if self.operationID == operationID { isBusy = false } }
        do {
            let question = try await services.nextQuestion(activeBrief, activeDifficulty, customers[index]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard self.operationID == operationID else { return }
            guard !question.isEmpty, !customers[index].questions.contains(where: { $0.lowercased() == question.lowercased() }) else { throw MazeAIError.repeatedQuestion }
            customers[index].question = question
            customers[index].questions.append(question)
            customers[index].needsNewQuestion = false
            feedback = nil
            answer = ""
        } catch {
            guard self.operationID == operationID else { return }
            self.error = error.localizedDescription
        }
    }

    func leaveEncounter() {
        guard !isBusy else { return }
        encounterID = nil
        feedback = nil
        error = nil
        answer = ""
        requestControls()
    }

    private func checkExit() {
        guard phase == .playing, customers.count == 3, customers.allSatisfy(\.passed),
              player.distance(to: layout.world(layout.exit)) < 1.0, let startedAt else { return }
        elapsed = max(0, clock() - startedAt)
        phase = .finishing
        releaseControls()
        Task { await finishRun() }
    }

    private func finishRun() async {
        let reward = rewards
        var fallback = false
        let coaching: MazeCoaching
        do { coaching = try await services.coach(activeBrief, attempts, activeDifficulty) }
        catch {
            fallback = true
            let strongest = attempts.filter { $0.evaluation.passed }.max { $0.evaluation.score < $1.evaluation.score }
            let weakest = attempts.min { $0.evaluation.score < $1.evaluation.score }
            coaching = .init(summary: "You convinced all three customers. A full final review was unavailable, so this debrief uses the AI feedback from your individual encounters.",
                strength: strongest?.evaluation.feedback ?? "Completed all customer encounters.",
                improvement: weakest?.evaluation.improvement ?? "Keep connecting benefits to the customer's needs.",
                nextStep: weakest?.evaluation.improvement ?? "Practise another route and aim for first-attempt passes.")
        }
        let completed = MazeRunResult(id: runID, difficulty: activeDifficulty, productBrief: activeBrief, seconds: elapsed,
            customerCount: customers.count, attempts: attempts, performanceXP: reward.performance, timeXP: reward.time,
            retryPenalty: reward.penalty, coaching: coaching, usedFallbackReview: fallback)
        result = completed
        commit?(completed)
        phase = .finished
    }

    func abandonRun() {
        guard phase == .playing || phase == .preparing else { return }
        operationID = UUID()
        isBusy = false
        reset()
    }

    func reset() {
        guard !isBusy, phase != .finishing else { return }
        operationID = UUID()
        releaseControls()
        showProductFacts = false
        customers = []
        attempts = []
        elapsed = 0
        hasStartedMoving = false
        lastApproachedID = nil
        commit = nil
        phase = .setup
        result = nil
        encounterID = nil
        feedback = nil
        error = nil
        startedAt = nil
        answer = ""
    }
}
