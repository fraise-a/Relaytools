import Foundation
import Testing
@testable import Relaytools

@Test @MainActor func unreadableSavedDataIsPreserved() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("training.json")
    let original = Data("incomplete saved JSON".utf8)
    try original.write(to: url)
    let workspace = TrainingStore(fileURL: url)
    #expect(workspace.storageError != nil)
    workspace.remember("A new brief must not overwrite unreadable saved activity.")
    workspace.save()
    #expect(try Data(contentsOf: url) == original)
    #expect(workspace.storageError != nil)
}

@Test func theWholeLatestPitchReachesTheCustomer() {
    let latest = String(repeating: "Context about this customer's needs. ", count: 35) + "The full price is £145 per month, with no annual commitment."
    let messages = [
        ChatMessage(isCustomer: true, text: "What happens to the price if we grow?"),
        ChatMessage(isCustomer: false, text: latest)
    ]
    let context = ConversationContext.transcript(messages)
    #expect(latest.count > 600)
    #expect(context.contains(latest))
    #expect(context.contains("£145 per month"))
}

@MainActor private final class PermissionGate {
    var pending: CheckedContinuation<Bool, Never>?
    var requests = 0

    func request() async -> Bool {
        requests += 1
        return await withCheckedContinuation { pending = $0 }
    }
    func allow() {
        pending?.resume(returning: true)
        pending = nil
    }
}

@Test @MainActor func cancelledSpeechSetupDoesNotRequestTheMicrophone() async {
    let gate = PermissionGate()
    var microphoneRequests = 0
    let voice = VoiceService(speechPermission: { await gate.request() }, microphonePermission: {
        microphoneRequests += 1
        return false
    })
    let pending = Task { await voice.startListening() }
    while gate.pending == nil { await Task.yield() }
    #expect(voice.isPreparing)
    // A repeated click cannot start a second permission flow.
    await voice.startListening()
    #expect(gate.requests == 1)
    voice.stopListening()
    gate.allow()
    await pending.value
    #expect(microphoneRequests == 0)
    #expect(!voice.isPreparing)
    #expect(!voice.isListening)
    #expect(voice.error == nil)
}

@MainActor private final class CustomerGate {
    var pending: CheckedContinuation<CustomerTurn, Never>?
    func wait() async -> CustomerTurn {
        await withCheckedContinuation { pending = $0 }
    }
    func resume() {
        pending?.resume(returning: .init(reply: "What would this change for my team?", signals: .init(),
            outcome: .ongoing, feedback: "Ask about the workflow.", strength: "Started a conversation.", improvement: "Discover the need."))
        pending = nil
    }
}

@Test @MainActor func sessionRetainsTheEngineSelectedWhenItStarted() async {
    let gate = CustomerGate()
    let practice = PracticeStore(responder: { _, _, _, _, _ in await gate.wait() })
    practice.voice.muted = true
    practice.engine = .demo
    practice.brief = "A product brief."
    let workspace = TrainingStore(persist: false)
    let starting = Task { await practice.start(workspace: workspace) }
    while gate.pending == nil { await Task.yield() }
    practice.engine = .onDevice
    gate.resume()
    await starting.value
    #expect(practice.activeEngine == .demo)
    #expect(practice.active)
}

@Test @MainActor func failedReplyCanBeEditedWithoutDuplicatingMessages() async {
    var failReply = true
    let practice = PracticeStore(responder: { _, _, _, messages, signals in
        if !messages.isEmpty && failReply { throw CustomerAIError.empty }
        return .init(reply: "What matters most to you about my workflow?", signals: signals, outcome: .ongoing,
            feedback: "A question was asked.", strength: "Discovery.", improvement: "Check the fit.")
    })
    practice.voice.muted = true
    practice.engine = .demo
    practice.brief = "A team inbox."
    let workspace = TrainingStore(persist: false)
    await practice.start(workspace: workspace)
    practice.draft = "My original reply."
    await practice.send(workspace: workspace)
    #expect(practice.needsRetry)
    #expect(practice.messages.count == 2)
    practice.editPendingReply()
    #expect(!practice.needsRetry)
    #expect(practice.error == nil)
    #expect(practice.draft == "My original reply.")
    #expect(practice.messages.count == 1)
    failReply = false
    practice.draft = "My improved reply."
    await practice.send(workspace: workspace)
    #expect(practice.messages.count == 3)
    #expect(practice.messages.filter { !$0.isCustomer }.map(\.text) == ["My improved reply."])
    await practice.finish(workspace: workspace)
    #expect(workspace.sessions.filter { !$0.isDemo }.count == 1)
}

@Test @MainActor func anEmptySessionHasNoScoreOrXp() async {
    let practice = PracticeStore()
    practice.voice.muted = true
    practice.engine = .demo
    practice.brief = "A team inbox."
    let workspace = TrainingStore(persist: false)
    await practice.start(workspace: workspace)
    await practice.finish(workspace: workspace)
    #expect(practice.result?.score == 0)
    #expect(practice.result?.xp == 0)
}
