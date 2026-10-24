import SwiftUI

struct ContentView: View {
    @Environment(TrainingStore.self) private var workspace
    @Environment(PracticeStore.self) private var practice
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 215, ideal: 235, max: 270)
        } detail: {
            Group {
                switch workspace.destination {
                case .dashboard: DashboardView()
                case .pitch: PitchView()
                case .maze: MazeView()
                case .quickPic: QuickPicView()
                case .leaderboard: LeaderboardView()
                case .history: HistoryView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Text("Relaytools").foregroundStyle(.tertiary)
                        Text("/").foregroundStyle(.quaternary)
                        Text(workspace.destination.rawValue).foregroundStyle(.secondary)
                    }.font(.system(size: 12, weight: .medium))
                }
                ToolbarItem(placement: .automatic) {
                    SettingsLink { Image(systemName: "slider.horizontal.3") }
                        .help("Profile & appearance").accessibilityLabel("Profile and appearance settings")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let error = workspace.storageError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11)).foregroundStyle(.orange).padding(10)
                }
            }
        }
        .navigationTitle("Relaytools")
        .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
    }
}
