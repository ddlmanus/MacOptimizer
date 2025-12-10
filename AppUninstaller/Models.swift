import Foundation
import AppKit

// MARK: - 文件类型枚举
enum FileType: String, CaseIterable, Identifiable {
    case preferences = "偏好设置"
    case applicationSupport = "应用支持"
    case caches = "缓存"
    case logs = "日志"
    case savedState = "保存状态"
    case containers = "容器"
    case groupContainers = "组容器"
    case cookies = "Cookies"
    case launchAgents = "启动代理"
    case crashReports = "崩溃报告"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .preferences: return "gear"
        case .applicationSupport: return "folder.fill"
        case .caches: return "archivebox.fill"
        case .logs: return "doc.text.fill"
        case .savedState: return "clock.arrow.circlepath"
        case .containers: return "shippingbox.fill"
        case .groupContainers: return "square.stack.3d.up.fill"
        case .cookies: return "birthday.cake.fill"
        case .launchAgents: return "bolt.fill"
        case .crashReports: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: NSColor {
        switch self {
        case .preferences: return NSColor.systemBlue
        case .applicationSupport: return NSColor.systemPurple
        case .caches: return NSColor.systemOrange
        case .logs: return NSColor.systemGreen
        case .savedState: return NSColor.systemTeal
        case .containers: return NSColor.systemIndigo
        case .groupContainers: return NSColor.systemPink
        case .cookies: return NSColor.systemYellow
        case .launchAgents: return NSColor.systemRed
        case .crashReports: return NSColor.systemGray
        }
    }
}

// MARK: - 已安装应用模型
class InstalledApp: Identifiable, ObservableObject, Hashable {
    let id = UUID()
    let name: String
    let path: URL
    let bundleIdentifier: String?
    let icon: NSImage
    @Published var size: Int64
    @Published var residualFiles: [ResidualFile] = []
    @Published var isScanning: Bool = false
    
    init(name: String, path: URL, bundleIdentifier: String?, icon: NSImage, size: Int64) {
        self.name = name
        self.path = path
        self.bundleIdentifier = bundleIdentifier
        self.icon = icon
        self.size = size
    }
    
    var totalResidualSize: Int64 {
        residualFiles.reduce(0) { $0 + $1.size }
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var formattedResidualSize: String {
        ByteCountFormatter.string(fromByteCount: totalResidualSize, countStyle: .file)
    }
    
    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - 残留文件模型
class ResidualFile: Identifiable, ObservableObject, Hashable {
    let id = UUID()
    let path: URL
    let type: FileType
    let size: Int64
    @Published var isSelected: Bool = true
    
    init(path: URL, type: FileType, size: Int64) {
        self.path = path
        self.type = type
        self.size = size
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var fileName: String {
        path.lastPathComponent
    }
    
    static func == (lhs: ResidualFile, rhs: ResidualFile) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - 删除结果
struct RemovalResult {
    let successCount: Int
    let failedCount: Int
    let totalSizeRemoved: Int64
    let failedPaths: [URL]
}
