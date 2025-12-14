import Foundation
import SwiftUI

struct FileItem: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let type: String
    let accessDate: Date
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

class LargeFileScanner: ObservableObject {
    @Published var foundFiles: [FileItem] = []
    @Published var isScanning = false
    @Published var scannedCount = 0
    @Published var totalSize: Int64 = 0
    @Published var hasCompletedScan = false
    
    private let minimumSize: Int64 = 50 * 1024 * 1024 // 50MB
    
    // Cleaning state
    @Published var isCleaning = false
    @Published var cleanedCount = 0
    @Published var cleanedSize: Int64 = 0
    @Published var isStopped = false
    @Published var selectedFiles: Set<UUID> = []
    private var shouldStop = false
    
    func stopScan() {
        shouldStop = true
        isScanning = false
        isStopped = true
    }
    
    func reset() {
        foundFiles = []
        isScanning = false
        scannedCount = 0
        totalSize = 0
        hasCompletedScan = false
        isCleaning = false
        cleanedCount = 0
        cleanedSize = 0
        isStopped = false
        shouldStop = false
        selectedFiles = []
    }
    
    func scan() async {
        await MainActor.run {
            self.isScanning = true
            self.foundFiles = []
            self.scannedCount = 0
            self.totalSize = 0
            self.hasCompletedScan = false
            self.isStopped = false
            self.shouldStop = false
        }
        
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        // 获取 Home 下的主要子目录，并行扫描
        // 扩展扫描范围以覆盖更多用户文件
        let mainDirectories = [
            "Documents", "Downloads", "Desktop", "Movies", "Music", "Pictures",
            "Developer", "Projects", "Work", "src", "code", "Public", "Creative Cloud Files"
        ]
        
        // 需要排除的目录
        let excludedDirs: Set<String> = ["Library", "Applications", "Public", ".Trash", ".git", "node_modules"]
        
        // 并发扫描所有主目录
        let collector = ScanResultCollector<FileItem>()
        var totalScannedCount = 0
        
        await withTaskGroup(of: ([FileItem], Int).self) { group in
            // 扫描主要子目录
            for dirName in mainDirectories {
                let dirURL = home.appendingPathComponent(dirName)
                guard fileManager.fileExists(atPath: dirURL.path) else { continue }
                
                group.addTask {
                    await self.scanDirectoryForLargeFiles(dirURL, excludedDirs: excludedDirs)
                }
            }
            
            // 扫描 Home 目录根级别的大文件（不递归）
            group.addTask {
                await self.scanRootLevelFiles(home)
            }
            
            // 收集结果并批量更新 UI
            var batchFiles: [FileItem] = []
            var batchSize: Int64 = 0
            var lastUpdateTime = Date()
            
            for await (files, count) in group {
                if self.shouldStop { break }
                batchFiles.append(contentsOf: files)
                totalScannedCount += count
                batchSize += files.reduce(0) { $0 + $1.size }
                
                // 每 0.2 秒或累积 20 个文件时更新 UI
                let now = Date()
                if now.timeIntervalSince(lastUpdateTime) >= 0.2 || batchFiles.count >= 20 {
                    let currentFiles = batchFiles.sorted(by: { $0.size > $1.size })
                    let currentTotal = batchSize
                    let currentCount = totalScannedCount
                    
                    await MainActor.run { [currentFiles, currentTotal, currentCount] in
                        self.foundFiles = currentFiles
                        self.totalSize = currentTotal
                        self.scannedCount = currentCount
                    }
                    
                    lastUpdateTime = now
                }
                
                await collector.appendContents(of: files)
            }
        }
        
        // 最终结果
        let finalFiles = await collector.getResults().sorted(by: { $0.size > $1.size })
        let finalTotal = finalFiles.reduce(0) { $0 + $1.size }
        
        await MainActor.run { [finalFiles, finalTotal, totalScannedCount] in
            self.foundFiles = finalFiles
            self.totalSize = finalTotal
            self.scannedCount = totalScannedCount
            self.isScanning = false
            self.hasCompletedScan = true
        }
    }
    
    /// 扫描单个目录中的大文件（并发优化版）
    private func scanDirectoryForLargeFiles(_ directory: URL, excludedDirs: Set<String>) async -> ([FileItem], Int) {
        let fileManager = FileManager.default
        var files: [FileItem] = []
        var scannedCount = 0
        
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentAccessDateKey],
            options: options
        ) else { return (files, scannedCount) }
        
        while let fileURL = enumerator.nextObject() as? URL {
            scannedCount += 1
            
            // 检查是否在排除目录中
            let fileName = fileURL.lastPathComponent
            if excludedDirs.contains(fileName) {
                enumerator.skipDescendants()
                continue
            }
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentAccessDateKey])
                
                // 跳过目录
                if let isDirectory = resourceValues.isDirectory, isDirectory {
                    continue
                }
                
                // 检查文件大小
                if let fileSize = resourceValues.fileSize, Int64(fileSize) > minimumSize {
                    let accessDate = resourceValues.contentAccessDate ?? Date()
                    let item = FileItem(
                        url: fileURL,
                        name: fileURL.lastPathComponent,
                        size: Int64(fileSize),
                        type: fileURL.pathExtension.isEmpty ? "File" : fileURL.pathExtension.uppercased(),
                        accessDate: accessDate
                    )
                    files.append(item)
                }
            } catch {
                // 静默处理权限错误
            }
        }
        
        return (files, scannedCount)
    }
    
    /// 扫描 Home 根目录级别的大文件（不递归）
    private func scanRootLevelFiles(_ home: URL) async -> ([FileItem], Int) {
        let fileManager = FileManager.default
        var files: [FileItem] = []
        var scannedCount = 0
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: home,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentAccessDateKey],
                options: [.skipsHiddenFiles]
            )
            
            for fileURL in contents {
                scannedCount += 1
                
                let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentAccessDateKey])
                
                // 只处理文件，不处理目录
                if let isDirectory = resourceValues?.isDirectory, isDirectory {
                    continue
                }
                
                if let fileSize = resourceValues?.fileSize, Int64(fileSize) > minimumSize {
                    let accessDate = resourceValues?.contentAccessDate ?? Date()
                    let item = FileItem(
                        url: fileURL,
                        name: fileURL.lastPathComponent,
                        size: Int64(fileSize),
                        type: fileURL.pathExtension.isEmpty ? "File" : fileURL.pathExtension.uppercased(),
                        accessDate: accessDate
                    )
                    files.append(item)
                }
            }
        } catch {
            // 静默处理错误
        }
        
        return (files, scannedCount)
    }
    
    // Helper to get relative path
    // Need to add this extension if not exists, or just check simple string containment

    
    func deleteItems(_ items: Set<UUID>) async {
         var successCount = 0
         var recoveredSize: Int64 = 0
         
         for file in foundFiles where items.contains(file.id) {
             do {
                 try FileManager.default.removeItem(at: file.url)
                 successCount += 1
                 recoveredSize += file.size
             } catch {
                 print("Failed to delete \(file.url.path): \(error)")
             }
         }
         
         // Re-scan or just remove directly from array
         let remainingFiles = foundFiles.filter { !items.contains($0.id) }
         let newTotal = remainingFiles.reduce(0) { $0 + $1.size }
         
         await MainActor.run { [remainingFiles, newTotal, successCount, recoveredSize] in
             self.foundFiles = remainingFiles
             self.totalSize = newTotal
             self.cleanedCount += successCount
             self.cleanedSize += recoveredSize
         }
    }
}

