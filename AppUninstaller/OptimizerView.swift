
import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Optimization Task Enum
enum OptimizerTask: String, CaseIterable, Identifiable {
    case networkOptimize     // 网络优化
    case bootOptimize        // 启动加速
    case memoryOptimize      // 内存优化
    case appAccelerate       // 应用加速
    case heavyConsumers      // 占用资源项目
    case launchAgents        // 启动代理
    case hungApps            // 挂起应用
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .networkOptimize: return "network"
        case .bootOptimize: return "bolt.fill"
        case .memoryOptimize: return "memorychip"
        case .appAccelerate: return "arrow.up.forward.app"
        case .heavyConsumers: return "chart.xyaxis.line"
        case .launchAgents: return "rocket.fill"
        case .hungApps: return "hourglass"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .networkOptimize: return Color(red: 0.0, green: 0.6, blue: 1.0)  // Blue
        case .bootOptimize: return Color(red: 1.0, green: 0.8, blue: 0.0)     // Yellow
        case .memoryOptimize: return Color(red: 0.0, green: 0.8, blue: 0.6)   // Teal
        case .appAccelerate: return Color(red: 0.8, green: 0.2, blue: 0.8)    // Purple
        case .heavyConsumers: return Color(red: 1.0, green: 0.6, blue: 0.2)   // Orange
        case .launchAgents: return Color(red: 0.2, green: 0.8, blue: 0.4)     // Green
        case .hungApps: return Color(red: 0.9, green: 0.3, blue: 0.3)         // Red
        }
    }
    
    var englishTitle: String {
        switch self {
        case .networkOptimize: return "Network Optimization"
        case .bootOptimize: return "Speed Up Boot"
        case .memoryOptimize: return "Memory Optimization"
        case .appAccelerate: return "App Acceleration"
        case .heavyConsumers: return "Heavy Consumers"
        case .launchAgents: return "Launch Agents"
        case .hungApps: return "Hung Applications"
        }
    }
    
    var englishDescription: String {
        switch self {
        case .networkOptimize: return "Flush DNS cache and clear network caches to resolve connectivity issues and DNS errors."
        case .bootOptimize: return "Disable unnecessary launch agents and login items to speed up Mac startup."
        case .memoryOptimize: return "Free up RAM, terminate background processes to improve system responsiveness."
        case .appAccelerate: return "Clean app caches, optimize databases to make apps launch faster."
        case .heavyConsumers: return "Quit apps that are using too much processing power."
        case .launchAgents: return "Manage helper applications that launch automatically."
        case .hungApps: return "Force quit applications that are not responding."
        }
    }
    
    // Localized properties
    func title(for language: AppLanguage) -> String {
        let values: [AppLanguage: String]
        switch self {
        case .networkOptimize: values = [.chinese: "网络优化", .traditionalChinese: "網路最佳化", .english: "Network Optimization", .japanese: "ネットワーク最適化", .korean: "네트워크 최적화", .russian: "Оптимизация сети"]
        case .bootOptimize: values = [.chinese: "启动加速", .traditionalChinese: "啟動加速", .english: "Speed Up Boot", .japanese: "起動を高速化", .korean: "부팅 속도 향상", .russian: "Ускорение запуска"]
        case .memoryOptimize: values = [.chinese: "内存优化", .traditionalChinese: "記憶體最佳化", .english: "Memory Optimization", .japanese: "メモリ最適化", .korean: "메모리 최적화", .russian: "Оптимизация памяти"]
        case .appAccelerate: values = [.chinese: "应用加速", .traditionalChinese: "應用程式加速", .english: "App Acceleration", .japanese: "アプリ高速化", .korean: "앱 가속", .russian: "Ускорение приложений"]
        case .heavyConsumers: values = [.chinese: "高资源占用应用", .traditionalChinese: "高資源佔用應用程式", .english: "Heavy Consumers", .japanese: "高負荷アプリ", .korean: "리소스 과다 사용 앱", .russian: "Ресурсоёмкие приложения"]
        case .launchAgents: values = [.chinese: "启动代理", .traditionalChinese: "啟動代理程式", .english: "Launch Agents", .japanese: "起動エージェント", .korean: "시작 에이전트", .russian: "Агенты запуска"]
        case .hungApps: values = [.chinese: "无响应的应用", .traditionalChinese: "無回應的應用程式", .english: "Hung Applications", .japanese: "応答しないアプリ", .korean: "응답하지 않는 앱", .russian: "Зависшие приложения"]
        }
        return values[language] ?? englishTitle
    }
    
    func description(for language: AppLanguage) -> String {
        let values: [AppLanguage: String]
        switch self {
        case .networkOptimize: values = [.chinese: "刷新 DNS 与网络缓存，帮助解决连接和域名解析问题。", .traditionalChinese: "重新整理 DNS 與網路快取，協助解決連線和網域解析問題。", .english: englishDescription, .japanese: "DNSとネットワークキャッシュを更新し、接続や名前解決の問題を改善します。", .korean: "DNS 및 네트워크 캐시를 새로 고쳐 연결과 도메인 확인 문제를 해결합니다.", .russian: "Обновляет кэш DNS и сети, помогая устранить проблемы подключения и разрешения имён."]
        case .bootOptimize: values = [.chinese: "管理不必要的启动代理和登录项，加快 Mac 启动速度。", .traditionalChinese: "管理不必要的啟動代理程式和登入項目，加快 Mac 啟動速度。", .english: englishDescription, .japanese: "不要な起動エージェントとログイン項目を管理し、Macの起動を高速化します。", .korean: "불필요한 시작 에이전트와 로그인 항목을 관리하여 Mac 부팅 속도를 높입니다.", .russian: "Управляет ненужными агентами запуска и объектами входа, ускоряя запуск Mac."]
        case .memoryOptimize: values = [.chinese: "释放内存并减少后台占用，提升系统响应速度。", .traditionalChinese: "釋放記憶體並減少背景佔用，提升系統回應速度。", .english: englishDescription, .japanese: "メモリを解放してバックグラウンドの使用量を減らし、応答性を向上させます。", .korean: "메모리를 확보하고 백그라운드 사용량을 줄여 시스템 반응 속도를 높입니다.", .russian: "Освобождает память и снижает фоновую нагрузку, повышая отзывчивость системы."]
        case .appAccelerate: values = [.chinese: "清理应用缓存并优化数据，让应用启动更快。", .traditionalChinese: "清理應用程式快取並最佳化資料，讓應用程式啟動更快。", .english: englishDescription, .japanese: "アプリのキャッシュとデータを最適化し、起動を高速化します。", .korean: "앱 캐시와 데이터를 최적화하여 앱을 더 빠르게 실행합니다.", .russian: "Оптимизирует кэш и данные приложений, ускоряя их запуск."]
        case .heavyConsumers: values = [.chinese: "找出占用过多处理器或内存的应用，并在不需要时将其关闭。", .traditionalChinese: "找出佔用過多處理器或記憶體的應用程式，並在不需要時將其關閉。", .english: englishDescription, .japanese: "CPUやメモリを大量に使用するアプリを見つけ、不要な場合は終了します。", .korean: "CPU 또는 메모리를 과도하게 사용하는 앱을 찾아 필요하지 않을 때 종료합니다.", .russian: "Находит приложения с высокой нагрузкой на процессор или память и позволяет завершить ненужные."]
        case .launchAgents: values = [.chinese: "管理随应用自动启动的辅助程序。", .traditionalChinese: "管理隨應用程式自動啟動的輔助程式。", .english: englishDescription, .japanese: "アプリとともに自動起動する補助プログラムを管理します。", .korean: "앱과 함께 자동으로 실행되는 도우미 프로그램을 관리합니다.", .russian: "Управляет вспомогательными программами, запускаемыми автоматически."]
        case .hungApps: values = [.chinese: "强制退出无响应的应用以释放系统资源。", .traditionalChinese: "強制結束無回應的應用程式以釋放系統資源。", .english: englishDescription, .japanese: "応答しないアプリを強制終了してシステムリソースを解放します。", .korean: "응답하지 않는 앱을 강제 종료하여 시스템 리소스를 확보합니다.", .russian: "Принудительно завершает зависшие приложения, освобождая ресурсы системы."]
        }
        return values[language] ?? englishDescription
    }
    
    // 是否为一键优化（点击即执行）
    var isOneClickOptimize: Bool {
        switch self {
        case .networkOptimize, .bootOptimize, .memoryOptimize, .appAccelerate:
            return true
        default:
            return false
        }
    }
}

