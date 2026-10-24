import Foundation
import Testing
@testable import Relaytools

private func evaluation(_ score: Int, serious: Bool = false, misleading: Bool = false, feedback: String = "Address the specific concern.") -> MazeEvaluation {
    .init(relevance: score, persuasiveness: score, accuracy: score, clarity: score, professionalism: score,
        understanding: score, seriousInaccuracy: serious, misleading: misleading,
        reaction: score >= 70 ? "That helps." : "I need a clearer answer.", feedback: feedback, improvement: "Use a documented fact.")
}

@MainActor private final class MazeTestClock {
    var now = 1000.0
}

@MainActor private func mazeServices(evaluate: @escaping (String, MazeDifficulty, MazeCustomer, String) async throws -> MazeEvaluation = { _, _, _, _ in evaluation(85) }) -> MazeServices {
    .init(prepare: { _, _ in ["What does it cost?", "How would this fit my team?", "What if it is not right for us?"] },
          nextQuestion: { _, _, customer in "What would a successful trial look like after attempt \(customer.attempts)?" },
          evaluate: evaluate,
          coach: { _, _, _ in .init(summary: "You completed three genuine conversations.", strength: "Explained the facts.", improvement: "Ask more discovery questions.", nextStep: "Practise acknowledging the concern first.") })
}

@Test func mazeRoutesHaveThreeUnavoidableCustomerGates() {
    for seed in 1...200 {
        let maze = MazeLayout(seed: UInt64(seed))
        #expect(maze.gates.count == 3)
        #expect(Set(maze.gates).count == 3)
        #expect(maze.path.first == maze.start)
        #expect(maze.path.last == maze.exit)
        for gate in maze.gates {
            #expect(MazeLayout.route(in: maze.floors.subtracting([gate]), from: maze.start, to: maze.exit).isEmpty)
            #expect(!maze.canOccupy(maze.world(gate), closedGates: [gate]))
            #expect(maze.canOccupy(maze.world(gate), closedGates: []))
        }
        #expect(!maze.canOccupy(maze.world(.init(x: 0, z: 0)), closedGates: []))
    }
}

@Test func mazePassThresholdAndFactualVetoAreAuthoritative() {
    #expect(!evaluation(69).passed)
    #expect(evaluation(70).passed)
    #expect(!evaluation(100, serious: true).passed)
    #expect(!evaluation(100, misleading: true).passed)
    #expect(evaluation(100).score == 100)
    #expect(evaluation(-100).score == 0)
}

@Test func mazeRewardsPrioritiseQualityAndPenaliseRetriesAndSlowFinishes() {
    let clean = (0..<3).map { MazeAttempt(customerID: $0, customerName: "Customer", question: "Why?", response: "A factual answer.", number: 1, evaluation: evaluation(100)) }
    let perfect = MazeRewards.calculate(difficulty: .medium, attempts: clean, customerCount: 3, seconds: 100)
    #expect(perfect.performance == 480)
    #expect(perfect.time == 120)
    #expect(perfect.total == 600)
    let failure = MazeAttempt(customerID: 0, customerName: "Customer", question: "Why?", response: "A weak answer.", number: 1, evaluation: evaluation(30))
    let retried = MazeRewards.calculate(difficulty: .medium, attempts: [failure] + clean, customerCount: 3, seconds: 100)
    #expect(retried.total < perfect.total)
    #expect(retried.penalty > 0)
    let slow = MazeRewards.calculate(difficulty: .medium, attempts: clean, customerCount: 3, seconds: 1000)
    #expect(slow.time == -120)
    #expect(slow.performance == perfect.performance)
    #expect(MazeRewards.calculate(difficulty: .expert, attempts: clean, customerCount: 3, seconds: 100).total > perfect.total)
}

@MainActor private func walk(_ game: MazeStore, toward point: MazePoint, clock: MazeTestClock) {
    game.requestControls()
    game.setCaptured(true)
    for _ in 0..<250 {
        let dx = point.x - game.player.x
        let dz = point.z - game.player.z
        if hypot(dx, dz) < 0.06 { break }
        let targetYaw = atan2(-dx, -dz)
        game.look(horizontal: targetYaw - game.yaw, vertical: 0)
        clock.now += 0.02
        game.step(delta: min(0.02, hypot(dx, dz) / 3.9), forward: 1, strafe: 0)
        if game.phase != .playing { break }
    }
}

