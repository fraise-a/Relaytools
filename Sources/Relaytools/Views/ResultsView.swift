import SwiftUI

struct ResultsView: View {
    @Environment(TrainingStore.self) private var workspace
    @Environment(PracticeStore.self) private var practice
    @Environment(\.dismiss) private var dismiss
    let result: SessionResult
    var allowsNewPractice = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                PageHeading(eyebrow: "The debrief", title: result.outcome.title, subtitle: "Your conversation with \(result.customer) · \(result.engine)")
                Surface {
                    HStack(spacing: 28) {
                        ZStack {
                            Circle().stroke(.quaternary, lineWidth: 9)
                            Circle().trim(from: 0, to: Double(result.score) / 100)
                                .stroke(Brand.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
                            VStack(spacing: 3) {
                                Text("\(result.score)").font(.system(size: 34, weight: .semibold, design: .rounded))
                                Text("OUT OF 100").font(.system(size: 8, weight: .medium)).foregroundStyle(.secondary)
                            }
                        }.frame(width: 112, height: 112)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(result.outcome == .won ? "Trust earned. Progress made." : result.outcome == .lost ? "A tough conversation. A useful lesson." : "Another rep in the bank.")
                                    .font(.system(size: 22, weight: .medium)).tracking(-0.4)
                                Spacer()
                                XPText(xp: result.xp)
                            }
                            Text(result.feedback).font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                            if !result.isDemo {
                                if workspace.isSaved(result) {
                                    StatusPill(text: "Saved to your practice history")
                                } else {
                                    HStack(spacing: 10) {
                                        StatusPill(text: "Not saved to disk yet", color: .orange)
                                        Button("Retry Save") { workspace.save() }
                                            .font(.system(size: 11))
                                    }
                                }
                            }
                        }
                    }
                }
                HStack(alignment: .top, spacing: 18) {
                    Surface {
                        VStack(alignment: .leading, spacing: 17) {
                            Label("What Worked", systemImage: "checkmark.seal").foregroundStyle(Brand.accent)
                                .font(.system(size: 14, weight: .semibold))
                            Text(result.displayStrength).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }.frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                    }
                    Surface {
                        VStack(alignment: .leading, spacing: 17) {
                            Label("Your Next Move", systemImage: "arrow.up.right").foregroundStyle(.orange)
                                .font(.system(size: 14, weight: .semibold))
                            Text(result.displayImprovement).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }.frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Where You Left the Customer").font(.system(size: 15, weight: .semibold))
                        SignalBar(title: "Convinced", value: result.signals.conviction, symbol: "lightbulb")
                        SignalBar(title: "At Ease", value: result.signals.comfort, symbol: "heart")
                        SignalBar(title: "Ready to Purchase", value: result.signals.readiness, symbol: "bag")
                    }
                }
                HStack(spacing: 14) {
                    if allowsNewPractice {
                        Button("Practise Again") { practice.reset() }.buttonStyle(.borderedProminent).controlSize(.large)
                    }
                    Button("Return to Dashboard") {
                        if !allowsNewPractice { dismiss() }
                        workspace.destination = .dashboard
                    }.controlSize(.large)
                    Spacer()
                    Text("Wins earn 100 + score XP. Lost customers: −60 XP. Other sessions: −30 to +70 XP.\nNo completed exchanges: 0 XP. Scores are training estimates.")
                        .font(.system(size: 9)).foregroundStyle(.tertiary).multilineTextAlignment(.trailing)
                }
                if !result.messages.isEmpty {
                    DisclosureGroup("Conversation Transcript") {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(result.messages) { message in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(message.isCustomer ? result.customer : "You").font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.accent)
                                    Text(message.text).font(.system(size: 12)).textSelection(.enabled)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }.padding(.vertical, 16)
                    }.font(.system(size: 12)).padding(.top, 8)
                }
            }.padding(32).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }
    }
}
