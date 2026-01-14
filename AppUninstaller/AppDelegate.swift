import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set application icon for all windows
        if let appIconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let appIcon = NSImage(contentsOfFile: appIconPath) {
            NSApp.applicationIconImage = appIcon
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
