import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set the running Dock tile directly, even if Launch Services cached an
        // earlier development build before its icon was added.
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL), icon.isValid else { return }
        NSApp.applicationIconImage = icon
        NSApp.dockTile.display()
    }
}
