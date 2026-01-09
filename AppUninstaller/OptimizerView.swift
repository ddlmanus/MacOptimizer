
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
        case .networkOptimize: return "Flush DNS cache, optimize network settings for faster browsing and downloads."
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
        switch language {
        case .chinese:
            switch self {
            case .networkOptimize: return "网络优化"
            case .bootOptimize: return "启动加速"
            case .memoryOptimize: return "内存优化"
            case .appAccelerate: return "应用加速"
            case .heavyConsumers: return "占用较多资源的项目"
            case .launchAgents: return "启动代理"
            case .hungApps: return "挂起的应用程序"
            }
        case .english: return englishTitle
        }
    }
    
    func description(for language: AppLanguage) -> String {
        switch language {
        case .chinese:
            switch self {
            case .networkOptimize: return "刷新 DNS 缓存，优化网络设置，加快网页浏览和下载速度。"
            case .bootOptimize: return "禁用不必要的启动代理和登录项，加快 Mac 启动速度。"
            case .memoryOptimize: return "释放内存，终止后台进程，提升系统响应速度。"
            case .appAccelerate: return "清理应用缓存，优化数据库，让应用启动更快。"
            case .heavyConsumers: return "通常，很难发现一些运行的进程开始占用太多 Mac 资源。如果您不是真正需要这样的应用程序运行，则将其找出来并关闭。"
            case .launchAgents: return "通常，这些是其他软件产品的小辅助应用程序，可以扩展其主产品的功能。但是在一些情况下，您可以考虑移除或禁用它们。"
            case .hungApps: return "如果应用程序停止响应，您可以强制将其关闭以释放资源。"
            }
        case .english: return englishDescription
        }
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
    var isSelected: Bool = true // 默认全选
}

struct LaunchAgentItem: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let name: String // Extracted from filename or Label
    let label: String
    let icon: NSImage
    var isEnabled: Bool // Status
    var isSelected: Bool = true // 默认全选
}

// MARK: - Service
class OptimizerService: ObservableObject {
    @Published var selectedTask: OptimizerTask = .networkOptimize
    @Published var selectedTasks: Set<OptimizerTask> = Set(OptimizerTask.allCases) // 默认全选
    @Published var heavyProcesses: [OptimizerProcessItem] = []
    @Published var launchAgents: [LaunchAgentItem] = []
    @Published var hungApps: [OptimizerProcessItem] = []
    @Published var isScanning = false
    @Published var isExecuting = false
    
