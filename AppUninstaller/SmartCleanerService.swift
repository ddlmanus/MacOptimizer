import Foundation
import AppKit
import SwiftUI
import CryptoKit
import Vision

// MARK: - 主分类（用于三栏布局）
enum MainCategory: String, CaseIterable, Identifiable {
    case systemJunk = "系统垃圾"
    case duplicates = "重复文件"
    case similarPhotos = "相似照片"
    case largeFiles = "大文件"
    case virus = "病毒威胁"
    case startupItems = "启动项"
    case performanceApps = "性能优化"
    case appUpdates = "应用更新"
    
    var id: String { rawValue }
    
    var englishName: String {
        switch self {
        case .systemJunk: return "System Junk"
        case .duplicates: return "Duplicates"
        case .similarPhotos: return "Similar Photos"
        case .largeFiles: return "Large Files"
        case .virus: return "Virus Threats"
        case .startupItems: return "Startup Items"
        case .performanceApps: return "Performance"
        case .appUpdates: return "App Updates"
        }
    }
    
    var icon: String {
        switch self {
        case .systemJunk: return "trash.fill"
        case .duplicates: return "doc.on.doc"
        case .similarPhotos: return "photo.on.rectangle"
        case .largeFiles: return "doc.fill"
        case .virus: return "shield.lefthalf.filled"
        case .startupItems: return "power.circle"
        case .performanceApps: return "bolt.fill"
        case .appUpdates: return "arrow.clockwise.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .systemJunk: return .pink
        case .duplicates: return .blue
        case .similarPhotos: return .purple
        case .largeFiles: return .orange
        case .virus: return .red
        case .startupItems: return .yellow
        case .performanceApps: return .green
        case .appUpdates: return .cyan
        }
    }
    
    // 获取该主分类下的子分类
    var subcategories: [CleanerCategory] {
        switch self {
        case .systemJunk:
            return [.userCache, .systemCache, .oldUpdates, .languageFiles, 
                    .systemLogs, .userLogs, .brokenLoginItems]
        case .duplicates:
            return [.duplicates]
        case .similarPhotos:
            return [.similarPhotos]
        case .largeFiles:
            return [.largeFiles]
        case .virus:
            return [.virus]
        case .startupItems:
            return [.startupItems]
        case .performanceApps:
            return [.performanceApps]
        case .appUpdates:
            return [.appUpdates]
        }
    }
}

// MARK: - 清理类型
enum CleanerCategory: String, CaseIterable {
    // 系统垃圾类别（新增）
    case systemJunk = "系统垃圾"
    case systemCache = "系统缓存文件"
    case oldUpdates = "下载与更新"
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
    
    // 新增智能扫描类别
    case virus = "病毒防护"
    case appUpdates = "应用更新"
    case startupItems = "开机启动"
    case performanceApps = "性能优化"
    
    var icon: String {
        switch self {
        case .systemJunk: return "globe"
        case .systemCache: return "internaldrive"
        case .oldUpdates: return "arrow.down.circle"
        case .userCache: return "person.crop.circle"
        case .languageFiles: return "character.bubble"
        case .systemLogs: return "doc.text"
        case .userLogs: return "person.text.rectangle"
        case .brokenLoginItems: return "exclamationmark.triangle"
        case .duplicates: return "doc.on.doc"
        case .similarPhotos: return "photo.on.rectangle"
        case .localizations: return "alphabet"
        case .largeFiles: return "doc"
        case .virus: return "shield.lefthalf.filled"
        case .appUpdates: return "arrow.clockwise.circle"
        case .startupItems: return "apps.ipad"
        case .performanceApps: return "bolt.fill"
        }
    }
    
