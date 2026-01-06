import Foundation
import AppKit

/// 恢复管理器 - 提供清理操作的撤销和恢复功能
class RecoveryManager: ObservableObject {
    static let shared = RecoveryManager()
    
    private let fileManager = FileManager.default
    private let backupDirectory: URL
    private let historyFile: URL
    
    @Published var deletionHistory: [DeletionRecord] = []
    @Published var backupSize: Int64 = 0
    
    // MARK: - 初始化
    
    private init() {
        // 备份目录: ~/Library/Application Support/MacOptimizer/Backups
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        backupDirectory = appSupport
            .appendingPathComponent("MacOptimizer")
            .appendingPathComponent("Backups")
        
        historyFile = appSupport
            .appendingPathComponent("MacOptimizer")
            .appendingPathComponent("deletion_history.json")
        
        // 创建备份目录
        try? fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        
        // 加载历史记录
        loadHistory()
        
        // 计算备份大小
        calculateBackupSize()
    }
    
    // MARK: - 公共API
    
    /// 备份文件 (在删除前调用)
    /// - Parameters:
    ///   - url: 要备份的文件URL
    ///   - category: 清理类别
    /// - Returns: 是否备份成功
    @discardableResult
    func backupBeforeDeletion(_ url: URL, category: String) -> Bool {
        // 对于关键配置文件才备份
        let shouldBackup = url.path.contains("/Library/Preferences") ||
                          url.path.contains("/Library/Application Support")
        
        guard shouldBackup else { return true }
        
        // 创建备份子目录
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        let backupSubdir = backupDirectory
            .appendingPathComponent(category)
            .appendingPathComponent(timestamp)
        
        do {
            try fileManager.createDirectory(at: backupSubdir, withIntermediateDirectories: true)
            
            // 复制文件到备份目录
            let backupURL = backupSubdir.appendingPathComponent(url.lastPathComponent)
            try fileManager.copyItem(at: url, to: backupURL)
            
            print("[RecoveryManager] ✅ Backed up: \(url.lastPathComponent)")
            return true
        } catch {
            print("[RecoveryManager] ⚠️ Backup failed: \(error)")
            return false
        }
    }
    
    /// 记录删除操作
    /// - Parameters:
    ///   - url: 删除的文件URL
    ///   - category: 清理类别
    ///   - size: 文件大小
    ///   - wasBackedUp: 是否已备份
    func recordDeletion(url: URL, category: String, size: Int64, wasBackedUp: Bool) {
        let record = DeletionRecord(
            originalPath: url.path,
            fileName: url.lastPathComponent,
            category: category,
            size: size,
            deletionDate: Date(),
            wasBackedUp: wasBackedUp,
            canRecover: wasBackedUp || isInTrash(url)
        )
        
        DispatchQueue.main.async {
            self.deletionHistory.insert(record, at: 0)
            self.saveHistory()
        }
    }
    
    /// 恢复文件 (从备份或废纸篓)
    /// - Parameter record: 删除记录
    /// - Returns: 是否恢复成功
    func recoverFile(_ record: DeletionRecord) async -> Bool {
        // 1. 尝试从备份恢复
        if record.wasBackedUp {
            // 查找备份文件
            if let backupURL = findBackupFile(for: record) {
                do {
                    let originalURL = URL(fileURLWithPath: record.originalPath)
                    
                    // 检查原位置是否已存在文件
                    if fileManager.fileExists(atPath: originalURL.path) {
                        print("[RecoveryManager] ⚠️ File already exists at original location")
                        return false
                    }
                    
                    // 恢复文件
                    try fileManager.copyItem(at: backupURL, to: originalURL)
                    print("[RecoveryManager] ✅ Recovered from backup: \(record.fileName)")
                    
                    // 从历史记录中移除
                    await MainActor.run {
                        deletionHistory.removeAll { $0.id == record.id }
                        saveHistory()
                    }
                    
                    return true
                } catch {
                    print("[RecoveryManager] ❌ Recovery failed: \(error)")
                    return false
                }
            }
        }
        
        // 2. 尝试从废纸篓恢复
        // TODO: 实现废纸篓恢复逻辑
        // macOS的废纸篓恢复比较复杂,需要解析.DS_Store文件
        
        return false
    }
    
    /// 清理过期备份 (默认保留30天)
    func cleanupExpiredBackups(daysToKeep: Int = 30) {
        let cutoffDate = Date().addingTimeInterval(-Double(daysToKeep * 86400))
        
        // 清理历史记录
        deletionHistory.removeAll { $0.deletionDate < cutoffDate }
        saveHistory()
        
        // 清理备份文件
        guard let contents = try? fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }
        
        for categoryDir in contents {
            guard let subdirs = try? fileManager.contentsOfDirectory(
                at: categoryDir,
                includingPropertiesForKeys: [.creationDateKey]
            ) else { continue }
            
            for backupDir in subdirs {
                if let creationDate = try? backupDir.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < cutoffDate {
                    try? fileManager.removeItem(at: backupDir)
                    print("[RecoveryManager] 🗑️ Removed expired backup: \(backupDir.lastPathComponent)")
                }
            }
        }
        
        calculateBackupSize()
    }
    
    // MARK: - 私有方法
    
    private func isInTrash(_ url: URL) -> Bool {
        let trashURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        let trashPath = trashURL.path
        
        // 检查文件是否在废纸篓中
        // 注意: 这个方法只能检查用户的废纸篓,不能检查其他卷的废纸篓
        return url.path.hasPrefix(trashPath)
    }
    
    private func findBackupFile(for record: DeletionRecord) -> URL? {
        let categoryDir = backupDirectory.appendingPathComponent(record.category)
        
        guard let timestampDirs = try? fileManager.contentsOfDirectory(
            at: categoryDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        
        // 按时间排序,查找最接近删除时间的备份
        let sortedDirs = timestampDirs.sorted { dir1, dir2 in
            let date1 = try? dir1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            let date2 = try? dir2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
        }
        
        for dir in sortedDirs {
            let backupFile = dir.appendingPathComponent(record.fileName)
            if fileManager.fileExists(atPath: backupFile.path) {
                return backupFile
            }
        }
        
        return nil
    }
    
    private func calculateBackupSize() {
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(
            at: backupDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return }
        
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        
        DispatchQueue.main.async {
            self.backupSize = totalSize
        }
    }
    
    private func loadHistory() {
        guard fileManager.fileExists(atPath: historyFile.path),
              let data = try? Data(contentsOf: historyFile),
              let records = try? JSONDecoder().decode([DeletionRecord].self, from: data) else {
            return
        }
        
        deletionHistory = records
    }
    
    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(deletionHistory) else { return }
        try? data.write(to: historyFile)
    }
}

// MARK: - 删除记录

struct DeletionRecord: Identifiable, Codable {
    let id = UUID()
    let originalPath: String
    let fileName: String
    let category: String
    let size: Int64
    let deletionDate: Date
    let wasBackedUp: Bool
    let canRecover: Bool
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: deletionDate)
    }
    
    enum CodingKeys: String, CodingKey {
        case originalPath, fileName, category, size, deletionDate, wasBackedUp, canRecover
    }
}