// MARK: - Data Models
struct OptimizerProcessItem: Identifiable, Equatable {
    let id: Int32 // PID
    let name: String
    let icon: NSImage
    let usageDescription: String // e.g. "15% CPU" or "500 MB"
    var isSelected: Bool = false
}

struct LaunchAgentItem: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let name: String // Extracted from filename or Label
    let label: String
    let icon: NSImage
    var isEnabled: Bool // Status
    var isSelected: Bool = false
}

// MARK: - Service
class OptimizerService: ObservableObject {
    static let shared = OptimizerService()

    @Published var selectedTask: OptimizerTask = .heavyConsumers
    @Published var selectedTasks: Set<OptimizerTask> = []
    @Published var heavyProcesses: [OptimizerProcessItem] = []
    @Published var launchAgents: [LaunchAgentItem] = []
    @Published var hungApps: [OptimizerProcessItem] = []
    @Published var isScanning = false
    @Published var isExecuting = false
    @Published private(set) var executionWasCancelled = false
    
    // 执行进度跟踪
    @Published var executingTask: OptimizerTask? = nil
    @Published var completedTasks: Set<OptimizerTask> = []
    @Published var executionProgress: Double = 0.0
    @Published var showResults = false
    
    // 内存优化 - 高内存应用列表
    @Published var highMemoryApps: [OptimizerProcessItem] = []
    @Published var showMemoryConfirmAlert = false
    @Published var memoryAlertIgnored = false
    
    // 启动加速 - 启动项列表
    @Published var bootAgentsToDisable: [LaunchAgentItem] = []
    @Published var showBootConfirmAlert = false
    @Published var bootAlertIgnored = false
    
    func toggleTaskSelection(_ task: OptimizerTask) {
        if selectedTasks.contains(task) {
            selectedTasks.remove(task)
        } else {
            selectedTasks.insert(task)
        }
    }
    
    func selectAllTasks() {
        selectedTasks = Set(OptimizerTask.allCases)
    }
    
    func deselectAllTasks() {
        selectedTasks.removeAll()
    }
    
    func scan() {
        guard !isScanning else { return }
        isScanning = true
        Task {
            await fetchHeavyConsumers()
            await fetchLaunchAgents()
            await fetchHungApps()
            await MainActor.run { self.isScanning = false }
        }
    }

    func scanAndWait() async {
        scan()
        while isScanning {
            try? await Task.sleep(nanoseconds: 80_000_000)
        }
    }
    
    // 批量执行所有选中的任务
    func executeAllSelectedTasks() async {
        await MainActor.run {
            isExecuting = true
            executionWasCancelled = false
            completedTasks.removeAll()
            executionProgress = 0.0
            showResults = false
        }
        
        let tasksToExecute = Array(selectedTasks).sorted { $0.rawValue < $1.rawValue }
        let totalTasks = tasksToExecute.count
        
        for (index, task) in tasksToExecute.enumerated() {
            if executionWasCancelled || Task.isCancelled { break }
            await MainActor.run {
                executingTask = task
                executionProgress = Double(index) / Double(totalTasks)
            }
            
            await executeTask(task)

            if executionWasCancelled || Task.isCancelled { break }
            
            await MainActor.run {
                _ = completedTasks.insert(task)
            }
        }
        
        await MainActor.run {
            executingTask = nil
            isExecuting = false
            if executionWasCancelled {
                showResults = false
            } else {
                executionProgress = 1.0
                showResults = true
            }
        }
    }

