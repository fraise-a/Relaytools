import Foundation
import Testing
@testable import Relaytools

@Test(.enabled(if: ProcessInfo.processInfo.environment["RELAYTOOLS_AI_SMOKE"] == "1"))
@MainActor func onDeviceCustomerAndReviewIntegration() async throws {
    #expect(CustomerAI.available)
    let persona = CustomerPersona(name: "Morgan Ellis", budget: "Moderate budget", personality: "Careful & analytical",
        experience: "Experienced buyer", priority: "Saving time")
    let opening = try await CustomerAI.respond(brief: DemoData.exampleBrief, persona: persona, messages: [], signals: .init())
    #expect(!opening.reply.isEmpty)
    #expect(opening.outcome != .won)
    let messages = [
        ChatMessage(isCustomer: true, text: opening.reply),
        ChatMessage(isCustomer: false, text: "Before I suggest a solution, what happens when your team misses a customer request, and what would you want to change?")
    ]
    let reply = try await CustomerAI.respond(brief: DemoData.exampleBrief, persona: persona, messages: messages, signals: .init())
    #expect(!reply.reply.isEmpty)
    #expect(reply.signals.conviction >= 0 && reply.signals.conviction <= 100)
    let review = try await CustomerAI.review(messages: messages + [.init(isCustomer: true, text: reply.reply)], outcome: .ended, signals: reply.signals, brief: DemoData.exampleBrief)
    #expect(!review.summary.isEmpty)
    #expect(!review.strength.isEmpty)
    #expect(!review.improvement.isEmpty)
}

@Test func rewardsRespectOutcomesAndEmptySessions() {
    #expect(Scoring.xp(score: 90, outcome: .won, turns: 5) == 190)
    #expect(Scoring.xp(score: 90, outcome: .lost, turns: 5) == -60)
    #expect(Scoring.xp(score: 20, outcome: .ended, turns: 2) == -30)
    #expect(Scoring.xp(score: 45, outcome: .ended, turns: 2) == -10)
    #expect(Scoring.xp(score: 70, outcome: .ended, turns: 3) == 55)
    #expect(Scoring.xp(score: 90, outcome: .ended, turns: 0) == 0)
}

@Test @MainActor func completedPracticeUpdatesRollingStatisticsOnlyOnce() async {
    let workspace = TrainingStore(persist: false)
    let previousXP = workspace.recentXP
    let previousCount = workspace.sessions.count
    let practice = PracticeStore()
    practice.voice.muted = true
    practice.engine = .demo
    practice.brief = DemoData.exampleBrief
    await practice.start(workspace: workspace)
    #expect(practice.active)
    #expect(workspace.prompts.count == 1)
    #expect(practice.customer != nil)

    practice.draft = "You are stupid. I don't care what you need."
    await practice.send(workspace: workspace)
    let result = try! #require(practice.result)
    #expect(result.outcome == .lost)
    #expect(result.xp == -60)
    #expect(workspace.recentXP == previousXP - 60)
    #expect(workspace.sessions.count == previousCount + 1)
    await practice.finish(workspace: workspace)
    workspace.record(result)
    #expect(workspace.sessions.count == previousCount + 1)
    #expect(workspace.recentXP == previousXP - 60)
    #expect(result.signals.comfort >= 0 && result.signals.comfort <= 100)
}

@Test @MainActor func promptsSaveOnStartAndDeduplicate() async {
    let workspace = TrainingStore(persist: false)
    let practice = PracticeStore()
    practice.voice.muted = true
    practice.engine = .demo
    practice.brief = "   "
    await practice.start(workspace: workspace)
    #expect(!practice.active)
    #expect(workspace.prompts.isEmpty)
    practice.brief = "Test product for busy teams."
    await practice.start(workspace: workspace)
    #expect(workspace.prompts.count == 1)
    await practice.finish(workspace: workspace)
    #expect(practice.result?.xp == 0)
    practice.reset()
    await practice.start(workspace: workspace)
    #expect(workspace.prompts.count == 1)
}

@Test @MainActor func aSuccessfulPracticeRecordsAWinAndReward() async {
    let workspace = TrainingStore(persist: false)
    let previousWins = workspace.totalWins
    let previousRecentWins = workspace.recentWins
    let practice = PracticeStore()
    practice.voice.muted = true
    practice.engine = .demo
    practice.brief = DemoData.exampleBrief
    await practice.start(workspace: workspace)
    for _ in 0..<4 {
        practice.draft = "I understand why that matters. It helps because you save time. Would you like to try a trial?"
        await practice.send(workspace: workspace)
    }
    #expect(practice.result?.outcome == .won)
    #expect((practice.result?.xp ?? 0) > 100)
    #expect(workspace.totalWins == previousWins + 1)
    #expect(workspace.recentWins == previousRecentWins + 1)
}

@Test @MainActor func profilePromptsAndResultsSurviveRelaunch() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let url = directory.appendingPathComponent("test.json")
    defer { try? FileManager.default.removeItem(at: directory) }
    let first = TrainingStore(fileURL: url)
    first.employeeName = "Demo Employee"
    first.remember("A product brief to reuse.")
    let result = SessionResult(customer: "Test Customer", product: "Test product", outcome: .won,
        signals: .init(conviction: 90, comfort: 95, readiness: 85), score: 90, xp: 190,
        feedback: "Good fit.", strength: "Listening.", improvement: "Ask about timing.")
    first.record(result)
    let reopened = TrainingStore(fileURL: url)
    #expect(reopened.employeeName == "Demo Employee")
    #expect(reopened.prompts.first?.text == "A product brief to reuse.")
    #expect(reopened.sessions.contains { $0.id == result.id })
    #expect(reopened.recentXP == first.recentXP)

    let before = reopened.recentXP
    var oldResult = result
    oldResult.id = UUID()
    oldResult.date = Date().addingTimeInterval(-31 * 86400)
    reopened.record(oldResult)
    #expect(reopened.recentXP == before)
}

@Test func pinnedPersonaTraitsAreRespected() {
    for _ in 0..<30 {
        let persona = CustomerPersona.make(budget: "Tight budget", personality: "Sceptical & direct",
            experience: "Experienced buyer", priority: "Reliability")
        #expect(persona.budget == "Tight budget")
        #expect(persona.personality == "Sceptical & direct")
        #expect(persona.experience == "Experienced buyer")
        #expect(persona.priority == "Reliability")
        #expect(!persona.name.isEmpty)
        let random = CustomerPersona.make(budget: "Surprise me", personality: "Surprise me",
            experience: "Surprise me", priority: "Surprise me")
        #expect(CustomerPersona.budgets.contains(random.budget))
        #expect(CustomerPersona.personalities.contains(random.personality))
    }
}

@Test @MainActor func leaderboardUsesCurrentEmployeeScore() {
    let workspace = TrainingStore(persist: false)
    let ownRow = workspace.leaderboard.first { $0.isYou }
    #expect(ownRow?.xp == workspace.recentXP)
    #expect(ownRow?.name == workspace.employeeName)
    #expect(workspace.leaderboard.map(\.xp) == workspace.leaderboard.map(\.xp).sorted(by: >))
}
