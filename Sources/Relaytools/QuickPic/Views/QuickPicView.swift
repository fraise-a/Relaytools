import SwiftUI

struct QuickPicView: View {
    @Environment(QuickPicStore.self) private var game
    var body: some View {
        Group {
            switch game.phase {
            case .setup: QuickPicSetupView()
            case .playing: QuickPicPlayView()
            case .finished:
                if let result = game.result { QuickPicResultsView(result: result) }
            }
        }
        .onAppear { game.tick() }
    }
}

struct QuickPicSetupView: View {
    @Environment(QuickPicStore.self) private var game
    @Environment(TrainingStore.self) private var workspace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                PageHeading(eyebrow: "Read the room. Make the call.", title: "QuickPic!",
                            subtitle: "Two minutes. Three judgements. Sharpen your sales instincts.")
                hero
                Text("Choose Your Difficulty").font(.system(size: 17, weight: .semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                    ForEach(QuickPicDifficulty.allCases) { difficulty in difficultyCard(difficulty) }
                }
                HStack(spacing: 18) {
                    Button("Start Game") { game.start(workspace: workspace) }
                        .buttonStyle(QuickPicPrimaryStyle()).keyboardShortcut(.return, modifiers: [])
                        .disabled(game.difficulty == nil)
                    Text(game.difficulty == nil ? "Select a difficulty to begin." : "The 02:00 countdown starts immediately.").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                }
                Surface {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("A Fair Call").font(.system(size: 15, weight: .semibold))
                        ForEach(QuickPicRating.allCases) { rating in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: rating.symbol).foregroundStyle(QuickPicStyle.color(rating)).frame(width: 20)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rating.title).font(.system(size: 12, weight: .semibold))
                                    Text(rating.definition).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        Divider()
                        Text("Exact judgement: base XP × your streak, up to 10×. Adjacent rating: 25% base XP. Opposite rating: −25% base XP. Any mistake resets the combo. Partial credit never receives a multiplier.")
                            .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                if !workspace.quickPicRuns.isEmpty { recentRuns }
            }.padding(28).frame(maxWidth: 1120).frame(maxWidth: .infinity)
        }
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 25) {
            VStack(alignment: .leading, spacing: 13) {
                Label("THE TWO-MINUTE MESSAGE CHALLENGE", systemImage: "bolt.fill")
                    .font(.system(size: 10, weight: .bold)).tracking(1.3).foregroundStyle(.white.opacity(0.7))
                Text("Great Response.\nOr Just a Good Pitch?")
                    .font(.system(size: 30, weight: .semibold)).tracking(-0.7).foregroundStyle(.white)
                Text("Read a customer message and the salesperson's reply. Rate the reply itself, using the product facts on the card.")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                Text("180 reviewed cards · No AI or internet required")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.65))
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 12) {
                Text("“Can you guarantee that?”")
                    .font(.system(size: 13)).padding(15).background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 15))
                Text("Read between the lines.")
                    .font(.system(size: 13, weight: .medium)).padding(15)
                    .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 15)).padding(.leading, 25)
                HStack { Spacer(); Label("02:00", systemImage: "timer").font(.system(size: 23, weight: .semibold, design: .monospaced)) }
            }.foregroundStyle(.white).frame(maxWidth: 260)
                .accessibilityHidden(true)
        }
        .padding(27)
        .background(LinearGradient(colors: [Color(red: 0.16, green: 0.18, blue: 0.37), QuickPicStyle.accent], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 19))
    }

    private func difficultyCard(_ difficulty: QuickPicDifficulty) -> some View {
        let selected = game.difficulty == difficulty
        let color: Color = difficulty == .easy ? Brand.accent : difficulty == .medium ? .indigo : .orange
        return Button { game.difficulty = difficulty } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: difficulty.symbol).font(.system(size: 23))
                    Spacer()
                    if selected { Image(systemName: "checkmark.circle.fill") }
                }.foregroundStyle(color)
                Text(difficulty.title).font(.system(size: 17, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                Text(difficulty.subtitle).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text("\(difficulty.baseXP) XP per correct answer").font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
                Text(workspace.quickPicBest(for: difficulty).map { "Personal Best: " + QuickPicFormat.xp($0) + " XP" } ?? "Your first score starts here.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .padding(20).frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
            .background(color.opacity(selected ? 0.11 : 0.035), in: RoundedRectangle(cornerRadius: 15))
            .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(color.opacity(selected ? 0.8 : 0.17), lineWidth: selected ? 2 : 1) }
            .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var recentRuns: some View {
        Surface {
            VStack(alignment: .leading, spacing: 13) {
                Text("Recent QuickPic! Games").font(.system(size: 15, weight: .semibold))
                ForEach(workspace.quickPicRuns.prefix(3)) { run in
                    Button { game.openResult(run) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(run.difficulty.title).font(.system(size: 12, weight: .medium))
                                Text("\(run.answers.count) judged · \(Int(run.accuracy.rounded()))% accuracy")
                                    .font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(QuickPicFormat.xp(run.xp, signed: true) + " XP").font(.system(size: 13, weight: .semibold)).foregroundStyle(QuickPicStyle.accent)
                            Text(run.date, style: .date).font(.system(size: 10)).foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.tertiary)
                        }.padding(.vertical, 9).contentShape(Rectangle())
                    }.buttonStyle(.plain).help("Open saved results and review mistakes")
                }
            }
        }
    }
}
