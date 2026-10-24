import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(TrainingStore.self) private var workspace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    PageHeading(eyebrow: "Your training workspace", title: "Good to see you, \(workspace.firstName).", subtitle: "A little practice. A lot more confidence.")
                    Spacer()
                    StatusPill(text: "Demo workspace", color: .secondary)
                }
                DashboardJourneyView { workspace.destination = $0 }
                HStack(spacing: 16) {
                    MetricCard(title: "Customers Convinced", value: "\(workspace.totalWins)", caption: "All time", symbol: "person.crop.circle.badge.checkmark")
                    MetricCard(title: "Convinced in 30 Days", value: "\(workspace.recentWins)", caption: "Rolling last 30 days", symbol: "checkmark.bubble")
                    MetricCard(title: "XP Earned", value: workspace.recentXP.formatted(), caption: "Rolling last 30 days", symbol: "sparkles")
                }
                HStack(alignment: .top, spacing: 18) {
                    activity.frame(maxWidth: .infinity)
                    team.frame(width: 286)
                }
                recent
                Text("Dashboard activity and teammates include sample figures for the demo. Completed results from all three tools update your XP automatically.")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            .padding(32)
            .frame(maxWidth: 1280)
            .frame(maxWidth: .infinity)
        }
    }

    private var activity: some View {
        Surface {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Practice Pays Off").font(.system(size: 15, weight: .semibold))
                        Text("XP earned over the last 14 days").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chart.bar.xaxis").foregroundStyle(Brand.accent)
                }
                Chart {
                    ForEach(0..<14, id: \.self) { offset in
                        let date = Calendar.current.startOfDay(for: Date().addingTimeInterval(Double(offset - 13) * 86400))
                        let practiceXP = workspace.sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.xp }
                            + workspace.mazeRuns.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.xp }
                        let xp = Double(practiceXP) + workspace.quickPicRuns.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.xp }
                        BarMark(x: .value("Day", date, unit: .day), y: .value("XP", xp))
                            .foregroundStyle(Brand.accent.gradient).cornerRadius(3)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
                .frame(height: 132)
                .accessibilityLabel("Daily practice XP for the last fourteen days")
            }
        }
    }

    private var team: some View {
        Surface {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("Team Standings").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Image(systemName: "trophy").foregroundStyle(.orange)
                }
                Text("Last 30 days · Demo team").font(.system(size: 11)).foregroundStyle(.secondary)
                ForEach(Array(workspace.leaderboard.prefix(3).enumerated()), id: \.element.id) { index, member in
                    HStack(spacing: 9) {
                        Text("\(index + 1)").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).frame(width: 13)
                        Text(member.name).font(.system(size: 11)).lineLimit(1)
                        Spacer()
                        Text(member.xp.formatted()).font(.system(size: 11, weight: .semibold)).monospacedDigit()
                    }
                }
                Divider()
                Button { workspace.destination = .leaderboard } label: {
                    HStack { Text("You're #\(workspace.rank) on the board"); Spacer(); Image(systemName: "arrow.right") }
                        .font(.system(size: 11, weight: .medium))
                }.buttonStyle(.plain).foregroundStyle(Brand.accent)
            }
        }
    }

    private var recent: some View {
        Surface {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Recent Pitch it! Practice").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Button("View History") { workspace.destination = .history }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Brand.accent)
                }.padding(.bottom, 5)
                ForEach(workspace.sessions.sorted { $0.date > $1.date }.prefix(3)) { session in
                    SessionRow(result: session)
                }
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let caption: String
    let symbol: String
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: symbol).foregroundStyle(Brand.accent)
                }
                Text(value).font(.system(size: 32, weight: .semibold, design: .rounded)).tracking(-0.8)
                Text(caption).font(.system(size: 10)).foregroundStyle(.tertiary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

