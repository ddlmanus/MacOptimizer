import SwiftUI
import Combine

// MARK: - Models

struct DeepCleanItem: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let category: DeepCleanCategory
    var isSelected: Bool = true
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

enum DeepCleanCategory: String, CaseIterable, Sendable {
    case largeFiles = "Large Files"
    case junkFiles = "System Junk"
    case systemLogs = "Log Files"
    case systemCaches = "Cache Files"
    case appResiduals = "App Residue"
    
    var localizedName: String {
        switch self {
        case .largeFiles: return LocalizationManager.shared.currentLanguage == .chinese ? "大文件" : "Large Files"
        case .junkFiles: return LocalizationManager.shared.currentLanguage == .chinese ? "系统垃圾" : "System Junk"
        case .systemLogs: return LocalizationManager.shared.currentLanguage == .chinese ? "日志文件" : "Log Files"
        case .systemCaches: return LocalizationManager.shared.currentLanguage == .chinese ? "缓存文件" : "Cache Files"
        case .appResiduals: return LocalizationManager.shared.currentLanguage == .chinese ? "应用残留" : "App Residue"
        }
    }
    
    var icon: String {
        switch self {
        case .largeFiles: return "arrow.down.doc.fill"
        case .junkFiles: return "trash.fill"
        case .systemLogs: return "doc.text.fill"
        case .systemCaches: return "externaldrive.fill"
        case .appResiduals: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .largeFiles: return .purple
        case .junkFiles: return .red
        case .systemLogs: return .gray
        case .systemCaches: return .blue
        case .appResiduals: return .orange
        }
    }
}

// MARK: - Scanner

class DeepCleanScanner: ObservableObject {
    @Published var items: [DeepCleanItem] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var scanProgress: Double = 0.0
    @Published var scanStatus: String = ""
    @Published var currentScanningUrl: String = ""
    @Published var completedCategories: Set<DeepCleanCategory> = []
    
    // 统计数据
    @Published var totalSize: Int64 = 0
    @Published var cleanedSize: Int64 = 0
    @Published var cleaningProgress: Double = 0.0
    @Published var currentCleaningItem: String = ""
    
    // 选中的大小
    var selectedSize: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    var selectedCount: Int {
        items.filter { $0.isSelected }.count
    }
    
    private let fileManager = FileManager.default
    private var scanTask: Task<Void, Never>?
    
    // 系统保护 - 绝对不删
    private let protectedPaths: Set<String> = [
        "/System",
        "/bin",
        "/sbin",
        "/usr",
        "/var/root"
    ]
    
    // MARK: - API
    
    func startScan() async {
        await MainActor.run {
            self.reset()
            self.isScanning = true
            self.scanStatus = LocalizationManager.shared.currentLanguage == .chinese ? "准备扫描..." : "Preparing..."
            self.scanProgress = 0.05 // Initial small progress
        }
        
        // 并发扫描所有类别
        await withTaskGroup(of: (DeepCleanCategory, [DeepCleanItem]).self) { group in
            
            // 1. 扫描大文件 (User Home + Applications)
            group.addTask {
                await self.updateStatus(LocalizationManager.shared.currentLanguage == .chinese ? "正在扫描大文件..." : "Scanning Large Files...", category: .largeFiles)
                let items = await self.scanLargeFiles()
                return (.largeFiles, items)
            }
            
            // 2. 扫描日志 (Logs)
            group.addTask {
                await self.updateStatus(LocalizationManager.shared.currentLanguage == .chinese ? "正在扫描日志..." : "Scanning Logs...", category: .systemLogs)
                let items = await self.scanLogs()
                return (.systemLogs, items)
            }
            
            // 3. 扫描缓存 (Caches)
            group.addTask {
                await self.updateStatus(LocalizationManager.shared.currentLanguage == .chinese ? "正在扫描缓存..." : "Scanning Caches...", category: .systemCaches)
                let items = await self.scanCaches()
                return (.systemCaches, items)
            }
            
            // 4. 扫描应用残留 (Containers/Support)
            group.addTask {
                await self.updateStatus(LocalizationManager.shared.currentLanguage == .chinese ? "正在扫描应用残留..." : "Scanning Leftovers...", category: .appResiduals)
                let items = await self.scanResiduals()
                return (.appResiduals, items)
            }
            
            // 5. 扫描系统垃圾 (Junk, Trash, Downloads, etc)
            group.addTask {
                await self.updateStatus(LocalizationManager.shared.currentLanguage == .chinese ? "正在扫描系统垃圾..." : "Scanning Junk...", category: .junkFiles)
                let items = await self.scanJunk()
                return (.junkFiles, items)
            }
            
            // 收集结果 (Incremental Updates)
            var completedTasks = 0
            let totalTasks = 5.0
            
            for await (category, result) in group {
                completedTasks += 1
                
                await MainActor.run {
                    // Mark category as complete
                    self.completedCategories.insert(category)
                    
                    // Update items immediately
                    self.items.append(contentsOf: result)
                    
                    // Update total size immediately
                    let newSize = result.reduce(0) { $0 + $1.size }
                    self.totalSize += newSize
                    
                    // Update progress
                    withAnimation(.linear(duration: 0.5)) {
                        self.scanProgress = Double(completedTasks) / totalTasks
                    }
                    
                    // Sort items immediately so UI looks correct
                    self.items.sort { $0.size > $1.size }
                    
                    // Clear scanning URL
                    self.currentScanningUrl = "" 
                }
            }
            
            await MainActor.run {
                self.isScanning = false
                self.scanStatus = LocalizationManager.shared.currentLanguage == .chinese ? "扫描完成" : "Scan Complete"
                self.scanProgress = 1.0
            }
        }
    }
    
