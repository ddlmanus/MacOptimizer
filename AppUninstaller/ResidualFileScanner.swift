import Foundation

// MARK: - 残留文件扫描服务
class ResidualFileScanner {
    private let fileManager = FileManager.default
    private let homeDirectory = URL(fileURLWithPath: NSHomeDirectory())
    private let scanCache = CacheManager<String, [ResidualFile]>(maxSizeBytes: 50 * 1024 * 1024) // 50MB cache
    private let taskQueue = BackgroundTaskQueue()
    
    /// 扫描应用的所有残留文件
    func scanResidualFiles(for app: InstalledApp) async -> [ResidualFile] {
        let cacheKey = app.bundleIdentifier ?? app.name
        
        // Check cache first (5 minute TTL)
        if let cachedFiles = scanCache.get(cacheKey) {
            return cachedFiles
        }
        
        // Perform scan on background thread
        let residualFiles = await taskQueue.enqueue { [weak self] in
            guard let self = self else { return [ResidualFile]() }
            
            var residualFiles: [ResidualFile] = []
            
            let appName = app.name
            let bundleId = app.bundleIdentifier
            
            // 扫描各个位置 - batch process results
            residualFiles.append(contentsOf: self.scanPreferences(appName: appName, bundleId: bundleId))
            residualFiles.append(contentsOf: self.scanApplicationSupport(appName: appName, bundleId: bundleId))
            residualFiles.append(contentsOf: self.scanCaches(appName: appName, bundleId: bundleId))
            residualFiles.append(contentsOf: self.scanLogs(appName: appName, bundleId: bundleId))
            residualFiles.append(contentsOf: self.scanSavedState(bundleId: bundleId))
            residualFiles.append(contentsOf: self.scanContainers(bundleId: bundleId))
            residualFiles.append(contentsOf: self.scanGroupContainers(bundleId: bundleId))
            residualFiles.append(contentsOf: self.scanCookies(appName: appName, bundleId: bundleId))
            residualFiles.append(contentsOf: self.scanLaunchAgents(appName: appName, bundleId: bundleId))
            residualFiles.append(contentsOf: self.scanCrashReports(appName: appName, bundleId: bundleId))
            residualFiles.append(contentsOf: self.scanDeveloper(appName: appName, bundleId: bundleId))
            residualFiles.append(contentsOf: self.scanKnownApplicationData(bundleId: bundleId))
            // AppCleaner 等价补全：以下位置原实现未覆盖
            residualFiles.append(contentsOf: self.scanHTTPStorages(bundleId: bundleId))
            residualFiles.append(contentsOf: self.scanWebKit(bundleId: bundleId))
            residualFiles.append(contentsOf: self.scanApplicationScripts(bundleId: bundleId))
            residualFiles.append(contentsOf: self.scanByHostPreferences(bundleId: bundleId))
            residualFiles.append(contentsOf: self.scanSystemWide(appName: appName, bundleId: bundleId))
            residualFiles.append(contentsOf: self.scanPrivilegedHelpers(bundleId: bundleId))
            residualFiles.append(contentsOf: self.scanPackageReceipts(bundleId: bundleId))
            
            var seenPaths = Set<String>()
            return residualFiles.filter {
                seenPaths.insert($0.path.standardizedFileURL.path).inserted &&
                ScanResultIgnoreStore.shouldInclude($0.path)
            }
        }
        
        // Cache the results
        scanCache.set(cacheKey, value: residualFiles, ttl: 300)
        
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
            
            // Process in batches to prevent memory spikes
            let batchSize = 100
            for batch in contents.chunked(into: batchSize) {
                for url in batch {
                    let fileName = url.lastPathComponent.lowercased()
                    let fileStem = url.deletingPathExtension().lastPathComponent.lowercased()
                    let appNameLower = appName.lowercased()
                    let bundleIdLower = bundleId?.lowercased() ?? ""
                    
                    var matches = false
                    
                    // 匹配应用名称
                    if fileName == appNameLower || fileStem == appNameLower {
                        matches = true
                    }
                    
                    // 匹配Bundle ID
                    if !bundleIdLower.isEmpty && fileName.contains(bundleIdLower) {
                        matches = true
                    }
                    
                    // 移除危险的 Bundle ID 组件拆分匹配
                    // 原逻辑会将 com.apple.safari 拆分为 apple 并匹配所有包含 apple 的文件，极其危险
                    // 仅保留完整的 Bundle ID 匹配和应用名称匹配
                    
                    if matches {
                        let size = calculateSize(at: url)
                        files.append(ResidualFile(path: url, type: type, size: size))
                    }
                }
            }
        } catch {
            // 忽略错误
        }
        
