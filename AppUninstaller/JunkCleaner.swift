import Foundation
import Combine
import AppKit

// MARK: - 垃圾类型枚举
enum JunkType: String, CaseIterable, Identifiable {
    case userCache = "用户缓存"
    case systemCache = "系统缓存"
    case userLogs = "用户日志"
    case systemLogs = "系统日志"
    case browserCache = "浏览器缓存"
    case appCache = "应用缓存"
    case chatCache = "聊天缓存"
    case mailAttachments = "邮件附件"
    case crashReports = "崩溃报告"
    case tempFiles = "临时文件"
    case xcodeDerivedData = "Xcode 衍生数据"
    // 新增类型
    case universalBinaries = "通用二进制文件"
    case unusedDiskImages = "不使用的磁盘镜像"
    case deletedUsers = "已删除用户"
    case iosBackups = "iOS 设备备份"
    case oldUpdates = "旧更新"
    case brokenPreferences = "损坏的偏好设置"
    case documentVersions = "文稿版本"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .userCache: return "archivebox.fill"
        case .systemCache: return "internaldrive.fill"
        case .userLogs: return "doc.text.fill"
        case .systemLogs: return "doc.text.fill"
        case .browserCache: return "globe.americas.fill"
        case .appCache: return "square.stack.3d.up.fill"
        case .chatCache: return "bubble.left.and.bubble.right.fill"
        case .mailAttachments: return "envelope.fill"
        case .crashReports: return "exclamationmark.triangle.fill"
        case .tempFiles: return "clock.fill"
        case .xcodeDerivedData: return "hammer.fill"
        // 新增图标
        case .universalBinaries: return "cpu"
        case .unusedDiskImages: return "externaldrive.fill"
        case .deletedUsers: return "person.crop.circle.badge.xmark"
        case .iosBackups: return "iphone"
        case .oldUpdates: return "arrow.down.circle.fill"
        case .brokenPreferences: return "gear.badge.xmark"
        case .documentVersions: return "doc.text.badge.plus"
        }
    }
    
    var description: String {
        switch self {
        case .userCache: return "应用程序产生的临时缓存文件"
        case .systemCache: return "macOS 系统产生的缓存"
        case .userLogs: return "应用程序运行日志"
        case .systemLogs: return "macOS 系统日志文件"
        case .browserCache: return "Chrome、Safari、Firefox 等浏览器缓存"
        case .appCache: return "各种应用的临时文件"
        case .chatCache: return "微信、QQ、Telegram 等聊天记录缓存"
        case .mailAttachments: return "邮件下载的附件文件"
        case .crashReports: return "应用崩溃产生的诊断报告"
        case .tempFiles: return "系统和应用产生的临时文件"
        case .xcodeDerivedData: return "Xcode 编译产生的中间文件"
        // 新增描述
        case .universalBinaries: return "支持多种系统架构的应用程序冗余代码"
        case .unusedDiskImages: return "下载后未使用的 DMG/ISO 镜像文件"
        case .deletedUsers: return "已删除用户的残留数据"
        case .iosBackups: return "iOS 设备备份文件"
        case .oldUpdates: return "已安装的软件更新包"
        case .brokenPreferences: return "已卸载应用的偏好设置残留"
        case .documentVersions: return "旧版本的文档历史记录"
        }
    }
    
    var searchPaths: [String] {
        // SAFETY: Only scan user home (~/) paths. NEVER scan system paths.
        switch self {
        case .userCache: 
            return [
                "~/Library/Caches",
                "~/Library/Saved Application State",
                "~/Library/Cookies"
            ]
        case .systemCache:
            // Removed all system paths - only user-accessible caches
            return [
                "~/Library/Caches"
            ]
        case .userLogs: 
            return [
                "~/Library/Logs",
                "~/Library/Application Support/CrashReporter"
            ]
        case .systemLogs:
            // Removed /Library/Logs, /private/var/log - only user logs
            return [
                "~/Library/Logs"
            ]
        case .browserCache: 
            // 仅包含安全的缓存路径，已移除包含登录信息的目录
            // 注意: 已移除 IndexedDB, LocalStorage, Databases, Firefox/Profiles, CacheStorage - 这些包含用户登录信息
            return [
                // Chrome - 安全缓存
                "~/Library/Caches/Google/Chrome",
                "~/Library/Application Support/Google/Chrome/Default/Cache",
                "~/Library/Application Support/Google/Chrome/Default/Code Cache",
                "~/Library/Application Support/Google/Chrome/Default/GPUCache",
                "~/Library/Application Support/Google/Chrome/ShaderCache",
                // Safari - 仅 Caches 安全
                "~/Library/Caches/com.apple.Safari",
                // Firefox - 仅 Caches 安全 (已移除 Profiles - 包含历史和登录)
                "~/Library/Caches/Firefox",
                // Edge - 安全缓存
                "~/Library/Caches/Microsoft Edge",
                "~/Library/Application Support/Microsoft Edge/Default/Cache",
                "~/Library/Application Support/Microsoft Edge/Default/Code Cache",
                // Arc - 安全缓存
                "~/Library/Caches/company.thebrowser.Browser",
                "~/Library/Application Support/Arc/User Data/Default/Cache",
                // Brave - 安全缓存
                "~/Library/Caches/BraveSoftware",
                "~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cache",
                // Opera
                "~/Library/Caches/com.operasoftware.Opera",
                // Vivaldi
                "~/Library/Caches/com.vivaldi.Vivaldi"
            ]
        case .appCache:
            return [
                // 音乐/媒体应用
                "~/Library/Caches/com.spotify.client",
                "~/Library/Application Support/Spotify/PersistentCache",
                "~/Library/Caches/com.apple.Music",
                "~/Library/Caches/com.apple.podcasts",
                "~/Library/Caches/com.apple.TV",
                "~/Library/Caches/com.netease.163music",
                "~/Library/Caches/com.kugou.mac.kugou",
                "~/Library/Caches/com.tencent.QQMusicMac",
                // 苹果系统应用
                "~/Library/Caches/com.apple.appstore",
                "~/Library/Caches/com.apple.news",
                "~/Library/Caches/com.apple.Maps",
                "~/Library/Caches/com.apple.Photos",
                "~/Library/Caches/com.apple.iChat",
                "~/Library/Caches/com.apple.FaceTime",
                "~/Library/Caches/com.apple.finder",
                "~/Library/Caches/com.apple.Preview",
                "~/Library/Caches/com.apple.QuickTimePlayerX",
                // 云存储
                "~/Library/Caches/com.apple.CloudDocs",
                "~/Library/Caches/com.getdropbox.dropbox",
                "~/Library/Caches/com.google.GoogleDrive",
                "~/Library/Application Support/Google/DriveFS",
                "~/Library/Caches/com.microsoft.OneDrive",
                // 办公应用
                "~/Library/Caches/com.microsoft.Word",
                "~/Library/Caches/com.microsoft.Excel",
                "~/Library/Caches/com.microsoft.Powerpoint",
                "~/Library/Caches/com.microsoft.Outlook",
                "~/Library/Caches/com.microsoft.teams",
                // 视频会议
                "~/Library/Caches/us.zoom.xos",
                "~/Library/Application Support/zoom.us/AutoUpdater",
                "~/Library/Caches/com.cisco.webexmeetingsapp",
                "~/Library/Caches/com.tencent.meeting",
                // 设计/创意应用
                "~/Library/Caches/com.adobe.Photoshop",
                "~/Library/Caches/com.adobe.illustrator",
                "~/Library/Caches/com.figma.Desktop",
                "~/Library/Caches/com.bohemiancoding.sketch3",
                // 视频应用
                "~/Library/Caches/com.bilibili.app.mac",
                "~/Library/Caches/com.youku.mac",
                "~/Library/Caches/tv.iqiyi.player",
                // 其他常用应用
                "~/Library/Caches/com.electron.react-native-macos-starter",
                "~/Library/Caches/com.linear",
                "~/Library/Caches/notion.id"
            ]
        case .chatCache:
            return [
                // 微信
                "~/Library/Containers/com.tencent.xinWeChat/Data/Library/Application Support/com.tencent.xinWeChat",
                "~/Library/Containers/com.tencent.xinWeChat/Data/Library/Caches",
                "~/Library/Caches/com.tencent.xinWeChat",
                // QQ
                "~/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ",
                "~/Library/Containers/com.tencent.qq/Data/Library/Caches",
                "~/Library/Caches/com.tencent.qq",
                // Telegram
                "~/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/stable",
                "~/Library/Caches/ru.keepcoder.Telegram",
                "~/Library/Application Support/Telegram Desktop",
                // 企业微信
                "~/Library/Containers/com.tencent.WeWorkMac/Data/Library/Application Support",
                "~/Library/Containers/com.tencent.WeWorkMac/Data/Library/Caches",
                // 钉钉
                "~/Library/Containers/com.alibaba.DingTalkMac/Data/Library/Application Support",
                "~/Library/Containers/com.alibaba.DingTalkMac/Data/Library/Caches",
                // Slack
                "~/Library/Caches/com.tinyspeck.slackmacgap",
                "~/Library/Application Support/Slack/Service Worker/CacheStorage",
                // Discord
                "~/Library/Caches/com.hnc.Discord",
                "~/Library/Application Support/discord/Cache",
                "~/Library/Application Support/discord/Code Cache",
                // WhatsApp
                "~/Library/Caches/net.whatsapp.WhatsApp",
                "~/Library/Application Support/WhatsApp/Cache",
                // Line
                "~/Library/Caches/jp.naver.line.mac",
                // iMessage 附件（可选择性清理）
                "~/Library/Messages/Attachments"
            ]
        case .mailAttachments:
            return [
                "~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
                "~/Library/Mail Downloads",
                "~/Library/Caches/com.apple.mail"
            ]
        case .crashReports:
            // Removed /Library paths - only user crash reports
            return [
                "~/Library/Logs/DiagnosticReports",
                "~/Library/Application Support/CrashReporter"
            ]
        case .tempFiles:
            // Removed /tmp, /private - only user temp files
            return [
                "~/Library/Application Support/CrashReporter",
                "~/Library/Caches/com.apple.helpd",
                "~/Library/Caches/CloudKit",
                "~/Library/Caches/GeoServices",
                "~/Library/Caches/com.apple.parsecd",
                "~/Downloads/*.dmg",
                "~/Downloads/*.pkg",
                "~/Downloads/*.zip"
            ]
        case .xcodeDerivedData: 
            return [
                "~/Library/Developer/Xcode/DerivedData",
                "~/Library/Developer/Xcode/Archives",
                "~/Library/Developer/CoreSimulator/Caches",
                "~/Library/Developer/CoreSimulator/Devices",
                "~/Library/Developer/Xcode/iOS DeviceSupport",
                "~/Library/Developer/Xcode/watchOS DeviceSupport",
                "~/Library/Developer/Xcode/tvOS DeviceSupport",
                "~/Library/Caches/com.apple.dt.Xcode",
                // CocoaPods
                "~/Library/Caches/CocoaPods",
                // npm/yarn/pnpm
                "~/.npm/_cacache",
                "~/.npm/_logs",
                "~/Library/Caches/Yarn",
                "~/Library/pnpm",
                // Gradle/Maven
                "~/.gradle/caches",
                "~/.m2/repository",
                // Homebrew
                "~/Library/Caches/Homebrew",
                // pip
                "~/Library/Caches/pip",
                // Ruby/Gem
                "~/.gem",
                // Go
                "~/go/pkg/mod/cache"
            ]
        // DISABLED TYPES - These are risky or require system access
        case .universalBinaries:
            return [] // DISABLED - Do not scan app binaries
        case .unusedDiskImages:
            return ["~/Downloads", "~/Desktop", "~/Documents"]
        case .deletedUsers:
            return [] // DISABLED - System path
        case .iosBackups:
            return ["~/Library/Application Support/MobileSync/Backup"]
        case .oldUpdates:
            return [] // DISABLED - System path
        case .brokenPreferences:
            return ["~/Library/Preferences"]
        case .documentVersions:
            return [] // DISABLED - System path
        }
    }
}