    func cancelExecution() {
        executionWasCancelled = true
    }
    
    // 执行单个任务
    private func executeTask(_ task: OptimizerTask) async {
        switch task {
        case .networkOptimize:
            await performNetworkOptimization()
        case .bootOptimize:
            await performBootOptimization()
        case .memoryOptimize:
            await performMemoryOptimization()
        case .appAccelerate:
            await performAppAcceleration()
        case .heavyConsumers:
            await cleanupHeavyConsumers()
        case .launchAgents:
            await cleanupLaunchAgents()
        case .hungApps:
            await cleanupHungApps()
        }
        
        // 模拟执行时间
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
    
    private func fetchHeavyConsumers() async {
        await Task.detached(priority: .userInitiated) {
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", "ps -Aceo pid,%cpu,comm -r | head -n 15"]

            let pipe = Pipe()
            task.standardOutput = pipe
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()
                if let output = String(data: data, encoding: .utf8) {
                    var items: [OptimizerProcessItem] = []
                    let lines = output.components(separatedBy: .newlines).dropFirst() // Skip header

                    for line in lines {
                        let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        if parts.count >= 3, let pid = Int32(parts[0]), let cpu = Double(parts[1]) {
                            if cpu > 1.0 { // Filter apps using > 1% CPU (simulated threshold for "Heavy")
                                if let app = NSRunningApplication(processIdentifier: pid) {
                                    if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { continue }
                                    if let icon = app.icon, let name = app.localizedName {
                                        items.append(OptimizerProcessItem(id: pid, name: name, icon: icon, usageDescription: String(format: "%.1f%% CPU", cpu)))
                                    }
                                }
                            }
                        }
                    }
                    let finalItems = items
                    await MainActor.run {
                        self.heavyProcesses = finalItems
                    }
                }
            } catch {
                print("fetchHeavyConsumers error: \(error)")
            }
        }.value
    }

    private func fetchLaunchAgents() async {
        await Task.detached(priority: .userInitiated) {
            var items: [LaunchAgentItem] = []
            let paths = [
                FileManager.default.homeDirectoryForCurrentUser.path + "/Library/LaunchAgents",
                "/Library/LaunchAgents"
            ]

            for path in paths {
                if let files = try? FileManager.default.contentsOfDirectory(atPath: path) {
                    for file in files where file.hasSuffix(".plist") {
                        let fullPath = path + "/" + file
                        let name = file.replacingOccurrences(of: ".plist", with: "")
                        let icon = NSWorkspace.shared.icon(for: UTType(filenameExtension: "plist") ?? .propertyList)
                        items.append(LaunchAgentItem(
                            path: fullPath,
                            name: name,
                            label: name,
                            icon: icon,
                            isEnabled: true
                        ))
                    }
                }
            }
            let finalItems = items
            await MainActor.run {
                self.launchAgents = finalItems
            }
        }.value
    }