        return files
    }

    /// Some Electron/Chromium apps keep their largest user data in a vendor or
    /// CLI directory whose name is not the app bundle name. CleanMyMac includes
    /// these paths in the installed app's total, so keep the mapping narrow and
    /// bundle-ID based to avoid claiming unrelated folders.
    private func scanKnownApplicationData(bundleId: String?) -> [ResidualFile] {
        guard let bundleId = bundleId?.lowercased() else { return [] }
        let paths: [(URL, FileType)]

        switch bundleId {
        case "com.google.chrome":
            paths = [
                (homeDirectory.appendingPathComponent("Library/Application Support/Google"), .applicationSupport),
                (homeDirectory.appendingPathComponent("Library/Caches/Google"), .caches),
                (homeDirectory.appendingPathComponent("Library/HTTPStorages/com.google.Chrome"), .caches)
            ]
        case "com.openai.codex":
            paths = [
                (homeDirectory.appendingPathComponent("Library/Application Support/Codex"), .applicationSupport),
                (homeDirectory.appendingPathComponent("Library/Caches/Codex"), .caches),
                (homeDirectory.appendingPathComponent(".codex"), .applicationSupport)
            ]
        case "com.todesktop.230313mzl4w4u92":
            paths = [
                (homeDirectory.appendingPathComponent("Library/Application Support/Cursor"), .applicationSupport),
                (homeDirectory.appendingPathComponent(".cursor"), .applicationSupport)
            ]
        default:
            paths = []
        }

        return paths.compactMap { url, type in
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return ResidualFile(path: url, type: type, size: calculateSize(at: url))
        }
    }
    
    // MARK: - AppCleaner 等价补全扫描
    //
    // AppCleaner 除了 ~/Library 下的常规目录，还会扫描 HTTPStorages、WebKit、
    // Application Scripts、ByHost 偏好、系统级 /Library 各处、特权助手以及 pkg 收据。
    // 以下实现按同样的路径集合做标识匹配，保证卸载后不留残渣。

    /// 统一的标识匹配：优先 bundle id，其次精确应用名。
    /// 只做「等于 / 前缀 / 后缀」判断，避免 com.foo.app 误伤 com.foo.app2。
    private func matchesResidual(_ candidate: String, appName: String, bundleId: String?) -> Bool {
        let lower = candidate.lowercased()
        guard !lower.isEmpty else { return false }

        if lower == appName.lowercased() { return true }

        guard let bid = bundleId?.lowercased(), !bid.isEmpty else { return false }
        if lower == bid { return true }
        if lower.hasPrefix(bid + ".") { return true }      // com.vendor.app / com.vendor.app.helper
        if lower.hasSuffix("." + bid) { return true }      // TeamID.com.vendor.app
        return false
    }

    /// 精确路径探测
    private func probePath(_ url: URL, type: FileType) -> [ResidualFile] {
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        return [ResidualFile(path: url, type: type, size: calculateSize(at: url))]
    }

    /// 列出目录内容（失败返回空数组，不抛错）
    private func listDirectory(_ url: URL) -> [URL] {
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        return (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
    }

    // MARK: 网络存储（HTTPStorages + binarycookies）
    private func scanHTTPStorages(bundleId: String?) -> [ResidualFile] {
        guard let bid = bundleId?.lowercased(), !bid.isEmpty else { return [] }
        let dir = homeDirectory.appendingPathComponent("Library/HTTPStorages")
        var files: [ResidualFile] = []

        for url in listDirectory(dir) {
            let stem = url.deletingPathExtension().lastPathComponent.lowercased()
            guard stem == bid || stem.hasPrefix(bid + ".") else { continue }
            files.append(ResidualFile(path: url, type: .httpStorages, size: calculateSize(at: url)))
        }
        return files
    }

    // MARK: WebKit 网页数据（localStorage / IndexedDB 常驻在此）
    private func scanWebKit(bundleId: String?) -> [ResidualFile] {
        guard let bid = bundleId, !bid.isEmpty else { return [] }
        let dir = homeDirectory.appendingPathComponent("Library/WebKit/\(bid)")
        return probePath(dir, type: .webKit)
    }

    // MARK: 应用脚本（AppleScript / 沙盒化脚本目录）
    private func scanApplicationScripts(bundleId: String?) -> [ResidualFile] {
        guard let bid = bundleId, !bid.isEmpty else { return [] }
        let dir = homeDirectory.appendingPathComponent("Library/Application Scripts/\(bid)")
        return probePath(dir, type: .applicationScripts)
    }

    // MARK: ByHost 偏好（~/Library/Preferences/ByHost/<bid>.<UUID>.plist）
    private func scanByHostPreferences(bundleId: String?) -> [ResidualFile] {
        guard let bid = bundleId?.lowercased(), !bid.isEmpty else { return [] }
        let dir = homeDirectory.appendingPathComponent("Library/Preferences/ByHost")
        var files: [ResidualFile] = []

        for url in listDirectory(dir) {
            let stem = url.deletingPathExtension().lastPathComponent.lowercased()
            guard stem == bid || stem.hasPrefix(bid + ".") else { continue }
            files.append(ResidualFile(path: url, type: .preferences, size: calculateSize(at: url)))
        }
        return files
    }

    // MARK: 系统级 /Library（需要管理员权限删除，FileRemover 会自动提权）
    private func scanSystemWide(appName: String, bundleId: String?) -> [ResidualFile] {
        var files: [ResidualFile] = []
        let libraryRoot = URL(fileURLWithPath: "/Library")

        let sections: [(String, FileType)] = [
            ("Application Support", .applicationSupport),
            ("Caches", .caches),
            ("Logs", .logs),
            ("LaunchAgents", .launchAgents),
            ("LaunchDaemons", .launchAgents)
        ]

        for (sub, type) in sections {
            for url in listDirectory(libraryRoot.appendingPathComponent(sub)) {
                let fileName = url.lastPathComponent.lowercased()
                let stem = url.deletingPathExtension().lastPathComponent.lowercased()
                if matchesResidual(fileName, appName: appName, bundleId: bundleId)
                    || matchesResidual(stem, appName: appName, bundleId: bundleId) {
                    files.append(ResidualFile(path: url, type: type, size: calculateSize(at: url)))
                }
            }
        }

        if let bid = bundleId, !bid.isEmpty {
            files.append(contentsOf: probePath(
                libraryRoot.appendingPathComponent("Preferences/\(bid).plist"),
                type: .preferences
            ))
        }
        return files
    }

    // MARK: 特权助手（/Library/PrivilegedHelperTools，形如 TeamID.bundleid.helper）
    private func scanPrivilegedHelpers(bundleId: String?) -> [ResidualFile] {
        guard let bid = bundleId?.lowercased(), !bid.isEmpty else { return [] }
        let dir = URL(fileURLWithPath: "/Library/PrivilegedHelperTools")
        return listDirectory(dir)
            .filter { $0.lastPathComponent.lowercased().contains(bid) }
            .map { ResidualFile(path: $0, type: .privilegedHelpers, size: calculateSize(at: $0)) }
    }

    // MARK: 安装收据（/private/var/db/receipts，pkg 安装残留）
    private func scanPackageReceipts(bundleId: String?) -> [ResidualFile] {
        guard let bid = bundleId?.lowercased(), !bid.isEmpty else { return [] }
        let dir = URL(fileURLWithPath: "/private/var/db/receipts")
        return listDirectory(dir)
            .filter { $0.lastPathComponent.lowercased().hasPrefix(bid) }
            .map { ResidualFile(path: $0, type: .receipts, size: calculateSize(at: $0)) }
    }

    // MARK: - 计算大小
    private func calculateSize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                let keys: [URLResourceKey] = [.fileSizeKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]
                let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: keys,
                    options: [.skipsHiddenFiles],
                    errorHandler: nil
                )
                
                while let fileURL = enumerator?.nextObject() as? URL {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: Set(keys))
                        totalSize += Int64(
                            resourceValues.totalFileAllocatedSize ??
                            resourceValues.fileAllocatedSize ??
                            resourceValues.fileSize ?? 0
                        )
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
