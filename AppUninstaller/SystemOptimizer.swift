import Foundation
import Combine
import AppKit

// MARK: - 优化功能类型
enum OptimizationType: String, CaseIterable, Identifiable {
    case freeMemory = "释放内存"
    case flushDNS = "刷新 DNS"
    case rebuildSpotlight = "重建 Spotlight 索引"
    case rebuildLaunchServices = "重建启动服务数据库"
    case clearFontCache = "清除字体缓存"
    case repairPermissions = "验证磁盘权限"
    case killBackgroundApps = "关闭后台应用"
    case clearClipboard = "清空剪贴板"
    case clearRecentItems = "清除最近使用记录"
    case restartFinder = "重启 Finder"
    case restartDock = "重启 Dock"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .freeMemory: return "memorychip"
        case .flushDNS: return "network"
        case .rebuildSpotlight: return "magnifyingglass"
        case .rebuildLaunchServices: return "arrow.triangle.2.circlepath"
        case .clearFontCache: return "textformat"
        case .repairPermissions: return "lock.shield"
        case .killBackgroundApps: return "xmark.app"
        case .clearClipboard: return "doc.on.clipboard"
        case .clearRecentItems: return "clock.arrow.circlepath"
        case .restartFinder: return "folder"
        case .restartDock: return "dock.rectangle"
        }
    }
    
    var description: String {
        switch self {
        case .freeMemory: return "清理系统内存，释放未使用的 RAM"
        case .flushDNS: return "清除 DNS 缓存，解决网络问题"
        case .rebuildSpotlight: return "重建搜索索引，修复搜索问题"
        case .rebuildLaunchServices: return "修复'打开方式'菜单重复项"
        case .clearFontCache: return "清除字体缓存，修复字体显示问题"
        case .repairPermissions: return "验证并修复系统目录权限"
        case .killBackgroundApps: return "强制关闭所有后台非活跃应用"
        case .clearClipboard: return "清空系统剪贴板内容"
        case .clearRecentItems: return "清除 Finder 最近使用的文件记录"
        case .restartFinder: return "重启 Finder 解决卡顿问题"
        case .restartDock: return "重启 Dock 解决图标显示问题"
        }
    }
    
    var requiresAdmin: Bool {
        switch self {
        case .rebuildSpotlight, .rebuildLaunchServices, .repairPermissions, .flushDNS:
            return true
        default:
            return false
        }
    }
    
    var command: String {
        switch self {
        case .freeMemory:
            return "sudo purge"
        case .flushDNS:
            return "sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"
        case .rebuildSpotlight:
            return "sudo mdutil -E /"
        case .rebuildLaunchServices:
            return "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user"
        case .clearFontCache:
            return "sudo atsutil databases -remove"
        case .repairPermissions:
            return "diskutil verifyPermissions /"
        case .killBackgroundApps:
            return "" // 特殊处理
        case .clearClipboard:
            return "pbcopy < /dev/null"
        case .clearRecentItems:
            return "rm -rf ~/Library/Application\\ Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/*"
        case .restartFinder:
            return "killall Finder"
        case .restartDock:
            return "killall Dock"
        }
    }
}

// MARK: - 启动项模型
class LaunchItem: Identifiable, ObservableObject {
    let id = UUID()
    let url: URL
    let name: String
    
    @Published var isEnabled: Bool
    
    init(url: URL) {
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.isEnabled = url.pathExtension == "plist"
    }
}

// MARK: - 运行中应用模型
class RunningAppItem: Identifiable, ObservableObject {
    let id = UUID()
    let app: NSRunningApplication
    let name: String
    let icon: NSImage
    @Published var isSelected: Bool = false
    
    init(app: NSRunningApplication) {
        self.app = app
        self.name = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
        self.icon = app.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }
}

// MARK: - 系统优化服务
class SystemOptimizer: ObservableObject {
    @Published var launchAgents: [LaunchItem] = []
    @Published var runningApps: [RunningAppItem] = []
    @Published var isScanning: Bool = false
    @Published var isOptimizing: Bool = false
    @Published var optimizationResult: String = ""
    @Published var backgroundApps: [NSRunningApplication] = []
    
    private let fileManager = FileManager.default
    private let agentsPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
    
