import SwiftUI

struct MazeResultsView: View {
    @Environment(MazeStore.self) private var game
    @Environment(TrainingStore.self) private var workspace
    @Environment(\.dismiss) private var dismiss
    let result: MazeRunResult
    var canRetry = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                HStack(alignment: .top) {
                    PageHeading(eyebrow: "A-maze-ing! / The debrief", title: "You Found Your Way.", subtitle: "\(result.difficulty.title) · Three conversations. One finish line.")
                    Spacer()
                    StatusPill(text: "Maze completed")
                }
                Surface {
                    HStack(spacing: 24) {
                        Image(systemName: "flag.checkered").font(.system(size: 42)).foregroundStyle(Brand.accent)
                        VStack(alignment: .leading, spacing: 10) {
                            Text(result.coaching.summary).font(.system(size: 15, weight: .medium)).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                            HStack {
                                if workspace.isMazeSaved(result) {
                                    StatusPill(text: "XP banked & run saved")
                                } else {
                                    StatusPill(text: "Run not saved to disk yet", color: .orange)
                                    Button("Retry Save") { workspace.save() }
                                }
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 7) {
                            Text(String(format: "%+d XP", result.xp)).font(.system(size: 29, weight: .semibold, design: .rounded))
                                .foregroundStyle(result.xp >= 0 ? Brand.accent : .orange)
                            Text("Final Reward").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                }
                HStack(spacing: 14) {
                    stat("Completion Time", value: MazeTime.display(result.seconds), symbol: "stopwatch")
                    stat("Customers Convinced", value: "\(result.convinced) / \(result.customerCount)", symbol: "person.crop.circle.badge.checkmark")
                    stat("Communication", value: "\(result.score) / 100", symbol: "bubble.left.and.bubble.right")
                }
                HStack(alignment: .top, spacing: 18) {
                    Surface {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Your Performance").font(.system(size: 15, weight: .semibold))
                            detail("Total Attempts", value: "\(result.attempts.count)")
                            detail("First-Attempt Success", value: "\(result.firstPassRate)%")
                            Divider()
                            detail("Communication Reward · 80%", value: "+\(result.performanceXP) XP")
                            detail("Pace Bonus / Deduction · 20%", value: String(format: "%+d XP", result.timeXP))
                            detail("Unsuccessful Attempt Deductions", value: "−\(result.retryPenalty) XP")
                            Text("Communication quality and first-attempt success carry most of the reward. Speed cannot open a customer gate.")
                                .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Surface {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Maze Timeboard").font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Image(systemName: "trophy").foregroundStyle(.orange)
                            }
                            Text("Same difficulty · Demo colleague times").font(.system(size: 10)).foregroundStyle(.secondary)
                            ForEach(Array(workspace.mazeTimeboard(for: result).enumerated()), id: \.element.id) { index, entry in
                                HStack {
                                    Text("\(index + 1)").foregroundStyle(.tertiary).frame(width: 15)
                                    Text(entry.name).fontWeight(entry.isYou ? .semibold : .regular).lineLimit(1)
                                    Spacer()
                                    Text(MazeTime.display(entry.seconds)).monospacedDigit()
                                }
                                .font(.system(size: 11))
                                .foregroundStyle(entry.isYou ? Brand.accent : .primary)
                                .padding(.vertical, 3)
                            }
                            Text("This run beat \(workspace.mazeTimeboard(for: result).filter { !$0.isYou && $0.seconds > result.seconds }.count) of 4 demo colleague times. Your row shows your best completed time. Colleague times are fictional demo benchmarks.")
                                .font(.system(size: 9)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 18) {
                        coaching("Strongest Responses", symbol: "checkmark.seal", text: result.coaching.strength, color: Brand.accent)
                        ForEach(result.attempts.filter { $0.evaluation.passed }.sorted { $0.evaluation.score > $1.evaluation.score }.prefix(2)) { attempt in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(attempt.customerName).font(.system(size: 11, weight: .semibold))
                                    Spacer()
                                    Text("\(attempt.evaluation.score)/100").font(.system(size: 11, weight: .semibold)).foregroundStyle(Brand.accent)
                                }
                                Text("“" + attempt.response + "”").font(.system(size: 12)).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                            .padding(14).background(Brand.accent.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                        }
                        Divider()
                        coaching("Room to Improve", symbol: "arrow.up.right", text: result.coaching.improvement, color: .orange)
                        Divider()
                        coaching("Your Next Practice", symbol: "scope", text: result.coaching.nextStep, color: Brand.accent)
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 13) {
                        Text("The Conversations").font(.system(size: 15, weight: .semibold))
                        ForEach(result.attempts) { attempt in
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Customer: " + attempt.question).fontWeight(.medium)
                                    Text("You: " + attempt.response).textSelection(.enabled)
                                    Text(attempt.evaluation.feedback).foregroundStyle(.secondary)
                                    Text("Next step: " + attempt.evaluation.improvement).foregroundStyle(.secondary)
                                }.font(.system(size: 12)).padding(.vertical, 12)
                            } label: {
                                HStack {
                                    Text("\(attempt.customerName) · Attempt \(attempt.number)")
                                    Spacer()
                                    Text("\(attempt.evaluation.score)/100 · \(attempt.evaluation.passed ? "Passed" : "Retry")")
                                        .foregroundStyle(attempt.evaluation.passed ? Brand.accent : .orange)
                                }.font(.system(size: 12))
                            }
                            Divider()
                        }
                    }
                }
                HStack(spacing: 13) {
                    if canRetry {
                        Button("Try Another Maze") { game.reset() }.buttonStyle(MazePrimaryButtonStyle()).controlSize(.large)
                    }
                    Button("Return to Dashboard") {
                        if !canRetry { dismiss() }
                        workspace.destination = .dashboard
                    }.controlSize(.large)
                    Spacer()
                    Text("AI feedback is an assessment of this practice, not a guarantee of real customer behaviour.")
                        .font(.system(size: 9)).foregroundStyle(.tertiary).multilineTextAlignment(.trailing)
                }
            }.padding(30).frame(maxWidth: 1170).frame(maxWidth: .infinity)
        }
    }

    private func stat(_ title: String, value: String, symbol: String) -> some View {
        Surface {
            VStack(alignment: .leading, spacing: 15) {
                Label(title, systemImage: symbol).font(.system(size: 11)).foregroundStyle(.secondary)
                Text(value).font(.system(size: 27, weight: .semibold, design: .rounded))
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func detail(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).monospacedDigit()
        }.font(.system(size: 11))
    }
    private func coaching(_ title: String, symbol: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
            Text(text).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