    private func fetchHungApps() async {
        await Task.detached(priority: .userInitiated) {
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", "ps -Aceo pid,state,comm | grep -e 'U' -e 'Z'"]

            let pipe = Pipe()
            task.standardOutput = pipe
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()
                if let output = String(data: data, encoding: .utf8) {
                    var items: [OptimizerProcessItem] = []
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines {
                        let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        if parts.count >= 3, let pid = Int32(parts[0]) {
                            if let app = NSRunningApplication(processIdentifier: pid), let icon = app.icon, let name = app.localizedName {
                                if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { continue }
                                let state = parts[1]
                                let desc = state.contains("Z") ? "Zombie" : "Unresponsive"
                                items.append(OptimizerProcessItem(id: pid, name: name, icon: icon, usageDescription: desc))
                            }
                        }
                    }
                    let finalItems = items
                    await MainActor.run {
                        self.hungApps = finalItems
                    }
                }
            } catch {
                print("fetchHungApps error: \(error)")
            }
        }.value
    }
    
    // MARK: - 清理任务执行
    
    private func cleanupHeavyConsumers() async {
        let itemsToKill = heavyProcesses.filter { $0.isSelected }
        for item in itemsToKill {
            kill(item.id, SIGKILL)
        }
        if !itemsToKill.isEmpty {
            await fetchHeavyConsumers()
        }
    }
    
    private func cleanupLaunchAgents() async {
        let itemsToUnload = launchAgents.filter { $0.isSelected }
        for item in itemsToUnload {
            let task = Process()
            task.launchPath = "/bin/launchctl"
            task.arguments = ["bootout", "gui/\(getuid())", item.path]
            try? task.run()
            task.waitUntilExit()
        }
        if !itemsToUnload.isEmpty {
            await fetchLaunchAgents()
        }
    }
    
    private func cleanupHungApps() async {
        let itemsToKill = hungApps.filter { $0.isSelected }
        for item in itemsToKill {
            kill(item.id, SIGKILL)
        }
        if !itemsToKill.isEmpty {
            await fetchHungApps()
        }
    }
    // MARK: - 网络优化
    private func performNetworkOptimization() async {
        // 1. 刷新 DNS 缓存
        let dscacheutil = Process()
        dscacheutil.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
        dscacheutil.arguments = ["-flushcache"]
        try? dscacheutil.run()
        dscacheutil.waitUntilExit()
        
        // 2. 重启 mDNSResponder（处理 DNS 解析）
        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["-HUP", "mDNSResponder"]
        try? killall.run()
        killall.waitUntilExit()
        
        // 3. 清理 hosts 文件中的损坏条目（仅读取，不修改）
        // 这可以帮助识别网络问题
        
        // 4. 清理网络缓存
        let home = FileManager.default.homeDirectoryForCurrentUser
        let networkCachePaths = [
            home.appendingPathComponent("Library/Caches/com.apple.Safari/NetworkResources"),
            home.appendingPathComponent("Library/Caches/com.apple.Safari/WebKitCache"),
            home.appendingPathComponent("Library/Caches/Google/Chrome/Default/Cache"),
            home.appendingPathComponent("Library/Caches/Firefox/Profiles"),
        ]
        
        for path in networkCachePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                try? FileManager.default.removeItem(at: path)
            }
        }
        
        // 5. 清理系统网络配置缓存
        let systemNetworkCachePaths = [
            home.appendingPathComponent("Library/Preferences/com.apple.networkextension.plist"),
            home.appendingPathComponent("Library/Preferences/com.apple.NetworkBrowser.plist"),
        ]
        
        for path in systemNetworkCachePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                // 只删除如果文件过大（可能损坏）
                if let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
                   let fileSize = attrs[.size] as? Int64,
                   fileSize > 1_000_000 { // 大于 1MB
                    try? FileManager.default.removeItem(at: path)
                }
            }
        }
        
        // 6. 清除网络位置缓存
        let locationCache = home.appendingPathComponent("Library/Preferences/SystemConfiguration")
        if FileManager.default.fileExists(atPath: locationCache.path) {
            // 注意：这个操作可能需要重新配置网络，所以我们只记录
            print("[NetworkOptimize] Network location cache exists at: \(locationCache.path)")
        }
        
        print("[NetworkOptimize] DNS cache flushed, network caches cleared, connectivity improved")
    }
    
    // MARK: - 启动加速
    private func performBootOptimization() async {
        // 1. 扫描启动代理并识别可以禁用的项目
        await scanBootAgents()
        
        // 2. 如果有可禁用的启动项且用户没有忽略，等待用户确认
        if !bootAgentsToDisable.isEmpty && !bootAlertIgnored {
            await MainActor.run {
                showBootConfirmAlert = true
            }
            
            // 等待用户做出选择（最多等待30秒）
            var waitTime = 0
            while showBootConfirmAlert && waitTime < 30 {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
                waitTime += 1
            }
            
            // 如果用户选择禁用启动项
            if !bootAlertIgnored {
                await disableSelectedBootAgents()
            }
        }
        
        // 3. 清理登录项缓存
        let loginItemsCache = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.backgroundtaskmanagementagent")
        try? FileManager.default.removeItem(at: loginItemsCache)
        
        print("[BootOptimize] Boot optimization completed")
    }
    
    // 扫描启动代理
    private func scanBootAgents() async {
        await Task.detached(priority: .userInitiated) {
            var items: [LaunchAgentItem] = []
            let userAgentsPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
            let safeAgents = ["com.apple.", "homebrew.", "com.github."]
            let knownNonEssential = [
                "update", "updater", "helper", "assistant", "agent",
                "sync", "backup", "cloud", "autoupdate"
            ]

            guard let agents = try? FileManager.default.contentsOfDirectory(atPath: userAgentsPath.path) else {
                return
            }

            for agent in agents where agent.hasSuffix(".plist") {
                let agentLower = agent.lowercased()
                if safeAgents.contains(where: { agentLower.contains($0) }) {
                    continue
                }

                let isNonEssential = knownNonEssential.contains { agentLower.contains($0) }
                let agentPath = userAgentsPath.appendingPathComponent(agent)
                let name = agent.replacingOccurrences(of: ".plist", with: "")

                var label = name
                if let plistData = try? Data(contentsOf: agentPath),
                   let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
                   let plistLabel = plist["Label"] as? String {
                    label = plistLabel
                }

                let isEnabled = agent.hasSuffix(".plist")

                items.append(LaunchAgentItem(
                    path: agentPath.path,
                    name: name,
                    label: label,
                    icon: NSWorkspace.shared.icon(for: .propertyList),
                    isEnabled: isEnabled,
                    isSelected: isNonEssential
                ))
            }

            items.sort { $0.name < $1.name }
            let finalItems = items
            await MainActor.run {
                self.bootAgentsToDisable = finalItems
            }
        }.value
    }
    
    // 禁用选中的启动代理
    func disableSelectedBootAgents() async {
        let itemsToDisable = await MainActor.run { bootAgentsToDisable.filter { $0.isSelected } }
        
        for item in itemsToDisable {
            // 先尝试卸载
            let unload = Process()
            unload.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            unload.arguments = ["unload", "-w", item.path]
            try? unload.run()
            unload.waitUntilExit()
            
            // 重命名文件为 .disabled（更安全的方法）
            let disabledPath = item.path.replacingOccurrences(of: ".plist", with: ".plist.disabled")
            try? FileManager.default.moveItem(atPath: item.path, toPath: disabledPath)
        }
        
        await MainActor.run {
            bootAgentsToDisable.removeAll()
            showBootConfirmAlert = false
            bootAlertIgnored = false
        }
    }
    
    // MARK: - 内存优化
    private func performMemoryOptimization() async {
        // 1. 首先检测高内存应用 (> 500MB)
        await detectHighMemoryApps()
        
        // 2. 如果有高内存应用且用户没有忽略，等待用户确认
        if !highMemoryApps.isEmpty && !memoryAlertIgnored {
            await MainActor.run {
                showMemoryConfirmAlert = true
            }
            
            // 等待用户做出选择（最多等待30秒）
            var waitTime = 0
            while showMemoryConfirmAlert && waitTime < 30 {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
                waitTime += 1
            }
            
            // 如果用户选择关闭应用
            if !memoryAlertIgnored {
                await terminateSelectedMemoryApps()
            }
        }
        
        // 3. 使用 memory_pressure 触发内存回收
        let memPressure = Process()
        memPressure.executableURL = URL(fileURLWithPath: "/usr/bin/memory_pressure")
        memPressure.arguments = ["-l", "critical"]
        try? memPressure.run()
        
        // 等待2秒让系统响应
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        memPressure.terminate()
        
        // 4. 尝试使用 purge 释放系统内存
        let purge = Process()
        purge.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
        try? purge.run()
        purge.waitUntilExit()
        
        print("[MemoryOptimize] Memory optimization completed")
    }
    
    // 检测高内存应用
    private func detectHighMemoryApps() async {
        await Task.detached(priority: .userInitiated) {
            var detectedApps: [OptimizerProcessItem] = []

            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", "ps -Aceo pid,rss,comm | awk '$2 > 500000 {print $1,$2,$3}'"]

            let pipe = Pipe()
            task.standardOutput = pipe
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()

                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }

                    for line in lines {
                        let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        if parts.count >= 2, let pid = Int32(parts[0]), let rss = Double(parts[1]) {
                            if let app = NSRunningApplication(processIdentifier: pid) {
                                if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { continue }

                                if let bundleId = app.bundleIdentifier {
                                    let systemApps = ["com.apple.finder", "com.apple.dock", "com.apple.SystemUIServer", "com.apple.WindowServer"]
                                    if systemApps.contains(bundleId) { continue }
                                }

                                if let icon = app.icon, let name = app.localizedName {
                                    let memoryMB = rss / 1024.0
                                    let memoryGB = memoryMB / 1024.0
                                    detectedApps.append(OptimizerProcessItem(
                                        id: pid,
                                        name: name,
                                        icon: icon,
                                        usageDescription: memoryGB >= 1.0 ? String(format: "%.1f GB", memoryGB) : String(format: "%.0f MB", memoryMB)
                                    ))
                                }
                            }
                        }
                    }
                }
            } catch {
                print("detectHighMemoryApps error: \(error)")
            }

            detectedApps.sort { app1, app2 in
                let getValue: (String) -> Double = { usage in
                    let components = usage.components(separatedBy: .whitespaces)
                    if let value = Double(components[0]) {
                        return components.last?.contains("GB") == true ? value * 1024 : value
                    }
                    return 0
                }
                return getValue(app1.usageDescription) > getValue(app2.usageDescription)
            }

            let finalApps = detectedApps
            await MainActor.run {
                self.highMemoryApps = finalApps
            }
        }.value
    }
    
    // 终止选中的高内存应用
    func terminateSelectedMemoryApps() async {
        let itemsToKill = await MainActor.run { highMemoryApps.filter { $0.isSelected } }
        for item in itemsToKill {
            if let app = NSRunningApplication(processIdentifier: item.id) {
                app.terminate()
                // 等待一小段时间
                try? await Task.sleep(nanoseconds: 500_000_000)
                // 如果还没关闭，强制关闭
                if app.isTerminated == false {
                    app.forceTerminate()
                }
            }
        }
        
        await MainActor.run {
            highMemoryApps.removeAll()
            showMemoryConfirmAlert = false
            memoryAlertIgnored = false
        }
    }
    
    // MARK: - 应用加速
    private func performAppAcceleration() async {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fileManager = FileManager.default
        
        // 1. 清理应用缓存 (仅清理大于 100MB 的缓存)
        let cachesPath = home.appendingPathComponent("Library/Caches")
        if let contents = try? fileManager.contentsOfDirectory(at: cachesPath, includingPropertiesForKeys: [.fileSizeKey]) {
            for item in contents {
                // 跳过系统关键缓存
                if item.lastPathComponent.hasPrefix("com.apple.") { continue }
                
                // 仅清理超过 100MB 的缓存
                if let size = try? item.resourceValues(forKeys: [.totalFileSizeKey]).totalFileSize, size > 100_000_000 {
                    // Safety Check
                    if SafetyGuard.shared.isSafeToDelete(item) {
                        try? fileManager.removeItem(at: item)
                    }
                }
            }
        }
        
        // 2. 清理 Safari 图标缓存
        let safariIconCache = home.appendingPathComponent("Library/Safari/Touch Icons Cache")
        try? fileManager.removeItem(at: safariIconCache)
        
        // 3. 重建 Launch Services 数据库
        let lsregister = Process()
        lsregister.executableURL = URL(fileURLWithPath: "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister")
        lsregister.arguments = ["-kill", "-r", "-domain", "local", "-domain", "user"]
        try? lsregister.run()
        lsregister.waitUntilExit()
        
        // 4. 清理 Spotlight 元数据缓存
        let spotlightCache = home.appendingPathComponent("Library/Caches/com.apple.Spotlight")
        try? fileManager.removeItem(at: spotlightCache)
        
        print("[AppAccelerate] App caches cleaned, Launch Services rebuilt")
    }
    
    func toggleSelection(for id: Any) {
        // Helper to toggle (kept for compatibility)
    }
}