    var englishName: String {
        switch self {
        case .systemJunk: return "System Junk"
        case .systemCache: return "System Cache"
        case .oldUpdates: return "Downloads & Updates"
        case .userCache: return "User Cache"
        case .languageFiles: return "Language Files"
        case .systemLogs: return "System Logs"
        case .userLogs: return "User Logs"
        case .brokenLoginItems: return "Broken Login Items"
        case .duplicates: return "Duplicates"
        case .similarPhotos: return "Similar Photos"
        case .localizations: return "Localizations"
        case .largeFiles: return "Large Files"
        case .virus: return "Virus Protection"
        case .appUpdates: return "App Updates"
        case .startupItems: return "Startup Items"
        case .performanceApps: return "Performance"
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
        case .virus: return .purple
        case .appUpdates: return .blue
        case .startupItems: return .orange
        case .performanceApps: return .green
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
struct CleanerFileItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    var isSelected: Bool = true  // 默认全选
    let groupId: String  // 用于分组显示
    let isDirectory: Bool
    
    // 用于树形展示的自引用
    var children: [CleanerFileItem]? = nil
    
    init(url: URL, name: String, size: Int64, groupId: String, isDirectory: Bool? = nil) {
        self.url = url
        self.name = name
        self.size = size
        self.groupId = groupId
        if let isDir = isDirectory {
            self.isDirectory = isDir
        } else {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            self.isDirectory = isDir.boolValue
        }
    }
    
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

// MARK: - 应用缓存分组
class AppCacheGroup: Identifiable, ObservableObject {
    let id = UUID()
    let appName: String
    let bundleId: String?
    let icon: NSImage
    @Published var files: [CleanerFileItem]
    @Published var isExpanded: Bool = false
    
    init(appName: String, bundleId: String?, icon: NSImage, files: [CleanerFileItem]) {
        self.appName = appName
        self.bundleId = bundleId
        self.icon = icon
        self.files = files
    }
    
    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }
    
    var selectedSize: Int64 {
        files.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
}

// MARK: - 智能清理服务
class SmartCleanerService: ObservableObject {
    
    // MARK: - 选中状态枚举
    enum SelectionState {
        case none      // 全部未选中
        case partial   // 部分选中（半勾选）
        case all       // 全部选中
    }
    
    // 按应用分组的缓存结果 (针对 userCache)
    @Published var appCacheGroups: [AppCacheGroup] = []
    
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
    
    // 扫描状态追踪 (针对 8 大分类)
    @Published var scannedCategories: Set<CleanerCategory> = []
    
    // 新增智能扫描结果
    @Published var virusThreats: [DetectedThreat] = []
    @Published var startupItems: [LaunchItem] = []
    @Published var performanceApps: [RunningAppItem] = []
    @Published var hasAppUpdates: Bool = false
    
    // 子服务实例
    private let malwareScanner = MalwareScanner()
    private let systemOptimizer = SystemOptimizer()
    private let updateChecker = UpdateCheckerService.shared
    
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
        let systemCache = systemCacheFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        let oldUpdates = oldUpdateFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        let userCache = userCacheFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        let groupedCache = appCacheGroups.reduce(0) { $0 + $1.selectedSize }
        let languages = languageFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        let sysLogs = systemLogFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        let userLogs = userLogFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        let brokenLogin = brokenLoginItems.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        
        return systemCache + oldUpdates + userCache + groupedCache + languages + sysLogs + userLogs + brokenLogin
    }
    
    var virusTotalSize: Int64 {
        virusThreats.reduce(0) { $0 + $1.size }
    }
    
    // MARK: - 获取指定分类的大小
    func sizeFor(category: CleanerCategory) -> Int64 {
        switch category {
        case .systemJunk:
            return systemJunkTotalSize
        case .systemCache:
            return systemCacheFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        case .oldUpdates:
            return oldUpdateFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        case .userCache:
            let looseFilesSize = userCacheFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
            let groupedFilesSize = appCacheGroups.reduce(0) { $0 + $1.selectedSize } // Use selectedSize property
            return looseFilesSize + groupedFilesSize
        case .languageFiles:
            return languageFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        case .systemLogs:
            return systemLogFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        case .userLogs:
            return userLogFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        case .brokenLoginItems:
            return brokenLoginItems.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        case .duplicates:
            return duplicateGroups.reduce(0) { $0 + $1.wastedSize }
        case .similarPhotos:
            return similarPhotoGroups.reduce(0) { $0 + $1.wastedSize }
        case .localizations:
            return localizationFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        case .largeFiles:
            return largeFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        case .virus:
            return virusTotalSize
        case .appUpdates:
            return 0 // 更新即使有大小也不计入清理大小，或者计入下载大小？暂时为0
        case .startupItems:
            return 0 // 启动项文件很小，可以忽略或计算 plist 大小
        case .performanceApps:
            return 0 // 进程内存不计入磁盘清理大小
        }
    }
    
    // MARK: - 获取指定分类的项目数
    func countFor(category: CleanerCategory) -> Int {
        switch category {
        case .systemJunk:
             // Need to update total count logic as well to include app groups if they are part of system junk aggregation
             // But simpler to just sum up the counts of sub-categories if possible, 
             // or manually add appCacheGroups.files.count
            return systemCacheFiles.count + oldUpdateFiles.count + userCacheFiles.count +
                   appCacheGroups.reduce(0) { $0 + $1.files.count } +
                   languageFiles.count + systemLogFiles.count + userLogFiles.count + brokenLoginItems.count
        case .systemCache:
            return systemCacheFiles.count
        case .oldUpdates:
            return oldUpdateFiles.count
        case .userCache:
            return userCacheFiles.count + appCacheGroups.reduce(0) { $0 + $1.files.count }
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
        case .virus:
            return virusThreats.count
        case .appUpdates:
            return hasAppUpdates ? 1 : 0
        case .startupItems:
            return startupItems.count
        case .performanceApps:
            return performanceApps.count
        }
    }
    
    // MARK: - 切换文件选择状态
    @MainActor
    func toggleFileSelection(file: CleanerFileItem, in category: CleanerCategory) {
        switch category {
        case .systemCache:
            if let idx = systemCacheFiles.firstIndex(where: { $0.url == file.url }) {
                systemCacheFiles[idx].isSelected.toggle()
            }
        case .oldUpdates:
            if let idx = oldUpdateFiles.firstIndex(where: { $0.url == file.url }) {
                oldUpdateFiles[idx].isSelected.toggle()
            }
        case .userCache:
            if let idx = userCacheFiles.firstIndex(where: { $0.url == file.url }) {
                userCacheFiles[idx].isSelected.toggle()
            }
            // 同时更新分组中的对应项，以确保 UI 同步 (CleanerFileItem 是 struct)
            for gIdx in appCacheGroups.indices {
                if let fIdx = appCacheGroups[gIdx].files.firstIndex(where: { $0.url == file.url }) {
                    appCacheGroups[gIdx].files[fIdx].isSelected.toggle()
                    // 关键修复: 手动触发 Group 的更新通知，确保 AppCacheGroupRow 刷新
                    appCacheGroups[gIdx].objectWillChange.send() 
                    break
                }
            }
            
            // 关键修复: 手动触发 Service 的更新通知，确保 Summary View 刷新统计数据
            self.objectWillChange.send()
        case .languageFiles:
            if let idx = languageFiles.firstIndex(where: { $0.url == file.url }) {
                languageFiles[idx].isSelected.toggle()
            }
        case .systemLogs:
            if let idx = systemLogFiles.firstIndex(where: { $0.url == file.url }) {
                systemLogFiles[idx].isSelected.toggle()
            }
        case .userLogs:
            if let idx = userLogFiles.firstIndex(where: { $0.url == file.url }) {
                userLogFiles[idx].isSelected.toggle()
            }
        case .brokenLoginItems:
            if let idx = brokenLoginItems.firstIndex(where: { $0.url == file.url }) {
                brokenLoginItems[idx].isSelected.toggle()
            }
        case .localizations:
            if let idx = localizationFiles.firstIndex(where: { $0.url == file.url }) {
                localizationFiles[idx].isSelected.toggle()
            }
        case .largeFiles:
            if let idx = largeFiles.firstIndex(where: { $0.url == file.url }) {
                largeFiles[idx].isSelected.toggle()
            }
        case .systemJunk, .duplicates, .similarPhotos, .virus, .appUpdates, .startupItems, .performanceApps:
            // 这些是复合分类，或不支持直接切换
            break
        }
    }
    
    /// 动态加载子文件夹内容
    func loadSubItems(for item: CleanerFileItem) async -> [CleanerFileItem] {
        guard item.isDirectory else { return [] }
        
        var subItems: [CleanerFileItem] = []
        do {
            let contents = try fileManager.contentsOfDirectory(at: item.url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles])
            for url in contents {
                let resources = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                let isDir = resources.isDirectory ?? false
                let size = isDir ? calculateSize(at: url) : Int64(resources.fileSize ?? 0)
                
                subItems.append(CleanerFileItem(
                    url: url,
                    name: url.lastPathComponent,
                    size: size,
                    groupId: item.groupId,
                    isDirectory: isDir
                ))
            }
        } catch {
            print("Failed to load sub items for \(item.url.path): \(error)")
        }
        
        return subItems.sorted { $0.size > $1.size }
    }
    
    /// 删除单个文件
    @MainActor
    func deleteSingleFile(_ file: CleanerFileItem, from category: CleanerCategory) async -> Bool {
        do {
            // 使用 FileManager 删除文件
            try fileManager.removeItem(at: file.url)
            
            // 从对应的数组中移除该文件
            removeFileFromCategory(file, category: category)
            
            return true
        } catch {
            print("删除文件失败: \(file.url.path) - \(error)")
            return false
        }
    }
    
    /// 从分类数组中移除文件
    @MainActor
    private func removeFileFromCategory(_ file: CleanerFileItem, category: CleanerCategory) {
        switch category {
        case .systemCache:
            systemCacheFiles.removeAll { $0.url == file.url }
        case .oldUpdates:
            oldUpdateFiles.removeAll { $0.url == file.url }
        case .userCache:
            userCacheFiles.removeAll { $0.url == file.url }
            // 同时更新分组中的该文件
            for gIdx in appCacheGroups.indices {
                appCacheGroups[gIdx].files.removeAll { $0.url == file.url }
            }
            // 移除空组
            appCacheGroups.removeAll { $0.files.isEmpty }
        case .languageFiles:
            languageFiles.removeAll { $0.url == file.url }
        case .systemLogs:
            systemLogFiles.removeAll { $0.url == file.url }
        case .userLogs:
            userLogFiles.removeAll { $0.url == file.url }
        case .brokenLoginItems:
            brokenLoginItems.removeAll { $0.url == file.url }
        case .localizations:
            localizationFiles.removeAll { $0.url == file.url }
        case .largeFiles:
            largeFiles.removeAll { $0.url == file.url }
        default:
            break
        }
    }
    
    // MARK: - 主分类支持方法
    
    /// 获取分类对应的文件列表
    @MainActor
    func filesFor(category: CleanerCategory) -> [CleanerFileItem] {
        switch category {
        case .userCache: return userCacheFiles + appCacheGroups.flatMap { $0.files }
        case .systemCache: return systemCacheFiles
        case .oldUpdates: return oldUpdateFiles
        case .languageFiles: return languageFiles
        case .systemLogs: return systemLogFiles
        case .userLogs: return userLogFiles
        case .brokenLoginItems: return brokenLoginItems
        case .duplicates: return duplicateGroups.flatMap { $0.files }
        case .similarPhotos: return similarPhotoGroups.flatMap { $0.files }
        case .largeFiles: return largeFiles
        case .localizations: return localizationFiles
        default: return []
        }
    }
    
    /// 获取主分类的统计信息
    @MainActor
    func statisticsFor(mainCategory: MainCategory) -> (count: Int, size: Int64) {
        let allFiles = mainCategory.subcategories.flatMap { filesFor(category: $0) }.filter { $0.isSelected }
        return (allFiles.count, allFiles.reduce(0) { $0 + $1.size })
    }
    
    /// 获取子分类的统计信息
    @MainActor
    func statisticsFor(category: CleanerCategory) -> (count: Int, size: Int64) {
        let files = filesFor(category: category).filter { $0.isSelected }
        return (files.count, files.reduce(0) { $0 + $1.size })
    }
    
    // MARK: - 选中状态检测
    
    /// 检查子分类的勾选状态
    @MainActor
    func getSelectionState(for category: CleanerCategory) -> SelectionState {
        let files = filesFor(category: category)
        guard !files.isEmpty else { return .none }
        
        let selectedCount = files.filter { $0.isSelected }.count
        if selectedCount == 0 { return .none }
        if selectedCount == files.count { return .all }
        return .partial
    }

    /// 检查主分类的勾选状态
    @MainActor
    func getSelectionState(for mainCategory: MainCategory) -> SelectionState {
        let allFiles = mainCategory.subcategories.flatMap { filesFor(category: $0) }
        guard !allFiles.isEmpty else { return .none }
        
        let selectedCount = allFiles.filter { $0.isSelected }.count
        if selectedCount == 0 { return .none }
        if selectedCount == allFiles.count { return .all }
        return .partial
    }
    
    /// 切换主分类选中状态
    @MainActor
    func toggleMainCategorySelection(_ mainCategory: MainCategory) {
        let currentState = getSelectionState(for: mainCategory)
        // 如果当前是全部选中，则取消全选；否则（部分选中或未选中）全选
        let newSelected = (currentState != .all)
        
        for category in mainCategory.subcategories {
            toggleCategorySelection(category, forceTo: newSelected)
        }
        
        // 确保触发更新
        objectWillChange.send()
    }
    
    /// 切换应用分组的选中状态（同步更新 userCacheFiles）
    @MainActor
    func toggleAppGroupSelection(_ group: AppCacheGroup) {
        // 计算新状态：只要不是全选，就设为全选（如果是部分选中，操作是补全选中）
        // 或者：只要是全选，就取消；否则全选。
        // Finder逻辑：点击Checkbox时，如果是混合状态，通常变为全选或全不选。
        // 根据 SelectionState 逻辑：
        // State is All -> Toggle to None
        // State is None -> Toggle to All
        // State is Partial -> Toggle to All
        
        let allSelected = group.files.allSatisfy { $0.isSelected }
        let targetState = !allSelected
        
        // 1. 更新 Group 内的文件状态 (引用类型直接更新)
        for i in group.files.indices {
            group.files[i].isSelected = targetState
        }
        
        // 2. 同步更新 userCacheFiles (打平的列表)
        // 建立 Group 文件 URL 集合以加速查找
        let groupURLs = Set(group.files.map { $0.url })
        for i in userCacheFiles.indices {
            if groupURLs.contains(userCacheFiles[i].url) {
                userCacheFiles[i].isSelected = targetState
            }
        }
        
        objectWillChange.send()
    }
    
    /// 切换整个子分类的选中状态
    @MainActor
    func toggleCategorySelection(_ category: CleanerCategory, forceTo: Bool? = nil) {
        let files = filesFor(category: category)
        // 如果提供了强制状态则使用之，否则反转当前全选状态
        let targetState = forceTo ?? !files.allSatisfy { $0.isSelected }
        
        // 全选或全不选
        switch category {
        case .systemCache:
            for i in systemCacheFiles.indices {
                systemCacheFiles[i].isSelected = targetState
            }
        case .oldUpdates:
            for i in oldUpdateFiles.indices {
                oldUpdateFiles[i].isSelected = targetState
            }
        case .userCache:
            for i in userCacheFiles.indices {
                userCacheFiles[i].isSelected = targetState
            }
            // 同时更新分组
            for gIdx in appCacheGroups.indices {
                for fIdx in appCacheGroups[gIdx].files.indices {
                    appCacheGroups[gIdx].files[fIdx].isSelected = targetState
                }
            }
        case .languageFiles:
            for i in languageFiles.indices {
                languageFiles[i].isSelected = targetState
            }
        case .systemLogs:
            for i in systemLogFiles.indices {
                systemLogFiles[i].isSelected = targetState
            }
        case .userLogs:
            for i in userLogFiles.indices {
                userLogFiles[i].isSelected = targetState
            }
        case .brokenLoginItems:
            for i in brokenLoginItems.indices {
                brokenLoginItems[i].isSelected = targetState
            }
        case .largeFiles:
            for i in largeFiles.indices {
                largeFiles[i].isSelected = targetState
            }
        case .duplicates:
            for gIdx in duplicateGroups.indices {
                for fIdx in duplicateGroups[gIdx].files.indices {
                    duplicateGroups[gIdx].files[fIdx].isSelected = targetState
                }
            }
        case .similarPhotos:
            for gIdx in similarPhotoGroups.indices {
                for fIdx in similarPhotoGroups[gIdx].files.indices {
                    similarPhotoGroups[gIdx].files[fIdx].isSelected = targetState
                }
            }
        default:
            break
        }
        
        // 手动触发ObservableObject更新，因为修改数组元素的属性不会自动触发
        objectWillChange.send()
    }
    
    /// 检查子分类是否全选
    @MainActor
    func isCategoryAllSelected(_ category: CleanerCategory) -> Bool {
        let files = filesFor(category: category)
        guard !files.isEmpty else { return false }
        return files.allSatisfy { $0.isSelected }
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
        
        // 4. 扫描语言文件 - ⚠️ 已禁用(用户要求只清理缓存和日志)
        // await updateProgress(step: currentStep, total: totalSteps, message: "正在扫描语言文件...")
        // let langFiles = await scanLanguageFiles()
        // await MainActor.run { languageFiles = langFiles }
        // currentStep += 1
        
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
        
        // 7. 扫描损坏的登录项 - ⚠️ 已禁用(用户要求只清理缓存和日志)
        // await updateProgress(step: currentStep, total: totalSteps, message: "正在扫描损坏的登录项...")
        // let brokenItems = await scanBrokenLoginItems()
        // await MainActor.run { brokenLoginItems = brokenItems }
        
        await MainActor.run {
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
                        if size > 1024 { // > 1KB，大幅降低阈值
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
                if size > 10 * 1024 { // 降低到 10KB（开发者缓存通常较大）
                    items.append(CleanerFileItem(
                        url: devCacheURL,
                        name: "开发: " + devCacheURL.lastPathComponent,
                        size: size,
                        groupId: "systemCache"
                    ))
                }
            }
        }
        
        // 3. 扫描 Apple 系统服务缓存（大幅扩展，包含关键高价值缓存）
        let appleCaches = [
            // ===== 核心系统服务（高价值，通常数 GB）=====
            "com.apple.coresymbolicationd",     // 符号化缓存，可达 4GB+
            "com.apple.iconservices.store",     // 图标服务缓存，数百 MB
            "com.apple.bird",                   // iCloud 同步缓存
            "com.apple.CrashReporter",          // 崩溃报告缓存
            "com.apple.CoreSimulator",          // iOS 模拟器缓存（开发者）
            
            // ===== 图形与渲染 =====
            "com.apple.Metal",                  // Metal 图形缓存
            "com.apple.ImageIO",                // 图像处理缓存
            "com.apple.QuickLook.thumbnailcache", // QuickLook 缩略图
            
            // ===== WebKit 与网络 =====
            "com.apple.WebKit.Networking",      // WebKit 网络缓存
            "com.apple.WebKit.WebContent",      // WebKit 内容缓存
            "com.apple.nsurlsessiond",          // URL 会话缓存
            "com.apple.nsservicescache",        // 服务缓存
            
            // ===== 系统索引与搜索 =====
            "com.apple.Spotlight",              // Spotlight 索引缓存
            "com.apple.spotlightknowledge",     // Spotlight 知识库
            "com.apple.parsecd",                // 解析缓存
            
            // ===== 位置与隐私 =====
            "com.apple.routined",               // 位置服务缓存
            "com.apple.ap.adprivacyd",          // 广告隐私
            
            // ===== 系统应用 =====
            "com.apple.Safari",
            "com.apple.finder",
            "com.apple.LaunchServices",
            "com.apple.DiskImages",
            "com.apple.helpd",
            "com.apple.iCloudHelper",
            "com.apple.appstore",
            "com.apple.Music",
            "com.apple.Photos",
            "com.apple.mail",
            "com.apple.Maps",
            "com.apple.AddressBook",
            "com.apple.CalendarAgent",
            "com.apple.reminders",
            "com.apple.VoiceMemos",
            "com.apple.Notes",
            "com.apple.FaceTime",
            "com.apple.TV",
            
            // ===== 开发者工具 =====
            "com.apple.dt.Xcode",
            "com.apple.dt.instruments",
            
            // ===== 其他系统服务 =====
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
                if size > 1024 { // 降低阈值到 1KB，捕获更多缓存
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
        
        // 4. 扫描私有临时文件夹 /private/var/folders
        // 这是系统及应用存放临时文件和缓存的主要位置
        if let _ = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
             let tempDir = NSTemporaryDirectory()
             let userTempRoot = URL(fileURLWithPath: tempDir).deletingLastPathComponent()
             
             let cacheDir = userTempRoot.appendingPathComponent("C")
             let tempDirUrl = userTempRoot.appendingPathComponent("T")
             
             let targetDirs = [cacheDir, tempDirUrl]
             
             for targetDir in targetDirs {
                 if fileManager.fileExists(atPath: targetDir.path) {
                     if let contents = try? fileManager.contentsOfDirectory(at: targetDir, includingPropertiesForKeys: nil) {
                         for itemURL in contents {
                             if itemURL.lastPathComponent == "com.apple.nsurlsessiond" { continue }
                             
                             let size = calculateSize(at: itemURL)
                             if size > 100 * 1024 { // 降低阈值到 100KB
                                 let name = itemURL.lastPathComponent.replacingOccurrences(of: "com.apple.", with: "Apple ")
                                 items.append(CleanerFileItem(
                                     url: itemURL,
                                     name: "系统临时文件: \(name)",
                                     size: size,
                                     groupId: "systemCache"
                                 ))
                             }
                         }
                     }
                 }
             }
        }

        // 5. 额外扫描 /private/var/tmp 和 /tmp
        let sharedTempPaths = ["/private/var/tmp", "/tmp"]
        for path in sharedTempPaths {
            let url = URL(fileURLWithPath: path)
            if let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                for itemURL in contents {
                    let size = calculateSize(at: itemURL)
                    if size > 512 * 1024 { // 512KB
                        items.append(CleanerFileItem(
                            url: itemURL,
                            name: "临时文件: \(itemURL.lastPathComponent)",
                            size: size,
                            groupId: "systemCache"
                        ))
                    }
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
        
        // 6. 深度递归扫描 /private/var/folders（重点查找 coresymbolicationd 等大型缓存）
        // 这些缓存通常在深层子目录中，例如 /private/var/folders/xx/xx/C/com.apple.coresymbolicationd
        let privateVarFolders = URL(fileURLWithPath: "/private/var/folders")
        if fileManager.isReadableFile(atPath: privateVarFolders.path) {
            // 关键缓存名称模式（这些通常占用数GB空间）
            let keyPatterns = [
                "com.apple.coresymbolicationd",
                "com.apple.iconservices",
                "com.apple.Metal",
                "com.apple.WebKit",
                "com.apple.bird",
                "com.apple.CoreSimulator",
                "com.apple.Spotlight"
            ]
            
            // 递归搜索函数
            func recursiveSearchForKeys(in directory: URL, depth: Int, maxDepth: Int = 5) {
                guard depth < maxDepth else { return }
                guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey]) else { return }
                
                for itemURL in contents {
                    let itemName = itemURL.lastPathComponent
                    
                    // 检查是否匹配关键模式
                    let isKeyCache = keyPatterns.contains { pattern in
                        itemName.contains(pattern)
                    }
                    
                    if isKeyCache {
                        let size = calculateSize(at: itemURL)
                        if size > 1024 { // > 1KB
                            let displayName = itemName
                                .replacingOccurrences(of: "com.apple.", with: "Apple ")
                            items.append(CleanerFileItem(
                                url: itemURL,
                                name: displayName,
                                size: size,
                                groupId: "systemCache"
                            ))
                        }
                    }
                    
                    // 继续递归（但避免扫描太深）
                    if (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                        recursiveSearchForKeys(in: itemURL, depth: depth + 1, maxDepth: maxDepth)
                    }
                }
            }
            
            // 从 /private/var/folders 开始递归
            recursiveSearchForKeys(in: privateVarFolders, depth: 0, maxDepth: 5)
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
        
        // 检查下载的 DMG/PKG 安装包及压缩包 (扩展到通用下载残留)
        let downloadsURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        if let contents = try? fileManager.contentsOfDirectory(at: downloadsURL, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) {
            let junkExtensions = ["dmg", "pkg", "app", "iso", "ipsw", "zip", "rar", "7z", "tar", "gz", "tgz"]
            
            for itemURL in contents {
                let ext = itemURL.pathExtension.lowercased()
                if junkExtensions.contains(ext) {
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
        
        // 获取所有已安装应用的信息
        let appInfo = getInstalledAppInfo()
        let installedAppBundleIds = appInfo.bundleIds
        
        // 临时存储应用分组数据
        var groupsMap: [String: AppCacheGroup] = [:] // Key: bundleId or lowerAppName
        
        // 辅助闭包：由路径或 ID 找出最匹配的应用信息
        let findAppInfo: (String) -> (name: String, path: URL, bundleId: String?)? = { id in
            let lowerId = id.lowercased()
            // 1. 尝试 Bundle ID 完全匹配
            if let info = appInfo.appMap[lowerId] { return info }
            
            // 2. 尝试寻找最佳（最长）匹配
            // 避免短词（如 "Google"）误匹配长词（如 "Google Antigravity" 应优先匹配 "Antigravity" 如果存在）
            var bestMatch: (info: (name: String, path: URL, bundleId: String?), score: Int)? = nil
            let minMatchLength = 3
            
            for (key, info) in appInfo.appMap {
                // key 必须足够长才允许被包含匹配
                if key.count < minMatchLength { continue }
                
                // 计算匹配分数 (key 长度)
                // 优先匹配更具体的应用名
                if lowerId.contains(key) {
                    // ID 包含 AppKey (e.g. com.google.Chrome contains Chrome)
                    let score = key.count
                    if score > (bestMatch?.score ?? 0) {
                        bestMatch = (info, score)
                    }
                } else if key.contains(lowerId) {
                    // AppKey 包含 ID (e.g. Google Chrome contains Chrome)
                    let score = lowerId.count
                    if score > (bestMatch?.score ?? 0) {
                        bestMatch = (info, score)
                    }
                }
            }
            return bestMatch?.info
        }
        
        // 辅助闭包：添加文件到组或散项
        let addItem: (CleanerFileItem, String) -> Void = { item, appIdentifier in
            if let info = findAppInfo(appIdentifier) {
                let groupKey = info.bundleId ?? info.name.lowercased()
                if let group = groupsMap[groupKey] {
                    group.files.append(item)
                    // groupsMap[groupKey] = group // 引用类型无需重新赋值
                } else {
                    let icon = NSWorkspace.shared.icon(forFile: info.path.path)
                    groupsMap[groupKey] = AppCacheGroup(
                        appName: info.name,
                        bundleId: info.bundleId,
                        icon: icon,
                        files: [item]
                    )
                }
            } else {
                // 找不到明确应用关联的，也尝试从 URL 获取图标并可能单独列出 (此处先加入全局 items)
                items.append(item)
            }
        }
        
        // 1. 扫描整个 ~/Library/Caches 目录
        let cacheURL = home.appendingPathComponent("Library/Caches")
        if let contents = try? fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil) {
            for itemURL in contents {
                let size = calculateSize(at: itemURL)
                if size > 50 * 1024 {
                    let bundleId = itemURL.lastPathComponent
                    let isOrphan = isOrphanedFile(bundleId: bundleId, installedIds: installedAppBundleIds)
                    let displayName = formatAppName(bundleId)
                    
                    let fileItem = CleanerFileItem(
                        url: itemURL,
                        name: isOrphan ? "⚠️ \(displayName) (已卸载)" : displayName,
                        size: size,
                        groupId: "userCache",
                        isDirectory: true // 这些根目录通常是文件夹
                    )
                    
                    if !isOrphan {
                        addItem(fileItem, bundleId)
                    } else {
                        items.append(fileItem)
                    }
                }
            }
        }
        
        // 2. 扫描 ~/Library/Containers 中的缓存
        let containersURL = home.appendingPathComponent("Library/Containers")
        if let containers = try? fileManager.contentsOfDirectory(at: containersURL, includingPropertiesForKeys: nil) {
            for containerURL in containers {
                let bundleId = containerURL.lastPathComponent
                let isOrphan = isOrphanedFile(bundleId: bundleId, installedIds: installedAppBundleIds)
                let appName = formatAppName(bundleId)
                
                // 扫描容器的 Data/Library/Caches
                let containerCacheURL = containerURL.appendingPathComponent("Data/Library/Caches")
                if fileManager.fileExists(atPath: containerCacheURL.path) {
                    let size = calculateSize(at: containerCacheURL)
                    if size > 50 * 1024 {
                        let fileItem = CleanerFileItem(
                            url: containerCacheURL,
                            name: isOrphan ? "⚠️ \(appName) 容器缓存 (已卸载)" : "\(appName) 容器缓存",
                            size: size,
                            groupId: "userCache"
                        )
                        if !isOrphan {
                            addItem(fileItem, bundleId)
                        } else {
                            items.append(fileItem)
                        }
                    }
                }
                
                // 扫描容器的临时文件
                let containerTmpURL = containerURL.appendingPathComponent("Data/tmp")
                if fileManager.fileExists(atPath: containerTmpURL.path) {
                    let size = calculateSize(at: containerTmpURL)
                    if size > 50 * 1024 {
                        let fileItem = CleanerFileItem(
                            url: containerTmpURL,
                            name: "\(appName) 临时文件",
                            size: size,
                            groupId: "userCache"
                        )
                        addItem(fileItem, bundleId)
                    }
                }
            }
        }
        
        // 3. 扫描 ~/Library/Saved Application State
        let runningAppIds = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier?.lowercased() })
        let savedStateURL = home.appendingPathComponent("Library/Saved Application State")
        if let contents = try? fileManager.contentsOfDirectory(at: savedStateURL, includingPropertiesForKeys: nil) {
            for itemURL in contents {
                let bundleId = itemURL.lastPathComponent.replacingOccurrences(of: ".savedState", with: "")
                if runningAppIds.contains(bundleId.lowercased()) { continue }
                
                let size = calculateSize(at: itemURL)
                if size > 5 * 1024 {
                    let isOrphan = isOrphanedFile(bundleId: bundleId, installedIds: installedAppBundleIds)
                    let fileItem = CleanerFileItem(
                        url: itemURL,
                        name: isOrphan ? "⚠️ \(formatAppName(bundleId)) 状态 (已卸载)" : "\(formatAppName(bundleId)) 状态",
                        size: size,
                        groupId: "userCache"
                    )
                    if !isOrphan {
                        addItem(fileItem, bundleId)
                    } else {
                        items.append(fileItem)
                    }
                }
            }
        }
        
        // 4. 扫描 ~/Library/Application Support 中的缓存目录
        let appSupportURL = home.appendingPathComponent("Library/Application Support")
        if let apps = try? fileManager.contentsOfDirectory(at: appSupportURL, includingPropertiesForKeys: nil) {
            for appURL in apps {
                let appName = appURL.lastPathComponent
                let isOrphan = isOrphanedAppSupport(dirName: appName, installedIds: installedAppBundleIds)
                
                for cacheDirName in ["Cache", "Caches", "cache", "GPUCache", "Code Cache", "ShaderCache"] {
                    let cacheDir = appURL.appendingPathComponent(cacheDirName)
                    if fileManager.fileExists(atPath: cacheDir.path) {
                        let size = calculateSize(at: cacheDir)
                        if size > 50 * 1024 {
                            let fileItem = CleanerFileItem(
                                url: cacheDir,
                                name: isOrphan ? "⚠️ \(appName) \(cacheDirName) (已卸载)" : "\(appName) \(cacheDirName)",
                                size: size,
                                groupId: "userCache"
                            )
                            if !isOrphan {
                                addItem(fileItem, appName)
                            } else {
                                items.append(fileItem)
                            }
                        }
                    }
                }
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
        
        // 11. 开发者工具缓存 (IDEA, VSCode, Cursor, Navicat 等)
        let developerPaths: [(name: String, path: String, appIdentifier: String)] = [
            // JetBrains / IDEA
            ("JetBrains Caches", "Library/Caches/JetBrains", "jetbrains"),
            ("JetBrains Logs", "Library/Logs/JetBrains", "jetbrains"),
            
            // VSCode
            ("VSCode Caches", "Library/Caches/com.microsoft.VSCode", "com.microsoft.VSCode"),
            ("VSCode CachedData", "Library/Application Support/Code/CachedData", "com.microsoft.VSCode"),
            ("VSCode Workspace Storage", "Library/Application Support/Code/User/workspaceStorage", "com.microsoft.VSCode"),
            
            // Cursor
            ("Cursor Caches", "Library/Caches/com.tull.cursor", "com.tull.cursor"),
            ("Cursor Caches", "Library/Caches/Cursor", "com.tull.cursor"),
            ("Cursor Workspace Storage", "Library/Application Support/Cursor/User/workspaceStorage", "com.tull.cursor"),
            ("Cursor CachedData", "Library/Application Support/Cursor/CachedData", "com.tull.cursor"),
            
            // Navicat
            ("Navicat Caches", "Library/Caches/com.prect.Navicat", "com.prect.Navicat"),
            ("Navicat Premium Caches", "Library/Caches/com.prect.NavicatPremium", "com.prect.NavicatPremium"),
            
            // Antigravity & Kiro (用户指定)
            ("Antigravity Caches", "Library/Caches/antigravity", "antigravity"),
            ("Kiro Caches", "Library/Caches/kiro", "kiro")
        ]
        
        for devApp in developerPaths {
            let url = home.appendingPathComponent(devApp.path)
            if fileManager.fileExists(atPath: url.path) {
                let size = calculateSize(at: url)
                if size > 1024 * 1024 { // > 1MB 才显示
                    let fileItem = CleanerFileItem(
                        url: url,
                        name: "🛠️ \(devApp.name)",
                        size: size,
                        groupId: "userCache"
                    )
                    addItem(fileItem, devApp.appIdentifier)
                }
            }
        }
        
        // 9. 更新服务状态
        let finalGroups = Array(groupsMap.values).sorted { $0.totalSize > $1.totalSize }
        await MainActor.run {
            self.appCacheGroups = finalGroups
        }
        
        return items.sorted { $0.size > $1.size }
    }
    
    // MARK: - 辅助方法：获取已安装应用信息（改进版）
    /// 返回 (bundleIds, appNames, appMap) 元组，用于更精确的匹配和展示
    private func getInstalledAppInfo() -> (bundleIds: Set<String>, appNames: Set<String>, appMap: [String: (name: String, path: URL, bundleId: String?)]) {
        var bundleIds = Set<String>()
        var appNames = Set<String>()
        var appMap: [String: (name: String, path: URL, bundleId: String?)] = [:]
        
        let home = fileManager.homeDirectoryForCurrentUser
        
        // 1. 扫描标准应用目录
        let appDirs = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            home.appendingPathComponent("Applications").path
        ]
        
        for appDir in appDirs {
            if let apps = try? fileManager.contentsOfDirectory(atPath: appDir) {
                for app in apps where app.hasSuffix(".app") {
                    let appPathString = (appDir as NSString).appendingPathComponent(app)
                    let appURL = URL(fileURLWithPath: appPathString)
                    let plistPath = appPathString + "/Contents/Info.plist"
                    
                    let appName = (app as NSString).deletingPathExtension
                    let lowerAppName = appName.lowercased()
                    appNames.insert(lowerAppName)
                    
                    if let plist = NSDictionary(contentsOfFile: plistPath),
                       let bundleId = plist["CFBundleIdentifier"] as? String {
                        let lowerBundleId = bundleId.lowercased()
                        bundleIds.insert(bundleId)
                        bundleIds.insert(lowerBundleId)
                        
                        let info = (name: appName, path: appURL, bundleId: bundleId)
                        appMap[lowerBundleId] = info
                        appMap[lowerAppName] = info
                        
                        // 提取 Bundle ID 的最后一个组件作为备用匹配
                        if let lastComponent = bundleId.components(separatedBy: ".").last {
                            let lowerLast = lastComponent.lowercased()
                            appNames.insert(lowerLast)
                            if appMap[lowerLast] == nil {
                                appMap[lowerLast] = info
                            }
                        }
                    } else {
                        // 如果没有 Bundle ID，也根据名称记录
                        let info = (name: appName, path: appURL, bundleId: nil as String?)
                        appMap[lowerAppName] = info
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
                    let lowerCask = cask.lowercased()
                    appNames.insert(lowerCask)
                    // 如果 Cask 下有应用，尝试获取其实际信息（简化处理：仅记录名称）
                }
            }
        }
        
        // 3. 添加正在运行的应用（最重要的安全检查）
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if let bundleId = app.bundleIdentifier {
                let lowerBundleId = bundleId.lowercased()
                bundleIds.insert(bundleId)
                bundleIds.insert(lowerBundleId)
                
                if let name = app.localizedName {
                    let lowerName = name.lowercased()
                    appNames.insert(lowerName)
                    if appMap[lowerBundleId] == nil && appMap[lowerName] == nil {
                        // 尝试为运行的应用查找路径
                        if let appURL = app.bundleURL {
                            appMap[lowerBundleId] = (name: name, path: appURL, bundleId: bundleId)
                        }
                    }
                }
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
        
        return (bundleIds, appNames, appMap)
    }
    
    // 保留旧方法以兼容现有调用
    private func getInstalledAppBundleIds() -> Set<String> {
        return getInstalledAppInfo().bundleIds
    }
    
    // MARK: - 辅助方法：检测是否为已卸载应用的残留（改进版）
    private func isOrphanedFile(bundleId: String, installedIds: Set<String>) -> Bool {
        let lowerBundleId = bundleId.lowercased()
        
        // 0. 跳过以 . 开头的系统隐藏偏好设置文件
        // 这些文件存储全局系统设置，如 .GlobalPreferences.plist（自然滚动、语言等）
        if bundleId.hasPrefix(".") { return false }
        
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
    // MARK: - 语言文件扫描
    private func scanLanguageFiles() async -> [CleanerFileItem] {
        var items: [CleanerFileItem] = []
        let fileManager = FileManager.default
        
        // 1. 获取用户偏好语言列表
        // 保留英语 (Base, en) 和用户首选语言
        var keepLanguages: Set<String> = ["Base", "en", "English"]
        
        // 添加用户当前系统语言
        for lang in Locale.preferredLanguages {
            // lang 格式可能是 "zh-Hans-CN", "en-US" 等
            // 我们需要提取主要部分，例如 "zh", "zh-Hans"
            // lang 格式可能是 "zh-Hans-CN", "en-US" 等
            let parts = lang.split(separator: "-").map(String.init)
            if let languageCode = parts.first {
                keepLanguages.insert(languageCode)
                if parts.count > 1 {
                    let secondPart = parts[1]
                    // 检查第二个部分是否是 Script (Hans, Hant 等，通常是 4 个字母)
                    if secondPart.count == 4 {
                        keepLanguages.insert("\(languageCode)-\(secondPart)")
                        keepLanguages.insert("\(languageCode)_\(secondPart)")
                    }
                }
            }
            keepLanguages.insert(lang)
        }
        
        // 2. 扫描应用程序目录
        let appDirs = [
            "/Applications",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path,
            "/Library/Application Support" // 增加 Application Support 扫描，有些应用数据存在这里
        ]
        
        for appDir in appDirs {
            guard let apps = try? fileManager.contentsOfDirectory(atPath: appDir) else { continue }
            
            for appName in apps where appName.hasSuffix(".app") {
                let appPath = (appDir as NSString).appendingPathComponent(appName)
                let appURL = URL(fileURLWithPath: appPath)
                
                // --- 安全检查 ---
                
                // 跳过系统应用 (com.apple.)
                let plistPath = appURL.appendingPathComponent("Contents/Info.plist")
                if let plist = NSDictionary(contentsOfFile: plistPath.path),
                   let bundleId = plist["CFBundleIdentifier"] as? String {
                    if bundleId.hasPrefix("com.apple.") { continue }
                }
                
                // 跳过 App Store 应用 (_MASReceipt) - 修改签名会导致无法运行
                let receiptPath = appURL.appendingPathComponent("Contents/_MASReceipt")
                if fileManager.fileExists(atPath: receiptPath.path) {
                    continue
                }
                
                // SIP 保护检查 (略，通常 /Applications 下的非系统应用可修改，但需注意)
                
                // --- 扫描 Resources ---
                
                let resourcesURL = appURL.appendingPathComponent("Contents/Resources")
                guard let resources = try? fileManager.contentsOfDirectory(at: resourcesURL, includingPropertiesForKeys: nil) else { continue }
                
                for itemURL in resources where itemURL.pathExtension == "lproj" {
                    let langName = itemURL.deletingPathExtension().lastPathComponent
                    
                    // 检查是否在保留列表中
                    // 模糊匹配：如果 keepLanguages 包含 langName 的前缀，或者 langName 包含 keepLanguages 的元素
                    let shouldKeep = keepLanguages.contains { keep in
                        // 精确匹配
                        if keep.lowercased() == langName.lowercased() { return true }
                        // zh-Hans 匹配 zh-Hans.lproj
                        if langName.lowercased().hasPrefix(keep.lowercased()) { return true }
                        return false
                    }
                    
                    if !shouldKeep {
                        let size = calculateSize(at: itemURL)
                        if size > 0 {
                            items.append(CleanerFileItem(
                                url: itemURL,
                                name: "\(appName) - \(langName)",
                                size: size,
                                groupId: "languageFiles"
                            ))
                        }
                    }
                }
            }
        }
        
        return items.sorted { $0.size > $1.size }
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
            
            // 使用 directoryEnumerator 进行递归扫描，跳过隐藏文件
            if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) {
                while let fileURL = enumerator.nextObject() as? URL {
                    let ext = fileURL.pathExtension.lowercased()
                    // 扩展检查范围
                    if ["log", "txt", "crash", "diag", "out", "err", "panic"].contains(ext) || fileURL.lastPathComponent.contains("log") {
                        if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                           let size = values.fileSize, size > 0 {
                            // 确保不是目录
                            if let isDir = values.isDirectory, !isDir {
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
        }
        
        return items.sorted { $0.size > $1.size }
    }
    
    // MARK: - 用户日志扫描
    private func scanUserLogs() async -> [CleanerFileItem] {
        var items: [CleanerFileItem] = []
        let home = fileManager.homeDirectoryForCurrentUser
        
        // 1. 标准日志目录 ~/Library/Logs
        let logsURL = home.appendingPathComponent("Library/Logs")
        
        if fileManager.fileExists(atPath: logsURL.path) {
            if let enumerator = fileManager.enumerator(at: logsURL, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) {
                while let fileURL = enumerator.nextObject() as? URL {
                    if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                       let isDir = values.isDirectory, !isDir,
                       let size = values.fileSize, size > 0 {
                        // 简单检查是否看起来像日志文件（可选，但 userLogs 目录里一般都是日志）
                        items.append(CleanerFileItem(
                            url: fileURL,
                            name: fileURL.lastPathComponent,
                            size: Int64(size),
                            groupId: "userLogs"
                        ))
                    }
                }
            }
        }
        
        // 2. 扫描 ~/Library/Application Support 中的 .log 文件
        // 用户提到"应用参数日志文件"，通常隐藏在 App Support 中
        let appSupportURL = home.appendingPathComponent("Library/Application Support")
        if fileManager.fileExists(atPath: appSupportURL.path) {
             if let enumerator = fileManager.enumerator(at: appSupportURL, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) {
                while let fileURL = enumerator.nextObject() as? URL {
                    // 只关心 .log 文件，严格匹配扩展名防误删
                    if fileURL.pathExtension.lowercased() == "log" {
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
                }
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
        
        let _ = allSizeResults.count
        
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
        
        while let fileURL = enumerator.nextObject() as? URL {
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
            while let fileURL = enumerator.nextObject() as? URL {
                let ext = fileURL.pathExtension.lowercased()
                if ["jpg", "jpeg", "png", "heic", "heif", "tiff"].contains(ext) {
                    totalCount += 1
                }
            }
        }
        
        // 计算图片特征
        if let enumerator = fileManager.enumerator(at: picturesDir, includingPropertiesForKeys: [.fileSizeKey]) {
            while let fileURL = enumerator.nextObject() as? URL {
                let ext = fileURL.pathExtension.lowercased()
                guard ["jpg", "jpeg", "png", "heic", "heif", "tiff"].contains(ext) else { continue }
                
                processedCount += 1
                await MainActor.run { [processedCount, totalCount] in
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
        let applicationsDir = URL(fileURLWithPath: "/Applications")
        let sharedDir = URL(fileURLWithPath: "/Users/Shared")
        
        // 获取所有可访问的卷 (排除系统引导卷，以免重复扫描)
        var scanTargets: [URL] = [applicationsDir, sharedDir]
        
        // 1. 获取家目录下所有二级目录
        var homeRootLargeFiles: [CleanerFileItem] = []
        if let homeContents = try? fileManager.contentsOfDirectory(at: homeDir, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) {
            for url in homeContents {
                let name = url.lastPathComponent
                if name == "Library" { continue }
                
                guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) else { continue }
                
                if values.isDirectory == true {
                    scanTargets.append(url)
                } else if let size = values.fileSize, Int64(size) >= minSize {
                    homeRootLargeFiles.append(CleanerFileItem(url: url, name: url.lastPathComponent, size: Int64(size), groupId: "large"))
                }
            }
        }
        
        // 2. 获取其他卷 (如外置硬盘)
        if let volumes = try? fileManager.contentsOfDirectory(at: URL(fileURLWithPath: "/Volumes"), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for vol in volumes {
                let name = vol.lastPathComponent
                // 排除一些系统保留或特殊的挂载点 (通常 Macintosh HD 是指向根目录的连接或挂载)
                if name == "Macintosh HD" || name == "Preboot" || name == "Recovery" || name == "VM" {
                    continue
                }
                scanTargets.append(vol)
            }
        }
        
        // 并行扫描所有目录
        let collector = ScanResultCollector<CleanerFileItem>()
        // 预存家目录根文件
        for file in homeRootLargeFiles {
            await collector.append(file)
        }
        
        let progressTracker = ScanProgressTracker()
        await progressTracker.setTotalTasks(scanTargets.count)
        
        await withTaskGroup(of: [CleanerFileItem].self) { group in
            for dirURL in scanTargets {
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
        
        while let fileURL = enumerator.nextObject() as? URL {
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
                        if DeletionLogService.shared.logAndDelete(at: duplicateGroups[i].files[j].url, category: "Duplicates") {
                            freedSize += duplicateGroups[i].files[j].size
                            success += 1
                        } else {
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
                        if DeletionLogService.shared.logAndDelete(at: similarPhotoGroups[i].files[j].url, category: "SimilarPhotos") {
                            freedSize += similarPhotoGroups[i].files[j].size
                            success += 1
                        } else {
                            failed += 1
                        }
                    }
                }
            }
            await scanSimilarPhotos()
            
        case .localizations:
            for file in localizationFiles where file.isSelected {
                // ⚠️ 安全修复: 使用 DeletionLogService 记录并删除
                if DeletionLogService.shared.logAndDelete(at: file.url, category: "Localizations") {
                    freedSize += file.size
                    success += 1
                } else {
                    failed += 1
                    print("[SmartCleaner] ⚠️ Failed to delete localization: \(file.name)")
                }
            }
            await scanLocalizations()
            
        case .largeFiles:
            for file in largeFiles where file.isSelected {
                if DeletionLogService.shared.logAndDelete(at: file.url, category: "LargeFiles") {
                    freedSize += file.size
                    success += 1
                } else {
                    failed += 1
                }
            }
            await scanLargeFiles()
            
        case .systemJunk, .systemCache, .oldUpdates, .userCache, .languageFiles, .systemLogs, .userLogs, .brokenLoginItems, .virus, .appUpdates, .startupItems, .performanceApps:
            // 系统垃圾及新类别使用统一清理或专用方法
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
        case .virus:
            return virusThreats.count
        case .appUpdates:
            return hasAppUpdates ? 1 : 0
        case .startupItems:
            return startupItems.count
        case .performanceApps:
            return performanceApps.count
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
        case .virus:
            return virusThreats.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        case .systemJunk, .systemCache, .oldUpdates, .userCache, .languageFiles, .systemLogs, .userLogs, .brokenLoginItems, .appUpdates, .startupItems, .performanceApps:
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
        
        // 新增重置
        appCacheGroups = []
        virusThreats = []
        startupItems = []
        performanceApps = []
        hasAppUpdates = false
    }
    
    // MARK: - 一键扫描所有
    func scanAll() async {
        // 重置停止标志和已扫描分类
        await MainActor.run { 
            shouldStopScanning = false
            scannedCategories = []
            scanProgress = 0.0
            isScanning = true
        }
        
        // --- 1. 系统垃圾 (仅缓存和日志) ---
        await MainActor.run { currentCategory = .systemJunk; currentScanPath = "Scanning for system junk..." }
        await scanSystemJunk()
        await MainActor.run { _ = scannedCategories.insert(.systemJunk); scanProgress = 0.125 }
        if shouldStopScanning { return }
        
        // --- 2. 重复文件 ---
        await MainActor.run { currentCategory = .duplicates; currentScanPath = "Searching for duplicates..." }
        await scanDuplicates()
        await MainActor.run { _ = scannedCategories.insert(.duplicates); scanProgress = 0.25 }
        if shouldStopScanning { return }
        
        // --- 3. 相似照片 ---
        await MainActor.run { currentCategory = .similarPhotos; currentScanPath = "Finding similar photos..." }
        await scanSimilarPhotos()
        await MainActor.run { _ = scannedCategories.insert(.similarPhotos); scanProgress = 0.375 }
        if shouldStopScanning { return }
        
        // --- 4. 大文件 ---
        await MainActor.run { currentCategory = .largeFiles; currentScanPath = "Scanning for large files..." }
        await scanLargeFiles()
        await MainActor.run { _ = scannedCategories.insert(.largeFiles); scanProgress = 0.5 }
        if shouldStopScanning { return }
        
        // --- 5. 病毒扫描 ---
        await MainActor.run { currentCategory = .virus; currentScanPath = "Scanning for threats..." }
        await malwareScanner.scan()
        await MainActor.run { 
            self.virusThreats = self.malwareScanner.threats
            _ = scannedCategories.insert(.virus)
            scanProgress = 0.625
        }
        if shouldStopScanning { return }
        
        // --- 6. 启动项扫描 ---
        await MainActor.run { currentCategory = .startupItems; currentScanPath = "Scanning startup items..." }
        await systemOptimizer.scanLaunchAgents()
        await MainActor.run { 
            self.startupItems = self.systemOptimizer.launchAgents.filter { $0.isEnabled }
            _ = scannedCategories.insert(.startupItems)
            scanProgress = 0.75
        }
        if shouldStopScanning { return }
        
        // --- 7. 性能优化 (后台应用) ---
        await MainActor.run { currentCategory = .performanceApps; currentScanPath = "Analyzing performance..." }
        await MainActor.run {
            self.systemOptimizer.scanRunningApps()
            self.systemOptimizer.selectAllApps(true) 
            self.performanceApps = self.systemOptimizer.runningApps
            _ = scannedCategories.insert(.performanceApps)
            scanProgress = 0.875
        }
        if shouldStopScanning { return }
        
        // --- 8. 应用更新检查 ---
        await MainActor.run { currentCategory = .appUpdates; currentScanPath = "Checking for updates..." }
        await updateChecker.checkForUpdates()
        await MainActor.run { 
            self.hasAppUpdates = self.updateChecker.hasUpdate
            _ = scannedCategories.insert(.appUpdates)
            scanProgress = 1.0
        }
        if shouldStopScanning { return }

        
        // 扫描结束
        await MainActor.run {
            isScanning = false
            currentScanPath = ""
        }
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
        
        // 辅助函数:安全删除文件
        func safeDelete(file: CleanerFileItem) -> Bool {
            let url = file.url
            let path = url.path
            
            // ⚠️ 安全修复: 使用SafetyGuard检查
            if !SafetyGuard.shared.isSafeToDelete(url) {
                print("[SmartCleaner] 🛡️ SafetyGuard blocked deletion: \(path)")
                failedFiles.append(file)
                return false
            }
            
            // 特殊处理:如果是废纸篓中的文件,可以直接删除
            if path.contains("/.Trash/") || path.hasSuffix("/.Trash") {
                do {
                    try fileManager.removeItem(at: url)
                    print("[SmartCleaner] ✅ Deleted trash file: \(file.name)")
                    return true
                } catch {
                    print("[SmartCleaner] ⚠️ Failed to delete trash file: \(error)")
                    failedFiles.append(file)
                    return false
                }
            }
            
            // 1. 检查文件是否可写/可删除
            if !fileManager.isDeletableFile(atPath: path) {
                failedFiles.append(file)
                return false
            }
            
            // 2. 🛡️ 使用 DeletionLogService 安全删除并记录日志
            // 这样文件可以从废纸篓恢复到原位置
            if DeletionLogService.shared.logAndDelete(at: url, category: "SmartClean") {
                print("[SmartCleaner] ✅ Moved to trash with log: \(file.name)")
                return true
            } else {
                print("[SmartCleaner] ⚠️ Failed to delete: \(file.name)")
                failedFiles.append(file)
                return false
            }
        }
        
        // 1. 清理系统垃圾
        await MainActor.run {
            cleaningCurrentCategory = .systemJunk
            cleaningDescription = "Cleaning System Junk..."
        }
        
        // 执行各子步骤清理...
        // 用户缓存 (包括散项和按应用分组的项目)
        for file in userCacheFiles where file.isSelected {
            if safeDelete(file: file) {
                totalSize += file.size
                totalSuccess += 1
            } else { totalFailed += 1 }
        }
        
        for group in appCacheGroups {
            for file in group.files where file.isSelected {
                if safeDelete(file: file) {
                    totalSize += file.size
                    totalSuccess += 1
                } else { totalFailed += 1 }
            }
        }
        
        // 系统缓存
        for file in systemCacheFiles {
            if safeDelete(file: file) {
                totalSize += file.size
                totalSuccess += 1
            } else { totalFailed += 1 }
        }
        
        // 旧更新
        for file in oldUpdateFiles {
            if safeDelete(file: file) {
                totalSize += file.size
                totalSuccess += 1
            } else { totalFailed += 1 }
        }
        
        // 语言文件
        for file in languageFiles {
            if safeDelete(file: file) {
                totalSize += file.size
                totalSuccess += 1
            } else { totalFailed += 1 }
        }
        
        // 日志
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
        
        // 损坏的登录项 - 这些通常只是 plist，但也可能需要权限
        for file in brokenLoginItems {
            if safeDelete(file: file) {
                totalSize += file.size
                totalSuccess += 1
            } else { totalFailed += 1 }
        }
        
        await MainActor.run { _ = cleanedCategories.insert(.systemJunk) }
        
        // 2. 清理重复文件
        if !duplicateGroups.isEmpty {
            await MainActor.run {
                cleaningCurrentCategory = .duplicates
                cleaningDescription = "Cleaning Duplicates..."
            }
            for i in 0..<duplicateGroups.count {
                for j in 1..<duplicateGroups[i].files.count { // 保留第一个
                    if safeDelete(file: duplicateGroups[i].files[j]) {
                        totalSize += duplicateGroups[i].files[j].size
                        totalSuccess += 1
                    } else { totalFailed += 1 }
                }
            }
            await MainActor.run { _ = cleanedCategories.insert(.duplicates) }
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
            await MainActor.run { _ = cleanedCategories.insert(.similarPhotos) }
        }
        
        // 4. 清理多语言本地化文件
        if !localizationFiles.isEmpty {
            await MainActor.run {
                cleaningCurrentCategory = .localizations
                cleaningDescription = "Cleaning Localizations..."
            }
            for file in localizationFiles { // 这里的都是选中的
                 if file.isSelected {
                     if safeDelete(file: file) {
                        totalSize += file.size
                        totalSuccess += 1
                    } else { totalFailed += 1 }
                 }
            }
            await MainActor.run { _ = cleanedCategories.insert(.localizations) }
        }
        
        // 5. 清理大文件
        if !largeFiles.isEmpty {
            await MainActor.run {
                cleaningCurrentCategory = .largeFiles
                cleaningDescription = "Cleaning Large Files..."
            }
            for file in largeFiles where file.isSelected {
                 if safeDelete(file: file) {
                    totalSize += file.size
                    totalSuccess += 1
                } else { totalFailed += 1 }
            }
            await MainActor.run { _ = cleanedCategories.insert(.largeFiles) }
        }
        
        // 6. 清理病毒
        if !virusThreats.isEmpty {
            await MainActor.run {
                cleaningCurrentCategory = .virus
                cleaningDescription = "Removing Threats..."
            }
            let (vSuccess, vFailed) = await malwareScanner.removeThreats()
            totalSuccess += vSuccess
            totalFailed += vFailed
            // Virus size is approximate or pre-calculated
            totalSize += virusTotalSize 
             await MainActor.run { _ = cleanedCategories.insert(.virus) }
        }
        
        // 7. 优化启动项
        if !startupItems.isEmpty {
            await MainActor.run {
                cleaningCurrentCategory = .startupItems
                cleaningDescription = "Disabling Startup Items..."
            }
            for item in startupItems where item.isSelected {
                if await systemOptimizer.toggleAgent(item) {
                    totalSuccess += 1
                } else {
                    totalFailed += 1
                }
            }
             await MainActor.run { _ = cleanedCategories.insert(.startupItems) }
        }
        
        // 8. 性能优化 (关闭后台应用)
        if !performanceApps.isEmpty {
            await MainActor.run {
                cleaningCurrentCategory = .performanceApps
                cleaningDescription = "Optimizing Performance..."
            }
            // 确保 SystemOptimizer 里的 runningApps 被选中
             await MainActor.run {
                 for app in self.performanceApps where app.isSelected {
                     // Sync selection just in case
                     if let optimizerApp = self.systemOptimizer.runningApps.first(where: { $0.id == app.id }) {
                         optimizerApp.isSelected = true
                     }
                 }
             }
            let killed = await systemOptimizer.terminateSelectedApps()
            totalSuccess += killed
             await MainActor.run { _ = cleanedCategories.insert(.performanceApps) }
        }
        
        // 9. 应用更新
        if hasAppUpdates {
            await MainActor.run {
                cleaningCurrentCategory = .appUpdates
                cleaningDescription = "Updating Apps..."
            }
            // 触发更新下载或打开页面? 
            if let url = updateChecker.downloadURL {
                NSWorkspace.shared.open(url)
                totalSuccess += 1
            }
             await MainActor.run { _ = cleanedCategories.insert(.appUpdates) }
        }

        // 10. 提权清理失败的文件
        if !failedFiles.isEmpty {
            let (sudoSuccess, _, sudoSize) = await cleanWithPrivileges(files: failedFiles)
            totalSuccess += sudoSuccess
            // 如果提权删除成功，原来的 totalFailed 需要减去这些成功的
            totalFailed -= sudoSuccess 
            totalSize += sudoSize
            
            // 更新 failedFiles 列表，移除那些已成功删除的
            // 简单的方法是重新检查存在性
             var remainingFailed: [CleanerFileItem] = []
             for file in failedFiles {
                 if fileManager.fileExists(atPath: file.url.path) {
                     remainingFailed.append(file)
                 }
             }
             failedFiles = remainingFailed
        }
        
        // 刷新所有数据
        await MainActor.run { [failedFiles] in
            // 只移除成功的，保留失败的
            let failedSet = Set(failedFiles.map(\.url))
            
            userCacheFiles = userCacheFiles.filter { failedSet.contains($0.url) }
            systemCacheFiles = systemCacheFiles.filter { failedSet.contains($0.url) }
            oldUpdateFiles = oldUpdateFiles.filter { failedSet.contains($0.url) }
            languageFiles = languageFiles.filter { failedSet.contains($0.url) }
            systemLogFiles = systemLogFiles.filter { failedSet.contains($0.url) }
            userLogFiles = userLogFiles.filter { failedSet.contains($0.url) }
            brokenLoginItems = brokenLoginItems.filter { failedSet.contains($0.url) }
            
            // 对于 duplicateGroups 和 similarPhotoGroups，重新扫描比较好，因为结构变了
            // 这里简单处理：如果某个文件还在，就保留它
             duplicateGroups = duplicateGroups.map { group in
                 DuplicateGroup(hash: group.hash, files: group.files.filter { failedSet.contains($0.url) || $0 == group.files.first })
             }.filter { $0.files.count > 1 }
            
             similarPhotoGroups = similarPhotoGroups.map { group in
                 DuplicateGroup(hash: group.hash, files: group.files.filter { failedSet.contains($0.url) || $0 == group.files.first })
             }.filter { $0.files.count > 1 }
            
            localizationFiles = localizationFiles.filter { failedSet.contains($0.url) || !$0.isSelected}
            largeFiles = largeFiles.filter { failedSet.contains($0.url) || !$0.isSelected }
            
            // 最终状态更新
            cleaningCurrentCategory = nil
            
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
        case .systemJunk, .systemCache, .oldUpdates, .userCache, .languageFiles, .systemLogs, .userLogs, .brokenLoginItems, .appUpdates:
            // 系统垃圾类别暂不支持单独选择
            break
        case .virus:
             // Virus threats don't have isSelected in DetectedThreat struct? 
             // Wait, DetectedThreat in MalwareScanner doesn't have isSelected? 
             // If not, we can't select. But usually generic CleanerFileItem has it.
             // Let's assume we can't or it's implicitly all.
             break
        case .startupItems:
             // Startup items usually don't have bulk select
             break
        case .performanceApps:
             for app in performanceApps {
                 app.isSelected = selected
             }
        }
    }
    
    // 总可清理大小（只计算已选中的文件）
    var totalCleanableSize: Int64 {
        // 系统垃圾分类
        let userCacheSize = userCacheFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        let systemCacheSize = systemCacheFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        let oldUpdatesSize = oldUpdateFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        let languageFilesSize = languageFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        let systemLogsSize = systemLogFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        let userLogsSize = userLogFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        let brokenLoginItemsSize = brokenLoginItems.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        
        // 重复文件（只计算选中的文件）
        let dupSize = duplicateGroups.flatMap { $0.files }.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        
        // 相似照片（只计算选中的文件）
        let photoSize = similarPhotoGroups.flatMap { $0.files }.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        
        // 本地化文件
        let locSize = localizationFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        
        // 大文件
        let largeSize = largeFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        
        // 病毒威胁
        let virusSize = virusThreats.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        
        return userCacheSize + systemCacheSize + oldUpdatesSize + languageFilesSize + 
               systemLogsSize + userLogsSize + brokenLoginItemsSize + 
               dupSize + photoSize + locSize + largeSize + virusSize
    }
    
    func toggleStartupItem(_ item: LaunchItem) async {
        if await systemOptimizer.toggleAgent(item) {
            await MainActor.run {
                // Refresh local startup items list
                if let index = startupItems.firstIndex(where: { $0.id == item.id }) {
                    startupItems[index].isEnabled = item.isEnabled
                }
            }
        }
    }
}
