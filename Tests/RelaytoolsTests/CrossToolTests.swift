import Foundation
import Testing
@testable import Relaytools

private func auditPitch(date: Date = Date()) -> SessionResult {
    .init(date: date, customer: "Test Customer", product: "Documented product",
          outcome: .won, signals: .init(conviction: 85, comfort: 85, readiness: 85),
          score: 85, xp: 185, feedback: "A relevant, factual pitch.",
          strength: "Discovery.", improvement: "Keep checking fit.")
}

private func auditMaze(date: Date = Date()) -> MazeRunResult {
    let evaluation = MazeEvaluation(relevance: 90, persuasiveness: 90, accuracy: 90, clarity: 90,
        professionalism: 90, understanding: 90, seriousInaccuracy: false, misleading: false,
        reaction: "That addresses my concern.", feedback: "Factual and relevant.", improvement: "Ask a follow-up.")
    let attempts = (0..<3).map {
        MazeAttempt(customerID: $0, customerName: "Customer \($0)", question: "Why this product?",
                    response: "Here are the documented facts.", number: 1, evaluation: evaluation)
    }
    return .init(id: UUID(), date: date, difficulty: .medium, productBrief: "Documented facts.",
                 seconds: 200, customerCount: 3, attempts: attempts, performanceXP: 430, timeXP: 120,
                 retryPenalty: 0, coaching: .init(summary: "Three customers convinced.", strength: "Honesty.",
                 improvement: "Discovery.", nextStep: "Ask another open question."), usedFallbackReview: false)
}

private func auditQuickPic(date: Date = Date()) -> QuickPicResult {
    let scenario = QuickPicBank.scenarios(for: .easy).first { $0.rating == .requiresImprovement }!
    let answer = QuickPicAnswer(scenario: scenario, chosen: .okay, responseTime: 2,
                               appliedMultiplier: 1, xpHalfUnits: 25)
    return .init(id: UUID(), date: date, difficulty: .easy, answers: [answer],
                 highestCombo: 1, previousBest: nil)
}

@Test @MainActor func everyToolCanRecoverFromAFailedSaveWithoutDuplicatingItsReward() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let directory = root.appendingPathComponent("storage")
    let url = directory.appendingPathComponent("training.json")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = TrainingStore(fileURL: url)
    let beforeXP = workspace.totalXP
    let beforeWins = workspace.totalWins
    // Replace only this test's empty storage directory with a file to force a write failure.
    try FileManager.default.removeItem(at: directory)
    try Data("blocked".utf8).write(to: directory)
    let pitch = auditPitch(), maze = auditMaze(), quickPic = auditQuickPic()
    workspace.record(pitch)
    workspace.recordMaze(maze)
    workspace.recordQuickPic(quickPic)
    workspace.record(pitch)
    workspace.recordMaze(maze)
    workspace.recordQuickPic(quickPic)
    #expect(workspace.storageError != nil)
    #expect(!workspace.isSaved(pitch))
    #expect(!workspace.isMazeSaved(maze))
    #expect(!workspace.isQuickPicSaved(quickPic))
    #expect(workspace.totalXP == beforeXP + 747.5)
    #expect(workspace.totalWins == beforeWins + 4)
    try FileManager.default.removeItem(at: directory)
    #expect(workspace.save())
    #expect(workspace.isSaved(pitch))
    #expect(workspace.isMazeSaved(maze))
    #expect(workspace.isQuickPicSaved(quickPic))
    let reopened = TrainingStore(fileURL: url)
    #expect(reopened.storageError == nil)
    #expect(reopened.totalXP == beforeXP + 747.5)
    #expect(reopened.totalWins == beforeWins + 4)
    #expect(reopened.sessions.filter { $0.id == pitch.id }.count == 1)
    #expect(reopened.mazeRuns == [maze])
    #expect(reopened.quickPicRuns == [quickPic])
    #expect(reopened.leaderboard.first { $0.isYou }?.xp == reopened.recentXP)
}

@Test @MainActor func allToolsUseTheSameRollingWindowAndPreserveHalfPointXp() {
    let workspace = TrainingStore(persist: false)
    let beforeRecent = workspace.recentXP
    let beforeTotal = workspace.totalXP
    let beforeWins = workspace.recentWins
    let old = Date().addingTimeInterval(-31 * 86400)
    let future = Date().addingTimeInterval(86400)
    workspace.record(auditPitch(date: old))
    workspace.recordMaze(auditMaze(date: old))
    workspace.recordQuickPic(auditQuickPic(date: old))
    workspace.record(auditPitch(date: future))
    workspace.recordMaze(auditMaze(date: future))
    workspace.recordQuickPic(auditQuickPic(date: future))
    #expect(workspace.recentXP == beforeRecent)
    #expect(workspace.recentWins == beforeWins)
    #expect(workspace.totalXP == beforeTotal + 1495)
    workspace.record(auditPitch())
    workspace.recordMaze(auditMaze())
    workspace.recordQuickPic(auditQuickPic())
    #expect(workspace.recentXP == beforeRecent + 747.5)
    #expect(workspace.recentWins == beforeWins + 4)
    #expect(workspace.totalXP == beforeTotal + 2242.5)
    #expect(workspace.leaderboard.first { $0.isYou }?.xp == workspace.recentXP)
}