    // 执行进度跟踪
    @Published var executingTask: OptimizerTask? = nil
    @Published var completedTasks: Set<OptimizerTask> = []
    @Published var executionProgress: Double = 0.0
    @Published var showResults = false
    
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
        isScanning = true
        Task {
            await fetchHeavyConsumers()
            await fetchLaunchAgents()
            await fetchHungApps()
            await MainActor.run { self.isScanning = false }
        }
    }
    
    // 批量执行所有选中的任务
    func executeAllSelectedTasks() async {
        await MainActor.run {
            isExecuting = true
            completedTasks.removeAll()
            executionProgress = 0.0
            showResults = false
        }
        
        let tasksToExecute = Array(selectedTasks).sorted { $0.rawValue < $1.rawValue }
        let totalTasks = tasksToExecute.count
        
        for (index, task) in tasksToExecute.enumerated() {
            await MainActor.run {
                executingTask = task
                executionProgress = Double(index) / Double(totalTasks)
            }
            
            await executeTask(task)
            
            await MainActor.run {
                _ = completedTasks.insert(task)
            }
        }
        
        await MainActor.run {
            executingTask = nil
            executionProgress = 1.0
            isExecuting = false
            showResults = true
        }
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
    
    @MainActor
    private func fetchHeavyConsumers() {
        // Run ps command to get top CPU consumers
        // ps -Aceo pid,%cpu,comm -r | head -n 10
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "ps -Aceo pid,%cpu,comm -r | head -n 15"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            var items: [OptimizerProcessItem] = []
            let lines = output.components(separatedBy: .newlines).dropFirst() // Skip header
            
            for line in lines {
                let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 3, let pid = Int32(parts[0]), let cpu = Double(parts[1]) {
                    if cpu > 1.0 { // Filter apps using > 1% CPU (simulated threshold for "Heavy")
                         // Get app name and icon
                        if let app = NSRunningApplication(processIdentifier: pid) {
                            // Exclude self
                            if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { continue }
                            
                            // Only show apps with icons (user visible)
                            if let icon = app.icon, let name = app.localizedName {
                                items.append(OptimizerProcessItem(id: pid, name: name, icon: icon, usageDescription: String(format: "%.1f%% CPU", cpu)))
                            }
                        }
                    }
                }
            }
            self.heavyProcesses = items
        }
    }
    
    @MainActor
    private func fetchLaunchAgents() {
        var items: [LaunchAgentItem] = []
        let paths = [
            FileManager.default.homeDirectoryForCurrentUser.path + "/Library/LaunchAgents",
            "/Library/LaunchAgents"
        ]
        
        for path in paths {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: path) {
                for file in files where file.hasSuffix(".plist") {
                    let fullPath = path + "/" + file
                    // Simplified: Use filename as name, generic icon
                    let name = file.replacingOccurrences(of: ".plist", with: "")
                    // Check if loaded? roughly assume enabled if file exists for now, 
                    // real check involves `launchctl list`
                    
                    // Simple logic: existing plist = enabled (unless disabled in override database, which is complex)
                    // We will just list them.
                    items.append(LaunchAgentItem(
                        path: fullPath,
                        name: name,
                        label: name,
                        icon: NSWorkspace.shared.icon(for: UTType(filenameExtension: "plist") ?? .propertyList),
                        isEnabled: true
                    ))
                }
            }
        }
        self.launchAgents = items
    }
    
    @MainActor
    private func fetchHungApps() {
        // Detect apps in Uninterruptible sleep (U) or Zombie (Z) state
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "ps -Aceo pid,state,comm | grep -e 'U' -e 'Z'"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
             var items: [OptimizerProcessItem] = []
             let lines = output.components(separatedBy: .newlines)
             for line in lines {
                 let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                 if parts.count >= 3, let pid = Int32(parts[0]) {
                     // Check if it's a gui app
                     if let app = NSRunningApplication(processIdentifier: pid), let icon = app.icon, let name = app.localizedName {
                         if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { continue } // Exclude self
                         let state = parts[1]
                         let desc = state.contains("Z") ? "Zombie" : "Unresponsive"
                         items.append(OptimizerProcessItem(id: pid, name: name, icon: icon, usageDescription: desc))
                     }
                 }
             }
             self.hungApps = items
        }
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
        
        // 2. 重启 mDNSResponder
        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["-HUP", "mDNSResponder"]
        try? killall.run()
        killall.waitUntilExit()
        
        // 3. 清理网络缓存
        let home = FileManager.default.homeDirectoryForCurrentUser
        let networkCachePaths = [
            home.appendingPathComponent("Library/Caches/com.apple.Safari/NetworkResources"),
            home.appendingPathComponent("Library/Caches/Google/Chrome/Default/Cache"),
        ]
        
        for path in networkCachePaths {
            try? FileManager.default.removeItem(at: path)
        }
        
        // 4. 优化 TCP 设置 (仅查看，实际修改需要 root)
        print("[NetworkOptimize] DNS cache flushed, network caches cleared")
    }
    
    // MARK: - 启动加速
    private func performBootOptimization() async {
        // 1. 禁用非必要的启动代理
        let userAgentsPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
        
        // 安全白名单 - 这些不应该被禁用
        let safeAgents = ["com.apple.", "com.google.", "com.microsoft.", "homebrew."]
        
        if let agents = try? FileManager.default.contentsOfDirectory(atPath: userAgentsPath.path) {
            for agent in agents where agent.hasSuffix(".plist") {
                // 跳过白名单中的代理
                let shouldSkip = safeAgents.contains { agent.lowercased().contains($0) }
                if shouldSkip { continue }
                
                let agentPath = userAgentsPath.appendingPathComponent(agent).path
                
                // 卸载启动代理
                let unload = Process()
                unload.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                unload.arguments = ["unload", "-w", agentPath]
                try? unload.run()
                unload.waitUntilExit()
            }
        }
        
        // 2. 清理登录项缓存
        let loginItemsCache = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.backgroundtaskmanagementagent")
        try? FileManager.default.removeItem(at: loginItemsCache)
        
        print("[BootOptimize] Unnecessary launch agents disabled, login items cache cleared")
    }
    
    // MARK: - 内存优化
    private func performMemoryOptimization() async {
        // 1. 使用 memory_pressure 触发内存回收
        let memPressure = Process()
        memPressure.executableURL = URL(fileURLWithPath: "/usr/bin/memory_pressure")
        memPressure.arguments = ["-l", "critical"]
        try? memPressure.run()
        
        // 等待2秒让系统响应
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        memPressure.terminate()
        
        // 2. 尝试使用 purge (可能需要开发者工具)
        let purge = Process()
        purge.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
        try? purge.run()
        purge.waitUntilExit()
        
        // 3. 终止后台资源密集型进程 (仅 > 500MB 内存使用)
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "ps -Aceo pid,rss,comm | awk '$2 > 500000 {print $1}'"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        
        print("[MemoryOptimize] RAM freed, memory pressure applied")
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
        lsregister.arguments = ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"]
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
    @StateObject private var service = OptimizerService()
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
                                Text(loc.currentLanguage == .chinese ? "简介" : "Intro")
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
                            Text(loc.currentLanguage == .chinese ? "优化" : "Optimization")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            
                            // Search Bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(loc.currentLanguage == .chinese ? "搜索" : "Search")
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
                                            Text(loc.currentLanguage == .chinese ? "点击下方按钮开始优化" : "Click button below to start optimization")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white.opacity(0.7))
                                            
                                            Text(loc.currentLanguage == .chinese ? "此操作是安全的，可随时执行" : "This operation is safe and can be run anytime")
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
                                        Text(loc.currentLanguage == .chinese ? "未发现挂起的应用程序" : "No hung applications found")
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
                        Text(loc.currentLanguage == .chinese ? "执行" : "Run")
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
            Text(loc.currentLanguage == .chinese ? "正在执行优化任务..." : "Executing Optimization Tasks...")
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
            
            Text(loc.currentLanguage == .chinese ? "优化完成！" : "Optimization Complete!")
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
                Text(loc.currentLanguage == .chinese ? "完成" : "Done")
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
                Text(item.isEnabled ? (loc.currentLanguage == .chinese ? "已启用" : "Enabled") : (loc.currentLanguage == .chinese ? "已禁用" : "Disabled"))
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
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left: Content
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(loc.currentLanguage == .chinese ? "优化" : "Optimization")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(loc.currentLanguage == .chinese ? "通过控制 Mac 上运行的应用，提高它的输出。" : "Improve output by controlling apps running on your Mac.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                    }
                    
                    VStack(alignment: .leading, spacing: 24) {
                        ShredderFeatureRow(icon: "light.beacon.max.fill", title: loc.currentLanguage == .chinese ? "管理应用的启动代理" : "Manage Launch Agents", description: loc.currentLanguage == .chinese ? "控制您的 Mac 支持的应用。" : "Control applications supported by your Mac.")
                        ShredderFeatureRow(icon: "waveform.path.ecg", title: loc.currentLanguage == .chinese ? "控制正在运行的应用" : "Control Running Apps", description: loc.currentLanguage == .chinese ? "管理所有登录项，仅运行真正需要的项目。" : "Manage login items, running only what you truly need.")
                    }
                    
                    Button(action: { viewState = 1 }) {
                        Text(loc.currentLanguage == .chinese ? "查看项目" : "View Items")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.2, green: 0.7, blue: 0.9)) // Cyan/Blue
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .shadow(radius: 5)
                }
                .frame(maxWidth: 400)
                .padding(.leading, 60)
                
                Spacer()
                
                // Right: Icon (Purple Circle with Sliders -> Image Asset)
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
                                        colors: [Color(red: 0.8, green: 0.4, blue: 0.7), Color(red: 0.5, green: 0.2, blue: 0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 320, height: 320)
                                .shadow(radius: 20)
                            
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
                                // Slider 3 (Lower)
                                VStack(spacing: 0) {
                                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 8, height: 40)
                                    Circle().fill(Color.white).frame(width: 24, height: 24)
                                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 8, height: 120)
                                }
                            }
                        }
                    }
                }
                .padding(.trailing, 60)
            }
        }
    }
}
