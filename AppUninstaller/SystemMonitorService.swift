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
    
    // 新增：定时提醒和永久忽略
    private var snoozedUntil: Date?  // 暂停提醒直到此时间
    private var permanentlyIgnoredApps: Set<String> = []  // 永久忽略的应用名称列表
    private let ignoredAppsKey = "MemoryMonitor.IgnoredApps"
    
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
    
    // UI Update Batching
    private let uiUpdater = BatchedUIUpdater(debounceDelay: 0.05)

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
        // 1. Get User Apps from NSWorkspace (GUI Apps)
        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        
        // 2. Scan ALL user processes to build a process tree
        // ps -x -o pid,ppid,%cpu,rss,comm
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "ps -x -o pid,ppid,%cpu,rss,comm | tail -n +2"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse all processes
                struct ProcessInfo {
                    let pid: Int32
                    let ppid: Int32
                    let cpu: Double
                    let rss: Double // GB
                    let name: String
                }
                
                var allProcesses: [Int32: ProcessInfo] = [:]
                var childrenMap: [Int32: [Int32]] = [:] // Parent -> [Children]
                
                let lines = output.components(separatedBy: "\n")
                for line in lines {
                    let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if parts.count >= 5,
                       let pid = Int32(parts[0]),
                       let ppid = Int32(parts[1]),
                       let cpu = Double(parts[2]),
                       let rssKB = Double(parts[3]) {
                        
                        // Extract name (rest of the line)
                        let nameParts = parts.dropFirst(4)
                        let fullPath = nameParts.joined(separator: " ")
                        let name = URL(fileURLWithPath: fullPath).lastPathComponent
                        
                        let info = ProcessInfo(pid: pid, ppid: ppid, cpu: cpu, rss: rssKB / 1024.0 / 1024.0, name: name)
                        allProcesses[pid] = info
                        
                        // Build tree
                        childrenMap[ppid, default: []].append(pid)
                    }
                }
                
                // Helper to calculate total stats recursively
                func getAggregatedStats(for pid: Int32, visited: inout Set<Int32>) -> (cpu: Double, mem: Double) {
                    if visited.contains(pid) { return (0, 0) }
                    visited.insert(pid)
                    
                    var totalCPU = 0.0
                    var totalMem = 0.0
                    
                    if let process = allProcesses[pid] {
                        totalCPU += process.cpu
                        totalMem += process.rss
                    }
                    
                    if let children = childrenMap[pid] {
                        for child in children {
                            let childStats = getAggregatedStats(for: child, visited: &visited)
                            totalCPU += childStats.cpu
                            totalMem += childStats.mem
                        }
                    }
                    
                    return (totalCPU, totalMem)
                }
                
                // 3. Aggregate stats for each App
                var appProcesses: [AppProcess] = []

                
                for app in runningApps {
                    let pid = app.processIdentifier
                    // Only process if valid and not already counted (though unlikely for main apps to duplicate)
                    
                    var visited = Set<Int32>() // Visited for this app's tree
                    let stats = getAggregatedStats(for: pid, visited: &visited)
                    
                    // Add app stats
                    appProcesses.append(AppProcess(
                        id: pid,
                        name: app.localizedName ?? "Unknown",
                        icon: app.icon,
                        cpu: stats.cpu,
                        memory: stats.mem
                    ))
                    
                    // Mark these PIDs as processed if we want to avoid double counting if we were scanning all processes.
                    // But here we only care about the Apps list from NSWorkspace.
                }
                
                // Sort and Update
                let sortedByMem = appProcesses.sorted { $0.memory > $1.memory }.prefix(10)
                let sortedByCPU = appProcesses.sorted { $0.cpu > $1.cpu }.prefix(10)
                
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
        loadIgnoredApps()
        startMonitoring()
    }
    
    /// 从UserDefaults加载永久忽略的应用列表
    private func loadIgnoredApps() {
        if let savedApps = UserDefaults.standard.array(forKey: ignoredAppsKey) as? [String] {
            permanentlyIgnoredApps = Set(savedApps)
        }
    }
    
    /// 保存永久忽略的应用列表到UserDefaults
    private func saveIgnoredApps() {
        UserDefaults.standard.set(Array(permanentlyIgnoredApps), forKey: ignoredAppsKey)
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
                let cpuUsageValue = min((totalCPU / coreCount) / 100.0, 1.0)
                
                // Batch CPU update
                Task {
                    await self.uiUpdater.batch {
                        self.cpuUsage = cpuUsageValue
                    }
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
                
                let memoryUsageValue = Double(usedRAM) / Double(totalRAM)
                let memoryUsedStringValue = ByteCountFormatter.string(fromByteCount: Int64(usedRAM), countStyle: .memory)
                let memoryTotalStringValue = ByteCountFormatter.string(fromByteCount: Int64(totalRAM), countStyle: .memory)
                
                // Batch memory updates
                Task {
                    await self.uiUpdater.batch {
                        self.memoryUsage = memoryUsageValue
                        self.memoryUsedString = memoryUsedStringValue
                        self.memoryTotalString = memoryTotalStringValue
                    }
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
                        
                        let totalDownloadStr = ByteCountFormatter.string(fromByteCount: Int64(bytesIn), countStyle: .file)
                        let totalUploadStr = ByteCountFormatter.string(fromByteCount: Int64(bytesOut), countStyle: .file)
                        
                        // Batch network updates
                        Task {
                            await self.uiUpdater.batch {
                                self.downloadSpeed = downloadRate
                                self.uploadSpeed = uploadRate
                                
                                // Update Totals (Cumulative from netstat)
                                self.totalDownload = totalDownloadStr
                                self.totalUpload = totalUploadStr
                                
                                // Update History
                                self.downloadSpeedHistory.removeFirst()
                                self.downloadSpeedHistory.append(downloadRate)
                                self.uploadSpeedHistory.removeFirst()
                                self.uploadSpeedHistory.append(uploadRate)
                            }
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
                Task {
                    await uiUpdater.batch {
                        self.wifiSSID = output
                    }
                }
            } else {
                 Task {
                    await uiUpdater.batch {
                        self.wifiSSID = "Wi-Fi Not Connected"
                    }
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
        
        let connectionDurationValue = String(format: "%d小时 %d分钟 %d秒", hours, minutes, seconds)
        
        Task {
            await uiUpdater.batch {
                self.connectionDuration = connectionDurationValue
            }
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
                    var batteryLevelValue: Double = 1.0
                    var isChargingValue = false
                    var batteryStateValue = "Unknown"
                    
                    if let range = statusLine.range(of: "\\d+%", options: .regularExpression) {
                        let percentString = String(statusLine[range]).dropLast()
                        if let percent = Double(percentString) {
                            batteryLevelValue = percent / 100.0
                        }
                    }
                    
                    // Parse Charging State
                    if output.contains("AC Power") {
                        isChargingValue = true
                        if statusLine.contains("charging") {
                            batteryStateValue = "正在充电"
                        } else {
                            batteryStateValue = "已连接电源"
                        }
                    } else {
                        isChargingValue = false
                        batteryStateValue = "使用电池"
                    }
                    
                    // Batch battery status update
                    Task {
                        await self.uiUpdater.batch {
                            self.batteryLevel = batteryLevelValue
                            self.isCharging = isChargingValue
                            self.batteryState = batteryStateValue
                        }
                    }
                }
            }
        } catch {
            print("Battery Scan Error: \(error)")
        }
    }
    

    func checkHighMemoryApps() {
        // 检查是否在暂停期间
        if let snoozedUntil = snoozedUntil, Date() < snoozedUntil {
            return  // 暂停期间不检测
        }
        
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
                            
                            // 获取应用名称用于检查永久忽略列表
                            let tempName = parts[2...].joined(separator: " ")
                            var appName = tempName
                            if let app = NSRunningApplication(processIdentifier: pid) {
                                appName = app.localizedName ?? tempName
                            }
                            
                            // 检查是否在永久忽略列表中
                            if permanentlyIgnoredApps.contains(appName) {
                                continue
                            }
                                                        
                            let rssGB = rssKB / 1024.0 / 1024.0
                            
                            if rssGB > memoryThresholdGB && rssGB > maxRSS {
                                maxRSS = rssGB
                                maxPID = pid
                                maxName = appName
                            }
                        }
                    }
                }
                
                if maxRSS > 0 {
                    // Batch high memory app update
                    Task {
                        await self.uiUpdater.batch { [weak self] in
                            guard let self = self else { return }
                            // Only update if it's a new alert or different app
                            if self.highMemoryApp?.id != maxPID {
                                var appIcon: NSImage?
                                
                                if let app = NSRunningApplication(processIdentifier: maxPID) {
                                    appIcon = app.icon
                                }
                                
                                self.highMemoryApp = HighMemoryApp(id: maxPID, name: maxName, usage: maxRSS, icon: appIcon)
                                self.showHighMemoryAlert = true
                            }
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
            
            Task {
                await uiUpdater.batch {
                    self.highMemoryApp = nil
                    self.showHighMemoryAlert = false
                }
            }
        }
    }
    
    /// 暂停内存警告一段时间（定时提醒）
    /// - Parameter minutes: 暂停的分钟数
    func snoozeAlert(minutes: Int) {
        snoozedUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        
        // 暂时关闭当前警告
        Task {
            await uiUpdater.batch {
                self.highMemoryApp = nil
                self.showHighMemoryAlert = false
            }
        }
        
        print("[MemoryMonitor] Snoozed for \(minutes) minutes until \(snoozedUntil!)")
    }
    
    /// 永久忽略当前高内存应用
    func ignoreAppPermanently() {
        guard let app = highMemoryApp else { return }
        
        // 添加到永久忽略列表
        permanentlyIgnoredApps.insert(app.name)
        saveIgnoredApps()
        
        // 关闭警告
        Task {
            await uiUpdater.batch {
                self.highMemoryApp = nil
                self.showHighMemoryAlert = false
            }
        }
        
        print("[MemoryMonitor] Permanently ignored app: \(app.name)")
    }
    
    /// 移除永久忽略的应用（用于设置界面）
    /// - Parameter appName: 应用名称
    func removeFromIgnoredApps(_ appName: String) {
        permanentlyIgnoredApps.remove(appName)
        saveIgnoredApps()
    }
    
    /// 获取所有永久忽略的应用列表
    func getIgnoredApps() -> [String] {
        return Array(permanentlyIgnoredApps).sorted()
    }
    
    /// 清除所有永久忽略的应用
    func clearAllIgnoredApps() {
        permanentlyIgnoredApps.removeAll()
        saveIgnoredApps()
    }
    
    func terminateHighMemoryApp() {
        if let app = highMemoryApp,
           let runningApp = NSRunningApplication(processIdentifier: app.id) {
            runningApp.terminate()
            // Force kill if needed? Start with terminate.
            
            // Add to ignore list so we don't alert again immediately if it takes time to close
            ignoredPids.insert(app.id)
            
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Batch alert dismissal
                await uiUpdater.batch {
                    self.highMemoryApp = nil
                    self.showHighMemoryAlert = false
                }
            }
        } else if let app = highMemoryApp {
             // Fallback for non-app processes? kill command
             let killTask = Process()
             killTask.launchPath = "/bin/kill"
             killTask.arguments = ["\(app.id)"]
             try? killTask.run()
             
             ignoredPids.insert(app.id)
             
             Task {
                 await uiUpdater.batch {
                     self.highMemoryApp = nil
                     self.showHighMemoryAlert = false
                 }
             }
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
        let memoryAppValue = Double(pagesActive * pageSize) / Double(totalRAM)
        let memoryWiredValue = Double(pagesWired * pageSize) / Double(totalRAM)
        let memoryCompressedValue = Double(pagesCompressed * pageSize) / Double(totalRAM)
        
        // Uptime
        var boottime = timeval()
        var size = MemoryLayout<timeval>.stride
        var systemUptimeValue: TimeInterval = 0
        if sysctlbyname("kern.boottime", &boottime, &size, nil, 0) == 0 {
            let bootDate = Date(timeIntervalSince1970: Double(boottime.tv_sec) + Double(boottime.tv_usec) / 1_000_000.0)
            systemUptimeValue = Date().timeIntervalSince(bootDate)
        }
        
        // Batch detailed stats update
        Task {
            await self.uiUpdater.batch {
                self.memoryApp = memoryAppValue
                self.memoryWired = memoryWiredValue
                self.memoryCompressed = memoryCompressedValue
                self.systemUptime = systemUptimeValue
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
                            let memoryPressureValue = (100.0 - freePercent) / 100.0
                            
                            // Batch pressure update
                            Task {
                                await self.uiUpdater.batch {
                                    self.memoryPressure = memoryPressureValue
                                }
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
                    
                    for (index, comp) in components.enumerated() {
                        if comp == "used" && index + 2 < components.count {
                             // index+1 is "=", index+2 is value
                             usedStr = components[index + 2]
                        }
                    }
                    
                    // Batch swap update
                    if !usedStr.isEmpty {
                        Task {
                            await self.uiUpdater.batch {
                                self.memorySwapUsed = usedStr
                            }
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
                     
                     // Batch battery details update
                     Task {
                         await self.uiUpdater.batch {
                             self.batteryCycleCount = cycleCount
                             self.batteryCondition = condition
                             self.batteryHealth = "\(maxCapacity)%"
                         }
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
