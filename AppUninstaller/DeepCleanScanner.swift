import SwiftUI

// MARK: - Models

struct OrphanedItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let bundleId: String?
    let size: Int64
    let type: OrphanedType
    var isSelected: Bool = true
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

enum OrphanedType: String, CaseIterable {
    case applicationSupport = "应用支持"
    case caches = "缓存文件"
    case preferences = "偏好设置"
    case containers = "沙盒容器"
    case savedState = "保存状态"
    case logs = "日志文件"
    
    var icon: String {
        switch self {
        case .applicationSupport: return "folder.fill"
        case .caches: return "externaldrive.fill"
        case .preferences: return "gearshape.fill"
        case .containers: return "shippingbox.fill"
        case .savedState: return "doc.fill"
        case .logs: return "doc.text.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .applicationSupport: return .blue
        case .caches: return .orange
        case .preferences: return .purple
        case .containers: return .green
        case .savedState: return .cyan
        case .logs: return .gray
        }
    }
}

// MARK: - Scanner

class DeepCleanScanner: ObservableObject {
    @Published var orphanedItems: [OrphanedItem] = []
    @Published var isScanning = false
    @Published var scanProgress: String = ""
    @Published var totalSize: Int64 = 0
    
    private let fileManager = FileManager.default
    private var installedBundleIds: Set<String> = []
    
    // 系统保护列表 - 不扫描这些
    private let systemPrefixes = [
        "com.apple.",
        "com.microsoft.",
        "group.com.apple.",
        "Apple",
        ".DS_Store",
        ".localized",
        "CloudKit",
        "CoreData",
        "Accounts",
        "AddressBook",
        "Calendar",
        "Cookies",
        "GameKit",
        "HomeKit",
        "KeyboardServices",
        "Keychains",
        "Mail",
        "Messages",
        "Safari",
        "Passes",
        "Photos",
        "SyncedPreferences",
        "Ubiquity"
    ]
    
    private let systemExactMatches = [
        "com.apple",
        "Accessibility",
        "Accounts",
        "Assistant",
        "Audio",
        "Bluetooth",
        "ColorPickers",
        "CoreDAV",
        "CoreData",
        "Dictionaries",
        "FaceTime",
        "FileProvider",
        "FontCollections",
        "Fonts",
        "FrontBoard",
        "GameKit",
        "GeoServices",
        "Google", // Google apps 通常用户会安装
        "HTTPStorages",
        "IdentityServices",
        "Input Methods",
        "Internet Plug-Ins",
        "iTunes",
        "Keyboard Layouts",
        "Keyboard",
        "LaunchAgents",
        "LaunchDaemons",
        "Managed Web Domains",
        "Media",
        "Metadata",
        "Mobile Documents",
        "News",
        "Passes",
        "Preferences",
        "PrivateFrameworks",
        "QuickLook",
        "Reminders",
        "Screen Savers",
        "ScreenRecordings",
        "Scripts",
        "Sounds",
        "Speech",
        "Spelling",
        "Spotlight",
        "StatusBarApps",
        "Suggestions",
        "Widgets"
    ]
    
    func scan() async {
        await MainActor.run {
            isScanning = true
            orphanedItems = []
            totalSize = 0
            scanProgress = "正在获取已安装应用列表..."
        }
        
        // 1. 获取已安装应用的 Bundle IDs
        installedBundleIds = await getInstalledBundleIds()
        
        var allItems: [OrphanedItem] = []
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let libraryURL = homeDir.appendingPathComponent("Library")
        
        // 2. 扫描各个目录
        let scanTasks: [(URL, OrphanedType)] = [
            (libraryURL.appendingPathComponent("Application Support"), .applicationSupport),
            (libraryURL.appendingPathComponent("Caches"), .caches),
            (libraryURL.appendingPathComponent("Preferences"), .preferences),
            (libraryURL.appendingPathComponent("Containers"), .containers),
            (libraryURL.appendingPathComponent("Group Containers"), .containers),
            (libraryURL.appendingPathComponent("Saved Application State"), .savedState),
            (libraryURL.appendingPathComponent("Logs"), .logs)
        ]
        
        for (url, type) in scanTasks {
            await MainActor.run {
                scanProgress = "正在扫描 \(type.rawValue)..."
            }
            
            let items = await scanDirectory(url, type: type)
            allItems.append(contentsOf: items)
        }
        
        // 3. 计算总大小
        var total: Int64 = 0
        for item in allItems {
            total += item.size
        }
        
        // 按大小排序
        let sortedItems = allItems.sorted { $0.size > $1.size }
        
        await MainActor.run {
            orphanedItems = sortedItems
            totalSize = total
            isScanning = false
            scanProgress = ""
        }
    }
    