@Test(arguments: [false, true]) @MainActor func completePlayableRouteBanksXpOnlyAtTheExitAndOnlyOnce(fallbackReview: Bool) async throws {
    let clock = MazeTestClock()
    var services = mazeServices(evaluate: { _, _, customer, _ in
        if fallbackReview, customer.id == 0, customer.attempts == 0 {
            return evaluation(100, serious: true, feedback: "This unsupported guarantee must never be praised.")
        }
        return evaluation(85, feedback: "You explained the documented price clearly.")
    })
    if fallbackReview { services.coach = { _, _, _ in throw MazeAIError.unavailable } }
    let game = MazeStore(services: services, clock: { clock.now })
    let workspace = TrainingStore(persist: false)
    let startingXP = workspace.totalXP
    game.brief = DemoData.exampleBrief
    await game.begin(workspace: workspace, seed: 42)
    #expect(game.phase == .playing)
    #expect(!game.hasStartedMoving)
    clock.now += 20
    game.step(delta: 0.02, forward: 0, strafe: 0)
    #expect(game.elapsed == 0)
    #expect(workspace.totalXP == startingXP)

    for cell in game.layout.path.dropFirst() {
        let target = game.layout.world(cell)
        if let customer = game.customers.first(where: { $0.cell == cell && !$0.passed }) {
            // Approach the closed gate from the preceding route cell.
            game.requestControls()
            game.setCaptured(true)
            let dx = target.x - game.player.x, dz = target.z - game.player.z
            game.look(horizontal: atan2(-dx, -dz) - game.yaw, vertical: 0)
            for _ in 0..<20 {
                clock.now += 0.02
                game.step(delta: 0.02, forward: 1, strafe: 0)
            }
            await game.approachNearest(force: true)
            #expect(game.activeCustomer?.id == customer.id)
            game.answer = "Here is the product's documented price and a relevant next step."
            await game.submit()
            if fallbackReview, customer.id == 0 {
                #expect(!game.customers[customer.id].passed)
                clock.now += 5.01
                await game.prepareRetry()
                game.answer = "A factual answer using documented product information."
                await game.submit()
            }
            #expect(game.customers[customer.id].passed)
            #expect(workspace.totalXP == startingXP)
            game.leaveEncounter()
        }
        walk(game, toward: target, clock: clock)
    }
    for _ in 0..<100 where game.phase == .finishing { await Task.yield() }
    let result = try #require(game.result)
    #expect(game.hasStartedMoving)
    #expect(result.convinced == 3)
    #expect(result.attempts.count == (fallbackReview ? 4 : 3))
    #expect(result.usedFallbackReview == fallbackReview)
    if fallbackReview {
        #expect(result.coaching.strength == "You explained the documented price clearly.")
    }
    #expect(game.phase == .finished)
    #expect(workspace.mazeRuns.count == 1)
    #expect(workspace.totalXP == startingXP + Double(result.xp))
    workspace.recordMaze(result)
    #expect(workspace.mazeRuns.count == 1)
    #expect(workspace.totalXP == startingXP + Double(result.xp))
}

@Test @MainActor func rejectedCustomerRemainsBlockedAndCooldownRequiresANewQuestion() async throws {
    let clock = MazeTestClock()
    let game = MazeStore(services: mazeServices(evaluate: { _, _, _, _ in evaluation(95, serious: true) }), clock: { clock.now })
    let workspace = TrainingStore(persist: false)
    game.brief = DemoData.exampleBrief
    await game.begin(workspace: workspace, seed: 42)
    let gate = try #require(game.customers.first)
    let index = try #require(game.layout.path.firstIndex(of: gate.cell))
    for cell in game.layout.path[1..<index] { walk(game, toward: game.layout.world(cell), clock: clock) }
    let target = game.layout.world(gate.cell)
    game.requestControls(); game.setCaptured(true)
    game.look(horizontal: atan2(-(target.x - game.player.x), -(target.z - game.player.z)) - game.yaw, vertical: 0)
    for _ in 0..<20 { clock.now += 0.02; game.step(delta: 0.02, forward: 1, strafe: 0) }
    await game.approachNearest(force: true)
    game.answer = "It guarantees an unverified outcome."
    await game.submit()
    #expect(game.feedback?.score == 95)
    #expect(game.feedback?.passed == false)
    #expect(!game.customers[0].passed)
    #expect(game.closedGates.contains(gate.cell))
    #expect(game.cooldownRemaining == 5)
    await game.prepareRetry()
    #expect(game.customers[0].question == gate.question)
    clock.now += 4.99
    game.step(delta: 0, forward: 0, strafe: 0)
    await game.prepareRetry()
    #expect(game.customers[0].question == gate.question)
    clock.now += 0.02
    game.step(delta: 0, forward: 0, strafe: 0)
    await game.prepareRetry()
    #expect(game.customers[0].question != gate.question)
    #expect(!game.customers[0].needsNewQuestion)
    #expect(game.closedGates.contains(gate.cell))
    #expect(workspace.mazeRuns.isEmpty)
}

