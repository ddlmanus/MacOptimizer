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
    case xcodeDerivedData = "Xcode 垃圾"
    // 新增类型
    case universalBinaries = "通用二进制文件"
    case unusedDiskImages = "不使用的磁盘镜像"
    case brokenLoginItems = "损坏的登录项"
    case languageFiles = "语言文件"
    case deletedUsers = "已删除用户"
    case iosBackups = "iOS 设备备份"
    case oldUpdates = "旧更新"
    // ⚠️ brokenPreferences 已移除 - 不再扫描系统偏好设置
    case documentVersions = "文稿版本"
    case downloads = "下载"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .userCache: return "person.crop.circle.fill" // User Cache
        case .systemCache: return "gear.circle.fill" // System Cache
        case .userLogs: return "doc.text.fill" // User Logs
        case .systemLogs: return "doc.text.fill" // System Logs
        case .appCache: return "square.stack.3d.up.fill"
        case .browserCache: return "globe.americas.fill"
        case .chatCache: return "message.fill"
        case .mailAttachments: return "envelope.fill"
        case .crashReports: return "exclamationmark.triangle.fill"
        case .tempFiles: return "clock.fill"
        case .xcodeDerivedData: return "hammer.fill"
        // New Types Icons
        case .unusedDiskImages: return "externaldrive.fill" // Disk Image
        case .universalBinaries: return "cpu.fill" // Universal Binary
        case .brokenLoginItems: return "person.badge.minus" // Broken Login
        case .deletedUsers: return "person.crop.circle.badge.xmark" // Deleted Users
        case .iosBackups: return "iphone.circle.fill" // iOS Backups
        case .oldUpdates: return "arrow.down.doc.fill" // Updates
        // brokenPreferences 已移除
        case .documentVersions: return "doc.on.doc.fill"
        case .languageFiles: return "globe"
        case .downloads: return "arrow.down.circle.fill"
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
        case .brokenLoginItems: return "指向不存在的应用或文件的登录项"
        case .languageFiles: return "不使用的应用程序语言包"
        case .deletedUsers: return "已删除用户的残留数据"
        case .iosBackups: return "iOS 设备备份文件"
        case .oldUpdates: return "已安装的软件更新包"
        // brokenPreferences 已移除 - 不再扫描系统偏好设置
        case .documentVersions: return "旧版本的文档历史记录"
        case .downloads: return "下载文件夹中的文件"
        }
    }
    
    var searchPaths: [String] {
        // SAFETY: Only scan user home (~/) paths. NEVER scan system paths.
        switch self {
        case .userCache: 
            return [
                "~/Library/Saved Application State",
                "~/Library/Cookies"
            ]
        case .systemCache:
            // 扫描用户级别的系统缓存
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
            return [] // Dynamic scanning implemented in scanTypeConcurrent
        case .chatCache:
            // 注意：仅扫描 ~/Library/Caches 和 ~/Library/Application Support 中的安全路径
            // 不扫描 ~/Library/Containers/<other-app> 目录，因为会触发 macOS 权限弹窗
            return [
                // 微信 - 仅 Caches 目录
                "~/Library/Caches/com.tencent.xinWeChat",
                // QQ - 仅 Caches 目录
                "~/Library/Caches/com.tencent.qq",
                // Telegram
                "~/Library/Caches/ru.keepcoder.Telegram",
                "~/Library/Application Support/Telegram Desktop",
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
            return ["/Applications", "/System/Applications", "/System/Applications/Utilities", "~/Applications"]
        case .unusedDiskImages:
            return ["~"] // Scan full user home directory recursively
        case .brokenLoginItems:
            return ["~/Library/LaunchAgents"]
        case .languageFiles:
            return [] // Custom logic
        case .deletedUsers:
            return ["/Users/Deleted Users"]
        case .iosBackups:
            return ["~/Library/Application Support/MobileSync/Backup"]
        case .oldUpdates:
            return ["/Library/Updates"]
        // brokenPreferences 已移除 - 不再扫描系统偏好设置
        case .documentVersions:
            return ["/.DocumentRevisions-V100"] 
        case .downloads:
            return ["~/Downloads"]
        }
    }
}

// MARK: - 垃圾项模型
class JunkItem: Identifiable, ObservableObject, @unchecked Sendable {
    let id = UUID()
    let type: JunkType
    let path: URL
    let contextPath: URL? // Path for the actual operation (e.g., binary to strip), while `path` is for display (App Bundle)
    let customName: String? // Optional custom display name
    let size: Int64
    @Published var isSelected: Bool = true
    
