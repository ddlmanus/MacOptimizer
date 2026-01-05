import SwiftUI

@main
struct AppUninstallerApp: App {
    // Hold a strong reference to the manager
    @StateObject var menuBarManager = MenuBarManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(.dark)
                .task {
                    await UpdateCheckerService.shared.checkForUpdates()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 750)
        
        // MenuBarExtra removed. Manager logic runs on init.
    }
}
