import SwiftUI

struct MazeView: View {
    @Environment(MazeStore.self) private var game
    var body: some View {
        Group {
            switch game.phase {
            case .setup, .preparing: MazeSetupView()
            case .playing, .finishing: MazePlayView()
            case .finished:
                if let result = game.result { MazeResultsView(result: result) }
            }
        }
        .onDisappear { game.releaseControls() }
    }
}

struct MazeSetupView: View {
    @Environment(MazeStore.self) private var game
    @Environment(TrainingStore.self) private var workspace
    @State private var selectedRun: MazeRunResult?

    var body: some View {
        @Bindable var game = game
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    PageHeading(eyebrow: "Find your way. Earn their trust.", title: "A-maze-ing!", subtitle: "A first-person sales challenge. Three customers stand between you and the exit.")
                    Spacer()
                    StatusPill(text: "3D communication challenge")
                }
                HStack(alignment: .top, spacing: 22) {
                    VStack(alignment: .leading, spacing: 18) {
                        Surface {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Know Your Product", systemImage: "shippingbox")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Give the AI the facts: what you sell, price, benefits, limitations, and the next step you can honestly offer.")
                                    .font(.system(size: 12)).foregroundStyle(.secondary)
                                TextEditor(text: $game.brief)
                                    .font(.system(size: 13)).scrollContentBackground(.hidden)
                                    .padding(10).frame(height: 170)
                                    .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                                    .accessibilityLabel("Maze product facts")
                                    .disabled(game.phase == .preparing)
                                HStack {
                                    Text("Fictional Starting Points").font(.system(size: 10)).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(game.brief.count) / 4,000").font(.system(size: 10)).foregroundStyle(game.brief.count > 4000 ? .red : .secondary)
                                }
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(SampleBriefs.all) { sample in
                                        Button { game.brief = sample.text } label: {
                                            Label(sample.title, systemImage: sample.symbol).font(.system(size: 11)).frame(maxWidth: .infinity, alignment: .leading)
                                        }.controlSize(.large).disabled(game.phase == .preparing)
                                    }
                                }
                                Divider()
                                HStack {
                                    Label(CustomerAI.status, systemImage: "sparkles").font(.system(size: 10)).foregroundStyle(.secondary)
                                    Spacer()
                                    Button {
                                        Task { await game.begin(workspace: workspace) }
                                    } label: {
                                        HStack {
                                            if game.phase == .preparing { ProgressView().controlSize(.small) }
                                            Text(game.phase == .preparing ? "Preparing your customers…" : "Build My Maze")
                                            if game.phase != .preparing { Image(systemName: "arrow.up.right") }
                                        }.font(.system(size: 12, weight: .semibold))
                                    }
                                    .buttonStyle(MazePrimaryButtonStyle()).controlSize(.large)
                                    .disabled(game.phase == .preparing || game.brief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || game.brief.count > 4000 || !CustomerAI.available)
                                }
                            }
                        }
                        Surface {
                            HStack(alignment: .top, spacing: 18) {
                                Image(systemName: "cube.transparent").font(.system(size: 34)).foregroundStyle(Brand.accent)
                                VStack(alignment: .leading, spacing: 9) {
                                    Text("An Actual Maze. Real Conversations.").font(.system(size: 16, weight: .semibold))
                                    Text("Move with W A S D and look with your mouse. Customers block the route until you answer convincingly. Score 70 or above with no serious inaccuracies or misleading claims to pass.")
                                        .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                    Text("Failed attempt? The gate stays closed for a five-second cooldown, then you get a new question.")
                                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }.frame(maxWidth: .infinity)
                    difficultyPanel.frame(width: 285)
                }
                if let error = game.error {
                    Label(error, systemImage: "exclamationmark.triangle").font(.system(size: 12)).foregroundStyle(.orange).textSelection(.enabled)
                }
                if !workspace.mazeRuns.isEmpty {
                    Surface {
                        VStack(alignment: .leading, spacing: 13) {
                            Text("Your Recent Maze Runs").font(.system(size: 15, weight: .semibold))
                            ForEach(workspace.mazeRuns.prefix(4)) { run in
                                Button { selectedRun = run } label: {
                                    HStack {
                                        Image(systemName: "flag.checkered").foregroundStyle(Brand.accent)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(run.difficulty.title).font(.system(size: 12, weight: .medium))
                                            Text("\(MazeTime.display(run.seconds)) · \(run.attempts.count) attempts · \(run.score)/100")
                                                .font(.system(size: 10)).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        XPText(xp: run.xp)
                                        Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.tertiary)
                                    }.padding(.vertical, 7).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }.padding(30).frame(maxWidth: 1250).frame(maxWidth: .infinity)
        }
        .sheet(item: $selectedRun) { run in
            VStack {
                HStack { Text("Maze Results").font(.headline); Spacer(); Button("Done") { selectedRun = nil } }.padding(16)
                MazeResultsView(result: run, canRetry: false)
            }.frame(width: 900, height: 760)
        }
    }

    private var difficultyPanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("CHOOSE YOUR CHALLENGE").font(.system(size: 10, weight: .semibold)).tracking(1.3).foregroundStyle(.secondary)
            ForEach(MazeDifficulty.allCases) { difficulty in
                Button { game.difficulty = difficulty } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text(difficulty.rawValue.uppercased()).font(.system(size: 9, weight: .bold)).tracking(1)
                            Spacer()
                            if game.difficulty == difficulty { Image(systemName: "checkmark.circle.fill") }
                        }.foregroundStyle(Brand.accent)
                        Text(difficulty.title).font(.system(size: 14, weight: .semibold))
                        Text(difficulty.description).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Text("Up to \(difficulty.xpBudget) XP · bigger stakes")
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(game.difficulty == difficulty ? Brand.accent.opacity(0.09) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(game.difficulty == difficulty ? Brand.accent.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: 1) }
                    .contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(game.phase == .preparing)
            }
            Text("80% communication · 20% time\nXP is only banked at the exit. Failed attempts reduce your reward; slow runs can lose the pace bonus.")
                .font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(4).padding(.top, 5)
        }
    }
}