// MARK: - 垃圾项模型
class JunkItem: Identifiable, ObservableObject {
    let id = UUID()
    let type: JunkType
    let path: URL
    let size: Int64
    @Published var isSelected: Bool = true
    
    init(type: JunkType, path: URL, size: Int64) {
        self.type = type
        self.path = path
        self.size = size
    }
    
    var name: String {
        path.lastPathComponent
    }
}

// MARK: - 垃圾清理服务
class JunkCleaner: ObservableObject {
    @Published var junkItems: [JunkItem] = []
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0
    
    private let fileManager = FileManager.default
    
    var totalSize: Int64 {
        junkItems.reduce(0) { $0 + $1.size }
    }
    
    var selectedSize: Int64 {
        junkItems.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    /// 扫描所有垃圾 - 使用多线程并发扫描优化
    func scanJunk() async {
        await MainActor.run {
            isScanning = true
            junkItems.removeAll()
            scanProgress = 0
        }
        
        // Exclude risky types: universalBinaries (modifies apps), documentVersions (SIP protected)
        let safeTypes = JunkType.allCases.filter { type in
            type != .universalBinaries && type != .documentVersions
        }
        let totalTypes = safeTypes.count
        let progressTracker = ScanProgressTracker()
        await progressTracker.setTotalTasks(totalTypes)
        
        // 使用 TaskGroup 并发扫描所有垃圾类型
        var allItems: [JunkItem] = []
        
        await withTaskGroup(of: (JunkType, [JunkItem]).self) { group in
            for type in safeTypes {
                group.addTask {
                    let typeItems = await self.scanTypeConcurrent(type)
                    return (type, typeItems)
                }
            }
            
            // 收集结果并更新进度
            for await (_, typeItems) in group {
                allItems.append(contentsOf: typeItems)
                await progressTracker.completeTask()
                
                let progress = await progressTracker.getProgress()
                await MainActor.run {
                    self.scanProgress = progress
                }
            }
        }
        
        // 排序：按大小降序
        allItems.sort { $0.size > $1.size }
        
        // 默认全选
        allItems.forEach { $0.isSelected = true }
        
        await MainActor.run {
            self.junkItems = allItems
            isScanning = false
        }
    }
    
    /// 并发扫描单个类型 - 优化版，并行处理多个搜索路径
    private func scanTypeConcurrent(_ type: JunkType) async -> [JunkItem] {
        let searchPaths = type.searchPaths
        
        // 预先获取已安装应用列表，仅在需要时获取 (Broken Preferences / Localizations 等可能需要)
        let installedBundleIds: Set<String>? = (type == .brokenPreferences) ? self.getAllInstalledAppBundleIds() : nil
        
        // 使用 TaskGroup 并行扫描多个路径
        var allItems: [JunkItem] = []
        
        await withTaskGroup(of: [JunkItem].self) { group in
            for pathStr in searchPaths {
                group.addTask {
                    let expandedPath = NSString(string: pathStr).expandingTildeInPath
                    let url = URL(fileURLWithPath: expandedPath)
                    
                    guard self.fileManager.fileExists(atPath: url.path) else { return [] }
                    
                    var items: [JunkItem] = []
                    
                    // --- 特殊类型的专门处理逻辑 ---
                    
                    if type == .universalBinaries {
                         // 扫描应用目录
                        if let contents = try? self.fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                             for appURL in contents where appURL.pathExtension == "app" {
                                 let binaryPath = appURL.appendingPathComponent("Contents/MacOS/\(appURL.deletingPathExtension().lastPathComponent)")
                                 if self.fileManager.fileExists(atPath: binaryPath.path) {
                                     // 使用 lipo -detailed_info 获取精确大小
                                     if let savings = self.calculateUniversalBinarySavings(at: binaryPath) {
                                         // 只有节省空间 > 0 才列出
                                         if savings > 0 {
                                             items.append(JunkItem(type: type, path: binaryPath, size: savings))
                                         }
                                     }
                                 }
                             }
                        }
                        return items
                    }
                    
                    if type == .unusedDiskImages {
                        // 递归扫描目录寻找 .dmg / .iso
                        if let enumerator = self.fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .contentAccessDateKey], options: [.skipsHiddenFiles]) {
                            for case let fileURL as URL in enumerator {
                                let ext = fileURL.pathExtension.lowercased()
                                if ["dmg", "iso", "pkg"].contains(ext) {
                                    // 检查是否"未使用" (例如超过 14 天未访问/修改)
                                    // 简单判断: 仅仅扫描出来让用户决定，或者增加时间过滤
                                    // 根据用户"完整计算"的要求，我们列出所有，但在 UI 上可以按时间排序。
                                    // 这里我们只过滤掉显然是正在下载的 (.part, .download) - 已包含在 ext check 中
                                    if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 {
                                        items.append(JunkItem(type: type, path: fileURL, size: Int64(size)))
                                    }
                                }
                            }
                        }
                        return items
                    }
                    
                    if type == .brokenPreferences {
                        guard let installedIds = installedBundleIds else { return [] }
                        
                        // Get bundle IDs of currently running apps to avoid flagging their prefs
                        let runningAppIds = NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier }
                        
                        // 扫描 plist 并检查是否 orphaned
                        if let contents = try? self.fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
                            for fileURL in contents where fileURL.pathExtension == "plist" {
                                let filename = fileURL.deletingPathExtension().lastPathComponent
                                
                                // 排除系统偏好设置
                                if filename.starts(with: "com.apple.") || filename.starts(with: ".") { continue }
                                
                                // 排除正在运行的应用
                                let isRunning = runningAppIds.contains { runningId in
                                    filename == runningId || filename.lowercased() == runningId.lowercased()
                                }
                                if isRunning { continue }
                                
                                // 检查是否属于任何已安装的 App
                                // 规则：文件名通常是 Bundle ID
                                let isInstalled = installedIds.contains { bundleId in
                                    // 精确匹配 range
                                    // 很多时候 plist 是 com.company.app.plist, bundleId 是 com.company.app
                                    return filename == bundleId || 
                                           filename.lowercased() == bundleId.lowercased() ||
                                           // 处理一些变体，如 com.company.app.plist vs com.company.app
                                           (filename.count > bundleId.count && filename.hasPrefix(bundleId))
                                }
                                
                                if !isInstalled {
                                    if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 {
                                        items.append(JunkItem(type: type, path: fileURL, size: Int64(size)))
                                    }
                                }
                            }
                        }
                        return items
                    }
                    
