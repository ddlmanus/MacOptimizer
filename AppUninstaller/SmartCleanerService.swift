import Foundation
import AppKit
import SwiftUI
import CryptoKit
import Vision

// MARK: - 清理类型
enum CleanerCategory: String, CaseIterable {
    // 系统垃圾类别（新增）
    case systemJunk = "系统垃圾"
    case systemCache = "系统缓存文件"
    case oldUpdates = "旧更新"
    case userCache = "用户缓存文件"
    case languageFiles = "语言文件"
    case systemLogs = "系统日志文件"
    case userLogs = "用户日志文件"
    case brokenLoginItems = "损坏的登录项"
    
    // 原有类别
    case duplicates = "重复文件"
    case similarPhotos = "相似照片"
    case localizations = "多语言文件"
    case largeFiles = "大文件"
    
    var icon: String {
        switch self {
        case .systemJunk: return "trash.fill"
        case .systemCache: return "internaldrive.fill"
        case .oldUpdates: return "arrow.down.circle.fill"
        case .userCache: return "person.crop.circle.fill"
        case .languageFiles: return "textformat.abc"
        case .systemLogs: return "doc.text.fill"
        case .userLogs: return "person.text.rectangle.fill"
        case .brokenLoginItems: return "exclamationmark.triangle.fill"
        case .duplicates: return "doc.on.doc"
        case .similarPhotos: return "photo.on.rectangle"
        case .localizations: return "globe"
        case .largeFiles: return "externaldrive.fill"
        }
    }
    
    var englishName: String {
        switch self {
        case .systemJunk: return "System Junk"
        case .systemCache: return "System Cache"
        case .oldUpdates: return "Old Updates"
        case .userCache: return "User Cache"
        case .languageFiles: return "Language Files"
        case .systemLogs: return "System Logs"
        case .userLogs: return "User Logs"
        case .brokenLoginItems: return "Broken Login Items"
        case .duplicates: return "Duplicates"
        case .similarPhotos: return "Similar Photos"
        case .localizations: return "Localizations"
        case .largeFiles: return "Large Files"
        }
    }
    
    var color: Color {
        switch self {
        case .systemJunk: return .pink
        case .systemCache: return .blue
        case .oldUpdates: return .orange
        case .userCache: return .cyan
        case .languageFiles: return .purple
        case .systemLogs: return .green
        case .userLogs: return .teal
        case .brokenLoginItems: return .red
        case .duplicates: return .blue
        case .similarPhotos: return .purple
        case .localizations: return .orange
        case .largeFiles: return .pink
        }
    }
    
    /// 是否是系统垃圾子类别
    var isSystemJunkSubcategory: Bool {
        switch self {
        case .systemCache, .oldUpdates, .userCache, .languageFiles, .systemLogs, .userLogs, .brokenLoginItems:
            return true
        default:
            return false
        }
    }
}

// MARK: - 文件项
struct CleanerFileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    var isSelected: Bool = true  // 默认全选
    let groupId: String  // 用于分组显示
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
    
    static func == (lhs: CleanerFileItem, rhs: CleanerFileItem) -> Bool {
        lhs.url == rhs.url
    }
}

// MARK: - 重复文件组
struct DuplicateGroup: Identifiable {
    let id = UUID()
    let hash: String
    var files: [CleanerFileItem]
    
    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }
    
    var wastedSize: Int64 {
        // 保留一个，其他都是浪费
        guard files.count > 1 else { return 0 }
        return files.dropFirst().reduce(0) { $0 + $1.size }
    }
}

// MARK: - 智能清理服务
class SmartCleanerService: ObservableObject {
    // 原有属性
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var similarPhotoGroups: [DuplicateGroup] = []
    @Published var localizationFiles: [CleanerFileItem] = []
    @Published var largeFiles: [CleanerFileItem] = []
    
    // 新增系统垃圾属性
    @Published var systemCacheFiles: [CleanerFileItem] = []
    @Published var oldUpdateFiles: [CleanerFileItem] = []
    @Published var userCacheFiles: [CleanerFileItem] = []
    @Published var languageFiles: [CleanerFileItem] = []
    @Published var systemLogFiles: [CleanerFileItem] = []
    @Published var userLogFiles: [CleanerFileItem] = []
    @Published var brokenLoginItems: [CleanerFileItem] = []
    
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var currentScanPath: String = ""
    @Published var currentCategory: CleanerCategory = .systemJunk
    
    // 停止扫描标志
    private var shouldStopScanning = false
    
    // 停止扫描方法
    @MainActor
    func stopScanning() {
        shouldStopScanning = true
        isScanning = false
        currentScanPath = ""
    }
    
    private let fileManager = FileManager.default
    
    // 保留的语言
    private let keepLocalizations = ["en.lproj", "Base.lproj", "zh-Hans.lproj", "zh-Hant.lproj", "zh_CN.lproj", "zh_TW.lproj", "Chinese.lproj", "English.lproj"]
    
