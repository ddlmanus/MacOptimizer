import Foundation
import SwiftUI
import os.log

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

struct DeletionResult: Sendable {
    let successCount: Int
    let failedCount: Int
    let recoveredSize: Int64
    let failedFiles: [String]
    let errors: [String]
    
    var isSuccessful: Bool {
        failedCount == 0
    }
}

/// Progress information for scan operations
struct ScanProgress: Sendable {
    let filesProcessed: Int
    let totalEstimated: Int
    let currentPath: String
    let elapsedTime: TimeInterval
}

class LargeFileScanner: ObservableObject {
    @Published var foundFiles: [FileItem] = []
    @Published var isScanning = false
    @Published var scannedCount = 0
    @Published var totalSize: Int64 = 0
    @Published var hasCompletedScan = false
    @Published var scanProgress: ScanProgress?
    
    private let minimumSize: Int64 = 50 * 1024 * 1024 // 50MB
    private let taskQueue = BackgroundTaskQueue()
    private let uiUpdater = BatchedUIUpdater()
    private let performanceMonitor = PerformanceMonitor()
    
    // Cleaning state
    @Published var isCleaning = false
    @Published var cleanedCount = 0
    @Published var cleanedSize: Int64 = 0
    @Published var isStopped = false
    @Published var selectedFiles: Set<UUID> = []
    private var shouldStop = false
    