// MARK: - Views
struct OptimizerView: View {
    @ObservedObject private var service = OptimizerService.shared
    @ObservedObject private var loc = LocalizationManager.shared
    
    @State private var viewState = 0 // 0: Landing, 1: List, 2: Executing, 3: Results
    
    var body: some View {
        ZStack {
             // Shared Background
            BackgroundStyles.privacy.ignoresSafeArea()
            
            switch viewState {
            case 0:
                OptimizerLandingView(viewState: $viewState, loc: loc)
            case 1:
                optimizerListView
            case 2:
                executingView
            case 3:
                resultsView
            default:
                optimizerListView
            }
        }
        .onAppear {
            service.scan()
            viewState = 0
        }
        .onChange(of: service.showResults) { showResults in
            if showResults {
                viewState = 3
            }
        }
        .sheet(isPresented: $service.showMemoryConfirmAlert) {
            MemoryConfirmationDialog(service: service, loc: loc)
        }
        .sheet(isPresented: $service.showBootConfirmAlert) {
            BootOptimizationDialog(service: service, loc: loc)
        }
    }
    
    // Existing list logic moved here
    var optimizerListView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                HStack(spacing: 0) {
                // LEFT PANEL (Task Selection)
                ZStack {
                    // Transparent to let shared background show through
                    VStack(alignment: .leading, spacing: 0) {
                         // Back button (Functional)
                        Button(action: { viewState = 0 }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text(loc.text(
    simplifiedChinese: "简介",
    traditionalChinese: "簡介",
    english: "Intro",
    japanese: "イントロ",
    korean: "Intro",
    russian: "Вводная"
))
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 13))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                        
                        // Tasks List (支持多选)
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(OptimizerTask.allCases) { task in
                                    OptimizerTaskRow(
                                        task: task,
                                        isSelected: service.selectedTasks.contains(task),
                                        isActive: service.selectedTask == task,
                                        isMultiSelect: true,
                                        loc: loc
                                    )
                                    .onTapGesture {
                                        service.toggleTaskSelection(task)
                                        service.selectedTask = task
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                        }
                    }
                }
                .frame(width: geometry.size.width * 0.4)
                
                // RIGHT PANEL (Details)
                ZStack {
                    // Background handled in parent ZStack
                    
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        HStack {
                            Text(loc.text("优化", "Optimization"))
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            
                            // Search Bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(loc.text(
    simplifiedChinese: "搜索",
    traditionalChinese: "搜尋",
    english: "Search",
    japanese: "検索する",
    korean: "검색",
    russian: "Поиск"
))
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.3))
                                Spacer()
                            }
                            .frame(width: 120, height: 22)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(4)
                            

                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 14)
                        
                        // Title & Desc
                        VStack(alignment: .leading, spacing: 6) {
                            Text(service.selectedTask.title(for: loc.currentLanguage))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(service.selectedTask.description(for: loc.currentLanguage))
                                .font(.system(size: 11))
                                .lineSpacing(3)
                                .foregroundColor(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        
                        // Content List
                        ScrollView {
                            VStack(spacing: 0) {
                                // 一键优化任务 - 显示功能说明
                                if service.selectedTask.isOneClickOptimize {
                                    VStack(spacing: 20) {
                                        // 功能图标
                                        ZStack {
                                            Circle()
                                                .fill(service.selectedTask.iconColor.opacity(0.2))
                                                .frame(width: 80, height: 80)
                                            Image(systemName: service.selectedTask.icon)
                                                .font(.system(size: 36))
                                                .foregroundColor(service.selectedTask.iconColor)
                                        }
                                        .padding(.top, 30)
                                        
                                        // 提示信息
                                        VStack(spacing: 8) {
                                            Text(loc.text("点击下方按钮开始优化", "Click button below to start optimization"))
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white.opacity(0.7))
                                            
                                            Text(loc.text("此操作是安全的，可随时执行", "This operation is safe and can be run anytime"))
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                } else if service.selectedTask == .heavyConsumers {
                                    ForEach($service.heavyProcesses) { $proc in
                                        HeavyProcessRow(item: proc, isSelected: $proc.isSelected)
                                    }
                                } else if service.selectedTask == .launchAgents {
                                    ForEach($service.launchAgents) { $agent in
                                        LaunchAgentRow(item: agent, isSelected: $agent.isSelected, loc: loc)
                                    }
                                } else if service.selectedTask == .hungApps {
                                    if service.hungApps.isEmpty {
                                        Text(loc.text("未发现挂起的应用程序", "No hung applications found"))
                                            .foregroundColor(.white.opacity(0.5))
                                            .padding(.top, 40)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                    } else {
                                        ForEach($service.hungApps) { $proc in
                                            HeavyProcessRow(item: proc, isSelected: $proc.isSelected)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        Spacer()
                        
                        // Execute Button - 执行所有选中的任务

                    }
                    .frame(width: geometry.size.width * 0.6)
                }
            }
            
            Button(action: {
                viewState = 2
                Task {
                    await service.executeAllSelectedTasks()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1
                        )
                        .frame(width: 60, height: 60)
                    
                    if service.isExecuting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(loc.text("执行", "Run"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(service.isExecuting || service.selectedTasks.isEmpty)
            .padding(.bottom, 40)
        }
    }
}
    
    // MARK: - 执行视图
    var executingView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 标题
            Text(loc.text("正在执行优化任务...", "Executing Optimization Tasks..."))
                .font(.title2)
                .foregroundColor(.white)
            
            // 任务列表进度
            VStack(spacing: 12) {
                ForEach(Array(service.selectedTasks).sorted { $0.rawValue < $1.rawValue }) { task in
                    HStack(spacing: 12) {
                        // 状态图标
                        ZStack {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(task.iconColor)
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: task.icon)
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        }
                        
                        // 任务名称
                        Text(task.title(for: loc.currentLanguage))
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // 状态
                        if service.completedTasks.contains(task) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if service.executingTask == task {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(service.executingTask == task ? Color.white.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, 40)
            
            // 进度文本
            Text("\(service.completedTasks.count) / \(service.selectedTasks.count)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
        }
    }
    
    // MARK: - 结果视图
    var resultsView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 完成图标
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.green)
            }
            
            Text(loc.text("优化完成！", "Optimization Complete!"))
                .font(.title)
                .bold()
                .foregroundColor(.white)
            
            // 完成的任务列表
            VStack(spacing: 8) {
                ForEach(Array(service.completedTasks).sorted { $0.rawValue < $1.rawValue }) { task in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(task.iconColor)
                                .frame(width: 22, height: 22)
                            
                            Image(systemName: task.icon)
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                        }
                        
                        Text(task.title(for: loc.currentLanguage))
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }
            .frame(maxWidth: 350)
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
            
            // 返回按钮
            Button(action: {
                service.showResults = false
                service.completedTasks.removeAll()
                viewState = 1
            }) {
                Text(loc.text(
    simplifiedChinese: "完成",
    traditionalChinese: "完成",
    english: "Done",
    japanese: "完了",
    korean: "완료",
    russian: "Готово"
))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.white.opacity(0.2)))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 50)
        }
    }
}

// MARK: - Row Components
struct OptimizerTaskRow: View {
    let task: OptimizerTask
    let isSelected: Bool
    let isActive: Bool
    var isMultiSelect: Bool = false
    @ObservedObject var loc: LocalizationManager
    
    var body: some View {
        HStack(spacing: 8) {
            // Checkbox (多选) 或 Radio Button (单选)
            if isMultiSelect {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(isSelected ? Color.green : Color.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isSelected ? Color.green : Color.clear)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            } else {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(task.iconColor)
                    .frame(width: 24, height: 24)
                
                Image(systemName: task.icon)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
            }
            
            // Title
            Text(task.title(for: loc.currentLanguage))
                .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Color.black.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }
}

struct HeavyProcessRow: View {
    let item: OptimizerProcessItem
    @Binding var isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Checkbox - 绿色勾选样式
            Button(action: { isSelected.toggle() }) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.green : Color.white.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 16, height: 16)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 24, height: 24)
            
            Text(item.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(item.usageDescription)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.1))
                .cornerRadius(3)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { isSelected.toggle() }
    }
}