    private func getInstalledBundleIds() async -> Set<String> {
        var bundleIds = Set<String>()
        
        let appDirs = [
            "/Applications",
            "/System/Applications",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]
        
        for dir in appDirs {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }
            
            for item in contents where item.hasSuffix(".app") {
                let appPath = (dir as NSString).appendingPathComponent(item)
                let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
                
                if let plist = NSDictionary(contentsOfFile: plistPath),
                   let bundleId = plist["CFBundleIdentifier"] as? String {
                    bundleIds.insert(bundleId.lowercased())
                    
                    // 也添加应用名称的变体
                    let appName = (item as NSString).deletingPathExtension
                    bundleIds.insert(appName.lowercased())
                }
            }
        }
        
        return bundleIds
    }
    
    private func scanDirectory(_ url: URL, type: OrphanedType) async -> [OrphanedItem] {
        var items: [OrphanedItem] = []
        
        guard fileManager.fileExists(atPath: url.path) else { return items }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
            
            for itemURL in contents {
                let itemName = itemURL.lastPathComponent
                
                // 跳过系统文件
                if isSystemItem(itemName) {
                    continue
                }
                
                // 跳过已安装应用的文件
                if isInstalledApp(itemName) {
                    continue
                }
                
                // 计算大小
                let size = calculateSize(at: itemURL)
                
                // 只添加有一定大小的项目 (>100KB)
                if size > 100 * 1024 {
                    let bundleId = extractBundleId(from: itemName)
                    let item = OrphanedItem(
                        url: itemURL,
                        name: formatDisplayName(itemName),
                        bundleId: bundleId,
                        size: size,
                        type: type
                    )
                    items.append(item)
                }
            }
        } catch {
            print("Error scanning \(url.path): \(error)")
        }
        
        return items
    }
    
    private func isSystemItem(_ name: String) -> Bool {
        let lowercaseName = name.lowercased()
        
        // 检查前缀
        for prefix in systemPrefixes {
            if lowercaseName.hasPrefix(prefix.lowercased()) {
                return true
            }
        }
        
        // 检查精确匹配
        for match in systemExactMatches {
            if lowercaseName == match.lowercased() {
                return true
            }
        }
        
        // 隐藏文件
        if name.hasPrefix(".") {
            return true
        }
        
        return false
    }
    
    private func isInstalledApp(_ name: String) -> Bool {
        let lowercaseName = name.lowercased()
            .replacingOccurrences(of: ".savedstate", with: "")
            .replacingOccurrences(of: ".plist", with: "")
            .replacingOccurrences(of: ".lockdownmode.plist", with: "")
        
        // 直接匹配
        if installedBundleIds.contains(lowercaseName) {
            return true
        }
        
        // Bundle ID 匹配
        for bundleId in installedBundleIds {
            if lowercaseName.contains(bundleId) || bundleId.contains(lowercaseName) {
                return true
            }
        }
        
        // 提取可能的应用名
        let parts = lowercaseName.components(separatedBy: ".")
        if let lastPart = parts.last, installedBundleIds.contains(lastPart) {
            return true
        }
        
        return false
    }
    
    private func extractBundleId(from name: String) -> String? {
        // 尝试从名称中提取 bundle id
        if name.contains(".") && !name.hasPrefix(".") {
            let cleanName = name
                .replacingOccurrences(of: ".savedstate", with: "")
                .replacingOccurrences(of: ".plist", with: "")
            return cleanName
        }
        return nil
    }
    
    private func formatDisplayName(_ name: String) -> String {
        var displayName = name
            .replacingOccurrences(of: ".savedstate", with: "")
            .replacingOccurrences(of: ".plist", with: "")
        
        // 尝试从 bundle id 提取应用名
        if displayName.contains(".") {
            let parts = displayName.components(separatedBy: ".")
            if let lastPart = parts.last, !lastPart.isEmpty {
                displayName = lastPart.capitalized
            }
        }
        
        return displayName
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
    
    func toggleSelection(for item: OrphanedItem) {
        if let index = orphanedItems.firstIndex(where: { $0.id == item.id }) {
            orphanedItems[index].isSelected.toggle()
        }
    }
    
    func selectAll() {
        for i in orphanedItems.indices {
            orphanedItems[i].isSelected = true
        }
    }
    
    func deselectAll() {
        for i in orphanedItems.indices {
            orphanedItems[i].isSelected = false
        }
    }
    
    var selectedCount: Int {
        orphanedItems.filter { $0.isSelected }.count
    }
    
    var selectedSize: Int64 {
        orphanedItems.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    func cleanSelected() async -> (count: Int, size: Int64) {
        var removedCount = 0
        var removedSize: Int64 = 0
        
        let selectedItems = orphanedItems.filter { $0.isSelected }
        
        for item in selectedItems {
            do {
                try fileManager.trashItem(at: item.url, resultingItemURL: nil)
                removedCount += 1
                removedSize += item.size
            } catch {
                print("Failed to remove \(item.url.path): \(error)")
            }
        }
        
        // 重新扫描
        await scan()
        
        return (removedCount, removedSize)
    }
}
