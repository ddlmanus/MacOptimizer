import Foundation
import Combine
import AppKit
import Darwin
import IOKit.ps
import CoreWLAN

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
    // Threshold set to 2GB as requested
    private let memoryThresholdGB: Double = 2.0 
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
    @Published var batteryState: String = "—"
    @Published var batteryTimeRemaining: String = ""
    
    private var timer: Timer?
    private let monitorQueue = DispatchQueue(
        label: "com.macoptimizer.system-monitor",
        qos: .utility
    )
    private var isUpdateInFlight = false
    private var updateCycle = 0
    
    private var prevCpuLoadInfo = host_cpu_load_info()
    private var hasPrevCpu = false

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
    @Published var wifiSignalStrength: String = "—"
    @Published var connectionDuration: String = "—"
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
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-x", "-o", "pid,ppid,%cpu,rss,comm"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
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
                for line in lines.dropFirst() {
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
        // Disable high memory alert for the first 30 seconds after app launch
        snoozedUntil = Date().addingTimeInterval(30)
        
        loadIgnoredApps()
    }

    deinit {
        timer?.invalidate()
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
        guard timer == nil else { return }

        scheduleUpdate()

        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.scheduleUpdate()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleUpdate() {
        guard !isUpdateInFlight else { return }

        isUpdateInFlight = true
        let cycle = updateCycle
        updateCycle += 1

        monitorQueue.async { [weak self] in
            guard let self else { return }
            self.updateStats(cycle: cycle)

            DispatchQueue.main.async { [weak self] in
                self?.isUpdateInFlight = false
            }
        }
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
    
    private func updateStats(cycle: Int) {
        let shouldRefreshApplications = cycle.isMultiple(of: 5)
        let shouldRefreshBatteryDetails = cycle.isMultiple(of: 30)

        if shouldRefreshApplications {
            checkHighMemoryApps()
            fetchUserProcesses()
        }
        
        // 1. CPU Usage using native Mach host_statistics (0 child processes)
        if let cpuUsageValue = getNativeCpuUsage() {
            Task {
                await self.uiUpdater.batch {
                    self.cpuUsage = cpuUsageValue
                }
            }
        }

        // 2. Memory Usage using native Mach host_statistics64 (0 child processes)
        if let (usedRAM, totalRAM, pagesActive, pagesWired, pagesCompressed, pageSize) = getNativeMemoryStats() {
            let memoryUsageValue = Double(usedRAM) / Double(totalRAM)
            let memoryUsedStringValue = ByteCountFormatter.string(fromByteCount: Int64(usedRAM), countStyle: .memory)
            let memoryTotalStringValue = ByteCountFormatter.string(fromByteCount: Int64(totalRAM), countStyle: .memory)

            Task {
                await self.uiUpdater.batch {
                    self.memoryUsage = memoryUsageValue
                    self.memoryUsedString = memoryUsedStringValue
                    self.memoryTotalString = memoryTotalStringValue
                }
            }

            self.updateDetailedStats(
                pagesActive: pagesActive,
                pagesWired: pagesWired,
                pagesCompressed: pagesCompressed,
                pageSize: pageSize,
                totalRAM: totalRAM,
                includePressureAndSwap: shouldRefreshApplications
            )
        }

        if shouldRefreshBatteryDetails {
            updateBatteryDetails()
        }

        // 3. Network Speed using native getifaddrs (0 child processes)
        if let (bytesIn, bytesOut) = getNativeNetworkBytes() {
            let now = Date()
            let timeDiff = now.timeIntervalSince(lastNetworkCheck)

            if timeDiff > 0 && lastBytesReceived > 0 {
                let downloadDelta = bytesIn > lastBytesReceived ? Double(bytesIn - lastBytesReceived) : 0
                let uploadDelta = bytesOut > lastBytesSent ? Double(bytesOut - lastBytesSent) : 0

                let downloadRate = downloadDelta / timeDiff
                let uploadRate = uploadDelta / timeDiff

                let totalDownloadStr = ByteCountFormatter.string(fromByteCount: Int64(bytesIn), countStyle: .file)
                let totalUploadStr = ByteCountFormatter.string(fromByteCount: Int64(bytesOut), countStyle: .file)

                Task {
                    await self.uiUpdater.batch {
                        self.downloadSpeed = downloadRate
                        self.uploadSpeed = uploadRate
                        self.totalDownload = totalDownloadStr
                        self.totalUpload = totalUploadStr
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
        
        if shouldRefreshApplications {
            fetchWiFiInfo()
            updateBatteryStatus()
        }
        updateConnectionDuration()
    }
    
    // Native Mach CPU usage calculation
    private func getNativeCpuUsage() -> Double? {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kerr == KERN_SUCCESS else { return nil }
        if !hasPrevCpu {
            prevCpuLoadInfo = cpuLoad
            hasPrevCpu = true
            return 0.0
        }
        let userDiff = Double(cpuLoad.cpu_ticks.0 >= prevCpuLoadInfo.cpu_ticks.0 ? cpuLoad.cpu_ticks.0 - prevCpuLoadInfo.cpu_ticks.0 : 0)
        let sysDiff  = Double(cpuLoad.cpu_ticks.1 >= prevCpuLoadInfo.cpu_ticks.1 ? cpuLoad.cpu_ticks.1 - prevCpuLoadInfo.cpu_ticks.1 : 0)
        let idleDiff = Double(cpuLoad.cpu_ticks.2 >= prevCpuLoadInfo.cpu_ticks.2 ? cpuLoad.cpu_ticks.2 - prevCpuLoadInfo.cpu_ticks.2 : 0)
        let niceDiff = Double(cpuLoad.cpu_ticks.3 >= prevCpuLoadInfo.cpu_ticks.3 ? cpuLoad.cpu_ticks.3 - prevCpuLoadInfo.cpu_ticks.3 : 0)
        prevCpuLoadInfo = cpuLoad
        let totalTicks = userDiff + sysDiff + idleDiff + niceDiff
        if totalTicks > 0 {
            return min(max((userDiff + sysDiff + niceDiff) / totalTicks, 0.0), 1.0)
        }
        return 0.0
    }

    // Native Mach memory statistics
    private func getNativeMemoryStats() -> (usedRAM: UInt64, totalRAM: UInt64, pagesActive: UInt64, pagesWired: UInt64, pagesCompressed: UInt64, pageSize: UInt64)? {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kerr == KERN_SUCCESS else { return nil }

        let pageSize = UInt64(vm_kernel_page_size)
        let pagesActive = UInt64(vmStats.active_count)
        let pagesInactive = UInt64(vmStats.inactive_count)
        let pagesSpeculative = UInt64(vmStats.speculative_count)
        let pagesWired = UInt64(vmStats.wire_count)
        let pagesCompressed = UInt64(vmStats.compressor_page_count)

        let totalRAM = ProcessInfo.processInfo.physicalMemory
        let usedPages = pagesActive + pagesWired + pagesCompressed + pagesSpeculative
        let usedRAM = usedPages * pageSize

        return (usedRAM, totalRAM, pagesActive + pagesInactive + pagesSpeculative, pagesWired, pagesCompressed, pageSize)
    }

    // Native getifaddrs network bytes
    private func getNativeNetworkBytes() -> (bytesIn: UInt64, bytesOut: UInt64)? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var totalBytesIn: UInt64 = 0
        var totalBytesOut: UInt64 = 0

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            guard (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING),
                  (flags & IFF_LOOPBACK) == 0,
                  let addr = ptr.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_LINK) else { continue }

            if let data = ptr.pointee.ifa_data {
                let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                totalBytesIn += UInt64(networkData.ifi_ibytes)
                totalBytesOut += UInt64(networkData.ifi_obytes)
            }
        }
        return (totalBytesIn, totalBytesOut)
    }

    // Native IOKit power source description
    private func getNativeBatteryInfo() -> (level: Double, isCharging: Bool, isActivelyCharging: Bool, timeRemaining: Int?)? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else { return nil }

        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
                let current = desc[kIOPSCurrentCapacityKey as String] as? Int ?? 0
                let max = desc[kIOPSMaxCapacityKey as String] as? Int ?? 100
                let isCharging = (desc[kIOPSIsChargingKey as String] as? Bool) ?? false
                let powerSourceState = desc[kIOPSPowerSourceStateKey as String] as? String
                let isAC = powerSourceState == (kIOPSACPowerValue as String)
                let timeToEmpty = desc[kIOPSTimeToEmptyKey as String] as? Int

                let level = max > 0 ? Double(current) / Double(max) : 1.0
                return (level, isAC || isCharging, isCharging, (timeToEmpty != nil && timeToEmpty! > 0) ? timeToEmpty : nil)
            }
        }
        return nil
    }

    // Fetch WiFi Info using CoreWLAN
    private func fetchWiFiInfo() {
        if let interface = CWWiFiClient.shared().interface(),
           let ssid = interface.ssid(),
           !ssid.isEmpty {
            Task {
                await uiUpdater.batch {
                    self.wifiSSID = ssid
                }
            }
            return
        }

        Task {
            await uiUpdater.batch {
                self.wifiSSID = LocalizationManager.shared.text(
                    simplifiedChinese: "Wi-Fi 未连接",
                    traditionalChinese: "Wi-Fi 未連線",
                    english: "Wi-Fi Not Connected",
                    japanese: "Wi-Fi未接続",
                    korean: "Wi-Fi 연결 안 됨",
                    russian: "Wi-Fi не подключён"
                )
            }
        }
    }
    
    private func updateConnectionDuration() {
        let duration = Date().timeIntervalSince(connectionStartTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        Task {
            await uiUpdater.batch {
                self.connectionDuration = LocalizationManager.shared.text(
                    simplifiedChinese: "\(hours)小时 \(minutes)分钟 \(seconds)秒",
                    traditionalChinese: "\(hours)小時 \(minutes)分鐘 \(seconds)秒",
                    english: "\(hours) hr \(minutes) min \(seconds) sec",
                    japanese: "\(hours)時間 \(minutes)分 \(seconds)秒",
                    korean: "\(hours)시간 \(minutes)분 \(seconds)초",
                    russian: "\(hours) ч \(minutes) мин \(seconds) с"
                )
            }
        }
    }
    
    private func updateBatteryStatus() {
        if let (level, isChargingValue, isActivelyCharging, timeRemainingMinutes) = getNativeBatteryInfo() {
            Task {
                await self.uiUpdater.batch {
                    let loc = LocalizationManager.shared
                    self.batteryLevel = level
                    self.isCharging = isChargingValue
                    if isChargingValue {
                        self.batteryState = isActivelyCharging
                            ? loc.text(
                                simplifiedChinese: "正在充电",
                                traditionalChinese: "正在充電",
                                english: "Charging",
                                japanese: "充電中",
                                korean: "충전 중",
                                russian: "Заряжается"
                            )
                            : loc.text(
                                simplifiedChinese: "已连接电源",
                                traditionalChinese: "已連接電源",
                                english: "Power Connected",
                                japanese: "電源に接続済み",
                                korean: "전원 연결됨",
                                russian: "Подключено питание"
                            )
                        self.batteryTimeRemaining = ""
                    } else {
                        self.batteryState = loc.text(
                            simplifiedChinese: "使用电池",
                            traditionalChinese: "使用電池",
                            english: "On Battery",
                            japanese: "バッテリー使用中",
                            korean: "배터리 사용 중",
                            russian: "Питание от аккумулятора"
                        )
                        if let mins = timeRemainingMinutes, mins > 0 {
                            let hours = mins / 60
                            let remMins = mins % 60
                            self.batteryTimeRemaining = loc.text(
                                simplifiedChinese: "剩余 \(hours)小时 \(remMins)分钟",
                                traditionalChinese: "剩餘 \(hours)小時 \(remMins)分鐘",
                                english: "\(hours) hr \(remMins) min remaining",
                                japanese: "残り\(hours)時間\(remMins)分",
                                korean: "\(hours)시간 \(remMins)분 남음",
                                russian: "Осталось \(hours) ч \(remMins) мин"
                            )
                        } else {
                            self.batteryTimeRemaining = ""
                        }
                    }
                }
            }
            return
        }
    }

    func checkHighMemoryApps() {
        // 检查是否在暂停期间
        if let snoozedUntil = snoozedUntil, Date() < snoozedUntil {
            return  // 暂停期间不检测
        }
        
        // Use direct ps execution
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-aceo", "pid,rss,comm"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
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
    @Published var batteryHealth: String = "—"
    @Published var batteryCycleCount: Int = 0
    @Published var batteryCondition: String = "—"
    
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
    private func updateDetailedStats(
        pagesActive: UInt64,
        pagesWired: UInt64,
        pagesCompressed: UInt64,
        pageSize: UInt64,
        totalRAM: UInt64,
        includePressureAndSwap: Bool
    ) {
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
        
        if includePressureAndSwap {
            updateMemoryPressureAndSwap()
        }
    }
    
    private func updateMemoryPressureAndSwap() {
        // Swap Usage via native sysctlbyname (0 child processes)
        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 {
            let usedStr = ByteCountFormatter.string(fromByteCount: Int64(swap.xsu_used), countStyle: .memory)
            let totalStr = ByteCountFormatter.string(fromByteCount: Int64(swap.xsu_total), countStyle: .memory)
            Task {
                await self.uiUpdater.batch {
                    self.memorySwapUsed = usedStr
                    self.memorySwapTotal = totalStr
                }
            }
        }

        // Memory Pressure calculation via Mach VM info
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            let total = Double(vmStats.active_count + vmStats.inactive_count + vmStats.speculative_count + vmStats.wire_count + vmStats.free_count)
            if total > 0 {
                let free = Double(vmStats.free_count + vmStats.inactive_count)
                let pressure = max(0.0, min(1.0, 1.0 - (free / total)))
                Task {
                    await self.uiUpdater.batch {
                        self.memoryPressure = pressure
                    }
                }
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
                             let loc = LocalizationManager.shared
                             switch condition.lowercased() {
                             case "normal", "good":
                                 self.batteryCondition = loc.text(
                                     simplifiedChinese: "正常",
                                     traditionalChinese: "正常",
                                     english: "Normal",
                                     japanese: "正常",
                                     korean: "정상",
                                     russian: "Нормальное"
                                 )
                             case "fair":
                                 self.batteryCondition = loc.text(
                                     simplifiedChinese: "一般",
                                     traditionalChinese: "一般",
                                     english: "Fair",
                                     japanese: "普通",
                                     korean: "보통",
                                     russian: "Удовлетворительное"
                                 )
                             case "poor", "check battery", "service recommended", "replace soon", "replace now", "service battery":
                                 self.batteryCondition = loc.text(
                                     simplifiedChinese: "建议维修",
                                     traditionalChinese: "建議維修",
                                     english: "Service Recommended",
                                     japanese: "修理サービス推奨",
                                     korean: "서비스 권장",
                                     russian: "Рекомендуется обслуживание"
                                 )
                             default:
                                 self.batteryCondition = loc.text(
                                     simplifiedChinese: "未知",
                                     traditionalChinese: "未知",
                                     english: "Unknown",
                                     japanese: "不明",
                                     korean: "알 수 없음",
                                     russian: "Неизвестно"
                                 )
                             }
                             self.batteryHealth = "\(maxCapacity)%"
                         }
                     }
                 }
            } catch {
                print("Battery Detail Error: \(error)")
            }
        }
    }
}
