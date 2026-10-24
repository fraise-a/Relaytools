import SwiftUI

struct LeaderboardView: View {
    @Environment(TrainingStore.self) private var workspace
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .top) {
                    PageHeading(eyebrow: "A little friendly competition", title: "Leaderboard", subtitle: "Better conversations are a team sport.")
                    Spacer()
                    StatusPill(text: "Last 30 days")
                }
                Surface {
                    HStack(spacing: 20) {
                        Image(systemName: "trophy.fill").font(.system(size: 37)).foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 7) {
                            Text("You're #\(workspace.rank). Keep the momentum.")
                                .font(.system(size: 22, weight: .medium)).tracking(-0.4)
                            Text("\(workspace.recentXP.formatted()) XP earned in the last 30 days.")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Earn More XP") { workspace.destination = .pitch }.buttonStyle(.borderedProminent).controlSize(.large)
                    }
                }
                Surface {
                    VStack(spacing: 0) {
                        HStack {
                            Text("RANK").frame(width: 65, alignment: .leading)
                            Text("TEAM MEMBER")
                            Spacer()
                            Text("30-DAY XP")
                        }.font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.tertiary)
                            .padding(.horizontal, 16).padding(.bottom, 16)
                        Divider()
                        ForEach(Array(workspace.leaderboard.enumerated()), id: \.element.id) { index, member in
                            HStack(spacing: 15) {
                                Text(String(format: "%02d", index + 1))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(index == 0 ? .orange : .secondary)
                                    .frame(width: 50, alignment: .leading)
                                Avatar(initials: member.name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined(),
                                       color: member.isYou ? Brand.accent : .secondary)
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(spacing: 8) {
                                        Text(member.name).font(.system(size: 13, weight: .medium))
                                        if member.isYou { StatusPill(text: "You") }
                                    }
                                    Text(member.isYou ? "Sales professional" : member.role)
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(member.xp.formatted()).font(.system(size: 17, weight: .semibold, design: .rounded))
                                Text("XP").font(.system(size: 10)).foregroundStyle(.tertiary)
                            }
                            .padding(16)
                            .background(member.isYou ? Brand.accent.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 10))
                            if index < workspace.leaderboard.count - 1 { Divider().padding(.leading, 82) }
                        }
                    }
                }
                Label("Demo leaderboard: teammates and starting scores are fictional. Completed results from all three tools update your row.", systemImage: "info.circle")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(32).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }
    }
}

struct HistoryView: View {
    @Environment(TrainingStore.self) private var workspace
    @State private var selected: SessionResult?
    @State private var filter = "All Sessions"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "Every rep counts", title: "Practice History", subtitle: "Revisit the conversations that are making you better.")
                Picker("Show", selection: $filter) {
                    Text("All Sessions").tag("All Sessions")
                    Text("My Practice").tag("My Practice")
                    Text("Customers Convinced").tag("Customers Convinced")
                }.pickerStyle(.segmented).frame(maxWidth: 460)
                Surface {
                    VStack(spacing: 0) {
                        if filtered.isEmpty {
                            ContentUnavailableView("Your first conversation is ahead.", systemImage: "bubble.left.and.bubble.right",
                                description: Text("Start Pitch it! to create your first practice session."))
                        }
                        ForEach(filtered) { session in
                            Button { selected = session } label: {
                                HStack {
                                    SessionRow(result: session)
                                    StatusPill(text: session.isDemo ? "Sample" : session.engine, color: .secondary)
                                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.tertiary)
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
            }.padding(32).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }
        .sheet(item: $selected) { result in
            VStack(spacing: 0) {
                HStack { Text("Session Details").font(.headline); Spacer(); Button("Done") { selected = nil } }.padding(18)
                Divider()
                ResultsView(result: result)
            }.frame(minWidth: 800, idealWidth: 900, minHeight: 650)
        }
    }

    private var filtered: [SessionResult] {
        workspace.sessions.filter {
            filter == "My Practice" ? !$0.isDemo : filter == "Customers Convinced" ? $0.outcome == .won : true
        }.sorted { $0.date > $1.date }
    }
}