    // 默认扫描目录
    private var scanDirectories: [URL] {
        let home = fileManager.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Pictures")
        ]
    }
    
    // MARK: - 系统垃圾总大小
    var systemJunkTotalSize: Int64 {
        systemCacheFiles.reduce(0) { $0 + $1.size } +
        oldUpdateFiles.reduce(0) { $0 + $1.size } +
        userCacheFiles.reduce(0) { $0 + $1.size } +
        languageFiles.reduce(0) { $0 + $1.size } +
        systemLogFiles.reduce(0) { $0 + $1.size } +
        userLogFiles.reduce(0) { $0 + $1.size } +
        brokenLoginItems.reduce(0) { $0 + $1.size }
    }
    
    // MARK: - 获取指定分类的大小
    func sizeFor(category: CleanerCategory) -> Int64 {
        switch category {
        case .systemJunk:
            return systemJunkTotalSize
        case .systemCache:
            return systemCacheFiles.reduce(0) { $0 + $1.size }
        case .oldUpdates:
            return oldUpdateFiles.reduce(0) { $0 + $1.size }
        case .userCache:
            return userCacheFiles.reduce(0) { $0 + $1.size }
        case .languageFiles:
            return languageFiles.reduce(0) { $0 + $1.size }
        case .systemLogs:
            return systemLogFiles.reduce(0) { $0 + $1.size }
        case .userLogs:
            return userLogFiles.reduce(0) { $0 + $1.size }
        case .brokenLoginItems:
            return brokenLoginItems.reduce(0) { $0 + $1.size }
        case .duplicates:
            return duplicateGroups.reduce(0) { $0 + $1.wastedSize }
        case .similarPhotos:
            return similarPhotoGroups.reduce(0) { $0 + $1.wastedSize }
        case .localizations:
            return localizationFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        case .largeFiles:
            return largeFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        }
    }
    
    // MARK: - 获取指定分类的项目数
    func countFor(category: CleanerCategory) -> Int {
        switch category {
        case .systemJunk:
            return systemCacheFiles.count + oldUpdateFiles.count + userCacheFiles.count +
                   languageFiles.count + systemLogFiles.count + userLogFiles.count + brokenLoginItems.count
        case .systemCache:
            return systemCacheFiles.count
        case .oldUpdates:
            return oldUpdateFiles.count
        case .userCache:
            return userCacheFiles.count
        case .languageFiles:
            return languageFiles.count
        case .systemLogs:
            return systemLogFiles.count
        case .userLogs:
            return userLogFiles.count
        case .brokenLoginItems:
            return brokenLoginItems.count
        case .duplicates:
            return duplicateGroups.flatMap { $0.files }.count
        case .similarPhotos:
            return similarPhotoGroups.flatMap { $0.files }.count
        case .localizations:
            return localizationFiles.count
        case .largeFiles:
            return largeFiles.count
        }
    }
    
    // MARK: - 扫描系统垃圾
    func scanSystemJunk() async {
        await MainActor.run {
            isScanning = true
            scanProgress = 0
            currentCategory = .systemJunk
            systemCacheFiles = []
            oldUpdateFiles = []
            userCacheFiles = []
            languageFiles = []
            systemLogFiles = []
            userLogFiles = []
            brokenLoginItems = []
        }
        
        let totalSteps = 7.0
        var currentStep = 0.0
        
        // 1. 扫描系统缓存
        await updateProgress(step: currentStep, total: totalSteps, message: "正在扫描系统缓存...")
        let sysCache = await scanSystemCache()
        await MainActor.run { systemCacheFiles = sysCache }
        currentStep += 1
        
        // 2. 扫描旧更新 (Skipped due to SIP protection issues)
        // await updateProgress(step: currentStep, total: totalSteps, message: "正在扫描旧更新...")
        // let oldUpd = await scanOldUpdates()
        // await MainActor.run { oldUpdateFiles = oldUpd }
        // currentStep += 1
        
        // 3. 扫描用户缓存
        await updateProgress(step: currentStep, total: totalSteps, message: "正在扫描用户缓存...")
        let usrCache = await scanUserCache()
        await MainActor.run { userCacheFiles = usrCache }
        currentStep += 1
        
        // 4. 扫描语言文件
        await updateProgress(step: currentStep, total: totalSteps, message: "正在扫描语言文件...")
        let langFiles = await scanLanguageFiles()
        await MainActor.run { languageFiles = langFiles }
        currentStep += 1
        
        // 5. 扫描系统日志
        await updateProgress(step: currentStep, total: totalSteps, message: "正在扫描系统日志...")
        let sysLogs = await scanSystemLogs()
        await MainActor.run { systemLogFiles = sysLogs }
        currentStep += 1
        
        // 6. 扫描用户日志
        await updateProgress(step: currentStep, total: totalSteps, message: "正在扫描用户日志...")
        let usrLogs = await scanUserLogs()
        await MainActor.run { userLogFiles = usrLogs }
        currentStep += 1
        
        // 7. 扫描损坏的登录项
        await updateProgress(step: currentStep, total: totalSteps, message: "正在扫描损坏的登录项...")
        let brokenItems = await scanBrokenLoginItems()
        await MainActor.run { brokenLoginItems = brokenItems }
        
        await MainActor.run {
            isScanning = false
            scanProgress = 1.0
            currentScanPath = ""
        }
    }
    
    private func updateProgress(step: Double, total: Double, message: String) async {
        await MainActor.run {
            scanProgress = step / total
            currentScanPath = message
        }
    }
    
    // MARK: - 系统缓存扫描 (全面扫描系统级缓存)
    private func scanSystemCache() async -> [CleanerFileItem] {
        var items: [CleanerFileItem] = []
        let home = fileManager.homeDirectoryForCurrentUser
        
        // 1. 扫描系统级 /Library/Caches（需要权限）
        let systemCachePaths = [
            "/Library/Caches",
            "/private/var/folders"  // 系统临时文件夹
        ]
        
        for systemPath in systemCachePaths {
            let url = URL(fileURLWithPath: systemPath)
            if fileManager.isReadableFile(atPath: url.path) {
                if let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                    for itemURL in contents {
                        let size = calculateSize(at: itemURL)
                        if size > 100 * 1024 { // > 100KB
                            items.append(CleanerFileItem(
                                url: itemURL,
                                name: "系统: " + itemURL.lastPathComponent,
                                size: size,
                                groupId: "systemCache"
                            ))
                        }
                    }
                }
            }
        }
        
        // 2. 扫描开发者缓存（通常非常大）
        let developerCaches = [
            home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            home.appendingPathComponent("Library/Developer/Xcode/Archives"),
            home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"),
            home.appendingPathComponent("Library/Developer/Xcode/watchOS DeviceSupport"),
            home.appendingPathComponent("Library/Developer/Xcode/tvOS DeviceSupport"),
            home.appendingPathComponent("Library/Developer/CoreSimulator/Caches"),
            home.appendingPathComponent("Library/Developer/CoreSimulator/Devices"),
            home.appendingPathComponent("Library/Caches/com.apple.dt.Xcode"),
            // CocoaPods
            home.appendingPathComponent("Library/Caches/CocoaPods"),
            // npm/yarn/pnpm
            home.appendingPathComponent(".npm/_cacache"),
            home.appendingPathComponent("Library/Caches/Yarn"),
            home.appendingPathComponent("Library/pnpm"),
            // Gradle/Maven
            home.appendingPathComponent(".gradle/caches"),
            home.appendingPathComponent(".m2/repository"),
            // Homebrew
            home.appendingPathComponent("Library/Caches/Homebrew"),
            // pip
            home.appendingPathComponent("Library/Caches/pip"),
            // Go
            home.appendingPathComponent("go/pkg/mod/cache")
        ]
        
        for devCacheURL in developerCaches {
            if fileManager.fileExists(atPath: devCacheURL.path) {
                let size = calculateSize(at: devCacheURL)
                if size > 100 * 1024 {
                    items.append(CleanerFileItem(
                        url: devCacheURL,
                        name: "开发: " + devCacheURL.lastPathComponent,
                        size: size,
                        groupId: "systemCache"
                    ))
                }
            }
        }
        
        // 3. 扫描 Apple 系统服务缓存
        let appleCaches = [
            "com.apple.Safari",
            "com.apple.finder",
            "com.apple.QuickLook.thumbnailcache",
            "com.apple.DiskImages",
            "com.apple.helpd",
            "com.apple.parsecd",
            "com.apple.nsservicescache", 
            "com.apple.nsurlsessiond",
            "com.apple.LaunchServices",
            "com.apple.spotlightknowledge",
            "com.apple.ap.adprivacyd",
            "com.apple.iCloudHelper",
            "com.apple.appstore",
            "com.apple.Music",
            "com.apple.Photos",
            "com.apple.preferencepanes.usercache",
            "com.apple.proactive.eventtracker",
            "CloudKit",
            "GeoServices",
            "FamilyCircle"
        ]
        
        let cacheBaseURL = home.appendingPathComponent("Library/Caches")
        for cacheName in appleCaches {
            let cacheURL = cacheBaseURL.appendingPathComponent(cacheName)
            if fileManager.fileExists(atPath: cacheURL.path) {
                let size = calculateSize(at: cacheURL)
                if size > 50 * 1024 { // 更低阈值
                    let displayName = cacheName
                        .replacingOccurrences(of: "com.apple.", with: "Apple ")
                    items.append(CleanerFileItem(
                        url: cacheURL,
                        name: displayName,
                        size: size,
                        groupId: "systemCache"
                    ))
                }
            }
        }
        
        // 4. 扫描浏览器数据 (仅安全的缓存目录)
        // 注意: 已移除 IndexedDB, LocalStorage, Databases - 这些包含用户登录信息
        let browserDataPaths = [
            // Chrome - 仅 Service Worker 和 ShaderCache (安全)
            home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Service Worker"),
            home.appendingPathComponent("Library/Application Support/Google/Chrome/ShaderCache"),
            // Edge - 仅 Service Worker (安全)
            home.appendingPathComponent("Library/Application Support/Microsoft Edge/Default/Service Worker")
            // Safari - 已移除 Databases 和 LocalStorage (包含登录信息)
        ]
        
        for browserPath in browserDataPaths {
            if fileManager.fileExists(atPath: browserPath.path) {
                let size = calculateSize(at: browserPath)
                if size > 100 * 1024 {
                    let parentName = browserPath.deletingLastPathComponent().lastPathComponent
                    items.append(CleanerFileItem(
                        url: browserPath,
                        name: "\(parentName) \(browserPath.lastPathComponent)",
                        size: size,
                        groupId: "systemCache"
                    ))
                }
            }
        }
        
        // 5. 扫描 Group Containers 缓存
        let groupContainersURL = home.appendingPathComponent("Library/Group Containers")
        if let groups = try? fileManager.contentsOfDirectory(at: groupContainersURL, includingPropertiesForKeys: nil) {
            for groupURL in groups {
                // 查找缓存目录
                for subdir in ["Library/Caches", "Caches", "Cache"] {
                    let cacheDir = groupURL.appendingPathComponent(subdir)
                    if fileManager.fileExists(atPath: cacheDir.path) {
                        let size = calculateSize(at: cacheDir)
                        if size > 100 * 1024 {
                            items.append(CleanerFileItem(
                                url: cacheDir,
                                name: "Group: " + groupURL.lastPathComponent,
                                size: size,
                                groupId: "systemCache"
                            ))
                        }
                    }
                }
            }
        }
        
        return items.sorted { $0.size > $1.size }
    }
    
    // MARK: - 旧更新扫描
    private func scanOldUpdates() async -> [CleanerFileItem] {
        var items: [CleanerFileItem] = []
        let paths = [
            "/Library/Updates",
            "~/Library/Caches/com.apple.SoftwareUpdate"
        ]
        
        for pathStr in paths {
            let expandedPath = NSString(string: pathStr).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            
            if let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                for itemURL in contents {
                    let size = calculateSize(at: itemURL)
                    if size > 0 {
                        items.append(CleanerFileItem(
                            url: itemURL,
                            name: itemURL.lastPathComponent,
                            size: size,
                            groupId: "oldUpdates"
                        ))
                    }
                }
            }
        }
        
        // 检查下载的 DMG/PKG 安装包
        let downloadsURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        if let contents = try? fileManager.contentsOfDirectory(at: downloadsURL, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) {
            for itemURL in contents {
                let ext = itemURL.pathExtension.lowercased()
                if ["dmg", "pkg", "app"].contains(ext) {
                    let size = calculateSize(at: itemURL)
                    if size > 0 {
                        items.append(CleanerFileItem(
                            url: itemURL,
                            name: itemURL.lastPathComponent,
                            size: size,
                            groupId: "oldUpdates"
                        ))
                    }
                }
            }
        }
        
        return items.sorted { $0.size > $1.size }
    }
    
    // MARK: - 用户缓存扫描 (全面扫描整个用户缓存目录 + 已安装应用缓存 + 卸载残留)
    private func scanUserCache() async -> [CleanerFileItem] {
        var items: [CleanerFileItem] = []
        let home = fileManager.homeDirectoryForCurrentUser
        
        // 获取所有已安装应用的 Bundle ID
        let installedAppBundleIds = getInstalledAppBundleIds()
        
        // 1. 扫描整个 ~/Library/Caches 目录（所有子目录）
        let cacheURL = home.appendingPathComponent("Library/Caches")
        if let contents = try? fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil) {
            for itemURL in contents {
                let size = calculateSize(at: itemURL)
                if size > 50 * 1024 { // > 50KB (更低阈值)
                    let bundleId = itemURL.lastPathComponent
                    let isOrphan = isOrphanedFile(bundleId: bundleId, installedIds: installedAppBundleIds)
                    let displayName = formatAppName(bundleId)
                    
                    items.append(CleanerFileItem(
                        url: itemURL,
                        name: isOrphan ? "⚠️ \(displayName) (已卸载)" : displayName,
                        size: size,
                        groupId: "userCache"
                    ))
                }
            }
        }
        
        // 2. 扫描 ~/Library/Containers 中的缓存
        let containersURL = home.appendingPathComponent("Library/Containers")
        if let containers = try? fileManager.contentsOfDirectory(at: containersURL, includingPropertiesForKeys: nil) {
            for containerURL in containers {
                let bundleId = containerURL.lastPathComponent
                let isOrphan = isOrphanedFile(bundleId: bundleId, installedIds: installedAppBundleIds)
                
                // 扫描容器的 Data/Library/Caches
                let containerCacheURL = containerURL.appendingPathComponent("Data/Library/Caches")
                if fileManager.fileExists(atPath: containerCacheURL.path) {
                    let size = calculateSize(at: containerCacheURL)
                    if size > 50 * 1024 {
                        let appName = formatAppName(bundleId)
                        items.append(CleanerFileItem(
                            url: containerCacheURL,
                            name: isOrphan ? "⚠️ \(appName) 容器缓存 (已卸载)" : "\(appName) 容器缓存",
                            size: size,
                            groupId: "userCache"
                        ))
                    }
                }
                
                // 扫描容器的临时文件
                let containerTmpURL = containerURL.appendingPathComponent("Data/tmp")
                if fileManager.fileExists(atPath: containerTmpURL.path) {
                    let size = calculateSize(at: containerTmpURL)
                    if size > 50 * 1024 {
                        items.append(CleanerFileItem(
                            url: containerTmpURL,
                            name: "\(formatAppName(bundleId)) 临时文件",
                            size: size,
                            groupId: "userCache"
                        ))
                    }
                }
                
                // ⚠️ 已禁用整体容器删除 - 误判风险过高，可能导致正常应用数据丢失
                // 只删除容器中的缓存和临时文件子目录
            }
        }
        
        // 3. 扫描 ~/Library/Saved Application State
        // 排除正在运行的应用，避免删除导致应用崩溃
        let runningAppIds = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier?.lowercased() })
        let savedStateURL = home.appendingPathComponent("Library/Saved Application State")
        if let contents = try? fileManager.contentsOfDirectory(at: savedStateURL, includingPropertiesForKeys: nil) {
            for itemURL in contents {
                let bundleId = itemURL.lastPathComponent.replacingOccurrences(of: ".savedState", with: "")
                
                // 跳过正在运行的应用，删除其状态文件可能导致崩溃
                if runningAppIds.contains(bundleId.lowercased()) { continue }
                
                let size = calculateSize(at: itemURL)
                if size > 5 * 1024 { // 更低阈值
                    let isOrphan = isOrphanedFile(bundleId: bundleId, installedIds: installedAppBundleIds)
                    items.append(CleanerFileItem(
                        url: itemURL,
                        name: isOrphan ? "⚠️ \(formatAppName(bundleId)) 状态 (已卸载)" : "\(formatAppName(bundleId)) 状态",
                        size: size,
                        groupId: "userCache"
                    ))
                }
            }
        }
        
        // 4. 扫描 ~/Library/Application Support 中的缓存目录
        let appSupportURL = home.appendingPathComponent("Library/Application Support")
        if let apps = try? fileManager.contentsOfDirectory(at: appSupportURL, includingPropertiesForKeys: nil) {
            for appURL in apps {
                let appName = appURL.lastPathComponent
                let isOrphan = isOrphanedAppSupport(dirName: appName, installedIds: installedAppBundleIds)
                
                // 查找各种缓存目录 (仅安全的缓存，已移除包含登录信息的目录)
                // 注意: 已移除 CacheStorage, Session Storage, Local Storage, IndexedDB, blob_storage - 这些可能包含登录信息
                for cacheDirName in ["Cache", "Caches", "cache", "GPUCache", "Code Cache", "ShaderCache"] {
                    let cacheDir = appURL.appendingPathComponent(cacheDirName)
                    if fileManager.fileExists(atPath: cacheDir.path) {
                        let size = calculateSize(at: cacheDir)
                        if size > 50 * 1024 {
                            items.append(CleanerFileItem(
                                url: cacheDir,
                                name: isOrphan ? "⚠️ \(appName) \(cacheDirName) (已卸载)" : "\(appName) \(cacheDirName)",
                                size: size,
                                groupId: "userCache"
                            ))
                        }
                    }
                }
                
                // ⚠️ 已禁用整体 Application Support 目录删除 - 误判风险过高
                // isOrphanedAppSupport 检测逻辑可能误判，删除正在使用的应用数据会导致应用无法启动
                // 只删除其中的缓存子目录
            }
        }
        
        // 5. 扫描 ~/Library/Preferences (已卸载应用的 plist)
        let prefsURL = home.appendingPathComponent("Library/Preferences")
        if let prefs = try? fileManager.contentsOfDirectory(at: prefsURL, includingPropertiesForKeys: nil) {
            for prefURL in prefs {
                if prefURL.pathExtension == "plist" {
                    let bundleId = prefURL.deletingPathExtension().lastPathComponent
                    if isOrphanedFile(bundleId: bundleId, installedIds: installedAppBundleIds) {
                        if let attrs = try? fileManager.attributesOfItem(atPath: prefURL.path),
                           let size = attrs[.size] as? Int64, size > 1024 {
                            items.append(CleanerFileItem(
                                url: prefURL,
                                name: "⚠️ \(formatAppName(bundleId)) 偏好设置 (已卸载)",
                                size: size,
                                groupId: "userCache"
                            ))
                        }
                    }
                }
            }
        }
        
        // 6. 已移除 ~/Library/Cookies 扫描 - 删除会导致所有网站登录状态丢失
        // 如需清理 Cookies，请使用隐私清理模块并明确确认
        
        // 7. 扫描 ~/Library/WebKit
        let webkitURL = home.appendingPathComponent("Library/WebKit")
        if fileManager.fileExists(atPath: webkitURL.path) {
            let size = calculateSize(at: webkitURL)
            if size > 50 * 1024 {
                items.append(CleanerFileItem(
                    url: webkitURL,
                    name: "WebKit 缓存",
                    size: size,
                    groupId: "userCache"
                ))
            }
        }
        
        // 8. 扫描 ~/Library/HTTPStorages
        let httpStorageURL = home.appendingPathComponent("Library/HTTPStorages")
        if fileManager.fileExists(atPath: httpStorageURL.path) {
            let size = calculateSize(at: httpStorageURL)
            if size > 5 * 1024 {
                items.append(CleanerFileItem(
                    url: httpStorageURL,
                    name: "HTTP 存储",
                    size: size,
                    groupId: "userCache"
                ))
            }
        }
        
        // 9. 扫描 ~/Library/Logs 作为用户缓存的一部分
        let logsURL = home.appendingPathComponent("Library/Logs")
        if let logs = try? fileManager.contentsOfDirectory(at: logsURL, includingPropertiesForKeys: nil) {
            for logURL in logs {
                let size = calculateSize(at: logURL)
                if size > 50 * 1024 {
                    items.append(CleanerFileItem(
                        url: logURL,
                        name: "\(logURL.lastPathComponent) 日志",
                        size: size,
                        groupId: "userCache"
                    ))
                }
            }
        }
        
        // 10. 扫描 ~/.Trash (废纸篓)
        let trashURL = home.appendingPathComponent(".Trash")
        if fileManager.fileExists(atPath: trashURL.path) {
            let size = calculateSize(at: trashURL)
            if size > 100 * 1024 {
                items.append(CleanerFileItem(
                    url: trashURL,
                    name: "🗑️ 废纸篓",
                    size: size,
                    groupId: "userCache"
                ))
            }
        }
        
        return items.sorted { $0.size > $1.size }
    }
    
    // MARK: - 辅助方法：获取已安装应用信息（改进版）
    /// 返回 (bundleIds, appNames) 元组，用于更精确的匹配
    private func getInstalledAppInfo() -> (bundleIds: Set<String>, appNames: Set<String>) {
        var bundleIds = Set<String>()
        var appNames = Set<String>()
        
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
                    
                    // 添加应用名称（去掉 .app 后缀）
                    let appName = (app as NSString).deletingPathExtension
                    appNames.insert(appName.lowercased())
                    
                    // 读取 Bundle ID
                    if let plist = NSDictionary(contentsOfFile: plistPath),
                       let bundleId = plist["CFBundleIdentifier"] as? String {
                        bundleIds.insert(bundleId)
                        bundleIds.insert(bundleId.lowercased())
                        
                        // 提取 Bundle ID 的最后一个组件作为备用匹配
                        if let lastComponent = bundleId.components(separatedBy: ".").last {
                            appNames.insert(lastComponent.lowercased())
                        }
                    }
                }
            }
        }
        
        // 2. 扫描 Homebrew Cask 安装的应用
        let homebrewPaths = [
            "/opt/homebrew/Caskroom",
            "/usr/local/Caskroom"
        ]
        
        for caskPath in homebrewPaths {
            if let casks = try? fileManager.contentsOfDirectory(atPath: caskPath) {
                for cask in casks {
                    appNames.insert(cask.lowercased())
                }
            }
        }
        
        // 3. 添加正在运行的应用（最重要的安全检查）
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if let bundleId = app.bundleIdentifier {
                bundleIds.insert(bundleId)
                bundleIds.insert(bundleId.lowercased())
            }
            if let name = app.localizedName {
                appNames.insert(name.lowercased())
            }
        }
        
        // 4. 添加系统关键服务的白名单
        let systemSafelist = [
            // Apple 服务
            "com.apple", "apple", "icloud", "cloudkit", "safari", "mail", "messages",
            "photos", "music", "podcasts", "news", "tv", "books", "maps", "notes",
            "reminders", "calendar", "contacts", "facetime", "preview", "quicktime",
            // 系统组件
            "finder", "dock", "spotlight", "siri", "systemuiserver", "loginwindow",
            "windowserver", "coreaudio", "coremedia", "coreservices",
            // 常见第三方应用组件
            "google", "chrome", "microsoft", "edge", "firefox", "mozilla",
            "adobe", "dropbox", "slack", "discord", "zoom", "telegram", "whatsapp",
            "wechat", "qq", "tencent", "alibaba", "jetbrains", "vscode", "visual studio"
        ]
        
        for safe in systemSafelist {
            appNames.insert(safe)
        }
        
        return (bundleIds, appNames)
    }
    
    // 保留旧方法以兼容现有调用
    private func getInstalledAppBundleIds() -> Set<String> {
        return getInstalledAppInfo().bundleIds
    }
    
    // MARK: - 辅助方法：检测是否为已卸载应用的残留（改进版）
    private func isOrphanedFile(bundleId: String, installedIds: Set<String>) -> Bool {
        let lowerBundleId = bundleId.lowercased()
        
        // 1. 跳过所有 Apple 系统服务
        if lowerBundleId.hasPrefix("com.apple.") { return false }
        if lowerBundleId.hasPrefix("apple") { return false }
        
        // 2. 扩展的系统/非应用目录白名单
        let systemDirs = [
            "cloudkit", "geoservices", "familycircle", "knowledge", "metadata",
            "tmp", "t", "caches", "cache", "logs", "preferences", "temp",
            "cookies", "webkit", "httpstorages", "containers", "group containers",
            "databases", "keychains", "accounts", "mail", "calendars", "contacts"
        ]
        if systemDirs.contains(lowerBundleId) { return false }
        
        // 3. 获取完整的应用信息
        let appInfo = getInstalledAppInfo()
        
        // 4. 检查 Bundle ID 是否匹配已安装应用
        if appInfo.bundleIds.contains(bundleId) || appInfo.bundleIds.contains(lowerBundleId) {
            return false
        }
        
        // 5. 检查应用名称是否匹配（模糊匹配）
        for appName in appInfo.appNames {
            if lowerBundleId.contains(appName) || appName.contains(lowerBundleId) {
                return false
            }
        }
        
        // 6. 检查 Bundle ID 各组件是否匹配应用名称
        let components = bundleId.components(separatedBy: ".")
        for component in components where component.count > 3 {
            if appInfo.appNames.contains(component.lowercased()) {
                return false
            }
        }
        
        // 所有检查都通过，才认为是孤立文件
        return true
    }
    
    private func isOrphanedAppSupport(dirName: String, installedIds: Set<String>) -> Bool {
        let lowerDirName = dirName.lowercased()
        
        // 1. 扩展的系统目录白名单（更全面）
        let systemSafelist = [
            // Apple 系统服务
            "apple", "crashreporter", "addressbook", "callhistorydb", "dock", "icloud",
            "knowledge", "mobilesync", "systemuiserver", "finder", "spotlight",
            "assistant", "siri", "icdd", "accounts", "bluetooth", "audio",
            // 系统框架和服务
            "coreservices", "coremedia", "coreaudio", "webkit", "cfnetwork",
            "networkservices", "securityagent", "syncservices", "ubiquity",
            // 常见应用名称变体
            "google", "chrome", "microsoft", "firefox", "mozilla", "safari",
            "adobe", "dropbox", "slack", "discord", "zoom", "telegram", "whatsapp",
            "wechat", "qq", "tencent", "alibaba", "jetbrains", "visual studio",
            // 开发工具
            "xcode", "simulator", "instruments", "compilers", "llvm", "clang",
            "homebrew", "brew", "npm", "yarn", "node", "python", "ruby", "java",
            // 媒体和音频
            "avid", "ableton", "logic", "garageband", "final cut", "motion",
            // 安全和系统工具
            "1password", "lastpass", "keychain", "security", "firewall",
            // 特殊处理
            "antigravity", "macoptimizer"
        ]
        
        for safe in systemSafelist {
            if lowerDirName.localizedCaseInsensitiveContains(safe) {
                return false
            }
        }
        
        // 2. 获取完整应用信息
        let appInfo = getInstalledAppInfo()
        
        // 3. 检查目录名是否与已安装应用匹配
        // 检查 Bundle ID
        for bundleId in appInfo.bundleIds {
            let lowerBundleId = bundleId.lowercased()
            
            // 完整匹配
            if lowerDirName == lowerBundleId {
                return false
            }
            
            // Bundle ID 包含目录名（例如 com.google.Chrome 包含 google）
            if lowerBundleId.contains(lowerDirName) && lowerDirName.count > 3 {
                return false
            }
            
            // 目录名包含 Bundle ID 组件
            let components = bundleId.components(separatedBy: ".")
            for component in components where component.count > 3 {
                if lowerDirName.contains(component.lowercased()) {
                    return false
                }
            }
        }
        
        // 4. 检查应用名称
        for appName in appInfo.appNames {
            // 双向模糊匹配
            if lowerDirName.contains(appName) || appName.contains(lowerDirName) {
                return false
            }
            
            // 处理空格分隔的应用名（例如 "Visual Studio Code"）
            let dirWords = lowerDirName.components(separatedBy: CharacterSet.alphanumerics.inverted)
            let appWords = appName.components(separatedBy: CharacterSet.alphanumerics.inverted)
            
            // 如果有多个共同词汇，认为匹配
            let commonWords = Set(dirWords).intersection(Set(appWords)).filter { $0.count > 2 }
            if commonWords.count >= 2 {
                return false
            }
        }
        
        // 5. 额外安全检查：如果目录看起来是某种框架或插件，不要删除
        let frameworkPatterns = ["framework", "plugin", "extension", "helper", "service", "daemon", "agent", "bundle"]
        for pattern in frameworkPatterns {
            if lowerDirName.contains(pattern) {
                return false
            }
        }
        
        // 所有检查都通过，才认为是孤立目录
        return true
    }
    
    private func formatAppName(_ bundleId: String) -> String {
        return bundleId
            .replacingOccurrences(of: "com.apple.", with: "Apple ")
            .replacingOccurrences(of: "com.tencent.", with: "腾讯 ")
            .replacingOccurrences(of: "com.google.", with: "Google ")
            .replacingOccurrences(of: "com.microsoft.", with: "Microsoft ")
            .replacingOccurrences(of: "com.", with: "")
            .replacingOccurrences(of: "io.", with: "")
            .replacingOccurrences(of: "org.", with: "")
    }
    
    // MARK: - 语言文件扫描
    private func scanLanguageFiles() async -> [CleanerFileItem] {
        // ⚠️ 已禁用语言文件扫描
        // 删除 /Applications/*.app/Contents/Resources/*.lproj 会破坏 App Store 应用的代码签名
        // 导致 macOS Gatekeeper 阻止应用运行，需要重新从 App Store 下载才能修复
        // 
        // 如需清理语言文件，用户应使用专门的工具（如 Monolingual）并了解风险
        return []
    }
    
    // MARK: - 系统日志扫描
    private func scanSystemLogs() async -> [CleanerFileItem] {
        var items: [CleanerFileItem] = []
        let paths = [
            "/Library/Logs",
            "/private/var/log"
        ]
        
        for pathStr in paths {
            let url = URL(fileURLWithPath: pathStr)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            
            if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    let ext = fileURL.pathExtension.lowercased()
                    if ["log", "txt", "crash", "diag"].contains(ext) || fileURL.lastPathComponent.contains("log") {
                        if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                           let size = values.fileSize, size > 0 {
                            items.append(CleanerFileItem(
                                url: fileURL,
                                name: fileURL.lastPathComponent,
                                size: Int64(size),
                                groupId: "systemLogs"
                            ))
                        }
                    }
                }
            }
        }
        
        return items.sorted { $0.size > $1.size }
    }
    
    // MARK: - 用户日志扫描
    private func scanUserLogs() async -> [CleanerFileItem] {
        var items: [CleanerFileItem] = []
        let logsURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")
        
        guard let enumerator = fileManager.enumerator(at: logsURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return items
        }
        
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
               let isDir = values.isDirectory, !isDir,
               let size = values.fileSize, size > 0 {
                items.append(CleanerFileItem(
                    url: fileURL,
                    name: fileURL.lastPathComponent,
                    size: Int64(size),
                    groupId: "userLogs"
                ))
            }
        }
        
        return items.sorted { $0.size > $1.size }
    }
    
    // MARK: - 损坏的登录项扫描
    private func scanBrokenLoginItems() async -> [CleanerFileItem] {
        var items: [CleanerFileItem] = []
        
        // 检查 LaunchAgents
        let launchAgentPaths = [
            "~/Library/LaunchAgents",
            "/Library/LaunchAgents"
        ]
        
        for pathStr in launchAgentPaths {
            let expandedPath = NSString(string: pathStr).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            
            if let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                for plistURL in contents where plistURL.pathExtension == "plist" {
                    // 检查 plist 是否指向不存在的程序
                    if let plistData = try? Data(contentsOf: plistURL),
                       let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
                       let program = plist["Program"] as? String ?? (plist["ProgramArguments"] as? [String])?.first {
                        
                        if !fileManager.fileExists(atPath: program) {
                            let size = (try? fileManager.attributesOfItem(atPath: plistURL.path)[.size] as? UInt64) ?? 0
                            items.append(CleanerFileItem(
                                url: plistURL,
                                name: plistURL.lastPathComponent,
                                size: Int64(size),
                                groupId: "brokenLoginItems"
                            ))
                        }
                    }
                }
            }
        }
        
        return items
    }
    
    // MARK: - 扫描重复文件 - 多线程优化版
    func scanDuplicates() async {
        await MainActor.run {
            isScanning = true
            scanProgress = 0
            duplicateGroups = []
            currentCategory = .duplicates
        }
        
        // 1. 并行扫描所有目录，按文件大小分组
        var sizeGroups: [Int64: [URL]] = [:]
        let sizeGroupsCollector = ScanResultCollector<(Int64, URL)>()
        
        await withTaskGroup(of: [(Int64, URL)].self) { group in
            for dir in scanDirectories {
                group.addTask {
                    await self.collectFilesBySize(in: dir)
                }
            }
            
            for await results in group {
                await sizeGroupsCollector.appendContents(of: results)
            }
        }
        
        // 构建大小分组
        let allSizeResults = await sizeGroupsCollector.getResults()
        for (size, url) in allSizeResults {
            if sizeGroups[size] == nil {
                sizeGroups[size] = []
            }
            sizeGroups[size]?.append(url)
        }
        
        let totalFiles = allSizeResults.count
        
        // 2. 筛选出同大小的文件组（潜在重复）
        let potentialDuplicates = sizeGroups.filter { $0.value.count > 1 }
        let filesToHash = potentialDuplicates.flatMap { $0.value }
        
        await MainActor.run {
            scanProgress = 0.3 // 完成扫描阶段
            currentScanPath = "正在计算文件哈希..."
        }
        
        // 3. 并行计算 MD5 哈希
        var hashGroups: [String: [CleanerFileItem]] = [:]
        let hashResultsCollector = ScanResultCollector<(String, CleanerFileItem)>()
        
        let chunkSize = max(10, filesToHash.count / 8) // 分成最多 8 个任务
        let chunks = stride(from: 0, to: filesToHash.count, by: chunkSize).map {
            Array(filesToHash[$0..<min($0 + chunkSize, filesToHash.count)])
        }
        
        let progressTracker = ScanProgressTracker()
        await progressTracker.setTotalTasks(chunks.count)
        
        await withTaskGroup(of: [(String, CleanerFileItem)].self) { group in
            for chunk in chunks {
                group.addTask {
                    var results: [(String, CleanerFileItem)] = []
                    
                    for url in chunk {
                        if let hash = self.md5Hash(of: url),
                           let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                            let item = CleanerFileItem(
                                url: url,
                                name: url.lastPathComponent,
                                size: Int64(size),
                                groupId: hash
                            )
                            results.append((hash, item))
                        }
                    }
                    
                    return results
                }
            }
            
            // 收集哈希结果
            for await chunkResults in group {
                await hashResultsCollector.appendContents(of: chunkResults)
                await progressTracker.completeTask()
                
                let progress = await progressTracker.getProgress()
                await MainActor.run {
                    self.scanProgress = 0.3 + progress * 0.7 // 哈希占 70% 进度
                }
            }
        }
        
        // 构建哈希分组
        let allHashResults = await hashResultsCollector.getResults()
        for (hash, item) in allHashResults {
            if hashGroups[hash] == nil {
                hashGroups[hash] = []
            }
            hashGroups[hash]?.append(item)
        }
        
        // 4. 筛选真正的重复组
        let groups = hashGroups.compactMap { (hash, files) -> DuplicateGroup? in
            guard files.count > 1 else { return nil }
            return DuplicateGroup(hash: hash, files: files)
        }.sorted { $0.wastedSize > $1.wastedSize }
        
        await MainActor.run {
            duplicateGroups = groups
            isScanning = false
            scanProgress = 1.0
            currentScanPath = ""
        }
    }
    
    /// 并行收集目录中的文件及其大小
    private func collectFilesBySize(in directory: URL) async -> [(Int64, URL)] {
        var results: [(Int64, URL)] = []
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return results }
        
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  let isDir = values.isDirectory, !isDir,
                  let size = values.fileSize, size > 1024 else { continue }
            
            results.append((Int64(size), fileURL))
        }
        
        return results
    }
    
    // MARK: - 扫描相似照片
    func scanSimilarPhotos() async {
        await MainActor.run {
            isScanning = true
            scanProgress = 0
            similarPhotoGroups = []
            currentCategory = .similarPhotos
        }
        
        let picturesDir = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Pictures")
        var photos: [(url: URL, fingerprint: VNFeaturePrintObservation)] = []
        var processedCount = 0
        var totalCount = 0
        
        // 收集所有图片
        if let enumerator = fileManager.enumerator(at: picturesDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                if ["jpg", "jpeg", "png", "heic", "heif", "tiff"].contains(ext) {
                    totalCount += 1
                }
            }
        }
        
        // 计算图片特征
        if let enumerator = fileManager.enumerator(at: picturesDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                guard ["jpg", "jpeg", "png", "heic", "heif", "tiff"].contains(ext) else { continue }
                
                processedCount += 1
                await MainActor.run {
                    scanProgress = Double(processedCount) / Double(max(totalCount, 1))
                    currentScanPath = fileURL.lastPathComponent
                }
                
                if let fingerprint = await extractImageFingerprint(from: fileURL) {
                    photos.append((url: fileURL, fingerprint: fingerprint))
                }
            }
        }
        
        // 比较相似度
        var similarGroups: [String: [CleanerFileItem]] = [:]
        var matched: Set<URL> = []
        
        for i in 0..<photos.count {
            guard !matched.contains(photos[i].url) else { continue }
            
            var groupFiles: [CleanerFileItem] = []
            let size1 = (try? photos[i].url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            groupFiles.append(CleanerFileItem(
                url: photos[i].url,
                name: photos[i].url.lastPathComponent,
                size: Int64(size1),
                groupId: photos[i].url.path
            ))
            
            for j in (i+1)..<photos.count {
                guard !matched.contains(photos[j].url) else { continue }
                
                var distance: Float = 0
                try? photos[i].fingerprint.computeDistance(&distance, to: photos[j].fingerprint)
                
                // 距离越小越相似，阈值 0.5 表示约 50% 相似
                if distance < 0.4 {
                    matched.insert(photos[j].url)
                    let size2 = (try? photos[j].url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    groupFiles.append(CleanerFileItem(
                        url: photos[j].url,
                        name: photos[j].url.lastPathComponent,
                        size: Int64(size2),
                        groupId: photos[i].url.path
                    ))
                }
            }
            
            if groupFiles.count > 1 {
                matched.insert(photos[i].url)
                similarGroups[photos[i].url.path] = groupFiles
            }
        }
        
        let groups = similarGroups.map { (key, files) in
            DuplicateGroup(hash: key, files: files)
        }.sorted { $0.totalSize > $1.totalSize }
        
        await MainActor.run {
            similarPhotoGroups = groups
            isScanning = false
            scanProgress = 1.0
            currentScanPath = ""
        }
    }
    
    // MARK: - 扫描多语言文件 - 多线程优化版
    func scanLocalizations() async {
        await MainActor.run {
            isScanning = true
            scanProgress = 0
            localizationFiles = []
            currentCategory = .localizations
        }
        
        let applicationsDir = URL(fileURLWithPath: "/Applications")
        let userAppsDir = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        
        // 收集所有应用
        var allApps: [URL] = []
        for dir in [applicationsDir, userAppsDir] {
            if let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                allApps.append(contentsOf: contents.filter { $0.pathExtension == "app" })
            }
        }
        
        let totalApps = allApps.count
        let progressTracker = ScanProgressTracker()
        await progressTracker.setTotalTasks(totalApps)
        
        // 并行扫描所有应用
        let collector = ScanResultCollector<CleanerFileItem>()
        
        await withTaskGroup(of: [CleanerFileItem].self) { group in
            for app in allApps {
                group.addTask {
                    await self.scanAppLocalizations(app)
                }
            }
            
            for await appItems in group {
                await collector.appendContents(of: appItems)
                await progressTracker.completeTask()
                
                let progress = await progressTracker.getProgress()
                await MainActor.run {
                    self.scanProgress = progress
                }
            }
        }
        
        let items = await collector.getResults()
        
        await MainActor.run {
            localizationFiles = items.sorted { $0.size > $1.size }
            isScanning = false
            scanProgress = 1.0
            currentScanPath = ""
        }
    }
    
    /// 扫描单个应用的多语言文件
    private func scanAppLocalizations(_ app: URL) async -> [CleanerFileItem] {
        var items: [CleanerFileItem] = []
        
        let resourcesDir = app.appendingPathComponent("Contents/Resources")
        guard let resources = try? fileManager.contentsOfDirectory(at: resourcesDir, includingPropertiesForKeys: nil) else {
            return items
        }
        
        for resource in resources {
            let name = resource.lastPathComponent
            guard name.hasSuffix(".lproj"), !keepLocalizations.contains(name) else { continue }
            
            let size = calculateSize(at: resource)
            let item = CleanerFileItem(
                url: resource,
                name: "\(app.deletingPathExtension().lastPathComponent) - \(name)",
                size: size,
                groupId: app.lastPathComponent
            )
            items.append(item)
        }
        
        return items
    }
    
    // MARK: - 扫描大文件 - 多线程优化版
    func scanLargeFiles(minSize: Int64 = 100 * 1024 * 1024) async { // 默认 100MB
        await MainActor.run {
            isScanning = true
            scanProgress = 0
            largeFiles = []
            currentCategory = .largeFiles
        }
        
        let homeDir = fileManager.homeDirectoryForCurrentUser
        
        // 定义要扫描的主目录
        let mainDirectories = [
            "Documents", "Downloads", "Desktop", "Movies", "Music", "Pictures",
            "Developer", "Projects", "Work"
        ]
        
        // 并行扫描所有目录
        let collector = ScanResultCollector<CleanerFileItem>()
        let progressTracker = ScanProgressTracker()
        await progressTracker.setTotalTasks(mainDirectories.count)
        
        await withTaskGroup(of: [CleanerFileItem].self) { group in
            for dirName in mainDirectories {
                let dirURL = homeDir.appendingPathComponent(dirName)
                guard fileManager.fileExists(atPath: dirURL.path) else { continue }
                
                group.addTask {
                    await self.scanDirectoryForLargeFiles(dirURL, minSize: minSize)
                }
            }
            
            for await dirItems in group {
                await collector.appendContents(of: dirItems)
                await progressTracker.completeTask()
                
                let progress = await progressTracker.getProgress()
                await MainActor.run {
                    self.scanProgress = progress
                }
            }
        }
        
        let items = await collector.getResults()
        
        await MainActor.run {
            largeFiles = items.sorted { $0.size > $1.size }
            isScanning = false
            scanProgress = 1.0
            currentScanPath = ""
        }
    }
    
    /// 扫描目录中的大文件
    private func scanDirectoryForLargeFiles(_ directory: URL, minSize: Int64) async -> [CleanerFileItem] {
        var items: [CleanerFileItem] = []
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return items }
        
        for case let fileURL as URL in enumerator {
            // 跳过 Library 等系统目录
            if fileURL.path.contains("/Library/") || fileURL.path.contains("/.git/") {
                continue
            }
            
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  let isDir = values.isDirectory, !isDir,
                  let size = values.fileSize, Int64(size) >= minSize else { continue }
            
            let item = CleanerFileItem(
                url: fileURL,
                name: fileURL.lastPathComponent,
                size: Int64(size),
                groupId: "large"
            )
            items.append(item)
        }
        
        return items
    }
    
    // MARK: - 删除选中文件
    func deleteSelectedFiles(from category: CleanerCategory) async -> (success: Int, failed: Int, size: Int64) {
        var success = 0
        var failed = 0
        var freedSize: Int64 = 0
        
        switch category {
        case .duplicates:
            for i in 0..<duplicateGroups.count {
                for j in 0..<duplicateGroups[i].files.count {
                    if duplicateGroups[i].files[j].isSelected {
                        do {
                            try fileManager.trashItem(at: duplicateGroups[i].files[j].url, resultingItemURL: nil)
                            freedSize += duplicateGroups[i].files[j].size
                            success += 1
                        } catch {
                            failed += 1
                        }
                    }
                }
            }
            await scanDuplicates()
            
        case .similarPhotos:
            for i in 0..<similarPhotoGroups.count {
                for j in 0..<similarPhotoGroups[i].files.count {
                    if similarPhotoGroups[i].files[j].isSelected {
                        do {
                            try fileManager.trashItem(at: similarPhotoGroups[i].files[j].url, resultingItemURL: nil)
                            freedSize += similarPhotoGroups[i].files[j].size
                            success += 1
                        } catch {
                            failed += 1
                        }
                    }
                }
            }
            await scanSimilarPhotos()
            
        case .localizations:
            for file in localizationFiles where file.isSelected {
                do {
                    try fileManager.removeItem(at: file.url)
                    freedSize += file.size
                    success += 1
                } catch {
                    failed += 1
                }
            }
            await scanLocalizations()
            
        case .largeFiles:
            for file in largeFiles where file.isSelected {
                do {
                    try fileManager.trashItem(at: file.url, resultingItemURL: nil)
                    freedSize += file.size
                    success += 1
                } catch {
                    failed += 1
                }
            }
            await scanLargeFiles()
            
        case .systemJunk, .systemCache, .oldUpdates, .userCache, .languageFiles, .systemLogs, .userLogs, .brokenLoginItems:
            // 系统垃圾分类使用统一清理方法
            break
        }
        
        return (success, failed, freedSize)
    }
    
    // MARK: - 辅助方法
    
    private func md5Hash(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    private func extractImageFingerprint(from url: URL) async -> VNFeaturePrintObservation? {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }
    
    private func calculateSize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }
    
    // MARK: - 统计
    
    func selectedCount(for category: CleanerCategory) -> Int {
        switch category {
        case .duplicates:
            return duplicateGroups.flatMap { $0.files }.filter { $0.isSelected }.count
        case .similarPhotos:
            return similarPhotoGroups.flatMap { $0.files }.filter { $0.isSelected }.count
        case .localizations:
            return localizationFiles.filter { $0.isSelected }.count
        case .largeFiles:
            return largeFiles.filter { $0.isSelected }.count
        case .systemJunk, .systemCache, .oldUpdates, .userCache, .languageFiles, .systemLogs, .userLogs, .brokenLoginItems:
            return countFor(category: category)
        }
    }
    
    func selectedSize(for category: CleanerCategory) -> Int64 {
        switch category {
        case .duplicates:
            return duplicateGroups.flatMap { $0.files }.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        case .similarPhotos:
            return similarPhotoGroups.flatMap { $0.files }.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        case .localizations:
            return localizationFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        case .largeFiles:
            return largeFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        case .systemJunk, .systemCache, .oldUpdates, .userCache, .languageFiles, .systemLogs, .userLogs, .brokenLoginItems:
            return sizeFor(category: category)
        }
    }
    
    func totalWastedSize() -> Int64 {
        let duplicateWaste = duplicateGroups.reduce(0) { $0 + $1.wastedSize }
        let photoWaste = similarPhotoGroups.reduce(0) { $0 + $1.wastedSize }
        let locWaste = localizationFiles.reduce(0) { $0 + $1.size }
        return duplicateWaste + photoWaste + locWaste
    }
    
    // MARK: - 重置所有扫描结果
    @MainActor
    func resetAll() {
        userCacheFiles = []
        systemCacheFiles = []
        oldUpdateFiles = []
        languageFiles = []
        systemLogFiles = []
        userLogFiles = []
        brokenLoginItems = []
        duplicateGroups = []
        similarPhotoGroups = []
        localizationFiles = []
        largeFiles = []
        scanProgress = 0
        currentScanPath = ""
    }
    
    // MARK: - 一键扫描所有
    func scanAll() async {
        // 重置停止标志
        await MainActor.run { shouldStopScanning = false }
        
        // 首先扫描系统垃圾
        await scanSystemJunk()
        if shouldStopScanning { return }
        
        // 然后扫描其他类别
        await scanDuplicates()
        if shouldStopScanning { return }
        
        await scanSimilarPhotos()
        if shouldStopScanning { return }
        
        await scanLocalizations()
        if shouldStopScanning { return }
        
        await scanLargeFiles()
    }
    
    @Published var isCleaning = false
    @Published var cleaningDescription: String = ""
    @Published var cleaningCurrentCategory: CleanerCategory? = nil
    @Published var cleanedCategories: Set<CleanerCategory> = []
    
    // MARK: - 一键清理所有
    func cleanAll() async -> (success: Int, failed: Int, size: Int64, failedFiles: [CleanerFileItem]) {
        await MainActor.run {
            isCleaning = true
            cleaningDescription = "Preparing..."
            cleanedCategories = []
            cleaningCurrentCategory = nil
        }
        
        defer {
            Task { @MainActor in isCleaning = false }
        }
        
        var totalSuccess = 0
        var totalFailed = 0
        var totalSize: Int64 = 0
        var failedFiles: [CleanerFileItem] = []
        
        // 辅助函数：安全删除文件
        func safeDelete(file: CleanerFileItem) -> Bool {
            let url = file.url
            let path = url.path
            
            // 1. 检查文件是否可写/可删除
            // 如果不可删除，直接跳过，留给管理员权限批量处理
            if !fileManager.isDeletableFile(atPath: path) {
                failedFiles.append(file)
                return false
            }
            
            // 2. 即使 isDeletableFile 返回 true，有些文件（如正在运行的应用）也可能无法删除
            // 尝试移动到废纸篓
            do {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
                return true
            } catch {
                // 3. 尝试直接删除
                do {
                    try fileManager.removeItem(at: url)
                    return true
                } catch {
                    failedFiles.append(file)
                    return false
                }
            }
        }
        
        // 1. 清理系统垃圾 (聚合 User Cache, System Cache, Old Updates, Language Files, Logs)
        await MainActor.run {
            cleaningCurrentCategory = .systemJunk
            cleaningDescription = "Cleaning System Junk..."
        }
        
        // 子步骤：用户缓存
        for file in userCacheFiles {
            if safeDelete(file: file) {
                totalSize += file.size
                totalSuccess += 1
            } else { totalFailed += 1 }
        }
        
        // 子步骤：系统缓存
        for file in systemCacheFiles {
            if safeDelete(file: file) {
                totalSize += file.size
                totalSuccess += 1
            } else { totalFailed += 1 }
        }
        
        // 子步骤：旧更新
        for file in oldUpdateFiles {
            if safeDelete(file: file) {
                totalSize += file.size
                totalSuccess += 1
            } else { totalFailed += 1 }
        }
        
        // 子步骤：语言文件
        for file in languageFiles {
            if safeDelete(file: file) {
                totalSize += file.size
                totalSuccess += 1
            } else { totalFailed += 1 }
        }
        
        // 子步骤：日志
        for file in systemLogFiles {
            if safeDelete(file: file) {
                totalSize += file.size
                totalSuccess += 1
            } else { totalFailed += 1 }
        }
        for file in userLogFiles {
            if safeDelete(file: file) {
                totalSize += file.size
                totalSuccess += 1
            } else { totalFailed += 1 }
        }
        
        await MainActor.run { cleanedCategories.insert(.systemJunk) }
        
        // 2. 清理重复文件
        if !duplicateGroups.isEmpty {
            await MainActor.run {
                cleaningCurrentCategory = .duplicates
                cleaningDescription = "Cleaning Duplicates..."
            }
            for i in 0..<duplicateGroups.count {
                for j in 1..<duplicateGroups[i].files.count {
                    if safeDelete(file: duplicateGroups[i].files[j]) {
                        totalSize += duplicateGroups[i].files[j].size
                        totalSuccess += 1
                    } else { totalFailed += 1 }
                }
            }
            await MainActor.run { cleanedCategories.insert(.duplicates) }
        }
        
        // 3. 清理相似照片
        if !similarPhotoGroups.isEmpty {
            await MainActor.run {
                cleaningCurrentCategory = .similarPhotos
                cleaningDescription = "Cleaning Similar Photos..."
            }
            for i in 0..<similarPhotoGroups.count {
                for j in 1..<similarPhotoGroups[i].files.count {
                    if safeDelete(file: similarPhotoGroups[i].files[j]) {
                        totalSize += similarPhotoGroups[i].files[j].size
                        totalSuccess += 1
                    } else { totalFailed += 1 }
                }
            }
            await MainActor.run { cleanedCategories.insert(.similarPhotos) }
        }
        
        // 4. 清理多语言本地化文件
        // 这里的 localizationFiles 是由 scanLocalizations 填充的，与 systemJunk 中的 languageFiles 不同。
        // languageFiles 是系统级别的语言包，localizationFiles 是应用内部的 .lproj 文件夹。
        // 假设 UI 上没有单独展示这个进度，或者可以归类到“其他”清理中。
        // 为了保持 UI 进度更新，我们将其归类到 .localizations 类别。
        if !localizationFiles.isEmpty {
            await MainActor.run {
                cleaningCurrentCategory = .localizations
                cleaningDescription = "Cleaning Localizations..."
            }
            for file in localizationFiles {
                if safeDelete(file: file) {
                    totalSize += file.size
                    totalSuccess += 1
                } else { totalFailed += 1 }
            }
            await MainActor.run { cleanedCategories.insert(.localizations) }
        }
        
        // 5. 清理大文件
        if !largeFiles.isEmpty {
            await MainActor.run {
                cleaningCurrentCategory = .largeFiles
                cleaningDescription = "Cleaning Large Files..."
            }
            for file in largeFiles {
                if safeDelete(file: file) {
                    totalSize += file.size
                    totalSuccess += 1
                } else { totalFailed += 1 }
            }
            await MainActor.run { cleanedCategories.insert(.largeFiles) }
        }
        
        // 刷新所有数据
        // 刷新所有数据
        await MainActor.run {
            // 只移除成功的，保留失败的
            let failedSet = Set(failedFiles.map(\.url))
            
            userCacheFiles = userCacheFiles.filter { failedSet.contains($0.url) }
            systemCacheFiles = systemCacheFiles.filter { failedSet.contains($0.url) }
            oldUpdateFiles = oldUpdateFiles.filter { failedSet.contains($0.url) }
            languageFiles = languageFiles.filter { failedSet.contains($0.url) }
            systemLogFiles = systemLogFiles.filter { failedSet.contains($0.url) }
            userLogFiles = userLogFiles.filter { failedSet.contains($0.url) }
            
            // 重复文件/相似照片比较复杂，这里简化处理：如果整个组都没了就移除
            // 对于 duplicateGroups，如果 failedSet 包含其中的文件，保留该组（可能需要重新计算大小，但暂时保留原样）
            // 注意：files[0] 是保留文件，从未被清理。如果组中有其他文件失败，则保留该组
            duplicateGroups = duplicateGroups.filter { group in
                group.files.dropFirst().contains { failedSet.contains($0.url) }
            }
            
            similarPhotoGroups = similarPhotoGroups.filter { group in
                group.files.dropFirst().contains { failedSet.contains($0.url) }
            }
            
            localizationFiles = localizationFiles.filter { failedSet.contains($0.url) }
            largeFiles = largeFiles.filter { failedSet.contains($0.url) }
            
            // 最终状态更新
            cleaningCurrentCategory = nil
            
            // 只有当该类别剩余大小为 0 时，才标记为完成
            for category in CleanerCategory.allCases {
                if sizeFor(category: category) == 0 {
                    cleanedCategories.insert(category)
                } else {
                    cleanedCategories.remove(category)
                }
            }
        }
        
        return (totalSuccess, totalFailed, totalSize, failedFiles)
    }
    
    // MARK: - 使用管理员权限清理失败的文件
    func cleanWithPrivileges(files: [CleanerFileItem]) async -> (success: Int, failed: Int, size: Int64) {
        if files.isEmpty {
            return (0, 0, 0)
        }
        
        await MainActor.run {
            isCleaning = true
            cleaningDescription = "Deleting with privileges..."
            // Reset categories to cleaning state if needed
            cleanedCategories = []
        }
        
        defer {
            Task { @MainActor in isCleaning = false }
        }
        
        var totalSuccess = 0
        var totalFailed = 0
        var totalSize: Int64 = 0
        
        // 1. 创建临时脚本文件
        let scriptContent = files.map { file in
            // 使用引号包裹路径以处理空格
            let escapedPath = file.url.path.replacingOccurrences(of: "\"", with: "\\\"")
            // rm -rf "path" || true (忽略错误继续执行)
            return "rm -rf \"\(escapedPath)\" || true"
        }.joined(separator: "\n")
        
        // 添加 exit 0 确保脚本总是成功返回，避免 AppleScript 报错
        let fullScript = "#!/bin/bash\n" + scriptContent + "\nexit 0"
        
        let tempScriptURL = fileManager.temporaryDirectory.appendingPathComponent("cleaner_script_\(UUID().uuidString).sh")
        
        do {
            try fullScript.write(to: tempScriptURL, atomically: true, encoding: .utf8)
            // 赋予执行权限
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptURL.path)
            
            // 2. 使用管理员权限执行该脚本
            // 注意：我们这里只请求一次权限
            let appleScriptCommand = "do shell script \"/bin/bash \(tempScriptURL.path)\" with administrator privileges"
            
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: appleScriptCommand) {
                appleScript.executeAndReturnError(&error)
                
                if error == nil {
                    // 假设脚本执行完成后，我们需要验证哪些文件实际上被删除了
                    for file in files {
                        if !fileManager.fileExists(atPath: file.url.path) {
                            totalSuccess += 1
                            totalSize += file.size
                        } else {
                            totalFailed += 1
                        }
                    }
                } else {
                    // 脚本执行失败（可能是用户取消了授权）
                    totalFailed = files.count
                    print("Admin script error: \(String(describing: error))")
                }
            } else {
                totalFailed = files.count
            }
            
            // 3. 清理临时脚本
            try? fileManager.removeItem(at: tempScriptURL)
            
        } catch {
            print("Failed to create temp script: \(error)")
            totalFailed = files.count
        }
        
        return (totalSuccess, totalFailed, totalSize)
    }
    
    // MARK: - 全选/取消全选
    func selectAll(for category: CleanerCategory, selected: Bool) {
        switch category {
        case .duplicates:
            for i in 0..<duplicateGroups.count {
                for j in 0..<duplicateGroups[i].files.count {
                    duplicateGroups[i].files[j].isSelected = selected
                }
            }
        case .similarPhotos:
            for i in 0..<similarPhotoGroups.count {
                for j in 0..<similarPhotoGroups[i].files.count {
                    similarPhotoGroups[i].files[j].isSelected = selected
                }
            }
        case .localizations:
            for i in 0..<localizationFiles.count {
                localizationFiles[i].isSelected = selected
            }
        case .largeFiles:
            for i in 0..<largeFiles.count {
                largeFiles[i].isSelected = selected
            }
        case .systemJunk, .systemCache, .oldUpdates, .userCache, .languageFiles, .systemLogs, .userLogs, .brokenLoginItems:
            // 系统垃圾类别暂不支持单独选择
            break
        }
    }
    
    // 总可清理大小
    var totalCleanableSize: Int64 {
        let dupSize = duplicateGroups.reduce(0) { $0 + $1.wastedSize }
        let photoSize = similarPhotoGroups.reduce(0) { $0 + $1.wastedSize }
        let locSize = localizationFiles.reduce(0) { $0 + $1.size }
        return dupSize + photoSize + locSize
    }
}
