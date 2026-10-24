import Foundation
import Testing
@testable import Relaytools

@Test @MainActor func finishingAfterAReplyFailureExcludesTheUnansweredPitch() async throws {
    let practice = PracticeStore(responder: { _, _, _, messages, signals in
        if messages.last?.text == "This reply never received a customer response." { throw CustomerAIError.empty }
        return .init(reply: "I would like to know more.", signals: signals, outcome: .ongoing,
            feedback: "Ask about the need.", strength: "A clear introduction.", improvement: "Be more specific.")
    })
    practice.engine = .demo
    practice.voice.muted = true
    practice.brief = "A product for small teams."
    let workspace = TrainingStore(persist: false)
    await practice.start(workspace: workspace)
    practice.draft = "What would help your team?"
    await practice.send(workspace: workspace)
    practice.draft = "This reply never received a customer response."
    await practice.send(workspace: workspace)
    #expect(practice.needsRetry)
    await practice.finish(workspace: workspace)
    let result = try #require(practice.result)
    #expect(result.messages.last?.isCustomer == true)
    #expect(!result.messages.contains { $0.text == "This reply never received a customer response." })
    #expect(result.feedback.contains("Across 1 exchanges"))
}

@Test @MainActor func aFailedSaveCanBeRetriedWithoutAwardingXpTwice() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let url = directory.appendingPathComponent("training.json")
    defer { try? FileManager.default.removeItem(at: directory) }
    let workspace = TrainingStore(fileURL: url)
    let startingXP = workspace.recentXP
    // Simulate a filesystem conflict after the store has opened normally.
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    let result = SessionResult(customer: "Morgan Ellis", product: "Team inbox", outcome: .won,
        signals: .init(conviction: 85, comfort: 80, readiness: 90), score: 86, xp: 186,
        feedback: "Good discovery.", strength: "Listened.", improvement: "Check timing.")
    workspace.record(result)
    #expect(workspace.storageError != nil)
    #expect(!workspace.isSaved(result))
    #expect(workspace.recentXP == startingXP + 186)

    try FileManager.default.removeItem(at: url)
    #expect(workspace.save())
    #expect(workspace.isSaved(result))
    #expect(workspace.storageError == nil)
    workspace.record(result)
    #expect(workspace.recentXP == startingXP + 186)
    let reopened = TrainingStore(fileURL: url)
    #expect(reopened.isSaved(result))
    #expect(reopened.sessions.filter { $0.id == result.id }.count == 1)
    #expect(reopened.recentXP == workspace.recentXP)
}

@Test func reviewKeepsTheFullLatestPricingAnswer() {
    var messages = (0..<20).map { index in
        ChatMessage(isCustomer: index.isMultiple(of: 2), text: "Earlier exchange \(index): " + String(repeating: "context ", count: 100))
    }
    let answer = String(repeating: "Here is how the product fits your team's needs. ", count: 35)
        + "The verified price is £145 per month. I cannot promise a discount."
    messages.append(.init(isCustomer: false, text: answer))
    messages.append(.init(isCustomer: true, text: "Thanks for being clear about the price."))
    let transcript = ConversationContext.reviewTranscript(messages, messageLimit: 8)
    #expect(transcript.contains(answer))
    #expect(transcript.contains("I cannot promise a discount."))
    #expect(transcript.contains("Thanks for being clear about the price."))
}