@Test @MainActor func anEmptyPitchCannotInheritInventedPraiseFromTheCustomerOpening() async throws {
    let practice = PracticeStore(responder: { _, _, _, _, signals in
        .init(reply: "What would change for my team?", signals: signals, outcome: .ongoing,
              feedback: "Opening question.", strength: "You handled the price objection brilliantly.",
              improvement: "Close the sale immediately.")
    })
    let workspace = TrainingStore(persist: false)
    let before = workspace.totalXP
    practice.brief = DemoData.exampleBrief
    await practice.start(workspace: workspace)
    await practice.finish(workspace: workspace)
    let result = try #require(practice.result)
    #expect(result.score == 0 && result.xp == 0)
    #expect(result.strength.contains("No sales responses were assessed"))
    #expect(!result.strength.contains("price objection"))
    #expect(result.improvement.contains("open question"))
    #expect(workspace.totalXP == before)
}

@Test func olderEmptyPitchRecordsAlsoShowHonestFeedbackWithoutChangingTheirSavedData() {
    var result = SessionResult(customer: "Test Customer", product: "Test brief", outcome: .ended,
        signals: .init(), score: 0, xp: 0, feedback: "No completed exchange.",
        strength: "You handled the objection brilliantly.", improvement: "Close the sale.")
    #expect(result.displayStrength == SessionResult.unassessedStrength)
    #expect(result.displayImprovement == SessionResult.unassessedImprovement)
    #expect(result.strength == "You handled the objection brilliantly.")
    result.isDemo = true
    #expect(result.displayStrength == result.strength)
    #expect(result.displayImprovement == result.improvement)
}

@Test @MainActor func deniedSpeechAndMicrophonePermissionsLeaveTypingAvailable() async {
    var microphoneAsked = false
    let speechDenied = VoiceService(speechPermission: { false }, microphonePermission: {
        microphoneAsked = true
        return true
    })
    await speechDenied.startListening()
    #expect(!microphoneAsked)
    #expect(!speechDenied.isListening && !speechDenied.isPreparing)
    #expect(speechDenied.error != nil)
    let microphoneDenied = VoiceService(speechPermission: { true }, microphonePermission: { false })
    await microphoneDenied.startListening()
    #expect(!microphoneDenied.isListening && !microphoneDenied.isPreparing)
    #expect(microphoneDenied.error != nil)
}

@Test @MainActor func cancellingWhileMicrophonePermissionIsPendingNeverStartsRecording() async throws {
    var pending: CheckedContinuation<Bool, Never>?
    let voice = VoiceService(speechPermission: { true }, microphonePermission: {
        await withCheckedContinuation { pending = $0 }
    })
    let task = Task { await voice.startListening() }
    for _ in 0..<100 where pending == nil { await Task.yield() }
    let continuation = try #require(pending)
    voice.stopListening()
    continuation.resume(returning: true)
    await task.value
    #expect(!voice.isListening)
    #expect(!voice.isPreparing)
    #expect(voice.error == nil)
}

@Test @MainActor func mazeCustomerPersonalitiesMatchTheSelectedDifficulty() async {
    let services = MazeServices(prepare: { _, _ in ["What does it cost?", "How does it fit?", "What can I verify?"] },
        nextQuestion: { _, _, _ in "Can I try it?" },
        evaluate: { _, _, _, _ in throw MazeAIError.unavailable },
        coach: { _, _, _ in throw MazeAIError.unavailable })
    for difficulty in MazeDifficulty.allCases {
        let game = MazeStore(services: services)
        game.brief = DemoData.exampleBrief
        game.difficulty = difficulty
        await game.begin(workspace: TrainingStore(persist: false), seed: 42)
        #expect(game.activeDifficulty == difficulty)
        #expect(game.customers.map(\.personality) == difficulty.personalities)
        #expect(game.customers.count == 3)
        #expect(game.passedCount == 0)
    }
    #expect(!MazeDifficulty.easy.personalities.joined().lowercased().contains("sceptical"))
    #expect(MazeDifficulty.expert.personalities.joined().lowercased().contains("evidence"))
}