    // MARK: - 一键优化
    func performOneClickOptimization() async -> (success: Bool, message: String) {
        await MainActor.run {
            isOptimizing = true
        }
        
        var results: [String] = []
        
        // 1. 关闭选中的应用
        let selectedApps = runningApps.filter { $0.isSelected }
        var closedCount = 0
        for appItem in selectedApps {
            if appItem.app.terminate() {
                closedCount += 1
            }
        }
        if closedCount > 0 {
            results.append("关闭了 \(closedCount) 个应用")
        }
        
        // 2. 释放内存
        _ = runCommand("sudo purge 2>/dev/null || true")
        results.append("内存已优化")
        
        // 3. 清空剪贴板
        NSPasteboard.general.clearContents()
        results.append("剪贴板已清空")
        
        // 4. 刷新后台应用列表
        await MainActor.run {
            scanRunningApps()
        }
        
        let message = results.joined(separator: "，")
        
        await MainActor.run {
            isOptimizing = false
            optimizationResult = message
        }
        
        return (true, message)
    }
    
    // MARK: - 扫描运行中的应用
    func scanRunningApps() {
        let runningApps = NSWorkspace.shared.runningApplications
        let frontApp = NSWorkspace.shared.frontmostApplication
        
        let protectedBundleIds = [
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.SystemUIServer",
            "com.apple.loginwindow",
            "com.apple.WindowServer",
            "com.apple.TextInputMenuAgent",
            "com.apple.Spotlight",
            "com.apple.notificationcenterui",
            "com.apple.controlcenter"
        ]
        
        let filteredApps = runningApps.filter { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            if protectedBundleIds.contains(bundleId) { return false }
            if bundleId == Bundle.main.bundleIdentifier { return false }
            if app == frontApp { return false }
            if app.activationPolicy != .regular { return false }
            return true
        }
        
        self.runningApps = filteredApps.map { RunningAppItem(app: $0) }
    }
    
    // MARK: - 关闭选中的应用
    func terminateSelectedApps() async -> Int {
        var count = 0
        for appItem in runningApps where appItem.isSelected {
            if appItem.app.terminate() {
                count += 1
            }
        }
        await MainActor.run {
            scanRunningApps()
        }
        return count
    }
    
    // MARK: - 全选/取消全选
    func selectAllApps(_ select: Bool) {
        for app in runningApps {
            app.isSelected = select
        }
        objectWillChange.send()
    }
    
    // MARK: - 执行优化
    func performOptimization(_ type: OptimizationType) async -> (success: Bool, message: String) {
        await MainActor.run {
            isOptimizing = true
        }
        
        var success = false
        var message = ""
        
        switch type {
        case .killBackgroundApps:
            let count = await killBackgroundApps()
            success = true
            message = "已关闭 \(count) 个后台应用"
            
        case .clearClipboard:
            NSPasteboard.general.clearContents()
            success = true
            message = "剪贴板已清空"
            
        case .freeMemory, .flushDNS, .rebuildSpotlight, .rebuildLaunchServices, 
             .clearFontCache, .repairPermissions, .clearRecentItems, .restartFinder, .restartDock:
            
            if type.requiresAdmin {
                let result = await executeWithAdminPrivileges(type.command)
                success = result.success
                message = result.success ? getSuccessMessage(for: type) : "执行失败: \(result.output)"
            } else {
                let result = runCommand(type.command)
                success = true
                message = getSuccessMessage(for: type)
            }
        }
        
        await MainActor.run {
            isOptimizing = false
            optimizationResult = message
        }
        
        return (success, message)
    }
    
    private func getSuccessMessage(for type: OptimizationType) -> String {
        switch type {
        case .freeMemory: return "内存已释放"
        case .flushDNS: return "DNS 缓存已刷新"
        case .rebuildSpotlight: return "Spotlight 索引正在重建"
        case .rebuildLaunchServices: return "启动服务数据库已重建"
        case .clearFontCache: return "字体缓存已清除，建议重启"
        case .repairPermissions: return "权限验证完成"
        case .killBackgroundApps: return "后台应用已关闭"
        case .clearClipboard: return "剪贴板已清空"
        case .clearRecentItems: return "最近使用记录已清除"
        case .restartFinder: return "Finder 已重启"
        case .restartDock: return "Dock 已重启"
        }
    }
    
