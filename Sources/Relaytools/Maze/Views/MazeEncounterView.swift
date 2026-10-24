import SwiftUI

struct MazeEncounterView: View {
    @Environment(MazeStore.self) private var game
    @FocusState private var answerFocused: Bool

    var body: some View {
        @Bindable var game = game
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let customer = game.activeCustomer {
                    HStack(spacing: 13) {
                        Avatar(initials: customer.name.split(separator: " ").compactMap { $0.first.map(String.init) }.joined(), size: 42)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(customer.name).font(.system(size: 18, weight: .semibold))
                            Text("CHECKPOINT \(customer.id + 1) OF 3 · \(game.activeDifficulty.rawValue.uppercased())")
                                .font(.system(size: 9, weight: .medium)).tracking(1).foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusPill(text: customer.passed ? "Gate open" : "Pass: 70+ & factual", color: customer.passed ? Brand.accent : .orange)
                    }
                    Text(customer.personality).font(.system(size: 11)).foregroundStyle(.secondary)
                    Text("“\(customer.question)”").font(.system(size: 20, weight: .medium)).tracking(-0.3).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    if let feedback = game.feedback {
                        feedbackPanel(feedback)
                        if feedback.passed {
                            Button("Continue Through the Passage") { game.leaveEncounter() }
                                .buttonStyle(MazePrimaryButtonStyle()).controlSize(.large)
                        } else {
                            HStack {
                                if game.cooldownRemaining > 0 {
                                    Label("Try again in \(game.cooldownRemaining)s", systemImage: "timer")
                                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.orange)
                                }
                                Button(game.isBusy ? "Preparing a new question…" : "Try Another Question") {
                                    Task { await game.prepareRetry(); answerFocused = true }
                                }
                                .buttonStyle(MazePrimaryButtonStyle()).controlSize(.large)
                                .disabled(game.cooldownRemaining > 0 || game.isBusy)
                                Spacer()
                            }
                        }
                    } else if customer.needsNewQuestion {
                        HStack {
                            Label(game.cooldownRemaining > 0 ? "Gate closed · \(game.cooldownRemaining)s cooldown" : "Ready for a different question", systemImage: "timer")
                                .font(.system(size: 12)).foregroundStyle(.orange)
                            Spacer()
                            Button(game.isBusy ? "Preparing…" : "Ask a New Question") {
                                Task { await game.prepareRetry(); answerFocused = true }
                            }.disabled(game.cooldownRemaining > 0 || game.isBusy)
                        }
                    } else {
                        TextField("How would you address this customer's concern?", text: $game.answer, axis: .vertical)
                            .lineLimit(4...8).font(.system(size: 13)).textFieldStyle(.plain)
                            .padding(14).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                            .focused($answerFocused).accessibilityLabel("Maze customer response")
                            .disabled(game.isBusy)
                        HStack {
                            Text("\(game.answer.count) / 2,500").font(.system(size: 10)).foregroundStyle(game.answer.count > 2500 ? .red : .secondary)
                            Spacer()
                            if game.isBusy { ProgressView().controlSize(.small) }
                            Button(game.isBusy ? "Customer is considering…" : "Make Your Case") {
                                answerFocused = false
                                Task { await game.submit() }
                            }
                            .buttonStyle(MazePrimaryButtonStyle()).controlSize(.large).keyboardShortcut(.return, modifiers: .command)
                            .disabled(game.isBusy || game.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || game.answer.count > 2500)
                        }
                    }
                    if let error = game.error {
                        Label(error, systemImage: "exclamationmark.triangle").font(.system(size: 11)).foregroundStyle(.orange)
                        Text("The gate stays closed. A service error does not count as a failed attempt.")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    if !customer.passed {
                        Button("Step Back into the Maze") { game.leaveEncounter() }
                            .disabled(game.isBusy)
                    }
                    DisclosureGroup("Reference: your product facts") {
                        Text(game.activeBrief).font(.system(size: 12)).foregroundStyle(.secondary).textSelection(.enabled).padding(.top, 8)
                    }.font(.system(size: 11))
                }
            }
            .padding(26)
        }
        .frame(width: 650)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.15), lineWidth: 1) }
        .padding(.horizontal, 20)
        .onAppear { answerFocused = true }
    }

    private func feedbackPanel(_ feedback: MazeEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label(feedback.passed ? "Customer convinced" : "The customer is not convinced", systemImage: feedback.passed ? "checkmark.seal.fill" : "hand.raised")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(feedback.passed ? Brand.accent : .orange)
                Spacer()
                Text("\(feedback.score) / 100").font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            Text("“\(feedback.reaction)”").font(.system(size: 13)).italic()
            Text(feedback.feedback).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if feedback.seriousInaccuracy || feedback.misleading {
                Label("Serious inaccuracies or misleading claims prevent a pass, regardless of the score.", systemImage: "exclamationmark.shield")
                    .font(.system(size: 11)).foregroundStyle(.orange)
            }
            if !feedback.passed {
                Text("Next try: " + feedback.improvement).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(16)
            .background((feedback.passed ? Brand.accent : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