@Test @MainActor func evaluationServiceFailureAllowsLeavingAndRetryingWithoutLosingXp() async throws {
    let clock = MazeTestClock()
    var failEvaluation = true
    let services = mazeServices(evaluate: { _, _, _, _ in
        if failEvaluation { throw MazeAIError.unavailable }
        return evaluation(85)
    })
    let game = MazeStore(services: services, clock: { clock.now })
    let workspace = TrainingStore(persist: false)
    let startingXP = workspace.totalXP
    game.brief = DemoData.exampleBrief
    await game.begin(workspace: workspace, seed: 42)
    let gate = try #require(game.customers.first)
    let index = try #require(game.layout.path.firstIndex(of: gate.cell))
    for cell in game.layout.path[1..<index] { walk(game, toward: game.layout.world(cell), clock: clock) }
    let target = game.layout.world(gate.cell)
    game.requestControls()
    game.setCaptured(true)
    game.look(horizontal: atan2(-(target.x - game.player.x), -(target.z - game.player.z)) - game.yaw, vertical: 0)
    for _ in 0..<20 { clock.now += 0.02; game.step(delta: 0.02, forward: 1, strafe: 0) }
    await game.approachNearest(force: true)
    game.answer = "A relevant factual response."
    await game.submit()
    #expect(game.error != nil)
    #expect(!game.isBusy)
    #expect(game.attempts.isEmpty)
    #expect(game.closedGates.contains(gate.cell))
    #expect(workspace.totalXP == startingXP)
    game.leaveEncounter()
    #expect(game.activeCustomer == nil)
    #expect(game.wantsCapture)
    failEvaluation = false
    await game.approachNearest(force: true)
    game.answer = "A relevant factual response."
    await game.submit()
    #expect(game.customers[0].passed)
    #expect(game.attempts.count == 1)
    #expect(game.attempts[0].number == 1)
    #expect(workspace.totalXP == startingXP)
    #expect(workspace.mazeRuns.isEmpty)
}

@Test @MainActor func quittingDuringPreparationIgnoresTheLateCustomers() async throws {
    var pending: CheckedContinuation<[String], Error>?
    var services = mazeServices()
    services.prepare = { _, _ in
        try await withCheckedThrowingContinuation { pending = $0 }
    }
    let game = MazeStore(services: services)
    let workspace = TrainingStore(persist: false)
    let startingXP = workspace.totalXP
    game.brief = DemoData.exampleBrief
    let task = Task { await game.begin(workspace: workspace, seed: 42) }
    for _ in 0..<100 where pending == nil { await Task.yield() }
    let continuation = try #require(pending)
    #expect(game.phase == .preparing)
    game.abandonRun()
    #expect(game.phase == .setup)
    #expect(!game.isBusy)
    continuation.resume(returning: ["Price?", "Fit?", "Trial?"])
    await task.value
    #expect(game.phase == .setup)
    #expect(game.customers.isEmpty)
    #expect(workspace.totalXP == startingXP)
    #expect(workspace.mazeRuns.isEmpty)
}

