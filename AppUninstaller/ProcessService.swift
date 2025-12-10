import SwiftUI
import AppKit
import Foundation

struct ProcessItem: Identifiable {
    let id = UUID()
    let pid: Int32
    let name: String
    let icon: NSImage?
    let isApp: Bool // true for GUI Apps, false for background processes
    let validationPath: String? // For apps, the bundle path
    
    var formattedPID: String {
        String(pid)
    }
}

class ProcessService: ObservableObject {
    @Published var processes: [ProcessItem] = []
    @Published var isScanning = false
    
    // Scan specific types
    func scanProcesses(showApps: Bool) async {
        await MainActor.run { isScanning = true }
        
        var items: [ProcessItem] = []
        
        if showApps {
            // Get Running Applications (GUI)
            let apps = NSWorkspace.shared.runningApplications
            for app in apps {
                // Filter out some system daemons that might show up as apps but have no icon or interface
                guard app.activationPolicy == .regular else { continue }
                
                let item = ProcessItem(
                    pid: app.processIdentifier,
                    name: app.localizedName ?? "Unknown App",
                    icon: app.icon,
                    isApp: true,
                    validationPath: app.bundleURL?.path
                )
                items.append(item)
            }
        } else {
            // Get Background Processes using ps command
            // We focus on user processes to avoid listing thousands of system kernel threads
            let task = Process()
            task.launchPath = "/bin/ps"
            task.arguments = ["-x", "-o", "pid,comm"] // List processes owned by user, PID and Command
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: "\n")
                    // Skip header
                    for (index, line) in lines.enumerated() {
                        if index == 0 || line.isEmpty { continue }
                        
                        let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)
                        if let pidString = parts.first, let pid = Int32(pidString) {
                            // Extract name (everything after PID)
                            let cmdParts = parts.dropFirst()
                            // Determine name from path (e.g. /usr/sbin/distnoted -> distnoted)
                            let fullPath = cmdParts.joined(separator: " ")
                             let name = URL(fileURLWithPath: fullPath).lastPathComponent
                            
                            // Filter out this app itself
                            if pid == ProcessInfo.processInfo.processIdentifier { continue }
                            
                            let item = ProcessItem(
                                pid: pid,
                                name: name,
                                icon: nil,
                                isApp: false,
                                validationPath: nil
                            )
                            items.append(item)
                        }
                    }
                }
            } catch {
                print("Error scanning background processes: \(error)")
            }
        }
        
        // Sort: Apps alphabetically, Processes by name
        let sortedItems = items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        
        await MainActor.run {
            self.processes = sortedItems
            self.isScanning = false
        }
    }
    
    func terminateProcess(_ item: ProcessItem) {
        if item.isApp {
            // Try nice termination first for Apps
            if let app = NSRunningApplication(processIdentifier: item.pid) {
                app.terminate()
                
                // If not responding ?? Maybe force option later.
                // For now, let's update list after short delay
            }
        } else {
            // Force kill for background processes
            let task = Process()
            task.launchPath = "/bin/kill"
            task.arguments = ["-9", String(item.pid)]
            try? task.run()
        }
        
        // Optimistic UI Removal
        DispatchQueue.main.async {
            self.processes.removeAll { $0.id == item.id }
        }
    }
}
