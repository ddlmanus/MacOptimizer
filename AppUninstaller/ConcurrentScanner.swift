import Foundation

// MARK: - 并发扫描工具类

/// 线程安全的扫描结果收集器
actor ScanResultCollector<T: Sendable> {
    private var results: [T] = []
    private var totalSize: Int64 = 0
    private var processedCount: Int = 0
    
    func append(_ item: T) {
        results.append(item)
    }
    
    func appendContents(of items: [T]) {
        results.append(contentsOf: items)
    }
    
    func addSize(_ size: Int64) {
        totalSize += size
    }
    
    func incrementCount() {
        processedCount += 1
    }
    
    func incrementCount(by count: Int) {
        processedCount += count
    }
    
    func getResults() -> [T] {
        return results
    }
    
    func getTotalSize() -> Int64 {
        return totalSize
    }
    
    func getProcessedCount() -> Int {
        return processedCount
    }
    
    func clear() {
        results.removeAll()
        totalSize = 0
        processedCount = 0
    }
}

/// 并发扫描进度跟踪器
actor ScanProgressTracker {
    private var completedTasks: Int = 0
    private var totalTasks: Int = 0
    private var currentPath: String = ""
    
    func setTotalTasks(_ count: Int) {
        totalTasks = count
    }
    
    func completeTask() {
        completedTasks += 1
    }
    
    func setCurrentPath(_ path: String) {
        currentPath = path
    }
    
    func getProgress() -> Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }
    
    func getCurrentPath() -> String {
        return currentPath
    }
    
    func reset() {
        completedTasks = 0
        totalTasks = 0
        currentPath = ""
    }
}

// MARK: - 并发文件大小计算

/// 并发计算目录大小（优化版）
func calculateSizeAsync(at url: URL, fileManager: FileManager = .default) async -> Int64 {
    var totalSize: Int64 = 0
    
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
    
    if isDirectory.boolValue {
        // 对于目录，使用并发枚举
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        // 批量收集文件 URL，减少锁竞争
        var fileURLs: [URL] = []
        for case let fileURL as URL in enumerator {
            fileURLs.append(fileURL)
        }
        
        // 并发计算大小
        let chunkSize = max(100, fileURLs.count / 8) // 分成最多 8 个任务
        let chunks = stride(from: 0, to: fileURLs.count, by: chunkSize).map {
            Array(fileURLs[$0..<min($0 + chunkSize, fileURLs.count)])
        }
        
        await withTaskGroup(of: Int64.self) { group in
            for chunk in chunks {
                group.addTask {
                    var chunkSize: Int64 = 0
                    for fileURL in chunk {
                        if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                            chunkSize += Int64(size)
                        }
                    }
                    return chunkSize
                }
            }
            
            for await size in group {
                totalSize += size
            }
        }
    } else {
        // 单个文件直接获取大小
        if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? UInt64 {
            totalSize = Int64(size)
        }
    }
    
    return totalSize
}

/// 快速估算目录大小（采样法，速度更快但不精确）
func estimateDirectorySize(at url: URL, sampleRate: Double = 0.1, fileManager: FileManager = .default) async -> Int64 {
    guard let enumerator = fileManager.enumerator(
        at: url,
        includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else { return 0 }
    
    var sampledSize: Int64 = 0
    var sampledCount = 0
    var totalCount = 0
    
    for case let fileURL as URL in enumerator {
        totalCount += 1
        
        // 按采样率采样
        if Double.random(in: 0...1) < sampleRate {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                sampledSize += Int64(size)
                sampledCount += 1
            }
        }
    }
    
    // 根据采样结果估算总大小
    guard sampledCount > 0 else { return 0 }
    let averageSize = Double(sampledSize) / Double(sampledCount)
    return Int64(averageSize * Double(totalCount))
}

// MARK: - 并发目录扫描

/// 扫描配置
struct ScanConfiguration {
    /// 最大并发任务数
    var maxConcurrency: Int = 8
    /// UI 更新间隔（处理多少个文件后更新一次）
    var uiUpdateInterval: Int = 100
    /// 最小文件大小阈值（字节）
    var minFileSize: Int64 = 0
    /// 是否跳过隐藏文件
    var skipHiddenFiles: Bool = true
    /// 要排除的目录路径
    var excludedPaths: Set<String> = []
    
    static let `default` = ScanConfiguration()
    