    // MARK: - 关闭后台应用
    private func killBackgroundApps() async -> Int {
        let runningApps = NSWorkspace.shared.runningApplications
        var killedCount = 0
        
        // 获取当前活跃应用和系统应用
        let frontApp = NSWorkspace.shared.frontmostApplication
        let protectedBundleIds = [
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.SystemUIServer",
            "com.apple.loginwindow",
            "com.apple.WindowServer",
            "com.apple.TextInputMenuAgent",
            "com.apple.Spotlight",
            "com.apple.notificationcenterui"
        ]
        
        for app in runningApps {
            guard let bundleId = app.bundleIdentifier else { continue }
            
            // 跳过保护的应用
            if protectedBundleIds.contains(bundleId) { continue }
            // 跳过当前应用
            if bundleId == Bundle.main.bundleIdentifier { continue }
            // 跳过当前前台应用
            if app == frontApp { continue }
            // 跳过没有界面的后台进程
            if app.activationPolicy == .prohibited { continue }
            
            // 尝试优雅关闭
            if app.terminate() {
                killedCount += 1
            }
        }
        
        return killedCount
    }
    
    // MARK: - 管理员权限执行
    private func executeWithAdminPrivileges(_ command: String) async -> (success: Bool, output: String) {
        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
        
        let script = """
        do shell script "\(escapedCommand)" with administrator privileges
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            
            if error == nil {
                return (true, result.stringValue ?? "")
            } else {
                let errorMsg = error?["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
                return (false, errorMsg)
            }
        }
        
        return (false, "Failed to create script")
    }
    
    // MARK: - 扫描启动项
    func scanLaunchAgents() async {
        await MainActor.run {
            isScanning = true
            launchAgents.removeAll()
        }
        
        guard fileManager.fileExists(atPath: agentsPath.path) else {
            await MainActor.run { isScanning = false }
            return
        }
        
        do {
            let urls = try fileManager.contentsOfDirectory(at: agentsPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            
            let items = urls
                .filter { $0.pathExtension == "plist" || $0.pathExtension == "disabled" }
                .map { LaunchItem(url: $0) }
                .sorted { $0.name < $1.name }
            
            await MainActor.run {
                self.launchAgents = items
                isScanning = false
            }
        } catch {
            print("Error scanning agents: \(error)")
            await MainActor.run { isScanning = false }
        }
    }
    
    // MARK: - 扫描后台应用
    func scanBackgroundApps() {
        let runningApps = NSWorkspace.shared.runningApplications
        let frontApp = NSWorkspace.shared.frontmostApplication
        
        let protectedBundleIds = [
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.SystemUIServer",
            "com.apple.loginwindow",
            "com.apple.WindowServer"
        ]
        
        backgroundApps = runningApps.filter { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            if protectedBundleIds.contains(bundleId) { return false }
            if bundleId == Bundle.main.bundleIdentifier { return false }
            if app == frontApp { return false }
            if app.activationPolicy == .prohibited { return false }
            return true
        }
    }
    
    // MARK: - 切换启用状态
    func toggleAgent(_ item: LaunchItem) async -> Bool {
        let currentUrl = item.url
        let newExtension = item.isEnabled ? "disabled" : "plist"
        let newUrl = currentUrl.deletingPathExtension().appendingPathExtension(newExtension)
        
        do {
            try fileManager.moveItem(at: currentUrl, to: newUrl)
            
            if item.isEnabled {
                _ = runCommand("launchctl unload \"\(currentUrl.path)\"")
            } else {
                _ = runCommand("launchctl load \"\(newUrl.path)\"")
            }
            
            await scanLaunchAgents()
            return true
        } catch {
            print("Failed to toggle agent: \(error)")
            return false
        }
    }
    
    // MARK: - 移除启动项
    func removeAgent(_ item: LaunchItem) async {
        do {
            if item.isEnabled {
                _ = runCommand("launchctl unload \"\(item.url.path)\"")
            }
            try fileManager.removeItem(at: item.url)
            await scanLaunchAgents()
        } catch {
            print("Failed to remove agent: \(error)")
        }
    }
    
    private func runCommand(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
