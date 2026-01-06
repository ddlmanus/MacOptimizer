import Foundation

// MARK: - 残留文件扫描服务
class ResidualFileScanner {
    private let fileManager = FileManager.default
    private let homeDirectory = URL(fileURLWithPath: NSHomeDirectory())
    
    /// 扫描应用的所有残留文件
    func scanResidualFiles(for app: InstalledApp) async -> [ResidualFile] {
        var residualFiles: [ResidualFile] = []
        
        let appName = app.name
        let bundleId = app.bundleIdentifier
        
        // 扫描各个位置
        residualFiles.append(contentsOf: scanPreferences(appName: appName, bundleId: bundleId))
        residualFiles.append(contentsOf: scanApplicationSupport(appName: appName, bundleId: bundleId))
        residualFiles.append(contentsOf: scanCaches(appName: appName, bundleId: bundleId))
        residualFiles.append(contentsOf: scanLogs(appName: appName, bundleId: bundleId))
        residualFiles.append(contentsOf: scanSavedState(bundleId: bundleId))
        residualFiles.append(contentsOf: scanContainers(bundleId: bundleId))
        residualFiles.append(contentsOf: scanGroupContainers(bundleId: bundleId))
        residualFiles.append(contentsOf: scanCookies(appName: appName, bundleId: bundleId))
        residualFiles.append(contentsOf: scanLaunchAgents(appName: appName, bundleId: bundleId))
        residualFiles.append(contentsOf: scanCrashReports(appName: appName, bundleId: bundleId))
        residualFiles.append(contentsOf: scanDeveloper(appName: appName, bundleId: bundleId))
        
        return residualFiles
    }
    
    // MARK: - 开发数据 (Xcode/Simulator etc)
    private func scanDeveloper(appName: String, bundleId: String?) -> [ResidualFile] {
        var files: [ResidualFile] = []
        let developerPath = homeDirectory.appendingPathComponent("Library/Developer")
        
        guard fileManager.fileExists(atPath: developerPath.path) else { return files }
        
        // 1. Generic Search in ~/Library/Developer
        files.append(contentsOf: searchDirectory(developerPath, appName: appName, bundleId: bundleId, type: .developer))
        
        // 2. Specialized Logic for Xcode
        if let bid = bundleId, bid == "com.apple.dt.Xcode" {
            // List of specific Xcode related paths in user directory
            let xcodePaths = [
                developerPath.appendingPathComponent("Xcode"),
                developerPath.appendingPathComponent("CoreSimulator"),
                developerPath.appendingPathComponent("XCPGDevices"),
                homeDirectory.appendingPathComponent("Library/MobileDevice"),
                homeDirectory.appendingPathComponent("Library/Caches/com.apple.dt.Xcode"),
                homeDirectory.appendingPathComponent("Library/Application Support/Xcode"),
                homeDirectory.appendingPathComponent("Library/Preferences/com.apple.dt.Xcode.plist"),
                homeDirectory.appendingPathComponent("Library/Saved Application State/com.apple.dt.Xcode.savedState"),
                homeDirectory.appendingPathComponent("Library/Application Support/com.apple.dt.Xcode") // Check for bundle ID folder too
            ]
            
            for path in xcodePaths {
                if fileManager.fileExists(atPath: path.path) {
                    let size = calculateSize(at: path)
                    // Determine type based on path
                    let type: FileType
                    if path.path.contains("/Caches/") { type = .caches }
                    else if path.path.contains("/Preferences/") { type = .preferences }
                    else if path.path.contains("/Application Support/") { type = .applicationSupport }
                    else if path.path.contains("/Saved Application State/") { type = .savedState }
                    else { type = .developer }
                    
                    files.append(ResidualFile(path: path, type: type, size: size))
                }
            }
        }
        
        return files
    }
    
    // MARK: - 偏好设置
    private func scanPreferences(appName: String, bundleId: String?) -> [ResidualFile] {
        var files: [ResidualFile] = []
        let preferencesPath = homeDirectory.appendingPathComponent("Library/Preferences")
        
        files.append(contentsOf: searchDirectory(preferencesPath, appName: appName, bundleId: bundleId, type: .preferences))
        
        return files
    }
    
    // MARK: - 应用支持
    private func scanApplicationSupport(appName: String, bundleId: String?) -> [ResidualFile] {
        var files: [ResidualFile] = []
        let appSupportPath = homeDirectory.appendingPathComponent("Library/Application Support")
        
        files.append(contentsOf: searchDirectory(appSupportPath, appName: appName, bundleId: bundleId, type: .applicationSupport))
        
        return files
    }
    
    // MARK: - 缓存
    private func scanCaches(appName: String, bundleId: String?) -> [ResidualFile] {
        var files: [ResidualFile] = []
        let cachesPath = homeDirectory.appendingPathComponent("Library/Caches")
        
        files.append(contentsOf: searchDirectory(cachesPath, appName: appName, bundleId: bundleId, type: .caches))
        
        return files
    }
    
    // MARK: - 日志
    private func scanLogs(appName: String, bundleId: String?) -> [ResidualFile] {
        var files: [ResidualFile] = []
        let logsPath = homeDirectory.appendingPathComponent("Library/Logs")
        
        files.append(contentsOf: searchDirectory(logsPath, appName: appName, bundleId: bundleId, type: .logs))
        
        return files
    }
    