    // Computed property for total size of selected files
    var totalSelectedSize: Int64 {
        foundFiles.filter { selectedFiles.contains($0.id) }.reduce(0) { $0 + $1.size }
    }
    
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
        scanProgress = nil
    }
    
    func scan() async {
        let token = performanceMonitor.startMeasuring("largeFileScan")
        defer { performanceMonitor.endMeasuring(token) }
        
        await MainActor.run {
            self.isScanning = true
            self.foundFiles = []
            self.scannedCount = 0
            self.totalSize = 0
            self.hasCompletedScan = false
            self.isStopped = false
            self.shouldStop = false
            self.scanProgress = nil
        }
        
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        // Critical directories to exclude from recursion
        let excludedDirs: Set<String> = [
            "Library", "Applications", "Public", ".Trash", ".git", "node_modules", 
            "go", "venv", ".build", "Pods" // Dev exclusions
        ]
        
        // Get all top-level items in Home
        guard let topLevelItems = try? fileManager.contentsOfDirectory(at: home, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            await MainActor.run { self.isScanning = false }
            return
        }
        
        let collector = ScanResultCollector<FileItem>()
        var totalScannedCount = 0
        let scanStartTime = Date()
        
        await withTaskGroup(of: ([FileItem], Int).self) { group in
            for itemURL in topLevelItems {
                let name = itemURL.lastPathComponent
                if excludedDirs.contains(name) { continue }
                
                // Determine if it's a directory
                let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
                let isDirectory = resourceValues?.isDirectory ?? false
                let isPackage = resourceValues?.isPackage ?? false
                
                if isDirectory && !isPackage {
                    // Spawn a task for each top-level directory (Recursively scan)
                    group.addTask {
                        await self.scanDirectoryRecursively(itemURL, excludedDirs: excludedDirs)
                    }
                } else {
                    // Check file size directly
                    group.addTask {
                        await self.checkFileSize(itemURL)
                    }
                }
            }
            
            // Collect results with batch processing and progress reporting
            var batchFiles: [FileItem] = []
            var batchSize: Int64 = 0
            var lastUpdateTime = Date()
            
            for await (files, count) in group {
                if self.shouldStop { break }
                batchFiles.append(contentsOf: files)
                totalScannedCount += count
                batchSize += files.reduce(0) { $0 + $1.size }
                
                // Update UI periodically with progress
                let now = Date()
                if now.timeIntervalSince(lastUpdateTime) >= 0.2 || batchFiles.count >= 20 {
                    let currentFiles = batchFiles.sorted(by: { $0.size > $1.size })
                    let currentTotal = batchSize
                    let currentCount = totalScannedCount
                    let elapsedTime = now.timeIntervalSince(scanStartTime)
                    
                    await self.uiUpdater.batch {
                        self.foundFiles = currentFiles
                        self.totalSize = currentTotal
                        self.scannedCount = currentCount
                        self.scanProgress = ScanProgress(
                            filesProcessed: currentCount,
                            totalEstimated: currentCount + 1000, // Rough estimate
                            currentPath: "",
                            elapsedTime: elapsedTime
                        )
                    }
                    lastUpdateTime = now
                }
                
                await collector.appendContents(of: files)
            }
        }
        
        // Final Update
        let finalFiles = await collector.getResults().sorted(by: { $0.size > $1.size })
        let finalTotal = finalFiles.reduce(0) { $0 + $1.size }
        let totalElapsedTime = Date().timeIntervalSince(scanStartTime)
        
        await uiUpdater.batch {
            self.foundFiles = finalFiles
            self.totalSize = finalTotal
            self.scannedCount = totalScannedCount
            self.isScanning = false
            self.hasCompletedScan = true
            self.scanProgress = ScanProgress(
                filesProcessed: totalScannedCount,
                totalEstimated: totalScannedCount,
                currentPath: "Scan complete",
                elapsedTime: totalElapsedTime
            )
        }
    }
    
    private func scanDirectoryRecursively(_ directory: URL, excludedDirs: Set<String>) async -> ([FileItem], Int) {
        let fileManager = FileManager.default
        var files: [FileItem] = []
        var scannedCount = 0
        
        // Use enumerator for deep recursion
        // skipsPackageDescendants is CRITICAL to treat Apps/Bundles as single files
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentAccessDateKey],
            options: options
        ) else { return (files, scannedCount) }
        
        while let fileURL = enumerator.nextObject() as? URL {
            // Check for cancellation
            if self.shouldStop || self.isStopped { break } // Simple check, though running in sync loop
            
            scannedCount += 1
            
            // Exclusion check
            if excludedDirs.contains(fileURL.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentAccessDateKey])
                
                if let isDirectory = resourceValues.isDirectory, isDirectory {
                    continue
                }
                
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
                continue
            }
        }
        
        return (files, scannedCount)
    }
    
    // Check single file
    private func checkFileSize(_ url: URL) async -> ([FileItem], Int) {
        var files: [FileItem] = []
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .contentAccessDateKey])
            if let fileSize = resourceValues.fileSize, Int64(fileSize) > minimumSize {
                 let item = FileItem(
                    url: url,
                    name: url.lastPathComponent,
                    size: Int64(fileSize),
                    type: url.pathExtension.isEmpty ? "File" : url.pathExtension.uppercased(),
                    accessDate: resourceValues.contentAccessDate ?? Date()
                )
                files.append(item)
            }
            return (files, 1)
        } catch {
            return ([], 1)
        }
    }
    
    // Helper to get relative path
    // Need to add this extension if not exists, or just check simple string containment

    
    func deleteItems(_ items: Set<UUID>) async -> DeletionResult {
        var successCount = 0
        var failedCount = 0
        var recoveredSize: Int64 = 0
        var failedFiles: [String] = []
        var errors: [String] = []
        
        let logger = Logger(subsystem: "com.appuninstaller", category: "LargeFileScanner")
        
        for file in foundFiles where items.contains(file.id) {
            do {
                try FileManager.default.removeItem(at: file.url)
                successCount += 1
                recoveredSize += file.size
                logger.info("Successfully deleted: \(file.name)")
            } catch {
                failedCount += 1
                failedFiles.append(file.name)
                let errorDescription = error.localizedDescription
                errors.append("\(file.name): \(errorDescription)")
                logger.error("Failed to delete \(file.url.path): \(error.localizedDescription)")
            }
        }
        
        // Re-scan or just remove directly from array
        let remainingFiles = foundFiles.filter { !items.contains($0.id) }
        let newTotal = remainingFiles.reduce(0) { $0 + $1.size }
        
        let result = DeletionResult(
            successCount: successCount,
            failedCount: failedCount,
            recoveredSize: recoveredSize,
            failedFiles: failedFiles,
            errors: errors
        )
        
        // Batch UI updates
        await uiUpdater.batch {
            self.foundFiles = remainingFiles
            self.totalSize = newTotal
            self.cleanedCount += successCount
            self.cleanedSize += recoveredSize
            self.selectedFiles.removeAll()
        }
        
        return result
    }
}

