import Foundation
import AppKit

// MARK: - 文件删除服务
class FileRemover {
    private let fileManager = FileManager.default
    
    /// 删除应用及其残留文件
    func removeApp(_ app: InstalledApp, includeApp: Bool = true, moveToTrash: Bool = true) async -> RemovalResult {
        var successCount = 0
        var failedCount = 0
        var totalSizeRemoved: Int64 = 0
        var failedPaths: [URL] = []
        
        // 删除残留文件
        for file in app.residualFiles where file.isSelected {
            let result = await removeItem(at: file.path, moveToTrash: moveToTrash)
            if result {
                successCount += 1
                totalSizeRemoved += file.size
            } else {
                failedCount += 1
                failedPaths.append(file.path)
            }
        }
        
        // 删除应用本体
        if includeApp {
            let result = await removeItem(at: app.path, moveToTrash: moveToTrash)
            if result {
                successCount += 1
                totalSizeRemoved += app.size
            } else {
                failedCount += 1
                failedPaths.append(app.path)
            }
        }
        
        return RemovalResult(
            successCount: successCount,
            failedCount: failedCount,
            totalSizeRemoved: totalSizeRemoved,
            failedPaths: failedPaths
        )
    }
    
    /// 仅删除残留文件（保留应用本体）
    func removeResidualFiles(of app: InstalledApp, moveToTrash: Bool = true) async -> RemovalResult {
        var successCount = 0
        var failedCount = 0
        var totalSizeRemoved: Int64 = 0
        var failedPaths: [URL] = []
        
        for file in app.residualFiles where file.isSelected {
            let result = await removeItem(at: file.path, moveToTrash: moveToTrash)
            if result {
                successCount += 1
                totalSizeRemoved += file.size
            } else {
                failedCount += 1
                failedPaths.append(file.path)
            }
        }
        
        return RemovalResult(
            successCount: successCount,
            failedCount: failedCount,
            totalSizeRemoved: totalSizeRemoved,
            failedPaths: failedPaths
        )
    }
    
    /// 删除单个项目
    private func removeItem(at url: URL, moveToTrash: Bool) async -> Bool {
        do {
            if moveToTrash {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
            } else {
                try fileManager.removeItem(at: url)
            }
            return true
        } catch {
            print("删除失败: \(url.path), 错误: \(error)")
            return false
        }
    }
    
    /// 检查应用是否正在运行
    func isAppRunning(_ app: InstalledApp) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        
        // 通过Bundle ID匹配
        if let bundleId = app.bundleIdentifier {
            if runningApps.contains(where: { $0.bundleIdentifier == bundleId }) {
                return true
            }
        }
        
        // 通过路径匹配
        if runningApps.contains(where: { $0.bundleURL == app.path }) {
            return true
        }
        
        return false
    }
    
    /// 尝试终止应用
    func terminateApp(_ app: InstalledApp) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        
        for runningApp in runningApps {
            if runningApp.bundleIdentifier == app.bundleIdentifier || runningApp.bundleURL == app.path {
                return runningApp.terminate()
            }
        }
        
        return false
    }
    
    /// 强制终止应用
    func forceTerminateApp(_ app: InstalledApp) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        
        for runningApp in runningApps {
            if runningApp.bundleIdentifier == app.bundleIdentifier || runningApp.bundleURL == app.path {
                return runningApp.forceTerminate()
            }
        }
        
        return false
    }
}
