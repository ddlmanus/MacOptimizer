import Foundation
import Combine

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
        }
    }
    
    var searchPaths: [String] {
        switch self {
        case .userCache: 
            return ["~/Library/Caches"]
        case .systemCache:
            return [
                "/Library/Caches",
                "/System/Library/Caches",
                "/private/var/folders"
            ]
        case .userLogs: 
            return ["~/Library/Logs"]
        case .systemLogs:
            return [
                "/Library/Logs",
                "/private/var/log"
            ]
        case .browserCache: 
            return [
                // Chrome
                "~/Library/Caches/Google/Chrome",
                "~/Library/Application Support/Google/Chrome/Default/Cache",
                "~/Library/Application Support/Google/Chrome/Default/Code Cache",
                "~/Library/Application Support/Google/Chrome/Default/GPUCache",
                // Safari
                "~/Library/Caches/com.apple.Safari",
                "~/Library/Safari/LocalStorage",
                // Firefox
                "~/Library/Caches/Firefox",
                "~/Library/Application Support/Firefox/Profiles",
                // Edge
                "~/Library/Caches/Microsoft Edge",
                "~/Library/Application Support/Microsoft Edge/Default/Cache",
                // Arc
                "~/Library/Caches/company.thebrowser.Browser",
                // Brave
                "~/Library/Caches/BraveSoftware"
            ]
        case .appCache:
            return [
                "~/Library/Caches/com.spotify.client",
                "~/Library/Caches/com.apple.Music",
                "~/Library/Caches/com.apple.podcasts",
                "~/Library/Caches/com.apple.appstore",
                "~/Library/Caches/com.apple.news",
                "~/Library/Caches/com.apple.Maps"
            ]
        case .chatCache:
            return [
                // 微信
                "~/Library/Containers/com.tencent.xinWeChat/Data/Library/Application Support/com.tencent.xinWeChat",
                "~/Library/Caches/com.tencent.xinWeChat",
                // QQ
                "~/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ",
                "~/Library/Caches/com.tencent.qq",
                // Telegram
                "~/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/stable",
                "~/Library/Caches/ru.keepcoder.Telegram",
                // 企业微信
                "~/Library/Containers/com.tencent.WeWorkMac/Data/Library/Application Support",
                // 钉钉
                "~/Library/Containers/com.alibaba.DingTalkMac/Data/Library/Application Support",
                // Slack
                "~/Library/Caches/com.tinyspeck.slackmacgap",
                // Discord
                "~/Library/Caches/com.hnc.Discord",
                "~/Library/Application Support/discord/Cache"
            ]
        case .mailAttachments:
            return [
                "~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
                "~/Library/Mail Downloads"
            ]
        case .crashReports:
            return [
                "~/Library/Logs/DiagnosticReports",
                "/Library/Logs/DiagnosticReports"
            ]
        case .tempFiles:
            return [
                "/tmp",
                "/private/tmp",
                "~/Library/Application Support/CrashReporter",
                "~/Library/Caches/com.apple.helpd"
            ]
        case .xcodeDerivedData: 
            return [
                "~/Library/Developer/Xcode/DerivedData",
                "~/Library/Developer/Xcode/Archives",
                "~/Library/Developer/CoreSimulator/Caches"
            ]
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
    
    /// 扫描所有垃圾
    func scanJunk() async {
        await MainActor.run {
            isScanning = true
            junkItems.removeAll()
            scanProgress = 0
        }
        
        var items: [JunkItem] = []
        let types = JunkType.allCases
        
        for (index, type) in types.enumerated() {
            let typeItems = await scanType(type)
            items.append(contentsOf: typeItems)
            
            await MainActor.run {
                scanProgress = Double(index + 1) / Double(types.count)
            }
        }
        
        // 排序：按大小降序
        items.sort { $0.size > $1.size }
        
        await MainActor.run {
            self.junkItems = items
            isScanning = false
        }
    }
    
    /// 清理选中的垃圾
    func cleanSelected() async -> (cleaned: Int64, failed: Int64, requiresAdmin: Bool) {
        var cleanedSize: Int64 = 0
        var failedSize: Int64 = 0
        var needsAdmin = false
        let selectedItems = junkItems.filter { $0.isSelected }
        var failedPaths: [String] = []
        
        for item in selectedItems {
            let success = await deleteItem(item)
            if success {
                cleanedSize += item.size
            } else {
                failedSize += item.size
                failedPaths.append(item.path.path)
            }
        }
        
        // 如果有失败的项目，尝试使用 sudo 权限删除
        if !failedPaths.isEmpty {
            let (sudoCleanedSize, sudoSuccess) = await cleanWithAdminPrivileges(paths: failedPaths, items: selectedItems)
            if sudoSuccess {
                cleanedSize += sudoCleanedSize
                failedSize -= sudoCleanedSize
            } else {
                needsAdmin = true
            }
        }
        
        await MainActor.run {
            self.junkItems.removeAll { item in
                selectedItems.contains { $0.id == item.id }
            }
        }
        
        // 重新扫描以反映最新状态
        await scanJunk()
        
        return (cleanedSize, failedSize, needsAdmin)
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
