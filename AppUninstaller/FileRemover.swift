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
        
        // 收集所有需要删除的路径
        var pathsToDelete: [(URL, Int64)] = []
        
        for file in app.residualFiles where file.isSelected {
            pathsToDelete.append((file.path, file.size))
        }
        
        if includeApp {
            pathsToDelete.append((app.path, app.size))
        }
        
        // 先尝试普通删除
        var failedForPrivileged: [(URL, Int64)] = []
        
        for (path, size) in pathsToDelete {
            let result = await removeItemNormal(at: path, moveToTrash: moveToTrash)
            if result {
                successCount += 1
                totalSizeRemoved += size
            } else {
                failedForPrivileged.append((path, size))
            }
        }
        
        // 如果有失败的，尝试提权删除
        if !failedForPrivileged.isEmpty {
            print("有 \(failedForPrivileged.count) 个项目需要提权删除")
            let privilegedResult = await removeItemsWithPrivilege(paths: failedForPrivileged.map { $0.0 })
            
            for (index, path) in failedForPrivileged.enumerated() {
                if privilegedResult[index] {
                    successCount += 1
                    totalSizeRemoved += path.1
                } else {
                    failedCount += 1
                    failedPaths.append(path.0)
                }
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
        
        var pathsToDelete: [(URL, Int64)] = []
        for file in app.residualFiles where file.isSelected {
            pathsToDelete.append((file.path, file.size))
        }
        
        var failedForPrivileged: [(URL, Int64)] = []
        
        for (path, size) in pathsToDelete {
            let result = await removeItemNormal(at: path, moveToTrash: moveToTrash)
            if result {
                successCount += 1
                totalSizeRemoved += size
            } else {
                failedForPrivileged.append((path, size))
            }
        }
        
        // 提权删除失败的项目
        if !failedForPrivileged.isEmpty {
            let privilegedResult = await removeItemsWithPrivilege(paths: failedForPrivileged.map { $0.0 })
            
            for (index, path) in failedForPrivileged.enumerated() {
                if privilegedResult[index] {
                    successCount += 1
                    totalSizeRemoved += path.1
                } else {
                    failedCount += 1
                    failedPaths.append(path.0)
                }
            }
        }
        
        return RemovalResult(
            successCount: successCount,
            failedCount: failedCount,
            totalSizeRemoved: totalSizeRemoved,
            failedPaths: failedPaths
        )
    }
    
    /// 普通删除（不提权）
    private func removeItemNormal(at url: URL, moveToTrash: Bool) async -> Bool {
        do {
            if moveToTrash {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
            } else {
                try fileManager.removeItem(at: url)
            }
            return true
        } catch {
            print("普通删除失败: \(url.path), 错误: \(error)")
            return false
        }
    }
    
    /// 使用管理员权限删除文件（通过 AppleScript）
    /// 会弹出密码输入框请求用户授权
    private func removeItemsWithPrivilege(paths: [URL]) async -> [Bool] {
        guard !paths.isEmpty else { return [] }
        
        // 对路径进行正确的 shell 转义
        func shellEscape(_ path: String) -> String {
            let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
            return "'\(escaped)'"
        }
        
        // 构建一个脚本，逐个删除每个路径，忽略单个错误
        // 这样一个文件删除失败不会影响其他文件
        // 安全检查：路径校验逻辑
        func isPathSafeToDelete(_ path: String) -> Bool {
            let standardPath = (path as NSString).standardizingPath
            
            // 1. 绝对禁止的系统根目录
            let dangerousPrefixes = [
                "/System",
                "/bin",
                "/sbin",
                "/usr",
                "/etc",
                "/var",
                "/Library", // 系统级Library通常不允许直接删除，除非特定子目录，这里从严
                "/Applications/Safari.app", // 系统应用保护
                "/Applications/System Preferences.app"
            ]
            
            if standardPath == "/" { return false }
            
            for prefix in dangerousPrefixes {
                if standardPath.hasPrefix(prefix) {
                    print("安全拦截: 试图删除受保护的系统路径 \(standardPath)")
                    return false
                }
            }
            
            // 2. 必须包含用户主目录 (强制沙盒化思维)
            // 允许删除 /Applications, /Users/xxx, /Library/xxx (特定)
            // 但为了防止万一，我们要求路径必须在 /Users 下，或者在 /Applications 下
            let validPrefixes = [
                "/Users/",
                "/Applications/",
                "/private/var/folders/", // 临时文件
                "/Volumes/" // 外接驱动器
            ]
            
            var isValid = false
            for prefix in validPrefixes {
                if standardPath.hasPrefix(prefix) {
                    isValid = true
                    break
                }
            }
            
            if !isValid {
                print("安全拦截: 路径不在允许的操作范围内 \(standardPath)")
                return false
            }
            
            // 3. 检查特殊字符防止 Shell 注入 (虽然有了 shellEscape，双重保障)
            // 禁止包含连续的 ..
            if standardPath.contains("..") { return false }
            
            return true
        }
        
        // 构建一个脚本，逐个删除每个路径，忽略单个错误
        // 这样一个文件删除失败不会影响其他文件
        var scriptLines: [String] = []
        var safePathsCount = 0
        
        for path in paths {
            let pathStr = path.path
            
            // 执行安全检查
            if !isPathSafeToDelete(pathStr) {
                print("跳过不安全路径: \(pathStr)")
                continue
            }
            
            safePathsCount += 1
            let escapedPath = shellEscape(pathStr)
            // 每个删除命令后加 || true，即使失败也继续
            scriptLines.append("rm -rf \(escapedPath) 2>/dev/null || true")
        }
        
        if safePathsCount == 0 {
            print("没有通过安全检查的有效路径，跳过执行")
            return Array(repeating: false, count: paths.count)
        }
        
        let shellCommands = scriptLines.joined(separator: "; ")
        
        let script = """
        do shell script "\(shellCommands)" with administrator privileges
        """
        
        print("执行提权删除脚本，共 \(paths.count) 个路径")
        
        return await MainActor.run {
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                _ = appleScript.executeAndReturnError(&error)
                
                if let errorDict = error {
                    let errorNumber = errorDict["NSAppleScriptErrorNumber"] as? Int ?? -1
                    if errorNumber == -128 {
                        print("用户取消了密码输入")
                        return Array(repeating: false, count: paths.count)
                    }
                    // 其他错误仍然继续验证
                    print("AppleScript 返回错误: \(errorDict), 但仍检查删除结果")
                }
                
                // 无论命令是否报错，都验证每个路径是否被删除
                var results: [Bool] = []
                for path in paths {
                    let deleted = !fileManager.fileExists(atPath: path.path)
                    if !deleted {
                        print("文件仍存在: \(path.path)")
                    }
                    results.append(deleted)
                }
                print("提权删除完成: \(results.filter { $0 }.count) 成功, \(results.filter { !$0 }.count) 失败")
                return results
            } else {
                print("无法创建 AppleScript 对象")
            }
            return Array(repeating: false, count: paths.count)
        }
    }
    
    /// 使用管理员权限删除单个文件
    func removeItemWithPrivilege(at url: URL) async -> Bool {
        let results = await removeItemsWithPrivilege(paths: [url])
        return results.first ?? false
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
    
    /// 使用管理员权限强制终止应用 (针对顽固进程)
    func forceTerminateAppWithPrivilege(_ app: InstalledApp) async -> Bool {
        guard let bundleId = app.bundleIdentifier else { return false }
        
        let script = """
        do shell script "pkill -9 -f '\(bundleId)'" with administrator privileges
        """
        
        return await MainActor.run {
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
                return error == nil
            }
            return false
        }
    }
}