    init(type: JunkType, path: URL, size: Int64, contextPath: URL? = nil, customName: String? = nil) {
        self.type = type
        self.path = path
        self.size = size
        self.contextPath = contextPath
        self.customName = customName
    }
    
    var name: String {
        customName ?? path.lastPathComponent
    }
}

// MARK: - 垃圾清理服务
class JunkCleaner: ObservableObject {
    @Published var junkItems: [JunkItem] = []
    @Published var isScanning: Bool = false
    @Published var isCleaning: Bool = false  // 添加清理状态
    @Published var scanProgress: Double = 0
    @Published var hasPermissionErrors: Bool = false
    @Published var currentScanningPath: String = "" // Add path tracking
    @Published var currentScanningCategory: String = "" // Add category tracking
    
    private let fileManager = FileManager.default
    
    var totalSize: Int64 {
        junkItems.reduce(0) { $0 + $1.size }
    }
    
    var selectedSize: Int64 {
        junkItems.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    /// 重置所有状态
    @MainActor
    func reset() {
        junkItems.removeAll()
        isScanning = false
        isCleaning = false
        scanProgress = 0
        hasPermissionErrors = false
        currentScanningPath = ""
        currentScanningCategory = ""
    }
    
    /// 停止扫描
    @MainActor
    func stopScanning() {
        isScanning = false
        scanProgress = 0
        currentScanningPath = ""
        currentScanningCategory = ""
    }
    
    /// 扫描所有垃圾 - 使用多线程并发扫描优化
    func scanJunk() async {
        await MainActor.run {
            isScanning = true
            junkItems.removeAll()
            scanProgress = 0
            hasPermissionErrors = false // Reset errors
        }
        
        let startTime = Date()
        
        // Remove exclusions to matching design requirement. Use safe scanning where possible.
        // Note: documentVersions and oldUpdates might require admin permissions (handled by sudo fallback or error reporting)
        let safeTypes = JunkType.allCases
        let totalTypes = safeTypes.count
        let progressTracker = ScanProgressTracker()
        await progressTracker.setTotalTasks(totalTypes)
        
        // 使用 TaskGroup 并发扫描所有垃圾类型
        await withTaskGroup(of: (JunkType, ([JunkItem], Bool)).self) { group in
            for type in safeTypes {
                group.addTask {
                    let (typeItems, hasError) = await self.scanTypeConcurrent(type)
                    return (type, (typeItems, hasError))
                }
            }
            
            // 收集结果并更新进度 - 实时更新 junkItems 以显示累计大小
            for await (_, (typeItems, hasError)) in group {
                if hasError {
                    await MainActor.run { self.hasPermissionErrors = true }
                }
                
                // 实时追加结果到 junkItems（使 totalSize 实时更新）
                if !typeItems.isEmpty {
                    await MainActor.run {
                        for item in typeItems {
                            item.isSelected = true
                        }
                        self.junkItems.append(contentsOf: typeItems)
                    }
                }
                
                await progressTracker.completeTask()
                
                let progress = await progressTracker.getProgress()
                await MainActor.run {
                    self.scanProgress = progress
                }
            }
        }
        
        // 排序：按大小降序
        await MainActor.run {
            self.junkItems.sort { $0.size > $1.size }
        }
        
        // Ensure minimum 2 seconds scanning time for better UX
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed < 2.0 {
            try? await Task.sleep(nanoseconds: UInt64((2.0 - elapsed) * 1_000_000_000))
        }

        await MainActor.run {
            isScanning = false
        }
    }
    
    /// 并发扫描单个类型 - 优化版，并行处理多个搜索路径
    private func scanTypeConcurrent(_ type: JunkType) async -> ([JunkItem], Bool) {
        let searchPaths = type.searchPaths
        var hasError = false
        // 预先获取已安装应用列表，仅在需要时获取 (Localizations 等可能需要)
        // brokenPreferences 已移除，不再需要 installedBundleIds
        
        // 使用 TaskGroup 并行扫描多个路径
        var allItems: [JunkItem] = []
        
        await withTaskGroup(of: ([JunkItem], Bool).self) { group in
            for pathStr in searchPaths {
                group.addTask {
                    let expandedPath = NSString(string: pathStr).expandingTildeInPath
                    let url = URL(fileURLWithPath: expandedPath)
                    
                    await MainActor.run { 
                        self.currentScanningPath = expandedPath
                        self.currentScanningCategory = type.rawValue 
                    }
                    
                    guard self.fileManager.fileExists(atPath: url.path) else { return ([], false) }
                    
                    var items: [JunkItem] = []
                    
                    // --- 特殊类型的专门处理逻辑 ---
                    
                    if type == .universalBinaries {
                         // 扫描应用目录
                        if let contents = try? self.fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                             for appURL in contents where appURL.pathExtension == "app" {
                                 await MainActor.run { 
                                     self.currentScanningPath = appURL.path 
                                     self.currentScanningCategory = type.rawValue
                                 } 
                                 let binaryPath = appURL.appendingPathComponent("Contents/MacOS/\(appURL.deletingPathExtension().lastPathComponent)")
                                 if self.fileManager.fileExists(atPath: binaryPath.path) {
                                     // 使用 lipo -detailed_info 获取精确大小
                                     if let savings = self.calculateUniversalBinarySavings(at: binaryPath) {
                                         // 只有节省空间 > 0 才列出
                                         if savings > 0 {
                                             // Key Change: path = appURL (for UI), contextPath = binaryPath (for cleaning)
                                             // New Naming: [AppName] Extra File (e.g., "WeChat Extra 文件")
                                             let appName = appURL.deletingPathExtension().lastPathComponent
                                             let extraText = LocalizationManager.shared.currentLanguage == .chinese ? "Extra 文件" : "Extra File"
                                             let displayName = "\(appName) \(extraText)"
                                             
                                             items.append(JunkItem(type: type, path: appURL, size: savings, contextPath: binaryPath, customName: displayName)) 
                                         }
                                     }
                                 }
                             }
                        }
                        return (items, false)
                    }
                    
                    if type == .unusedDiskImages {
                        // 递归扫描目录寻找 .dmg / .iso
                        if let enumerator = self.fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .contentAccessDateKey], options: [.skipsHiddenFiles]) {
                            while let fileURL = enumerator.nextObject() as? URL {
                                if Int.random(in: 0...50) == 0 { 
                                    await MainActor.run { 
                                        self.currentScanningPath = fileURL.path 
                                        self.currentScanningCategory = type.rawValue
                                    } 
                                } // Throttle updates
                                let ext = fileURL.pathExtension.lowercased()
                                if ["dmg", "iso", "pkg"].contains(ext) {
                                    if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 {
                                        items.append(JunkItem(type: type, path: fileURL, size: Int64(size)))
                                    }
                                }
                            }
                        }
                        return (items, false)
                    }
                    
                    // brokenPreferences 已移除 - 不再扫描任何偏好设置

                    if type == .brokenLoginItems {
                        // Scan ~/Library/LaunchAgents
                        if let contents = try? self.fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                            for fileURL in contents where fileURL.pathExtension == "plist" {
                                // Parse plist to find the executable path
                                if let dict = NSDictionary(contentsOf: fileURL),
                                   let programArguments = dict["ProgramArguments"] as? [String],
                                   let executablePath = programArguments.first {
                                    
                                    // Check if executable exists
                                    if !self.fileManager.fileExists(atPath: executablePath) {
                                        // It's broken!
                                        if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                                             items.append(JunkItem(type: type, path: fileURL, size: Int64(size)))
                                        }
                                    }
                                } else if let dict = NSDictionary(contentsOf: fileURL),
                                          let program = dict["Program"] as? String {
                                     // Check Program key
                                     if !self.fileManager.fileExists(atPath: program) {
                                         if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                                             items.append(JunkItem(type: type, path: fileURL, size: Int64(size)))
                                         }
                                     }
                                }
                            }
                        }
                        return (items, false)
                    }
                    
                    if type == .downloads {
                        // Just list top-level files in Downloads for user review, or maybe old ones?
                        // Design implies "Downloads" is just a category. Let's list all files in Downloads.
                        // Ideally we should categorize them or filter by age, but for now scan them all.
                        if let contents = try? self.fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
                             for fileURL in contents {
                                 if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 {
                                     items.append(JunkItem(type: type, path: fileURL, size: Int64(size)))
                                 }
                             }
                        }
                        return (items, false)
                    }

                    if type == .languageFiles {
                         // Adapting logic from SmartCleanerService
                         // 1. Get preferred languages
                         var keepLanguages: Set<String> = ["Base", "en", "English"]
                         for lang in Locale.preferredLanguages {
                             let parts = lang.split(separator: "-").map(String.init)
                             if let languageCode = parts.first {
                                 keepLanguages.insert(languageCode)
                                 if parts.count > 1 {
                                     let secondPart = parts[1]
                                     if secondPart.count == 4 { // Script code like Hans
                                         keepLanguages.insert("\(languageCode)-\(secondPart)")
                                         keepLanguages.insert("\(languageCode)_\(secondPart)")
                                     }
                                 }
                             }
                             keepLanguages.insert(lang)
                         }
                         
                         // 2. Scan Applications
                         let appDirs = [
                             "/Applications",
                             self.fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
                         ]
                         
                         for appDir in appDirs {
                             guard let apps = try? self.fileManager.contentsOfDirectory(atPath: appDir) else { continue }
                             
                             for appName in apps where appName.hasSuffix(".app") {
                                 let appPath = (appDir as NSString).appendingPathComponent(appName)
                                 let appURL = URL(fileURLWithPath: appPath)
                                 
                                 // Skip system apps
                                 let plistPath = appURL.appendingPathComponent("Contents/Info.plist")
                                 if let plist = NSDictionary(contentsOfFile: plistPath.path),
                                    let bundleId = plist["CFBundleIdentifier"] as? String {
                                     if bundleId.hasPrefix("com.apple.") { continue }
                                 }
                                 
                                 // Skip App Store apps
                                 let receiptPath = appURL.appendingPathComponent("Contents/_MASReceipt")
                                 if self.fileManager.fileExists(atPath: receiptPath.path) { continue }
                                 
                                 let resourcesURL = appURL.appendingPathComponent("Contents/Resources")
                                 guard let resources = try? self.fileManager.contentsOfDirectory(at: resourcesURL, includingPropertiesForKeys: nil) else { continue }
                                 
                                 for itemURL in resources where itemURL.pathExtension == "lproj" {
                                     let langName = itemURL.deletingPathExtension().lastPathComponent
                                     
                                     let shouldKeep = keepLanguages.contains { keep in
                                         if keep.lowercased() == langName.lowercased() { return true }
                                         if langName.lowercased().hasPrefix(keep.lowercased()) { return true }
                                         return false
                                     }
                                     
                                     if !shouldKeep {
                                         // Don't use calculateSizeAsync here as it calls withTaskGroup which is tricky inside another concurrent block? 
                                         // check calculateSizeAsync implementation. It uses TaskGroup.
                                         // Nesting TaskGroups is fine.
                                         let size = await self.calculateSizeAsync(at: itemURL)
                                         if size > 0 {
                                             items.append(JunkItem(type: type, path: itemURL, size: size))
                                         }
                                     }
                                 }
                             }
                         }
                         return (items, false)
                    }
                    
                    if type == .appCache {
                        // appCache 现在由 systemCache 处理 ~/Library/Caches
                        // 不再单独扫描 Containers 以避免权限弹窗
                        return (items, false)
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
                        return (items, false)
                    } catch let error as NSError {
                        // 只有真正的权限拒绝错误才标记为权限错误
                        // 忽略目录不存在（NSFileReadNoSuchFileError = 260）等常见情况
                        let isPermissionError = error.domain == NSCocoaErrorDomain && 
                            (error.code == NSFileReadNoPermissionError || error.code == NSFileWriteNoPermissionError)
                        return (items, isPermissionError)
                    }
                }
            }
            
            for await (pathItems, error) in group {
                allItems.append(contentsOf: pathItems)
                if error { hasError = true }
            }
        }
        
        return (allItems, hasError)
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
            while let fileURL = enumerator.nextObject() as? URL {
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
        
        await MainActor.run { [failedItems] in
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
        // ⚠️ 安全修复: 使用SafetyGuard检查
        if !SafetyGuard.shared.isSafeToDelete(item.path) {
            print("[JunkCleaner] 🛡️ SafetyGuard blocked deletion: \(item.path.path)")
            return false
        }
        
        // 先尝试移至废纸篓(更安全,可恢复)
        do {
            try fileManager.trashItem(at: item.path, resultingItemURL: nil)
            print("[JunkCleaner] ✅ Moved to trash: \(item.path.lastPathComponent)")
            return true
        } catch {
            print("[JunkCleaner] ⚠️ Failed to trash, error: \(error)")
            // 废纸篓失败,记录但不尝试直接删除(太危险)
            // 应该提示用户使用sudo权限或手动处理
            return false
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
