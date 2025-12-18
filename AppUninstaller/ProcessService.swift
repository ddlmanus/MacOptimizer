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
    let memoryUsage: Int64 // 内存使用量（字节）
    
    var formattedPID: String {
        String(pid)
    }
    
    /// 格式化的内存使用量
    var formattedMemory: String {
        ByteCountFormatter.string(fromByteCount: memoryUsage, countStyle: .memory)
    }
}

class ProcessService: ObservableObject {
    @Published var processes: [ProcessItem] = []
    @Published var isScanning = false
    
    // 缓存 PID 到内存使用量的映射
    private var memoryCache: [Int32: Int64] = [:]
    
    // Scan specific types
    func scanProcesses(showApps: Bool) async {
        await MainActor.run { isScanning = true }
        
        // 首先获取所有进程的内存使用量
        await fetchMemoryUsage()
        
        var items: [ProcessItem] = []
        
        if showApps {
            // Get Running Applications (GUI)
            let apps = NSWorkspace.shared.runningApplications
            for app in apps {
                // Filter out some system daemons that might show up as apps but have no icon or interface
                guard app.activationPolicy == .regular else { continue }
                
                let memory = memoryCache[app.processIdentifier] ?? 0
                
                let item = ProcessItem(
                    pid: app.processIdentifier,
                    name: app.localizedName ?? "Unknown App",
                    icon: app.icon,
                    isApp: true,
                    validationPath: app.bundleURL?.path,
                    memoryUsage: memory
                )
                items.append(item)
            }
        } else {
            // Get Background Processes using ps command
            // We focus on user processes to avoid listing thousands of system kernel threads
            let task = Process()
            task.launchPath = "/bin/ps"
            task.arguments = ["-x", "-o", "pid,rss,comm"] // List processes owned by user, PID, RSS (memory) and Command
            
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
                        
                        let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        guard parts.count >= 3,
                              let pid = Int32(parts[0]),
                              let rssKB = Int64(parts[1]) else { continue }
                        
                        // Extract name (everything after PID and RSS)
                        let cmdParts = parts.dropFirst(2)
                        // Determine name from path (e.g. /usr/sbin/distnoted -> distnoted)
                        let fullPath = cmdParts.joined(separator: " ")
                        let name = URL(fileURLWithPath: fullPath).lastPathComponent
                        
                        // Filter out this app itself
                        if pid == ProcessInfo.processInfo.processIdentifier { continue }
                        
                        // RSS is in KB, convert to bytes
                        let memoryBytes = rssKB * 1024
                        
                        let item = ProcessItem(
                            pid: pid,
                            name: name,
                            icon: nil,
                            isApp: false,
                            validationPath: nil,
                            memoryUsage: memoryBytes
                        )
                        items.append(item)
                    }
                }
            } catch {
                print("Error scanning background processes: \(error)")
            }
        }
        
        // Sort: Apps by memory (descending), then by name
        let sortedItems = items.sorted { 
            if $0.memoryUsage != $1.memoryUsage {
                return $0.memoryUsage > $1.memoryUsage // 内存大的排前面
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending 
        }
        
        await MainActor.run {
            self.processes = sortedItems
            self.isScanning = false
        }
    }
    
    /// 获取所有进程的内存使用量
    private func fetchMemoryUsage() async {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-ax", "-o", "pid,rss"] // 所有进程的 PID 和 RSS (内存, KB)
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var cache: [Int32: Int64] = [:]
                let lines = output.components(separatedBy: "\n")
                for (index, line) in lines.enumerated() {
                    if index == 0 || line.isEmpty { continue }
                    
                    let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    guard parts.count >= 2,
                          let pid = Int32(parts[0]),
                          let rssKB = Int64(parts[1]) else { continue }
                    
                    // RSS is in KB, convert to bytes
                    cache[pid] = rssKB * 1024
                }
                memoryCache = cache
            }
        } catch {
            print("Error fetching memory usage: \(error)")
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

    
    func forceTerminateProcess(_ item: ProcessItem) {
        // Always use "kill -9" for force quit
        let task = Process()
        task.launchPath = "/bin/kill"
        task.arguments = ["-9", String(item.pid)]
        try? task.run()
        
        // Optimistic UI Removal
        DispatchQueue.main.async {
            self.processes.removeAll { $0.id == item.id }
        }
    }
}
