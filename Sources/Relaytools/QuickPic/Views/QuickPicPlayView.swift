import SwiftUI

struct QuickPicPlayView: View {
    @Environment(QuickPicStore.self) private var game
    @Environment(TrainingStore.self) private var workspace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showQuit = false

    var body: some View {
        let presentedScenarioID = game.scenario?.id
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                ProgressView(value: game.remaining, total: QuickPicStore.duration)
                    .tint(game.remaining < 15 ? .orange : QuickPicStyle.accent)
                    .accessibilityLabel("Time remaining").accessibilityValue(QuickPicFormat.time(game.remaining))
                HStack {
                    Label(game.activeDifficulty.title, systemImage: game.activeDifficulty.symbol)
                    Spacer()
                    Text("\(game.answers.count) judged").monospacedDigit()
                }.font(.system(size: 11)).foregroundStyle(.secondary)
                if let scenario = game.scenario {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right").foregroundStyle(QuickPicStyle.accent)
                            Text("The Conversation").font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Text(scenario.topic.rawValue).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        QuickPicConversation(scenario: scenario)
                    }
                    .padding(22).background(.background, in: RoundedRectangle(cornerRadius: 18))
                    .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.quaternary, lineWidth: 1) }
                    .id(scenario.id)
                    .transition(.opacity)
                }
                Text("How Good Was the Salesperson's Response?").font(.system(size: 15, weight: .semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                    ForEach(QuickPicRating.allCases) { rating in
                        QuickPicRatingButton(rating: rating) { game.answer(rating, scenarioID: presentedScenarioID) }
                            .disabled(!game.canAnswer)
                    }
                }
                feedbackStrip
                HStack {
                    Text("Keys 1, 2, 3 to judge · ⌘. to quit")
                    Spacer()
                    Text("The timer keeps running during feedback and away from this page.")
                }.font(.system(size: 10)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(26).frame(maxWidth: 1060).frame(maxWidth: .infinity)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.13), value: game.scenario?.id)
        .alert("Quit QuickPic!", isPresented: $showQuit) {
            Button("Quit Game", role: .destructive) {
                if game.quit() { workspace.destination = .dashboard }
            }
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text("This unfinished game's XP will not be added to your profile. Your previous scores and personal bests will stay saved.")
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 22) {
                gameTitle
                Spacer()
                metrics
                quitButton
            }
            VStack(alignment: .leading, spacing: 15) {
                HStack { gameTitle; Spacer(); quitButton }
                metrics
            }
        }
    }
    private var gameTitle: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("QuickPic!").font(.system(size: 27, weight: .semibold)).tracking(-0.8)
            Text("Read. Judge. Repeat.").font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
    private var quitButton: some View {
        Button { showQuit = true } label: { Label("Quit Game", systemImage: "rectangle.portrait.and.arrow.right") }
            .controlSize(.large).keyboardShortcut(".", modifiers: .command)
    }
    private var metrics: some View {
        HStack(spacing: 28) {
            VStack(alignment: .trailing, spacing: 5) {
                Text("TIME LEFT").font(.system(size: 8, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
                Text(QuickPicFormat.time(game.remaining))
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .foregroundStyle(game.remaining < 15 ? Color.orange : Color.primary)
                    .phaseAnimator([false, true, false], trigger: game.remaining < 15) { content, phase in
                        content.scaleEffect(!reduceMotion && phase && game.remaining < 15 ? 1.08 : 1)
                    } animation: { _ in .easeInOut(duration: 0.25) }
            }.accessibilityElement(children: .combine)
            VStack(alignment: .trailing, spacing: 5) {
                Text("SESSION XP").font(.system(size: 8, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
                Text(QuickPicFormat.xp(game.xp)).font(.system(size: 28, weight: .semibold, design: .rounded)).foregroundStyle(QuickPicStyle.accent).monospacedDigit()
            }.accessibilityElement(children: .combine)
            VStack(alignment: .trailing, spacing: 5) {
                Text("COMBO").font(.system(size: 8, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
                Text("\(game.combo)×").font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(game.combo >= 5 ? .orange : Brand.accent)
                    .phaseAnimator([false, true, false], trigger: game.feedback?.id) { content, phase in
                        content
                            .scaleEffect(!reduceMotion && phase ? (game.streak == 0 ? 0.95 : game.combo >= 5 ? 1.17 : 1.09) : 1)
                            .shadow(color: game.combo >= 5 && phase && !reduceMotion ? .orange.opacity(0.4) : .clear, radius: 9)
                    } animation: { _ in .spring(duration: 0.18) }
            }.accessibilityElement(children: .combine)
        }
    }

    private var feedbackStrip: some View {
        HStack(spacing: 12) {
            if let feedback = game.feedback {
                Image(systemName: feedback.judgement == .correct ? "checkmark.circle.fill" : feedback.judgement == .partial ? "circle.lefthalf.filled" : "xmark.circle")
                VStack(alignment: .leading, spacing: 4) {
                    Text(feedback.judgement.rawValue).font(.system(size: 13, weight: .semibold))
                    Text(feedback.judgement == .correct ? "Correct rating: " + feedback.scenario.rating.title : "The correct rating was " + feedback.scenario.rating.title + ".")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                if feedback.judgement == .correct && feedback.appliedMultiplier == 10 {
                    Label("10× · Brilliant Run!", systemImage: "sparkles").font(.system(size: 11, weight: .semibold))
                } else if feedback.judgement == .correct && feedback.appliedMultiplier == 5 {
                    Label("5× · Finding Your Flow", systemImage: "bolt.fill").font(.system(size: 11, weight: .semibold))
                } else if feedback.judgement != .correct {
                    Text("Combo Reset").font(.system(size: 11, weight: .medium))
                }
                Text(QuickPicFormat.xp(feedback.xp, signed: true) + " XP")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .phaseAnimator([false, true, false], trigger: feedback.id) { content, phase in
                        content.scaleEffect(!reduceMotion && phase ? 1.09 : 1)
                    } animation: { _ in .easeOut(duration: 0.16) }
            } else {
                Image(systemName: "hand.tap")
                Text("Judge the reply, not what you would have said.").font(.system(size: 12))
                Spacer()
                Text("Next Correct: \(game.nextMultiplier)×").font(.system(size: 11, weight: .medium))
            }
        }
        .foregroundStyle(game.feedback?.judgement == .incorrect ? Color.orange : QuickPicStyle.accent)
        .padding(16).frame(maxWidth: .infinity, minHeight: 72)
        .background(QuickPicStyle.accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 13))
        .accessibilityElement(children: .combine)
    }
}
