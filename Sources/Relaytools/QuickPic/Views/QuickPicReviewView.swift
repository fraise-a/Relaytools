import SwiftUI

struct QuickPicReviewView: View {
    let mistakes: [QuickPicAnswer]
    @State private var index = 0
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("Review Your Mistakes", systemImage: "text.magnifyingglass").font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Text("\(mistakes.count) to review").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                if mistakes.isEmpty {
                    Label("No mistakes to review. Every answered conversation received the correct judgement.", systemImage: "checkmark.seal")
                        .font(.system(size: 13)).foregroundStyle(Brand.accent)
                } else {
                    let answer = mistakes[min(index, mistakes.count - 1)]
                    HStack {
                        StatusPill(text: answer.judgement.rawValue, color: .orange)
                        Spacer()
                        Text("Conversation \(index + 1) of \(mistakes.count)").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    QuickPicConversation(scenario: answer.scenario, compact: true)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                        rating("Your Rating", value: answer.chosen, color: .orange)
                        rating("Correct Rating", value: answer.scenario.rating, color: Brand.accent)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why This Rating Is Correct").font(.system(size: 13, weight: .semibold))
                        Text(answer.scenario.explanation).font(.system(size: 13)).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        Label(answer.scenario.rating == .perfect ? "Why This Response Worked" : "A Stronger Response",
                              systemImage: answer.scenario.rating == .perfect ? "checkmark.seal" : "pencil.line")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(QuickPicStyle.accent)
                        if answer.scenario.rating == .perfect {
                            Text("The original response already meets the standard. Keep its accurate facts, direct answer and customer-focused approach; no unnecessary rewrite is needed.")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        } else {
                            Text("“" + answer.scenario.improvedResponse + "”").font(.system(size: 13)).lineSpacing(3).textSelection(.enabled)
                        }
                    }
                    .padding(17).frame(maxWidth: .infinity, alignment: .leading)
                    .background(QuickPicStyle.accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                    HStack {
                        Button { index = max(0, index - 1) } label: { Label("Previous Mistake", systemImage: "chevron.left") }
                            .disabled(index == 0)
                            .keyboardShortcut(.leftArrow, modifiers: .option)
                        Spacer()
                        Button { index = min(mistakes.count - 1, index + 1) } label: { Label("Next Mistake", systemImage: "chevron.right") }
                            .disabled(index >= mistakes.count - 1)
                            .keyboardShortcut(.rightArrow, modifiers: .option)
                    }.controlSize(.large)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func rating(_ title: String, value: QuickPicRating, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }
}
