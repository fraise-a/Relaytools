import SwiftUI

struct QuickPicResultsView: View {
    @Environment(QuickPicStore.self) private var game
    @Environment(TrainingStore.self) private var workspace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let result: QuickPicResult
    private var coaching: QuickPicFeedback { .init(result: result) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    PageHeading(eyebrow: "QuickPic! / The debrief", title: "Two Minutes. Sharper Instincts.",
                                subtitle: coaching.assessment)
                    summary
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 13)], spacing: 13) {
                        QuickPicStat(title: "Questions Answered", value: "\(result.answers.count)", symbol: "bubble.left.and.bubble.right")
                        QuickPicStat(title: "Correct Answers", value: "\(result.correct)", symbol: "checkmark.circle")
                        QuickPicStat(title: "Partially Correct Answers", value: "\(result.partial)", symbol: "circle.lefthalf.filled")
                        QuickPicStat(title: "Incorrect Answers", value: "\(result.incorrect)", symbol: "xmark.circle")
                        QuickPicStat(title: "Accuracy Percentage", value: result.accuracy.formatted(.number.precision(.fractionLength(0...1))) + "%", symbol: "scope")
                        QuickPicStat(title: "Highest Combo", value: "\(result.highestCombo)×", symbol: "bolt")
                        QuickPicStat(title: "Average Response Time", value: result.averageResponseTime.formatted(.number.precision(.fractionLength(1))) + "s", symbol: "stopwatch")
                        QuickPicStat(title: "Personal Best", value: QuickPicFormat.xp(workspace.quickPicBest(for: result.difficulty) ?? result.personalBest) + " XP", symbol: "trophy")
                    }
                    Text("Accuracy is exactly correct answers divided by all answered questions. Partial-credit answers are shown separately. Unanswered cards at 00:00 are discarded.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 18) {
                            feedback.frame(minWidth: 300, maxWidth: .infinity)
                            leaderboard.frame(minWidth: 300, maxWidth: .infinity)
                        }
                        VStack(spacing: 18) { feedback; leaderboard }
                    }
                    ViewThatFits(in: .horizontal) {
                        actions(proxy)
                        VStack(alignment: .leading, spacing: 12) {
                            Button("Play Again") { game.start(workspace: workspace) }.buttonStyle(QuickPicPrimaryStyle())
                            Button("Change Difficulty") { game.changeDifficulty() }
                            Button("Review Your Mistakes") { scrollToMistakes(proxy) }
                            Button("Return to Dashboard") { workspace.destination = .dashboard }
                        }.controlSize(.large)
                    }
                    QuickPicReviewView(mistakes: result.mistakes).id("mistakes")
                }
                .padding(28).frame(maxWidth: 1120).frame(maxWidth: .infinity)
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Total XP Earned").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.75))
                    Text(QuickPicFormat.xp(result.xp, signed: true) + " XP")
                        .font(.system(size: 42, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                    Text("Net score, including partial credit and deductions.").font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                if result.isNewPersonalBest && !game.isReviewingSavedResult {
                    Label("New Personal Best!", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        .padding(12).background(.white.opacity(0.15), in: Capsule())
                        .phaseAnimator([false, true, false]) { content, phase in
                            content.scaleEffect(!reduceMotion && phase ? 1.035 : 1)
                        } animation: { _ in .easeInOut(duration: 0.8) }
                }
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Difficulty Played").font(.system(size: 10)).foregroundStyle(.white.opacity(0.65))
                    Text(result.difficulty.title).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                }
                Spacer()
                if workspace.isQuickPicSaved(result) {
                    Label("Score Saved", systemImage: "checkmark.circle").font(.system(size: 11)).foregroundStyle(.white.opacity(0.8))
                } else {
                    Button("Retry Save") { workspace.save() }.controlSize(.large)
                }
            }
        }
        .padding(25).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(red: 0.16, green: 0.18, blue: 0.37), QuickPicStyle.accent], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18))
    }

    private var feedback: some View {
        Surface {
            VStack(alignment: .leading, spacing: 20) {
                advice("Your Strengths", text: coaching.strength, symbol: "checkmark.seal", color: Brand.accent)
                Divider()
                advice("Where to Improve", text: coaching.improvement, symbol: "scope", color: .orange)
                Divider()
                advice("Your Next Round", text: coaching.nextStep, symbol: "arrow.up.right", color: QuickPicStyle.accent)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var leaderboard: some View {
        Surface {
            VStack(alignment: .leading, spacing: 17) {
                Label("QuickPic! Leaderboard", systemImage: "trophy").font(.system(size: 15, weight: .semibold))
                Text("Personal bests · Same difficulty").font(.system(size: 10)).foregroundStyle(.secondary)
                ForEach(Array(workspace.quickPicLeaderboard(for: result).enumerated()), id: \.element.id) { position, entry in
                    HStack(spacing: 10) {
                        Text("\(position + 1)").foregroundStyle(.tertiary).frame(width: 16)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.name).fontWeight(entry.isYou ? .semibold : .regular).lineLimit(1)
                            Text(entry.role).font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(QuickPicFormat.xp(entry.xp) + " XP").monospacedDigit()
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(entry.isYou ? QuickPicStyle.accent : .primary)
                    .padding(.vertical, 5)
                }
                Divider()
                Text("Colleagues are fictional demo benchmarks. Your score and personal best are saved from your own completed games.")
                    .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func advice(_ title: String, text: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
            Text(text).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func actions(_ proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 12) {
            Button("Play Again") { game.start(workspace: workspace) }.buttonStyle(QuickPicPrimaryStyle())
            Button("Change Difficulty") { game.changeDifficulty() }
            Button("Review Your Mistakes") { scrollToMistakes(proxy) }
            Button("Return to Dashboard") { workspace.destination = .dashboard }
        }.controlSize(.large)
    }
    private func scrollToMistakes(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { proxy.scrollTo("mistakes", anchor: .top) }
    }
}