                    // --- 通用扫描逻辑 (原有逻辑) ---
                    
                    do {
                        let contents = try self.fileManager.contentsOfDirectory(
                            at: url,
                            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                            options: [.skipsHiddenFiles]
                        )
                        
                        // 并发计算每个子项的大小
                        await withTaskGroup(of: JunkItem?.self) { sizeGroup in
                            for fileUrl in contents {
                                sizeGroup.addTask {
                                    let size = await self.calculateSizeAsync(at: fileUrl)
                                    if size > 0 {
                                        return JunkItem(type: type, path: fileUrl, size: size)
                                    }
                                    return nil
                                }
                            }
                            
                            for await item in sizeGroup {
                                if let item = item {
                                    items.append(item)
                                }
                            }
                        }
                    } catch {
                        // 静默处理权限错误
                    }
                    
                    return items
                }
            }
            
            for await pathItems in group {
                allItems.append(contentsOf: pathItems)
            }
        }
        
        return allItems
    }
    
    // MARK: - 辅助分析方法
    
    /// 计算通用二进制文件瘦身可释放的空间
    private func calculateUniversalBinarySavings(at url: URL) -> Int64? {
        let path = url.path
        let task = Process()
        task.launchPath = "/usr/bin/lipo"
        task.arguments = ["-detailed_info", path]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }
            
            // 解析 output
            // 格式示例:
            // architecture x86_64
            //     size 123456
            //     offset 0
            // architecture arm64
            //     size 123456
            
            var archSizes: [String: Int64] = [:]
            
            let lines = output.components(separatedBy: .newlines)
            var currentArch: String?
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.starts(with: "architecture ") {
                    currentArch = trimmed.components(separatedBy: " ").last
                } else if let arch = currentArch, trimmed.starts(with: "size ") {
                    if let sizeStr = trimmed.components(separatedBy: " ").last,
                       let size = Int64(sizeStr) {
                        archSizes[arch] = size
                    }
                }
            }
            
            // 确定当前架构
            var currentSystemArch = "x86_64"
            #if arch(arm64)
            currentSystemArch = "arm64"
            #endif
            
            // 必须包含当前架构，且至少包含另一个架构才算 Universal
            guard archSizes.keys.contains(currentSystemArch) && archSizes.count > 1 else {
                return nil
            }
            
            // 计算可移除的架构总大小
            // 保留当前架构，移除其他所有
            let totalRemovable = archSizes.filter { $0.key != currentSystemArch }.reduce(0) { $0 + $1.value }
            
            return totalRemovable
            
        } catch {
            return nil
        }
    }
    
    /// 获取所有已安装应用的 Bundle ID（改进版）
    private func getAllInstalledAppBundleIds() -> Set<String> {
        var bundleIds = Set<String>()
        
        // 1. 扫描标准应用目录
        let appDirs = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]
        
        for appDir in appDirs {
            if let apps = try? fileManager.contentsOfDirectory(atPath: appDir) {
                for app in apps where app.hasSuffix(".app") {
                    let appPath = "\(appDir)/\(app)"
                    let plistPath = "\(appPath)/Contents/Info.plist"
                    
                    // 添加应用名称作为备用匹配
                    let appName = (app as NSString).deletingPathExtension
                    bundleIds.insert(appName.lowercased())
                    
                    if let plist = NSDictionary(contentsOfFile: plistPath),
                       let bundleId = plist["CFBundleIdentifier"] as? String {
                        bundleIds.insert(bundleId)
                        bundleIds.insert(bundleId.lowercased())
                        
                        // 提取 Bundle ID 的最后组件
                        if let lastComponent = bundleId.components(separatedBy: ".").last {
                            bundleIds.insert(lastComponent.lowercased())
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
                    bundleIds.insert(cask.lowercased())
                }
            }
        }
        
        // 3. 添加正在运行的应用
        for app in NSWorkspace.shared.runningApplications {
            if let bundleId = app.bundleIdentifier {
                bundleIds.insert(bundleId)
                bundleIds.insert(bundleId.lowercased())
            }
            if let name = app.localizedName {
                bundleIds.insert(name.lowercased())
            }
        }
        
        // 4. 添加系统安全名单
        let systemSafelist = [
            "com.apple", "apple", "google", "chrome", "microsoft", "firefox",
            "adobe", "dropbox", "slack", "discord", "zoom", "telegram",
            "wechat", "qq", "tencent", "jetbrains", "xcode", "safari"
        ]
        for safe in systemSafelist {
            bundleIds.insert(safe)
        }
        
        return bundleIds
    }
    
    // 异步计算目录大小 (保留原有优化版)
    private func calculateSizeAsync2(at url: URL) async -> Int64 {
        // ... (kept for reference, actual implementation uses check below)
        return await calculateSizeAsync(at: url)
    }
    
    /// 异步计算目录大小 - 优化版
    private func calculateSizeAsync(at url: URL) async -> Int64 {
        var totalSize: Int64 = 0
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
        
        if isDirectory.boolValue {
            // 对于目录，收集所有文件然后批量计算
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { return 0 }
            
            var fileURLs: [URL] = []
            for case let fileURL as URL in enumerator {
                fileURLs.append(fileURL)
            }
            
            // 分块并发计算
            let chunkSize = max(50, fileURLs.count / 4)
            let chunks = stride(from: 0, to: fileURLs.count, by: chunkSize).map {
                Array(fileURLs[$0..<min($0 + chunkSize, fileURLs.count)])
            }
            
            await withTaskGroup(of: Int64.self) { group in
                for chunk in chunks {
                    group.addTask {
                        var chunkTotal: Int64 = 0
                        for fileURL in chunk {
                            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                               let size = values.fileSize {
                                chunkTotal += Int64(size)
                            }
                        }
                        return chunkTotal
                    }
                }
                
                for await size in group {
                    totalSize += size
                }
            }
        } else {
            if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? UInt64 {
                totalSize = Int64(size)
            }
        }
        
        return totalSize
    }
    
    /// 清理选中的垃圾
    func cleanSelected() async -> (cleaned: Int64, failed: Int64, requiresAdmin: Bool) {
        var cleanedSize: Int64 = 0
        var failedSize: Int64 = 0
        var needsAdmin = false
        let selectedItems = junkItems.filter { $0.isSelected }
        var failedItems: [JunkItem] = []
        
        for item in selectedItems {
            // 特殊类型处理
            if item.type == .universalBinaries {
                let freedBytes = await thinUniversalBinary(item)
                if freedBytes > 0 {
                    cleanedSize += freedBytes
                    // 成功瘦身，释放了 freedBytes 大小
                } else {
                    failedSize += item.size
                    failedItems.append(item)
                }
                continue
            }
            
            let success = await deleteItem(item)
            if success {
                cleanedSize += item.size
            } else {
                failedSize += item.size
                failedItems.append(item)
            }
        }
        
        // 如果有失败的项目（且不是瘦身失败的，瘦身失败通常不建议 sudo 强行破坏），尝试使用 sudo 权限删除
        // 过滤掉 Universal Binaries 的 sudo 重试，因为 lipo 需要复杂参数，简单的 rm -rf 不适用
        let retryItems = failedItems.filter { $0.type != .universalBinaries }
        
        if !retryItems.isEmpty {
            let failedPaths = retryItems.map { $0.path.path }
            let (sudoCleanedSize, sudoSuccess) = await cleanWithAdminPrivileges(paths: failedPaths, items: retryItems)
            if sudoSuccess {
                cleanedSize += sudoCleanedSize
                failedSize -= sudoCleanedSize
            } else {
                needsAdmin = true
            }
        }
        
        await MainActor.run {
            self.junkItems.removeAll { item in
                selectedItems.contains { $0.id == item.id } && !failedItems.contains { $0.id == item.id }
            }
        }
        
        // 重新扫描以反映最新状态
        await scanJunk()
        
        return (cleanedSize, failedSize, needsAdmin)
    }
    
    /// 瘦身通用二进制文件
    /// 返回值: 释放的字节数 (0 表示失败)
    private func thinUniversalBinary(_ item: JunkItem) async -> Int64 {
        let path = item.path.path
        let fileManager = FileManager.default
        
        // 1. 记录原始大小
        guard let attrsBefore = try? fileManager.attributesOfItem(atPath: path),
              let sizeBefore = attrsBefore[.size] as? Int64 else { return 0 }
        
        // 2. 获取当前架构
        var currentArch = "x86_64"
        #if arch(arm64)
        currentArch = "arm64"
        #endif
        
        let tempPath = path + ".thin"
        
        // 3. 运行 lipo 命令
        let lipoTask = Process()
        lipoTask.launchPath = "/usr/bin/lipo"
        lipoTask.arguments = [path, "-thin", currentArch, "-output", tempPath]
        
        do {
            try lipoTask.run()
            lipoTask.waitUntilExit()
            
            if lipoTask.terminationStatus == 0 && fileManager.fileExists(atPath: tempPath) {
                // lipo 成功
                
                // 4. 替换原文件
                let backupPath = path + ".bak"
                try? fileManager.moveItem(atPath: path, toPath: backupPath) // 备份
                
                try fileManager.moveItem(atPath: tempPath, toPath: path)
                try? fileManager.removeItem(atPath: backupPath) // 删除备份
                
                // 5. 重新签名
                if !reSignApp(path) {
                    print("Resign failed for \(path). Reverting...")
                    // 签名失败，回滚
                    try? fileManager.removeItem(atPath: path) // 删除失败的瘦身文件
                    try? fileManager.moveItem(atPath: backupPath, toPath: path) // 恢复备份
                    return 0
                }
                
                // 成功，删除备份
                try? fileManager.removeItem(atPath: backupPath)
                
                // 6. 计算新大小并返回差值
                if let attrsAfter = try? fileManager.attributesOfItem(atPath: path),
                   let sizeAfter = attrsAfter[.size] as? Int64 {
                    let freed = max(0, sizeBefore - sizeAfter)
                    return freed
                }
                
                // 如果无法读取新大小，返回估算值（或 0）
                return 0
            }
        } catch {
            print("Lipo failed: \(error)")
        }
        
        return 0
    }
    
    /// 重新签名 App (Ad-hoc)
    private func reSignApp(_ binaryPath: String) -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/codesign"
        task.arguments = ["--force", "--sign", "-", binaryPath]
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    /// 删除单个项目
    private func deleteItem(_ item: JunkItem) async -> Bool {
        // 先尝试移至废纸篓（更安全）
        do {
            try fileManager.trashItem(at: item.path, resultingItemURL: nil)
            return true
        } catch {
            // 废纸篓失败，尝试直接删除
            do {
                try fileManager.removeItem(at: item.path)
                return true
            } catch {
                print("Failed to delete \(item.path.path): \(error)")
                return false
            }
        }
    }
    
    /// 使用管理员权限清理（通过 AppleScript）
    private func cleanWithAdminPrivileges(paths: [String], items: [JunkItem]) async -> (Int64, Bool) {
        var cleanedSize: Int64 = 0
        
        // 构建删除命令
        // 使用 rm -rf 
        let escapedPaths = paths.map { path in
            path.replacingOccurrences(of: "'", with: "'\\''")
        }
        
        let rmCommands = escapedPaths.map { "rm -rf '\($0)'" }.joined(separator: " && ")
        
        let script = """
        do shell script "\(rmCommands)" with administrator privileges
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            
            if error == nil {
                // 成功，计算清理的大小
                for path in paths {
                    if let item = items.first(where: { $0.path.path == path }) {
                        cleanedSize += item.size
                    }
                }
                return (cleanedSize, true)
            }
        }
        
        return (0, false)
    }
    
    private func scanType(_ type: JunkType) async -> [JunkItem] {
        var items: [JunkItem] = []
        
        for pathStr in type.searchPaths {
            let expandedPath = NSString(string: pathStr).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath)
            
            guard fileManager.fileExists(atPath: url.path) else { continue }
            
            // 对于 Caches 和 Logs，我们扫描子文件夹
            // 对于 Trash，扫描子文件
            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles])
                
                for fileUrl in contents {
                    let size = calculateSize(at: fileUrl)
                    if size > 0 {
                        items.append(JunkItem(type: type, path: fileUrl, size: size))
                    }
                }
            } catch {
                print("Error scanning \(url.path): \(error)")
            }
        }
        
        return items
    }
    
    private func calculateSize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
                for case let fileURL as URL in enumerator {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                        totalSize += Int64(resourceValues.fileSize ?? 0)
                    } catch { continue }
                }
            } else {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: url.path)
                    totalSize = Int64(attributes[.size] as? UInt64 ?? 0)
                } catch { return 0 }
            }
        }
        
        return totalSize
    }
}