    static let junkScan = ScanConfiguration(
        maxConcurrency: 8,
        uiUpdateInterval: 50,
        minFileSize: 0,
        skipHiddenFiles: false,
        excludedPaths: []
    )
    
    static let largeFileScan = ScanConfiguration(
        maxConcurrency: 8,
        uiUpdateInterval: 100,
        minFileSize: 50 * 1024 * 1024, // 50MB
        skipHiddenFiles: true,
        excludedPaths: ["Library", "Applications", "Public", ".Trash"]
    )
}

/// 并发扫描目录，返回符合条件的文件
func scanDirectoryConcurrently<T: Sendable>(
    directories: [URL],
    configuration: ScanConfiguration = .default,
    transform: @escaping @Sendable (URL, URLResourceValues) async -> T?
) async -> [T] {
    let collector = ScanResultCollector<T>()
    let fileManager = FileManager.default
    
    await withTaskGroup(of: [T].self) { group in
        for directory in directories {
            group.addTask {
                var items: [T] = []
                
                guard fileManager.fileExists(atPath: directory.path) else { return items }
                
                let options: FileManager.DirectoryEnumerationOptions = configuration.skipHiddenFiles 
                    ? [.skipsHiddenFiles] 
                    : []
                
                guard let enumerator = fileManager.enumerator(
                    at: directory,
                    includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
                    options: options
                ) else { return items }
                
                for case let fileURL as URL in enumerator {
                    // 检查是否在排除列表中
                    let relativePath = fileURL.path.replacingOccurrences(of: directory.path, with: "")
                    let shouldExclude = configuration.excludedPaths.contains { 
                        relativePath.hasPrefix("/\($0)") || relativePath.hasPrefix($0)
                    }
                    
                    if shouldExclude {
                        enumerator.skipDescendants()
                        continue
                    }
                    
                    guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]) else {
                        continue
                    }
                    
                    // 跳过目录
                    if values.isDirectory == true { continue }
                    
                    // 大小过滤
                    let size = Int64(values.fileSize ?? 0)
                    if size < configuration.minFileSize { continue }
                    
                    // 转换
                    if let item = await transform(fileURL, values) {
                        items.append(item)
                    }
                }
                
                return items
            }
        }
        
        for await items in group {
            await collector.appendContents(of: items)
        }
    }
    
    return await collector.getResults()
}

// MARK: - 批量 UI 更新管理器

/// 批量 UI 更新管理器，减少 MainActor 调用频率
actor BatchUIUpdater {
    private var pendingUpdates: [() -> Void] = []
    private var lastUpdateTime: Date = Date()
    private let minUpdateInterval: TimeInterval
    
    init(minUpdateInterval: TimeInterval = 0.1) {
        self.minUpdateInterval = minUpdateInterval
    }
    
    func scheduleUpdate(_ update: @escaping () -> Void) async {
        pendingUpdates.append(update)
        
        let now = Date()
        if now.timeIntervalSince(lastUpdateTime) >= minUpdateInterval {
            await flush()
        }
    }
    
    func flush() async {
        guard !pendingUpdates.isEmpty else { return }
        
        let updates = pendingUpdates
        pendingUpdates.removeAll()
        lastUpdateTime = Date()
        
        await MainActor.run {
            for update in updates {
                update()
            }
        }
    }
}

// MARK: - 文件哈希并发计算

import CryptoKit

/// 并发计算多个文件的 MD5 哈希
func computeHashesConcurrently(for urls: [URL], maxConcurrency: Int = 8) async -> [URL: String] {
    var results: [URL: String] = [:]
    
    await withTaskGroup(of: (URL, String?).self) { group in
        // 使用信号量控制并发数
        var pendingCount = 0
        var urlIndex = 0
        
        while urlIndex < urls.count || pendingCount > 0 {
            // 添加新任务直到达到最大并发数
            while pendingCount < maxConcurrency && urlIndex < urls.count {
                let url = urls[urlIndex]
                urlIndex += 1
                pendingCount += 1
                
                group.addTask {
                    guard let data = try? Data(contentsOf: url) else { return (url, nil) }
                    let digest = Insecure.MD5.hash(data: data)
                    let hash = digest.map { String(format: "%02x", $0) }.joined()
                    return (url, hash)
                }
            }
            
            // 等待一个任务完成
            if let (url, hash) = await group.next() {
                pendingCount -= 1
                if let hash = hash {
                    results[url] = hash
                }
            }
        }
    }
    
    return results
}
