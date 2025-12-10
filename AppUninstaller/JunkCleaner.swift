import Foundation
import Combine

// MARK: - 垃圾类型枚举
enum JunkType: String, CaseIterable, Identifiable {
    case userCache = "用户缓存"
    case userLogs = "用户日志"
    case trash = "废纸篓"
    case browserCache = "浏览器缓存"
    case appCache = "应用缓存"
    case xcodeDerivedData = "Xcode 衍生数据" // 给开发者的额外福利
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .userCache: return "archivebox.fill"
        case .userLogs: return "doc.text.fill"
        case .trash: return "trash.fill"
        case .browserCache: return "globe.americas.fill"
        case .appCache: return "square.stack.3d.up.fill"
        case .xcodeDerivedData: return "hammer.fill"
        }
    }
    
    var description: String {
        switch self {
        case .userCache: return "应用程序产生的临时缓存文件"
        case .userLogs: return "应用程序运行日志和崩溃报告"
        case .trash: return "废纸篓中的已删除文件"
        case .browserCache: return "Chrome、Safari 等浏览器的临时文件"
        case .appCache: return "邮件附件、微信等应用的缓存文件"
        case .xcodeDerivedData: return "Xcode 编译产生的中间文件"
        }
    }
    
    var searchPaths: [String] {
        switch self {
        case .userCache: return ["~/Library/Caches"]
        case .userLogs: return ["~/Library/Logs"]
        case .trash: return ["~/.Trash"]
        case .browserCache: 
            return [
                "~/Library/Caches/Google/Chrome/Default/Cache",
                "~/Library/Caches/com.apple.Safari",
                "~/Library/Caches/Firefox/Profiles",
                "~/Library/Caches/Microsoft Edge/Default/Cache"
            ]
        case .appCache:
            return [
                "~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
                "~/Library/Caches/com.tencent.xinWeChat"
            ]
        case .xcodeDerivedData: return ["~/Library/Developer/Xcode/DerivedData"]
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
    func cleanSelected() async -> Int64 {
        var cleanedSize: Int64 = 0
        let selectedItems = junkItems.filter { $0.isSelected }
        
        for item in selectedItems {
            do {
                if item.type == .trash {
                    // 废纸篓特殊处理：通常不能简单remove，但如果有权限可以直接清空，
                    // 这里简化逻辑，尝试删除废纸篓内的子项
                    // 注意：直接操作 ~/.Trash 可能需要Full Disk Access
                }
                
                try fileManager.removeItem(at: item.path)
                cleanedSize += item.size
            } catch {
                print("Failed to delete \(item.path.path): \(error)")
            }
        }
        
        await MainActor.run {
            self.junkItems.removeAll { $0.isSelected }
        }
        
        return cleanedSize
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
