import Foundation
import Combine
import AppKit

struct HighMemoryApp: Identifiable {
    let id: pid_t
    let name: String
    let usage: Double // GB
    let icon: NSImage?
}

class SystemMonitorService: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0 // Percentage
    @Published var memoryUsedString: String = "0 GB"
    @Published var memoryTotalString: String = "0 GB"
    
    // High Memory Alert
    @Published var highMemoryApp: HighMemoryApp?
    @Published var showHighMemoryAlert: Bool = false
    // Threshold set to 1GB for demonstration
    private let memoryThresholdGB: Double = 1.0 
    private var ignoredPids: Set<pid_t> = []
    
    // Network Speed Monitoring
    @Published var downloadSpeed: Double = 0.0 // bytes per second
    @Published var uploadSpeed: Double = 0.0   // bytes per second
    @Published var downloadSpeedHistory: [Double] = Array(repeating: 0, count: 20)
    @Published var uploadSpeedHistory: [Double] = Array(repeating: 0, count: 20)
    
    private var lastBytesReceived: UInt64 = 0
    private var lastBytesSent: UInt64 = 0
    private var lastNetworkCheck: Date = Date()
    
    // Battery Monitoring
    @Published var batteryLevel: Double = 1.0
    @Published var isCharging: Bool = false
    @Published var batteryState: String = "Unknown" 
    
    private var timer: Timer?

    // Process Monitoring
    struct AppProcess: Identifiable {
        let id: pid_t
        let name: String
        let icon: NSImage?
        let cpu: Double // Percentage
        let memory: Double // GB
    }
    
    @Published var topMemoryProcesses: [AppProcess] = []
    @Published var topCPUProcesses: [AppProcess] = []
    
    // Speed Test
    @Published var isTestingSpeed: Bool = false
    @Published var speedTestResult: Double = 0.0 // Mbps
    @Published var speedTestProgress: Double = 0.0
    
    // WiFi Info
    @Published var wifiSSID: String = "Wi-Fi"
    @Published var wifiSecurity: String = "WPA2 Personal" // Default/Mock for now
    @Published var wifiSignalStrength: String = "良好"
    @Published var connectionDuration: String = "0小时 0分钟 0秒"
    private var connectionStartTime: Date = Date()
    
    // Total Traffic
    @Published var totalDownload: String = "0 KB"
    @Published var totalUpload: String = "0 KB"
    
    // ... updateStats logic ...
    
    private func fetchUserProcesses() {
        // 1. Get User Apps from NSWorkspace
        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        let pids = runningApps.map { $0.processIdentifier }
        
        guard !pids.isEmpty else { return }
        
        // 2. Build map of PID -> App Info
        var appMap: [pid_t: (String, NSImage?)] = [:]
        for app in runningApps {
            appMap[app.processIdentifier] = (app.localizedName ?? "Unknown", app.icon)
        }
        
        // 3. Run ps command to get stats for these pids
        // ps -p pid1,pid2 -o pid,%cpu,rss
        let pidString = pids.map { String($0) }.joined(separator: ",")
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "ps -p \(pidString) -o pid,%cpu,rss | tail -n +2"] // Tail skip header
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var processes: [AppProcess] = []
                
                let lines = output.components(separatedBy: "\n")
                for line in lines {
                    let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if parts.count >= 3,
                       let pid = pid_t(parts[0]),
                       let cpu = Double(parts[1]),
                       let rssKB = Double(parts[2]) {
                        
                        if let info = appMap[pid] {
                            processes.append(AppProcess(
                                id: pid,
                                name: info.0,
                                icon: info.1,
                                cpu: cpu,
                                memory: rssKB / 1024.0 / 1024.0 // KB -> GB
                            ))
                        }
                    }
                }
                
                // Sort and Update
                let sortedByMem = processes.sorted { $0.memory > $1.memory }.prefix(5)
                let sortedByCPU = processes.sorted { $0.cpu > $1.cpu }.prefix(5)
                
                DispatchQueue.main.async {
                    self.topMemoryProcesses = Array(sortedByMem)
                    self.topCPUProcesses = Array(sortedByCPU)
                }
            }
        } catch {
            print("User Process Scan Error: \(error)")
        }
    }
    
    func runSpeedTest() {
        guard !isTestingSpeed else { return }
        isTestingSpeed = true
        speedTestResult = 0
        speedTestProgress = 0
        
        // Simple download test (download a 10MB file or similar)
        // Using a reliable CDN test file (e.g., Cloudflare)
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=10000000") else { return }
        
        let startTime = Date()
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isTestingSpeed = false
                self?.speedTestProgress = 1.0
                
                if let data = data {
                    let duration = Date().timeIntervalSince(startTime)
                    let bits = Double(data.count) * 8
                    let mbps = (bits / duration) / 1_000_000
                    self?.speedTestResult = mbps
                }
            }
        }
        
        // Fake Progress or delegate? simpler for now just wait.
        // Or implement delegate for progress.
        task.resume()
    }
    
    // ... add fetchUserProcesses() to updateStats ...
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        updateStats()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    // 格式化网络速度
    func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000_000 {
            return String(format: "%.1f GB/s", bytesPerSecond / 1_000_000_000)
        } else if bytesPerSecond >= 1_000_000 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000)
        } else if bytesPerSecond >= 1_000 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1_000)
        } else {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }
    
    private func updateStats() {
        checkHighMemoryApps()
        fetchUserProcesses()
        
        // CPU Usage (Simplified using top for now to avoid complex Mach calls issues in pure Swift script context initially, 
        // but robust implementation would use host_processor_info. Let's try to parse top -l 1 output specifically designed for machine reading if possible, 
        // or just standard parsing.)
        // Actually, let's use a simpler bash command approach which is safer/easier to debug in this agent environment.
        // `ps -A -o %cpu | awk '{s+=$1} END {print s}'` gives total CPU usage sum (can be > 100% on multi-core).
        
        let cpuTask = Process()
        cpuTask.launchPath = "/bin/bash"
        cpuTask.arguments = ["-c", "ps -A -o %cpu | awk '{s+=$1} END {print s}'"]
        
        let pipe = Pipe()
        cpuTask.standardOutput = pipe
        
        do {
            try cpuTask.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let totalCPU = Double(output) {
                // Normalize by core count approximately? Or just show raw. 
                // Let's normalize by active core count to get 0-100% range typically expected by users.
                let coreCount = Double(ProcessInfo.processInfo.activeProcessorCount)
                DispatchQueue.main.async {
                    self.cpuUsage = min((totalCPU / coreCount) / 100.0, 1.0)
                }
            }
        } catch {
            print("CPU Scan Error: \(error)")
        }
        
        // Memory Usage
        // Uses `vm_stat`
        let memTask = Process()
        memTask.launchPath = "/usr/bin/vm_stat"
        
        let memPipe = Pipe()
        memTask.standardOutput = memPipe
        
        do {
            try memTask.run()
            let data = memPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                var pageSize: UInt64 = 16384 // Apple Silicon default
                var pagesActive: UInt64 = 0
                var pagesInactive: UInt64 = 0
                var pagesSpeculative: UInt64 = 0
                var pagesWired: UInt64 = 0
                var pagesCompressed: UInt64 = 0 // Pages occupied by compressor
                
                for line in lines {
                    if line.contains("page size of") {
                        // Format: "Mach Virtual Memory Statistics: (page size of 16384 bytes)"
                        if let match = line.range(of: "\\d+", options: .regularExpression) {
                            if let size = UInt64(line[match]) {
                                pageSize = size
                            }
                        }
                    } else if line.hasPrefix("Pages active:") {
                        pagesActive = extractPageCount(line)
                    } else if line.hasPrefix("Pages inactive:") {
                        pagesInactive = extractPageCount(line)
                    } else if line.hasPrefix("Pages speculative:") {
                        pagesSpeculative = extractPageCount(line)
                    } else if line.hasPrefix("Pages wired down:") {
                        pagesWired = extractPageCount(line)
                    } else if line.hasPrefix("Pages occupied by compressor:") {
                        pagesCompressed = extractPageCount(line)
                    }
                }
                
                let totalRAM = ProcessInfo.processInfo.physicalMemory
                
                // Activity Monitor "App Memory" ≈ Anonymous pages = Active + Inactive - Purgeable (approx)
                // "Used Memory" ≈ App + Wired + Compressed
                // More accurate: used = total - free - (purgeable is part of inactive)
                // Let's match Activity Monitor's "Used Memory" more closely:
                // Used = (Pages Active + Inactive + Speculative + Wired + Compressor) - Purgeable
                // Or simpler: Used = Total - Free - Purgeable (cached that can be freed)
                
                let usedPages = pagesActive + pagesWired + pagesCompressed + pagesSpeculative
                let usedRAM = usedPages * pageSize
                
                // For breakdown: App Memory ≈ Active + Inactive (anonymous portion) - hard to get exact
                // Let's use: App = Active, Wired = Wired, Compressed = Compressor pages
                // This is simpler and somewhat matches. For exact match, would need more complex parsing.
                
                // Refined: Activity Monitor shows:
                // App Memory = internal (anonymous) pages = Active + Inactive that are anonymous
                // Wired = wired
                // Compressed = compressor occupied
                // Since we can't easily separate anonymous vs file-backed in inactive, let's use:
                // App = Active + (Inactive - Pages Purgeable) roughly
                // But for simplicity in UI matching, let's just use direct values for now.
                
                DispatchQueue.main.async {
                    self.memoryUsage = Double(usedRAM) / Double(totalRAM)
                    self.memoryUsedString = ByteCountFormatter.string(fromByteCount: Int64(usedRAM), countStyle: .memory)
                    self.memoryTotalString = ByteCountFormatter.string(fromByteCount: Int64(totalRAM), countStyle: .memory)
                }
                
                // For detailed breakdown, use raw page counts
                self.updateDetailedStats(pagesActive: pagesActive + pagesInactive + pagesSpeculative, pagesWired: pagesWired, pagesCompressed: pagesCompressed, pageSize: pageSize, totalRAM: totalRAM)
            }
        } catch {
            print("Memory Scan Error: \(error)")
        }
        
        updateBatteryDetails() // Call new battery details
        
        // Network Speed - 使用 netstat 获取网络流量
        // 找到 en0 接口中有实际流量的行（第7列 Ibytes > 0）
        let netTask = Process()
        netTask.launchPath = "/bin/bash"
        netTask.arguments = ["-c", "netstat -ib | awk '/en0/ && $7 > 0 {print $7, $10; exit}'"]
        
        let netPipe = Pipe()
        netTask.standardOutput = netPipe
        
        do {
            try netTask.run()
            let data = netPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                let parts = output.components(separatedBy: " ").filter { !$0.isEmpty }
                if parts.count >= 2,
                   let bytesIn = UInt64(parts[0]),
                   let bytesOut = UInt64(parts[1]) {
                    
                    let now = Date()
                    let timeDiff = now.timeIntervalSince(lastNetworkCheck)
                    
                    if timeDiff > 0 && lastBytesReceived > 0 {
                        let downloadDelta = bytesIn > lastBytesReceived ? Double(bytesIn - lastBytesReceived) : 0
                        let uploadDelta = bytesOut > lastBytesSent ? Double(bytesOut - lastBytesSent) : 0
                        
                        let downloadRate = downloadDelta / timeDiff
                        let uploadRate = uploadDelta / timeDiff
                        
                        DispatchQueue.main.async {
                            self.downloadSpeed = downloadRate
                            self.uploadSpeed = uploadRate
                            
                            // Update Totals (Cumulative from netstat)
                            self.totalDownload = ByteCountFormatter.string(fromByteCount: Int64(bytesIn), countStyle: .file)
                            self.totalUpload = ByteCountFormatter.string(fromByteCount: Int64(bytesOut), countStyle: .file)
                            
                            // Update History
                            self.downloadSpeedHistory.removeFirst()
                            self.downloadSpeedHistory.append(downloadRate)
                            self.uploadSpeedHistory.removeFirst()
                            self.uploadSpeedHistory.append(uploadRate)
                        }
                    }
                    
                    lastBytesReceived = bytesIn
                    lastBytesSent = bytesOut
                    lastNetworkCheck = now
                }
            }
        } catch {
            print("Network Scan Error: \(error)")
        }
        
        fetchWiFiInfo()
        updateConnectionDuration()
        updateBatteryStatus()
    }
    
    // Fetch WiFi Info using airport utility
    private func fetchWiFiInfo() {
        let task = Process()
        task.launchPath = "/bin/bash"
        // Use standard path for airport utility on macOS
        task.arguments = ["-c", "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk -F': ' '/ SSID/ {print $2}'"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
                DispatchQueue.main.async {
                    self.wifiSSID = output
                }
            } else {
                 DispatchQueue.main.async {
                    self.wifiSSID = "Wi-Fi Not Connected"
                }
            }
        } catch {
             // Fallback
        }
    }
    
    private func updateConnectionDuration() {
        let duration = Date().timeIntervalSince(connectionStartTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        DispatchQueue.main.async {
             self.connectionDuration = String(format: "%d小时 %d分钟 %d秒", hours, minutes, seconds)
        }
    }
    
    private func updateBatteryStatus() {
        // Use pmset -g batt
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["-g", "batt"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Example output:
                // Now drawing from 'AC Power'
                // -InternalBattery-0 (id=1234567)	98%; charging; 0:10 remaining present: true
                
                let lines = output.components(separatedBy: "\n")
                if lines.count >= 2 {
                    let statusLine = lines[1]
                    
                    // Parse Percentage
                    if let range = statusLine.range(of: "\\d+%", options: .regularExpression) {
                        let percentString = String(statusLine[range]).dropLast()
                        if let percent = Double(percentString) {
                            DispatchQueue.main.async {
                                self.batteryLevel = percent / 100.0
                            }
                        }
                    }
                    
                    // Parse Charging State
                    DispatchQueue.main.async {
                        if output.contains("AC Power") {
                            self.isCharging = true
                            if statusLine.contains("charging") {
                                self.batteryState = "正在充电"
                            } else {
                                self.batteryState = "已连接电源"
                            }
                        } else {
                            self.isCharging = false
                            self.batteryState = "使用电池"
                        }
                    }
                }
            }
        } catch {
            print("Battery Scan Error: \(error)")
        }
    }
    

    func checkHighMemoryApps() {
        // Use ps to get pid and rss
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "ps -aceo pid,rss,comm"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                // Skip header (PID RSS COMM)
                
                var maxRSS: Double = 0
                var maxPID: pid_t = 0
                var maxName: String = ""
                
                for line in lines.dropFirst() {
                    let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if parts.count >= 3 {
                        if let pid = pid_t(parts[0]),
                           let rssKB = Double(parts[1]) {
                            
                            // Check ignore list and self
                            if pid == ProcessInfo.processInfo.processIdentifier { continue }
                            if ignoredPids.contains(pid) { continue }
                                                        
                            let rssGB = rssKB / 1024.0 / 1024.0
                            
                            if rssGB > memoryThresholdGB && rssGB > maxRSS {
                                maxRSS = rssGB
                                maxPID = pid
                                // Comm might be truncated or just the binary name.
                                // Use NSRunningApplication for better name/icon if possible.
                                maxName = parts[2...].joined(separator: " ") 
                            }
                        }
                    }
                }
                
                if maxRSS > 0 {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        // Only update if it's a new alert or different app
                        if self.highMemoryApp?.id != maxPID {
                            var appName = maxName
                            var appIcon: NSImage?
                            
                            if let app = NSRunningApplication(processIdentifier: maxPID) {
                                appName = app.localizedName ?? maxName
                                appIcon = app.icon
                            }
                            
                            self.highMemoryApp = HighMemoryApp(id: maxPID, name: appName, usage: maxRSS, icon: appIcon)
                            self.showHighMemoryAlert = true
                        }
                    }
                }
            }
        } catch {
            print("Process Scan Error: \(error)")
        }
    }
    
    func ignoreCurrentHighMemoryApp() {
        if let app = highMemoryApp {
            ignoredPids.insert(app.id)
            highMemoryApp = nil
            showHighMemoryAlert = false
        }
    }
    
    func terminateHighMemoryApp() {
        if let app = highMemoryApp,
           let runningApp = NSRunningApplication(processIdentifier: app.id) {
            runningApp.terminate()
            // Force kill if needed? Start with terminate.
            
            // Add to ignore list so we don't alert again immediately if it takes time to close
            ignoredPids.insert(app.id)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.highMemoryApp = nil
                self?.showHighMemoryAlert = false
            }
        } else if let app = highMemoryApp {
             // Fallback for non-app processes? kill command
             let killTask = Process()
             killTask.launchPath = "/bin/kill"
             killTask.arguments = ["\(app.id)"]
             try? killTask.run()
             
             ignoredPids.insert(app.id)
             highMemoryApp = nil
             showHighMemoryAlert = false
        }
    }
    
    // Detailed Stats
    @Published var systemUptime: TimeInterval = 0
    @Published var memoryApp: Double = 0
    @Published var memoryWired: Double = 0
    @Published var memoryCompressed: Double = 0
    @Published var memoryPressure: Double = 0.0 // Percentage
    @Published var memorySwapUsed: String = "0 B"
    @Published var memorySwapTotal: String = "0 B"
    @Published var batteryHealth: String = "Good"
    @Published var batteryCycleCount: Int = 0
    @Published var batteryCondition: String = "Normal"
    
    // ... existing extractPageCount ...
    private func extractPageCount(_ line: String) -> UInt64 {
        let parts = line.components(separatedBy: ":")
        if parts.count == 2 {
            let numberPart = parts[1].replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)
            return UInt64(numberPart) ?? 0
        }
        return 0
    }
    
    // Add logic to updateStats
    private func updateDetailedStats(pagesActive: UInt64, pagesWired: UInt64, pagesCompressed: UInt64, pageSize: UInt64, totalRAM: UInt64) {
        DispatchQueue.main.async {
            self.memoryApp = Double(pagesActive * pageSize) / Double(totalRAM)
            self.memoryWired = Double(pagesWired * pageSize) / Double(totalRAM)
            self.memoryCompressed = Double(pagesCompressed * pageSize) / Double(totalRAM)
            
            // Uptime
            var boottime = timeval()
            var size = MemoryLayout<timeval>.stride
            if sysctlbyname("kern.boottime", &boottime, &size, nil, 0) == 0 {
                let bootDate = Date(timeIntervalSince1970: Double(boottime.tv_sec) + Double(boottime.tv_usec) / 1_000_000.0)
                self.systemUptime = Date().timeIntervalSince(bootDate)
            }
        }
        
        updateMemoryPressureAndSwap()
    }
    
    private func updateMemoryPressureAndSwap() {
        // Memory Pressure
        let pressureTask = Process()
        pressureTask.launchPath = "/usr/bin/memory_pressure"
        pressureTask.arguments = ["-Q"]
        
        let pressurePipe = Pipe()
        pressureTask.standardOutput = pressurePipe
        
        DispatchQueue.global(qos: .background).async {
            do {
                try pressureTask.run()
                let data = pressurePipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    // Output: "System-wide memory free percentage: 48%"
                    if let range = output.range(of: "\\d+%", options: .regularExpression) {
                        let percentString = String(output[range]).dropLast()
                        if let freePercent = Double(percentString) {
                            DispatchQueue.main.async {
                                // Pressure is inverse of free percentage in this context roughly,
                                // or we can use the "inverted" value as pressure.
                                // CleanMyMac pressure usually aligns with "Used" but let's assume
                                // Pressure = 100 - Free% for now as a proxy if no better stat.
                                self.memoryPressure = (100.0 - freePercent) / 100.0
                            }
                        }
                    }
                }
            } catch {
                print("Memory Pressure Error: \(error)")
            }
        }
        
        // Swap Usage
        // sysctl vm.swapusage
        let swapTask = Process()
        swapTask.launchPath = "/usr/sbin/sysctl"
        swapTask.arguments = ["vm.swapusage"]
        
        let swapPipe = Pipe()
        swapTask.standardOutput = swapPipe
        
        DispatchQueue.global(qos: .background).async {
            do {
                try swapTask.run()
                let data = swapPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    // vm.swapusage: total = 5120.00M  used = 4426.56M  free = 693.44M  (encrypted)
                    let components = output.components(separatedBy: " ")
                    var usedStr = ""
//                    var totalStr = ""
                    
                    for (index, comp) in components.enumerated() {
                        if comp == "used" && index + 2 < components.count {
                             // index+1 is "=", index+2 is value
                             usedStr = components[index + 2]
                        }
                    }
                    
                    // Parse "4426.56M" to bytes for formatting if needed, but it comes with unit.
                    // Let's re-format nicely.
                    // Actually, let's keep it simple and just trim/clean.
                    
                    DispatchQueue.main.async {
                         if !usedStr.isEmpty {
                            self.memorySwapUsed = usedStr
                        }
                    }
                }
            } catch {
                print("Swap Usage Error: \(error)")
            }
        }
    }
    
    private func updateBatteryDetails() {
         let task = Process()
         task.launchPath = "/usr/sbin/system_profiler"
         task.arguments = ["SPPowerDataType"]
         
         let pipe = Pipe()
         task.standardOutput = pipe
         
         // Run asynchronously to avoid blocking main thread heavy task
         DispatchQueue.global(qos: .background).async {
             do {
                 try task.run()
                 let data = pipe.fileHandleForReading.readDataToEndOfFile()
                 if let output = String(data: data, encoding: .utf8) {
                     // Parse Cycle Count and Condition
                     // "Cycle Count: 123"
                     // "Condition: Normal"
                     var cycleCount = 0
                     var condition = "Normal"
                     var maxCapacity = 100
                     
                     let lines = output.components(separatedBy: "\n")
                     for line in lines {
                         if line.contains("Cycle Count:") {
                             if let val = Int(line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "") {
                                 cycleCount = val
                             }
                         } else if line.contains("Condition:") {
                             condition = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "Normal"
                         } else if line.contains("Maximum Capacity:") {
                              if let val = Int(line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "") ?? "") {
                                 maxCapacity = val
                             }
                         }
                     }
                     
                     DispatchQueue.main.async {
                         self.batteryCycleCount = cycleCount
                         self.batteryCondition = condition
                         self.batteryHealth = "\(maxCapacity)%"
                     }
                 }
             } catch {
                 print("Battery Detail Error: \(error)")
             }
    }
    
    func formatSpeed(_ bytes: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.zeroPadsFractionDigits = true
        return formatter.string(fromByteCount: Int64(bytes)) + "/s"
    }
}
}
