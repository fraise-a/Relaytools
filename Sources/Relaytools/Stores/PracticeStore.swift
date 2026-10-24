import Foundation
import Observation

enum PracticeEngine: String, CaseIterable, Identifiable {
    case onDevice = "On-device AI"
    case demo = "Demo simulation"
    var id: String { rawValue }
}

@MainActor @Observable
final class PracticeStore {
    typealias Responder = @MainActor (PracticeEngine, String, CustomerPersona, [ChatMessage], CustomerSignals) async throws -> CustomerTurn
    @ObservationIgnored private let respond: Responder

    init(responder: Responder? = nil) {
        respond = responder ?? { engine, brief, persona, messages, signals in
            if engine == .onDevice {
                return try await CustomerAI.respond(brief: brief, persona: persona, messages: messages, signals: signals)
            }
            return DemoCustomer.respond(persona: persona, messages: messages, signals: signals)
        }
    }

    var brief = ""
    var budget = "Surprise me"
    var personality = "Surprise me"
    var experience = "Surprise me"
    var priority = "Surprise me"
    var engine: PracticeEngine = CustomerAI.available ? .onDevice : .demo
    var activeEngine: PracticeEngine = .onDevice
    private(set) var customer: CustomerPersona?
    private(set) var messages: [ChatMessage] = []
    private(set) var signals = CustomerSignals()
    private(set) var isBusy = false
    private(set) var isFinishing = false
    private(set) var outcome: PracticeOutcome = .ongoing
    private(set) var result: SessionResult?
    var error: String?
    var draft = ""
    var needsRetry = false
    let voice = VoiceService()
    @ObservationIgnored private var sessionID = UUID()
    @ObservationIgnored private var currentBrief = ""
    @ObservationIgnored private var lastFeedback = "Build trust by listening before pitching."
    @ObservationIgnored private var strength = "Started a practice conversation."
    @ObservationIgnored private var improvement = "Ask an open question about the customer's needs."
    @ObservationIgnored private var successfulTurns = 0

    var active: Bool { customer != nil && result == nil }
    var productTitle: String {
        let first = currentBrief.split(separator: "\n").first.map(String.init) ?? "Sales practice"
        return String(first.prefix(90))
    }

    func start(workspace: TrainingStore) async {
        let trimmed = brief.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 4000, !isBusy, !active else { return }
        error = nil
        isBusy = true
        defer { isBusy = false }
        let selectedEngine = engine
        let persona = CustomerPersona.make(budget: budget, personality: personality, experience: experience, priority: priority)
        do {
            let opening = try await respond(selectedEngine, trimmed, persona, [], .init())
            sessionID = UUID()
            currentBrief = trimmed
            activeEngine = selectedEngine
            customer = persona
            messages = [.init(isCustomer: true, text: opening.reply)]
            signals = CustomerSignals()
            outcome = .ongoing
            result = nil
            draft = ""
            needsRetry = false
            successfulTurns = 0
            lastFeedback = opening.feedback
            strength = opening.strength
            improvement = opening.improvement
            workspace.remember(trimmed)
            if workspace.destination == .pitch { voice.speak(opening.reply) }
        } catch { self.error = error.localizedDescription }
    }

    func send(workspace: TrainingStore) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard active, !isBusy, !needsRetry, !text.isEmpty, text.count <= 2500 else { return }
        voice.stopListening()
        voice.stopSpeaking()
        messages.append(.init(isCustomer: false, text: text))
        draft = ""
        await requestReply(workspace: workspace)
    }

    func retry(workspace: TrainingStore) async {
        guard needsRetry, !isBusy, active else { return }
        await requestReply(workspace: workspace)
    }

    func editPendingReply() {
        guard needsRetry, !isBusy, let pending = messages.last, !pending.isCustomer else { return }
        messages.removeLast()
        draft = pending.text
        needsRetry = false
        error = nil
    }

    private func requestReply(workspace: TrainingStore) async {
        guard let customer else { return }
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            let turn = try await respond(activeEngine, currentBrief, customer, messages, signals)
            messages.append(.init(isCustomer: true, text: turn.reply))
            successfulTurns += 1
            signals = turn.signals.clamped()
            outcome = turn.outcome
            lastFeedback = turn.feedback
            strength = turn.strength
            improvement = turn.improvement
            needsRetry = false
            if workspace.destination == .pitch { voice.speak(turn.reply) }
            if turn.outcome == .won || turn.outcome == .lost { await complete(workspace: workspace) }
        } catch {
            self.error = error.localizedDescription
            needsRetry = true
        }
    }

    func finish(workspace: TrainingStore) async {
        guard active, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        voice.stopListening()
        voice.stopSpeaking()
        if outcome == .ongoing { outcome = .ended }
        await complete(workspace: workspace)
    }

    private func complete(workspace: TrainingStore) async {
        guard result == nil, let customer else { return }
        isFinishing = true
        defer { isFinishing = false }
        // An unanswered pending pitch must not affect the final assessment.
        let completedMessages = needsRetry && messages.last?.isCustomer == false ? Array(messages.dropLast()) : messages
        if activeEngine == .onDevice && successfulTurns > 0 {
            do {
                let review = try await CustomerAI.review(messages: completedMessages, outcome: outcome, signals: signals, brief: currentBrief)
                lastFeedback = review.summary
                strength = review.strength
                improvement = review.improvement
            } catch {
                lastFeedback += " A full AI review was unavailable; this is feedback from the last completed exchange."
            }
        }
        let score = successfulTurns > 0 ? Scoring.score(signals) : 0
        let xp = Scoring.xp(score: score, outcome: outcome, turns: successfulTurns)
        let summary = successfulTurns == 0
            ? "You ended before completing an exchange. No XP was awarded or deducted."
            : "Across \(successfulTurns) exchanges, you reached \(signals.conviction)% conviction, \(signals.comfort)% comfort, and \(signals.readiness)% purchase readiness. " + lastFeedback
        let completed = SessionResult(id: sessionID, customer: customer.name, product: productTitle, outcome: outcome,
            signals: signals, score: score, xp: xp, feedback: summary,
            strength: successfulTurns > 0 ? strength : SessionResult.unassessedStrength,
            improvement: successfulTurns > 0 ? improvement : SessionResult.unassessedImprovement,
            messages: completedMessages, engine: activeEngine.rawValue)
        result = completed
        workspace.record(completed)
    }

    func reset() {
        guard !isBusy else { return }
        voice.stopListening()
        voice.stopSpeaking()
        customer = nil
        result = nil
        messages = []
        signals = .init()
        error = nil
        needsRetry = false
        draft = ""
    }
}