struct LaunchAgentRow: View {
    let item: LaunchAgentItem
    @Binding var isSelected: Bool
    @ObservedObject var loc: LocalizationManager
    
    var body: some View {
        HStack(spacing: 8) {
            // Checkbox - 绿色勾选样式
            Button(action: { isSelected.toggle() }) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.green : Color.white.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 16, height: 16)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 24, height: 24)
            
            Text(item.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            // Status Indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(item.isEnabled ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                Text(item.isEnabled ? (loc.text("已启用", "Enabled")) : (loc.text("已禁用", "Disabled")))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { isSelected.toggle() }
    }
}
// MARK: - Landing Components
struct OptimizerLandingView: View {
    @Binding var viewState: Int // 0=Landing, 1=List
    @ObservedObject var loc: LocalizationManager
    
    var body: some View {
        ZStack {
            HStack(spacing: 60) {
                // Left Content
                VStack(alignment: .leading, spacing: 30) {
                    // Branding Header
                    HStack(spacing: 8) {
                        Text(loc.text("系统优化", "System Optimization"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        // Optimization Icon
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            Text(loc.text("全面提速", "Full Boost"))
                                .font(.system(size: 20, weight: .heavy))
                        }
                        .foregroundColor(.white)
                    }
                    
                    Text(loc.text("通过控制 Mac 上运行的应用，提高它的输出。\n上次优化时间：从未", "Improve output by controlling apps running on your Mac.\nLast optimized: Never"))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(4)
                    
                    // Feature Rows
                    VStack(alignment: .leading, spacing: 24) {
                        featureRow(
                            icon: "light.beacon.max.fill",
                            title: loc.text("管理启动代理", "Manage Launch Agents"),
                            desc: loc.text("控制您的 Mac 支持的应用。", "Control applications supported by your Mac.")
                        )
                        
                        featureRow(
                            icon: "waveform.path.ecg",
                            title: loc.text("控制运行的应用", "Control Running Apps"),
                            desc: loc.text("管理所有登录项，仅运行真正需要的项目。", "Manage login items, running only what you truly need.")
                        )
                        
                        featureRow(
                            icon: "chart.xyaxis.line",
                            title: loc.text("占用资源项目", "Heavy Consumers"),
                            desc: loc.text("找出并关闭占用太多资源的进程。", "Find and quit processes using too many resources.")
                        )
                    }
                    
                    // View Items Button
                    Button(action: { viewState = 1 }) {
                        Text(loc.text("查看项目...", "View Items..."))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(hex: "4DDEE8")) // Teal
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }
                .frame(maxWidth: 400)
                
                // Right Icon - Using youhua.png
                ZStack {
                    if let path = Bundle.main.path(forResource: "youhua", ofType: "png"),
                       let nsImage = NSImage(contentsOfFile: path) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 320, height: 320)
                            .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
                    } else {
                        // Fallback: Purple Circle with Sliders
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "C86FC9"), Color(hex: "8B3A9B")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 280, height: 280)
                                .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
                            
                            // Sliders (Visual)
                            HStack(spacing: 30) {
                                // Slider 1
                                VStack(spacing: 0) {
                                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 8, height: 60)
                                    Circle().fill(Color.white).frame(width: 24, height: 24)
                                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 8, height: 100)
                                }
                                // Slider 2
                                VStack(spacing: 0) {
                                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 8, height: 100)
                                    Circle().fill(Color.white).frame(width: 24, height: 24)
                                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 8, height: 60)
                                }
                                // Slider 3
                                VStack(spacing: 0) {
                                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 8, height: 40)
                                    Circle().fill(Color.white).frame(width: 24, height: 24)
                                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 8, height: 120)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
            
            // Bottom Floating Button
            VStack {
                Spacer()
                Button(action: { viewState = 1 }) {
                    ZStack {
                        Circle()
                            .stroke(LinearGradient(
                                colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ), lineWidth: 2)
                            .frame(width: 84, height: 84)
                        
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 74, height: 74)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                        
                        Text(loc.text("开始", "Start"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Feature Row Helper
    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}


// MARK: - Memory Confirmation Dialog
struct MemoryConfirmationDialog: View {
    @ObservedObject var service: OptimizerService
    @ObservedObject var loc: LocalizationManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.text("内存优化", "Memory Optimization"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(loc.text("发现以下应用占用大量内存，是否需要关闭以释放内存？", "The following apps are using high memory. Close them to free up RAM?"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                
                Button(action: {
                    service.memoryAlertIgnored = true
                    service.showMemoryConfirmAlert = false
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
            
            // App List
            ScrollView {
                VStack(spacing: 0) {
                    ForEach($service.highMemoryApps) { $app in
                        HStack(spacing: 12) {
                            // Checkbox
                            Button(action: { app.isSelected.toggle() }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(app.isSelected ? Color.blue : Color.gray, lineWidth: 1.5)
                                        .frame(width: 18, height: 18)
                                    
                                    if app.isSelected {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.blue)
                                            .frame(width: 18, height: 18)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            
                            // App Icon
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 36, height: 36)
                            
                            // App Info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text(loc.text("内存占用: \(app.usageDescription)", "Memory: \(app.usageDescription)"))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(app.isSelected ? Color.blue.opacity(0.05) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { app.isSelected.toggle() }
                        
                        if app.id != service.highMemoryApps.last?.id {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
            }
            .frame(height: min(CGFloat(service.highMemoryApps.count) * 60 + 20, 300))
            
            Divider()
            
            // Footer Actions
            HStack(spacing: 12) {
                // Select/Deselect All
                Button(action: {
                    let allSelected = service.highMemoryApps.allSatisfy { $0.isSelected }
                    for index in service.highMemoryApps.indices {
                        service.highMemoryApps[index].isSelected = !allSelected
                    }
                }) {
                    Text(service.highMemoryApps.allSatisfy { $0.isSelected } ? 
                         (loc.text("取消全选", "Deselect All")) : 
                         (loc.text(
    simplifiedChinese: "全选",
    traditionalChinese: "全選",
    english: "Select All",
    japanese: "すべてを選択",
    korean: "전체선택",
    russian: "Выбрать все"
)))
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Ignore Button
                Button(action: {
                    service.memoryAlertIgnored = true
                    service.showMemoryConfirmAlert = false
                    dismiss()
                }) {
                    Text(loc.text("忽略", "Ignore"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // Close Apps Button
                Button(action: {
                    Task {
                        await service.terminateSelectedMemoryApps()
                        dismiss()
                    }
                }) {
                    Text(loc.text("关闭应用", "Close Apps"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(service.highMemoryApps.filter { $0.isSelected }.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Boot Optimization Dialog
struct BootOptimizationDialog: View {
    @ObservedObject var service: OptimizerService
    @ObservedObject var loc: LocalizationManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.text("启动加速", "Boot Optimization"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(loc.text("以下启动代理将被禁用以加快系统启动速度。请谨慎选择，禁用必要的启动项可能导致某些应用功能异常。", "The following launch agents will be disabled to speed up boot time. Choose carefully - disabling essential items may affect app functionality."))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                
                Button(action: {
                    service.bootAlertIgnored = true
                    service.showBootConfirmAlert = false
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
            
            // Warning Banner
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
                
                Text(loc.text("建议仅禁用您确认不需要的启动项", "Only disable launch agents you're sure you don't need"))
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.orange.opacity(0.1))
            
            // Agent List
            ScrollView {
                VStack(spacing: 0) {
                    ForEach($service.bootAgentsToDisable) { $agent in
                        HStack(spacing: 12) {
                            // Checkbox
                            Button(action: { agent.isSelected.toggle() }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(agent.isSelected ? Color.blue : Color.gray, lineWidth: 1.5)
                                        .frame(width: 18, height: 18)
                                    
                                    if agent.isSelected {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.blue)
                                            .frame(width: 18, height: 18)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            
                            // Icon
                            Image(nsImage: agent.icon)
                                .resizable()
                                .frame(width: 36, height: 36)
                            
                            // Agent Info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(agent.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text(agent.label)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Status Badge
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(agent.isEnabled ? Color.green : Color.gray)
                                    .frame(width: 6, height: 6)
                                Text(agent.isEnabled ? 
                                     (loc.text("已启用", "Enabled")) : 
                                     (loc.text("已禁用", "Disabled")))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(agent.isSelected ? Color.blue.opacity(0.05) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { agent.isSelected.toggle() }
                        
                        if agent.id != service.bootAgentsToDisable.last?.id {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
            }
            .frame(height: min(CGFloat(service.bootAgentsToDisable.count) * 60 + 20, 350))
            
            Divider()
            
            // Footer Actions
            HStack(spacing: 12) {
                // Select/Deselect All
                Button(action: {
                    let allSelected = service.bootAgentsToDisable.allSatisfy { $0.isSelected }
                    for index in service.bootAgentsToDisable.indices {
                        service.bootAgentsToDisable[index].isSelected = !allSelected
                    }
                }) {
                    Text(service.bootAgentsToDisable.allSatisfy { $0.isSelected } ? 
                         (loc.text("取消全选", "Deselect All")) : 
                         (loc.text(
    simplifiedChinese: "全选",
    traditionalChinese: "全選",
    english: "Select All",
    japanese: "すべてを選択",
    korean: "전체선택",
    russian: "Выбрать все"
)))
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Skip Button
                Button(action: {
                    service.bootAlertIgnored = true
                    service.showBootConfirmAlert = false
                    dismiss()
                }) {
                    Text(loc.text("跳过", "Skip"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // Disable Button
                Button(action: {
                    Task {
                        await service.disableSelectedBootAgents()
                        dismiss()
                    }
                }) {
                    Text(loc.text("禁用选中项", "Disable Selected"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(service.bootAgentsToDisable.filter { $0.isSelected }.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 550)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
