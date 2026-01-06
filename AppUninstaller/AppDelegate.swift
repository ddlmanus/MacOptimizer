import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // App started
        // Reset the force quit flag if needed, though mostly irrelevant now
        UserDefaults.standard.set(false, forKey: "ForceQuitApp")
        
        // Initialize MenuBar Manager if needed, ensuring the menu bar icon appears
        _ = MenuBarManager.shared
    }
    
    // Standard Behavior: Terminate when last window closed
    // This solves "Duplicate Windows" by ensuring no ghost process remains.
    // This also removes the Top Menu Bar Icon when app closes, as requested/accepted by user.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