    // Throttled UI Update Helper
    private var lastUpdateTime: Date = Date()
    
    func updateScanningUrl(_ url: String) {
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) > 0.05 else { return } // Update every 50ms max
        lastUpdateTime = now
        
        Task { @MainActor in
            self.currentScanningUrl = url
        }
    }
    
    func stopScan() {
        scanTask?.cancel()
        isScanning = false
    }
    
    func cleanSelected() async -> (count: Int, size: Int64) {
        await MainActor.run {
            self.isCleaning = true
            self.scanStatus = LocalizationManager.shared.currentLanguage == .chinese ? "正在清理..." : "Cleaning..."
            self.cleaningProgress = 0
        }
        
        let selectedItems = items.filter { $0.isSelected }
        var deletedCount = 0
        var deletedSize: Int64 = 0
        var failures: [URL] = []
        let totalItems = selectedItems.count
        
        for (index, item) in selectedItems.enumerated() {
            // Update progress for each item
            await MainActor.run {
                self.currentCleaningItem = item.name
                self.scanStatus = LocalizationManager.shared.currentLanguage == .chinese ?
                    "正在清理: \(item.name)" : "Cleaning: \(item.name)"
                self.cleaningProgress = Double(index) / Double(totalItems)
            }
            
            do {
                // Use trashItem for safety (moves to Trash instead of permanent delete)
                try fileManager.trashItem(at: item.url, resultingItemURL: nil)
                deletedCount += 1
                deletedSize += item.size
            } catch {
                print("Delete failed for \(item.url): \(error.localizedDescription)")
                failures.append(item.url)
            }
        }
        
        let finalDeletedSize = deletedSize
        let finalDeletedCount = deletedCount
        
        await MainActor.run {
            self.items.removeAll { item in
                selectedItems.contains(where: { $0.id == item.id }) && !failures.contains(item.url)
            }
            self.cleanedSize = finalDeletedSize
            self.totalSize -= finalDeletedSize
            self.isCleaning = false
            self.cleaningProgress = 1.0
            self.currentCleaningItem = ""
            self.scanStatus = LocalizationManager.shared.currentLanguage == .chinese ? "清理完成" : "Cleanup Complete"
        }
        
        return (finalDeletedCount, finalDeletedSize)
    }
    
    func reset() {
        items = []
        totalSize = 0
        cleanedSize = 0
        scanProgress = 0
        scanStatus = ""
        currentScanningUrl = ""
        completedCategories = []
    }
    
    // MARK: - Helper Methods
    
    private func updateStatus(_ status: String, category: DeepCleanCategory? = nil) async {
        await MainActor.run {
            self.scanStatus = status
        }
    }
    
    // MARK: - Scanning Implementations
    
    private func scanLargeFiles() async -> [DeepCleanItem] {
        // SAFETY: Only scan user's home directory, NEVER /Applications
        let home = fileManager.homeDirectoryForCurrentUser
        let scanRoots = [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Movies"),
            home.appendingPathComponent("Music")
        ]
        
        // SAFETY: Exclude Library entirely to protect app data
        let config = ScanConfiguration(
            minFileSize: 50 * 1024 * 1024, // 50MB
            skipHiddenFiles: true,
            excludedPaths: ["Library", ".Trash", "Applications", ".app"] // NEVER touch apps
        )
        
        let results = await scanDirectoryConcurrently(directories: scanRoots, configuration: config) { url, values -> DeepCleanItem? in
            // SAFETY: Skip .app bundles and application-related files
            if url.path.contains(".app") || 
               url.path.contains("/Applications/") ||
               url.path.contains("/Library/") {
                return nil
            }
            
            return DeepCleanItem(
                url: url,
                name: url.lastPathComponent,
                size: Int64(values.fileSize ?? 0),
                category: .largeFiles
            )
        }
        
        return results
    }
    
    private func scanLogs() async -> [DeepCleanItem] {
        var logDirs = [URL]()
        
        // User Logs - 安全
        let userLogs = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")
        logDirs.append(userLogs)
        
        // 注意: 已移除系统日志路径 /Library/Logs 和 /private/var/log - 可能影响系统稳定性
        
        let config = ScanConfiguration(
            minFileSize: 0,
            skipHiddenFiles: false
        )
        
        return await scanDirectoryConcurrently(directories: logDirs, configuration: config) { url, values in
            // UI Update
            self.updateScanningUrl(url.path)
            
            if url.pathExtension == "log" || url.path.contains("/Logs/") {
                return DeepCleanItem(
                    url: url,
                    name: url.lastPathComponent,
                    size: Int64(values.fileSize ?? 0),
                    category: .systemLogs
                )
            }
            return nil
        }
    }
    
    private func scanCaches() async -> [DeepCleanItem] {
        var cacheDirs = [URL]()
        
        // User Caches - 安全
        let userCaches = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches")
        cacheDirs.append(userCaches)
        
        // 注意: 已移除 /Library/Caches - 系统缓存应由系统自行管理
        
        // 这里我们只扫描顶级文件夹或大文件，避免列出数百万个小缓存文件
        // 策略：列出 Caches 下的一级子文件夹，计算其大小，作为一个 Item
        var items: [DeepCleanItem] = []
        
        for dir in cacheDirs {
            guard let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            
            await withTaskGroup(of: DeepCleanItem?.self) { group in
                for url in contents {
                    group.addTask {
                        // UI Update
                        await MainActor.run {
                            self.updateScanningUrl(url.path)
                        }
                        
                        let size = await calculateSizeAsync(at: url)
                        if size > 1024 * 1024 { // > 1MB
                            return DeepCleanItem(
                                url: url,
                                name: url.lastPathComponent,
                                size: size,
                                category: .systemCaches
                            )
                        }
                        return nil
                    }
                }
                
                for await item in group {
                    if let item = item {
                        items.append(item)
                    }
                }
            }
        }
        
        return items
    }
    
    private func scanResiduals() async -> [DeepCleanItem] {
        // ⚠️ SAFETY: Disabled due to risk of damaging installed applications.
        // This feature incorrectly flagged Chrome and other apps as "residuals".
        // TODO: Implement proper app detection that compares bundle IDs, not folder names.
        print("[DeepClean] scanResiduals DISABLED for safety")
        return []
    }
    
    private func scanJunk() async -> [DeepCleanItem] {
        // Trash, Downloads (Older than X?), Xcode DerivedData
        let home = fileManager.homeDirectoryForCurrentUser
        let trash = home.appendingPathComponent(".Trash")
        
        var items: [DeepCleanItem] = []
        
        // Scan Trash
        updateScanningUrl(trash.path)
        let trashSize = await calculateSizeAsync(at: trash)
        if trashSize > 0 {
            items.append(DeepCleanItem(
                url: trash,
                name: LocalizationManager.shared.currentLanguage == .chinese ? "废纸篓" : "Trash",
                size: trashSize,
                category: .junkFiles
            ))
        }
        
        // Xcode DerivedData
        let developer = home.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        if fileManager.fileExists(atPath: developer.path) {
            updateScanningUrl(developer.path)
            let size = await calculateSizeAsync(at: developer)
             if size > 0 {
                items.append(DeepCleanItem(
                    url: developer,
                    name: "Xcode DerivedData",
                    size: size,
                    category: .junkFiles
                ))
            }
        }
        
        return items
    }
    
    // MARK: - App Helpers
    
    /// 获取已安装应用的标识符集合 (Bundle ID + Name) - 改进版
    private func getInstalledAppParams() async -> Set<String> {
        var params = Set<String>()
        
        // 1. 扫描标准应用目录
        let appDirs = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]
        
        for dir in appDirs {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }
            
            for item in contents {
                if item.hasSuffix(".app") {
                    // 添加应用名称 (去除后缀)
                    let name = (item as NSString).deletingPathExtension
                    params.insert(name.lowercased())
                    
                    // 读取 Info.plist 获取 Bundle ID
                    let appPath = (dir as NSString).appendingPathComponent(item)
                    let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
                    
                    if let plistData = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
                       let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
                       let bundleId = plist["CFBundleIdentifier"] as? String {
                        params.insert(bundleId.lowercased())
                        
                        // 提取 Bundle ID 各组件
                        for component in bundleId.components(separatedBy: ".") where component.count > 3 {
                            params.insert(component.lowercased())
                        }
                    }
                }
            }
        }
        
        // 2. 添加 Homebrew Cask 应用
        let homebrewPaths = ["/opt/homebrew/Caskroom", "/usr/local/Caskroom"]
        for caskPath in homebrewPaths {
            if let casks = try? fileManager.contentsOfDirectory(atPath: caskPath) {
                for cask in casks {
                    params.insert(cask.lowercased())
                }
            }
        }
        
        // 3. 添加正在运行的应用（最重要的安全检查）
        for app in NSWorkspace.shared.runningApplications {
            if let bundleId = app.bundleIdentifier {
                params.insert(bundleId.lowercased())
            }
            if let name = app.localizedName {
                params.insert(name.lowercased())
            }
        }
        
        // 4. 扩展的系统安全名单
        let systemSafelist = [
            "com.apple", "cloudkit", "safari", "mail", "messages", "photos",
            "finder", "dock", "spotlight", "siri", "xcode", "instruments",
            "google", "chrome", "microsoft", "firefox", "adobe", "dropbox",
            "slack", "discord", "zoom", "telegram", "wechat", "qq", "tencent",
            "jetbrains", "vscode", "homebrew", "npm", "python", "ruby", "java"
        ]
        for safe in systemSafelist {
            params.insert(safe)
        }
        
        return params
    }
    
    private func isAppInstalled(_ name: String, params: Set<String>) -> Bool {
        let lowerName = name.lowercased()
        
        // 1. 直接匹配
        if params.contains(lowerName) { return true }
        
        // 2. 检查是否为系统保留
        if lowerName.starts(with: "com.apple.") { return true }
        if lowerName.starts(with: "apple") { return true }
        
        // 3. 模糊匹配：检查是否包含已安装应用名称
        for param in params {
            // 双向包含检查
            if lowerName.contains(param) || param.contains(lowerName) {
                return true
            }
        }
        
        // 4. 框架和插件保护
        let safePatterns = ["framework", "plugin", "extension", "helper", "service", "daemon", "agent"]
        for pattern in safePatterns {
            if lowerName.contains(pattern) { return true }
        }
        
        return false
    }

    
    // Toggle Logic
    func toggleSelection(for item: DeepCleanItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].isSelected.toggle()
        }
    }
    
    func selectItems(in category: DeepCleanCategory) {
        for i in items.indices where items[i].category == category {
            items[i].isSelected = true
        }
    }
    
    func deselectItems(in category: DeepCleanCategory) {
        for i in items.indices where items[i].category == category {
            items[i].isSelected = false
        }
    }
}

