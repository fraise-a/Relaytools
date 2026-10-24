import SwiftUI

@main
struct RelaytoolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var workspace = TrainingStore()
    @State private var practice = PracticeStore()
    @State private var maze = MazeStore()
    @State private var quickPic = QuickPicStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Brand.accent)
                .frame(minWidth: 1120, minHeight: 740)
                .environment(workspace)
                .environment(practice)
                .environment(maze)
                .environment(quickPic)
        }
        .defaultSize(width: 1380, height: 900)
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            AppearanceSettings()
                .environment(workspace)
                .tint(Brand.accent)
        }
    }
}
