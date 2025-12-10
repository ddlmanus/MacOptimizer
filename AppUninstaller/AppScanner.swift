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
        
        let applicationsPaths = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications")
        ]
        
        var scannedApps: [InstalledApp] = []
        
        for applicationsPath in applicationsPaths {
            guard fileManager.fileExists(atPath: applicationsPath.path) else { continue }
            
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: applicationsPath,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
                
                for url in contents {
                    if url.pathExtension == "app" {
                        if let app = await createApp(from: url) {
                            scannedApps.append(app)
                        }
                    }
                }
            } catch {
                print("扫描应用目录失败: \(error)")
            }
        }
        
        // 按名称排序
        scannedApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        await MainActor.run {
            apps = scannedApps
            isScanning = false
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
        
        return InstalledApp(
            name: name,
            path: url,
            bundleIdentifier: bundleIdentifier,
            icon: icon,
            size: size
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
            NSWorkspace.shared.icon(forFile: url.path)
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
}
