import Foundation
import AppKit

// MARK: - 应用扫描服务
class AppScanner: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var isScanning: Bool = false
    
    private let fileManager = FileManager.default
    
    /// 扫描所有已安装的应用程序
    func scanApplications() async {
        await MainActor.run {
            isScanning = true
            apps.removeAll()
        }
        
        // 扫描多个可能的应用安装位置
        let homeDir = URL(fileURLWithPath: NSHomeDirectory())
        var applicationsPaths: [URL] = [
            // 标准安装位置
            URL(fileURLWithPath: "/Applications"),
            homeDir.appendingPathComponent("Applications"),
            // System applications (read-only, but can be listed)
            URL(fileURLWithPath: "/System/Applications"),
            // Utilities
            URL(fileURLWithPath: "/Applications/Utilities"),
            // Homebrew Cask applications
            URL(fileURLWithPath: "/opt/homebrew/Caskroom"),
            URL(fileURLWithPath: "/usr/local/Caskroom"),
            
            // 便携式应用可能存放的位置 (无需安装直接运行)
            homeDir.appendingPathComponent("Downloads"),
            homeDir.appendingPathComponent("Desktop"),
            homeDir.appendingPathComponent("Documents"),
            // 一些用户可能直接把app放在主目录
            homeDir
        ]
        
        // 也扫描 /Applications 下的子文件夹（有些开发者把应用放在子文件夹里）
        let mainAppsPath = URL(fileURLWithPath: "/Applications")
        if let subdirs = try? fileManager.contentsOfDirectory(at: mainAppsPath, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for subdir in subdirs {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: subdir.path, isDirectory: &isDir) && isDir.boolValue && subdir.pathExtension != "app" {
                    applicationsPaths.append(subdir)
                }
            }
        }
        
        var scannedApps: [InstalledApp] = []
        var seenBundleIds = Set<String>()  // 避免重复
        
        for applicationsPath in applicationsPaths {
            guard fileManager.fileExists(atPath: applicationsPath.path) else { continue }
            
            // 递归扫描，但限制深度以提高性能
            await scanDirectory(applicationsPath, depth: 0, maxDepth: 2, scannedApps: &scannedApps, seenBundleIds: &seenBundleIds)
        }
        
        // 按名称排序
        scannedApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        await MainActor.run { [scannedApps] in
            apps = scannedApps
            isScanning = false
        }
    }
    
    /// 递归扫描目录
    private func scanDirectory(_ directory: URL, depth: Int, maxDepth: Int, scannedApps: inout [InstalledApp], seenBundleIds: inout Set<String>) async {
        guard depth <= maxDepth else { return }
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            for url in contents {
                if url.pathExtension == "app" {
                    if let app = await createApp(from: url) {
                        // 避免重复（通过 bundle ID）
                        if let bundleId = app.bundleIdentifier {
                            if seenBundleIds.contains(bundleId) {
                                continue
                            }
                            seenBundleIds.insert(bundleId)
                        }
                        scannedApps.append(app)
                    }
                } else {
                    // 检查是否是目录，如果是则递归
                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue {
                        await scanDirectory(url, depth: depth + 1, maxDepth: maxDepth, scannedApps: &scannedApps, seenBundleIds: &seenBundleIds)
                    }
                }
            }
        } catch {
            // 忽略无法访问的目录
            print("扫描目录失败: \(directory.path), 错误: \(error)")
        }
    }
    
    /// 从.app包创建InstalledApp对象
    private func createApp(from url: URL) async -> InstalledApp? {
        let bundle = Bundle(url: url)
        let bundleIdentifier = bundle?.bundleIdentifier
        let name = url.deletingPathExtension().lastPathComponent
        
        // 获取应用图标
        let icon = await getAppIcon(from: url, bundle: bundle)
        
        // 计算应用大小
        let size = calculateDirectorySize(url)
        
        // 检测是否为 App Store 应用
        let maskingReceiptPath = url.appendingPathComponent("Contents/_MASReceipt/receipt")
        let isAppStore = fileManager.fileExists(atPath: maskingReceiptPath.path)
        
        // 尝试获取厂商名
        var vendor = "Unknown"
        if let id = bundleIdentifier {
            let components = id.components(separatedBy: ".")
            if components.count >= 2 {
                // e.g. com.google.chrome -> Google
                let potentialVendor = components[1].capitalized
                if potentialVendor != "Com" && potentialVendor != "Org" {
                    vendor = potentialVendor
                } else if components.count > 2 {
                     vendor = components[2].capitalized
                }
            }
        }
        
        // 修正特定厂商
        if vendor == "Apple" || bundleIdentifier?.starts(with: "com.apple.") == true {
            vendor = "Apple"
        }
        
        // 获取应用版本
        let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? 
                      bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        
        return InstalledApp(
            name: name,
            path: url,
            bundleIdentifier: bundleIdentifier,
            icon: icon,
            size: size,
            vendor: vendor,
            isAppStore: isAppStore,
            version: version
        )
    }
    
    /// 获取应用图标
    private func getAppIcon(from url: URL, bundle: Bundle?) async -> NSImage {
        // 首先尝试从Bundle获取图标
        if let bundle = bundle,
           let iconName = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String {
            let iconPath: String
            if iconName.hasSuffix(".icns") {
                iconPath = bundle.bundlePath + "/Contents/Resources/" + iconName
            } else {
                iconPath = bundle.bundlePath + "/Contents/Resources/" + iconName + ".icns"
            }
            
            if let icon = NSImage(contentsOfFile: iconPath) {
                return icon
            }
        }
        
        // 尝试获取CFBundleIconName (用于现代应用)
        if let bundle = bundle,
           let iconName = bundle.object(forInfoDictionaryKey: "CFBundleIconName") as? String {
            let icnsPath = bundle.bundlePath + "/Contents/Resources/" + iconName + ".icns"
            if let icon = NSImage(contentsOfFile: icnsPath) {
                return icon
            }
        }
        
        // 使用NSWorkspace获取图标
        return await MainActor.run {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            return UnsafeTransfer(icon)
        }.value
    }
    
    /// 扫描应用的残留文件
    func scanResidualFiles(for app: InstalledApp) async {
        await MainActor.run { app.isScanning = true }
        let scanner = ResidualFileScanner()
        let files = await scanner.scanResidualFiles(for: app)
        await MainActor.run {
            app.residualFiles = files
            // 默认选中所有残留文件
            for file in files {
                file.isSelected = true
            }
            app.isScanning = false
        }
    }
    
    /// 批量扫描多个应用的残留文件
    func scanResidualFilesForApps(_ apps: [InstalledApp]) async {
        await withTaskGroup(of: Void.self) { group in
            for app in apps {
                group.addTask {
                    await self.scanResidualFiles(for: app)
                }
            }
        }
    }
    
    /// 移除已卸载的应用
    func removeFromList(app: InstalledApp) async {
        await MainActor.run {
            apps.removeAll { $0.id == app.id }
        }
    }
    
    /// 移除多个已卸载的应用
    func removeFromList(apps appsToRemove: [InstalledApp]) async {
        let idsToRemove = Set(appsToRemove.map { $0.id })
        await MainActor.run {
            apps.removeAll { idsToRemove.contains($0.id) }
        }
    }
    
    /// 计算目录大小
    private func calculateDirectorySize(_ url: URL) -> Int64 {
        var totalSize: Int64 = 0
        
        let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                if resourceValues.isDirectory == false {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }
        
        return totalSize
    }
    
    /// 刷新单个应用的大小（清理后更新）
    func refreshAppSize(for app: InstalledApp) async {
        let newSize = calculateDirectorySize(app.path)
        await MainActor.run {
            app.size = newSize
            // 触发列表更新
            if let index = apps.firstIndex(where: { $0.id == app.id }) {
                apps[index] = app 
            }
        }
    }
}