@Test(arguments: [false, true]) @MainActor func quittingDuringCustomerAiIgnoresLateResponses(retrying: Bool) async throws {
    let clock = MazeTestClock()
    var evaluationPending: CheckedContinuation<MazeEvaluation, Error>?
    var questionPending: CheckedContinuation<String, Error>?
    var services = mazeServices()
    services.evaluate = { _, _, _, _ in
        if retrying { return evaluation(30) }
        return try await withCheckedThrowingContinuation { evaluationPending = $0 }
    }
    services.nextQuestion = { _, _, _ in
        try await withCheckedThrowingContinuation { questionPending = $0 }
    }
    let game = MazeStore(services: services, clock: { clock.now })
    let workspace = TrainingStore(persist: false)
    let startingXP = workspace.totalXP
    game.brief = DemoData.exampleBrief
    await game.begin(workspace: workspace, seed: 42)
    let gate = try #require(game.customers.first)
    let index = try #require(game.layout.path.firstIndex(of: gate.cell))
    for cell in game.layout.path[1..<index] { walk(game, toward: game.layout.world(cell), clock: clock) }
    let target = game.layout.world(gate.cell)
    game.requestControls()
    game.setCaptured(true)
    game.look(horizontal: atan2(-(target.x - game.player.x), -(target.z - game.player.z)) - game.yaw, vertical: 0)
    for _ in 0..<20 { clock.now += 0.02; game.step(delta: 0.02, forward: 1, strafe: 0) }
    await game.approachNearest(force: true)
    game.answer = "A sales response."
    if retrying {
        await game.submit()
        clock.now += 5.01
    }
    let task = Task {
        if retrying { await game.prepareRetry() } else { await game.submit() }
    }
    for _ in 0..<100 where evaluationPending == nil && questionPending == nil { await Task.yield() }
    #expect(game.isBusy)
    game.abandonRun()
    #expect(game.phase == .setup)
    #expect(!game.isBusy)
    #expect(!game.isCaptured)
    #expect(!game.wantsCapture)
    #expect(game.elapsed == 0)
    #expect(game.activeCustomer == nil)
    #expect(game.attempts.isEmpty)
    #expect(game.brief == DemoData.exampleBrief)
    // Start another run before the abandoned request returns.
    await game.begin(workspace: workspace, seed: 84)
    if retrying {
        let continuation = try #require(questionPending)
        continuation.resume(returning: "A stale question from the previous run.")
    } else {
        let continuation = try #require(evaluationPending)
        continuation.resume(returning: evaluation(100))
    }
    await task.value
    #expect(game.phase == .playing)
    #expect(game.attempts.isEmpty)
    #expect(game.passedCount == 0)
    #expect(game.feedback == nil)
    #expect(!game.customers.contains { $0.question == "A stale question from the previous run." })
    #expect(workspace.totalXP == startingXP)
    #expect(workspace.mazeRuns.isEmpty)
}

@Test @MainActor func mazeRunsPreserveLegacyDataAndPersistRewards() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let url = directory.appendingPathComponent("training.json")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    // This is the pre-maze document shape, with no mazeRuns field.
    try Data(#"{"employeeName":"Existing Employee","prompts":[],"sessions":[]}"#.utf8).write(to: url)
    let workspace = TrainingStore(fileURL: url)
    #expect(workspace.employeeName == "Existing Employee")
    #expect(workspace.mazeRuns.isEmpty)
    #expect(workspace.storageError == nil)
    let attempts = (0..<3).map { MazeAttempt(customerID: $0, customerName: "Customer \($0)", question: "Why?", response: "A factual explanation.", number: 1, evaluation: evaluation(90)) }
    let run = MazeRunResult(id: UUID(), difficulty: .medium, productBrief: "Test facts.", seconds: 200,
        customerCount: 3, attempts: attempts, performanceXP: 430, timeXP: 120, retryPenalty: 0,
        coaching: .init(summary: "Well done.", strength: "Honesty.", improvement: "Discovery.", nextStep: "Ask one open question."), usedFallbackReview: false)
    workspace.recordMaze(run)
    workspace.recordMaze(run)
    #expect(workspace.totalXP == 550)
    #expect(workspace.totalWins == 3)
    #expect(workspace.isMazeSaved(run))
    let reopened = TrainingStore(fileURL: url)
    #expect(reopened.employeeName == "Existing Employee")
    #expect(reopened.mazeRuns == [run])
    #expect(reopened.recentXP == 550)
    #expect(reopened.leaderboard.first(where: { $0.isYou })?.xp == 550)
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["RELAYTOOLS_MAZE_AI_SMOKE"] == "1"))
@MainActor func mazeUsesContextualAIAndRejectsInventedGuarantees() async throws {
    let questions = try await MazeAI.prepare(brief: DemoData.exampleBrief, difficulty: .medium)
    #expect(questions.count == 3)
    let customer = MazeCustomer(id: 0, name: "Morgan Ellis", personality: "Careful and price-conscious",
        cell: .init(x: 2, z: 1), question: "What will it cost for five people, and can I try it without an annual commitment?",
        questions: ["What will it cost for five people, and can I try it without an annual commitment?"])
    let good = try await MazeAI.evaluate(brief: DemoData.exampleBrief, difficulty: .medium, customer: customer,
        response: "For five users, the published £29 per user comes to £145 per month. There is a 14-day free trial and no annual commitment. We could use that trial to see whether clear message ownership and highlighting unanswered requests help your team before you commit to paying. What would you want to measure during the trial?")
    #expect(good.passed)
    let bad = try await MazeAI.evaluate(brief: DemoData.exampleBrief, difficulty: .medium, customer: customer,
        response: "It is free forever for everyone. I guarantee it will double your revenue, and I can give a 90% discount. Just buy it.")
    #expect(!bad.passed)
    #expect(bad.seriousInaccuracy || bad.misleading)
}