    // MARK: - 保存状态
    private func scanSavedState(bundleId: String?) -> [ResidualFile] {
        guard let bundleId = bundleId else { return [] }
        var files: [ResidualFile] = []
        let savedStatePath = homeDirectory.appendingPathComponent("Library/Saved Application State")
        let targetPath = savedStatePath.appendingPathComponent("\(bundleId).savedState")
        
        if fileManager.fileExists(atPath: targetPath.path) {
            let size = calculateSize(at: targetPath)
            files.append(ResidualFile(path: targetPath, type: .savedState, size: size))
        }
        
        return files
    }
    
    // MARK: - 容器
    private func scanContainers(bundleId: String?) -> [ResidualFile] {
        guard let bundleId = bundleId else { return [] }
        var files: [ResidualFile] = []
        let containersPath = homeDirectory.appendingPathComponent("Library/Containers")
        let targetPath = containersPath.appendingPathComponent(bundleId)
        
        if fileManager.fileExists(atPath: targetPath.path) {
            let size = calculateSize(at: targetPath)
            files.append(ResidualFile(path: targetPath, type: .containers, size: size))
        }
        
        return files
    }
    
    // MARK: - 组容器
    private func scanGroupContainers(bundleId: String?) -> [ResidualFile] {
        guard let bundleId = bundleId else { return [] }
        var files: [ResidualFile] = []
        let groupContainersPath = homeDirectory.appendingPathComponent("Library/Group Containers")
        
        guard fileManager.fileExists(atPath: groupContainersPath.path) else { return files }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: groupContainersPath, includingPropertiesForKeys: nil)
            for url in contents {
                if url.lastPathComponent.contains(bundleId) {
                    let size = calculateSize(at: url)
                    files.append(ResidualFile(path: url, type: .groupContainers, size: size))
                }
            }
        } catch {
            // 忽略错误
        }
        
        return files
    }
    
    // MARK: - Cookies
    private func scanCookies(appName: String, bundleId: String?) -> [ResidualFile] {
        var files: [ResidualFile] = []
        let cookiesPath = homeDirectory.appendingPathComponent("Library/Cookies")
        
        files.append(contentsOf: searchDirectory(cookiesPath, appName: appName, bundleId: bundleId, type: .cookies))
        
        return files
    }
    
    // MARK: - 启动代理
    private func scanLaunchAgents(appName: String, bundleId: String?) -> [ResidualFile] {
        var files: [ResidualFile] = []
        let launchAgentsPath = homeDirectory.appendingPathComponent("Library/LaunchAgents")
        
        files.append(contentsOf: searchDirectory(launchAgentsPath, appName: appName, bundleId: bundleId, type: .launchAgents))
        
        return files
    }
    
    // MARK: - 崩溃报告
    private func scanCrashReports(appName: String, bundleId: String?) -> [ResidualFile] {
        var files: [ResidualFile] = []
        let crashLogsPath = homeDirectory.appendingPathComponent("Library/Logs/DiagnosticReports")
        
        guard fileManager.fileExists(atPath: crashLogsPath.path) else { return files }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: crashLogsPath, includingPropertiesForKeys: nil)
            for url in contents {
                let fileName = url.lastPathComponent.lowercased()
                if fileName.contains(appName.lowercased()) {
                    let size = calculateSize(at: url)
                    files.append(ResidualFile(path: url, type: .crashReports, size: size))
                }
            }
        } catch {
            // 忽略错误
        }
        
        return files
    }
    
    // MARK: - 通用搜索
    private func searchDirectory(_ directory: URL, appName: String, bundleId: String?, type: FileType) -> [ResidualFile] {
        var files: [ResidualFile] = []
        
        guard fileManager.fileExists(atPath: directory.path) else { return files }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            
            for url in contents {
                let fileName = url.lastPathComponent.lowercased()
                let appNameLower = appName.lowercased()
                let bundleIdLower = bundleId?.lowercased() ?? ""
                
                var matches = false
                
                // 匹配应用名称
                if fileName.contains(appNameLower) {
                    matches = true
                }
                
                // 匹配Bundle ID
                if !bundleIdLower.isEmpty && fileName.contains(bundleIdLower) {
                    matches = true
                }
                
                // 对于Bundle ID的部分匹配 (例如 com.company.appname 匹配 company 或 appname)
                if !bundleIdLower.isEmpty {
                    let components = bundleIdLower.split(separator: ".")
                    for component in components {
                        if fileName.contains(String(component)) && component.count > 3 {
                            matches = true
                            break
                        }
                    }
                }
                
                if matches {
                    let size = calculateSize(at: url)
                    files.append(ResidualFile(path: url, type: type, size: size))
                }
            }
        } catch {
            // 忽略错误
        }
        
        return files
    }
    
    // MARK: - 计算大小
    private func calculateSize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.fileSizeKey],
                    options: [.skipsHiddenFiles],
                    errorHandler: nil
                )
                
                while let fileURL = enumerator?.nextObject() as? URL {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                        totalSize += Int64(resourceValues.fileSize ?? 0)
                    } catch {
                        continue
                    }
                }
            } else {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: url.path)
                    totalSize = Int64(attributes[.size] as? UInt64 ?? 0)
                } catch {
                    // 忽略错误
                }
            }
        }
        
        return totalSize
    }
}
