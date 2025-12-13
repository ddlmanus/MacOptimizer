import Foundation
import SwiftUI

// MARK: - 全局扫描服务管理器
/// 单例管理器，保持所有扫描服务的状态，防止视图切换时丢失扫描进度和结果
class ScanServiceManager: ObservableObject {
    static let shared = ScanServiceManager()
    
    // 各个扫描服务 - 作为单例保持
    let junkCleaner = JunkCleaner()
    let largeFileScanner = LargeFileScanner()
    let deepCleanScanner = DeepCleanScanner()
    let smartCleanerService = SmartCleanerService()
    
    // 扫描任务状态跟踪
    @Published var activeScans: Set<ScanType> = []
    
    private init() {}
    
    enum ScanType: String, CaseIterable {
        case junk = "垃圾扫描"
        case largeFiles = "大文件扫描"
        case deepClean = "深度清理"
        case smartClean = "智能清理"
        case duplicates = "重复文件"
        case similarPhotos = "相似照片"
        case localizations = "多语言文件"
    }
    
    // MARK: - 后台扫描管理
    
    /// 启动垃圾扫描（如果未在进行中）
    func startJunkScanIfNeeded() {
        guard !junkCleaner.isScanning else { return }
        activeScans.insert(.junk)
        Task {
            await junkCleaner.scanJunk()
            await MainActor.run {
                activeScans.remove(.junk)
            }
        }
    }
    
    /// 启动大文件扫描（如果未在进行中）
    func startLargeFileScanIfNeeded() {
        guard !largeFileScanner.isScanning else { return }
        activeScans.insert(.largeFiles)
        Task {
            await largeFileScanner.scan()
            await MainActor.run {
                activeScans.remove(.largeFiles)
            }
        }
    }
    
    /// 启动深度清理扫描（如果未在进行中）
    func startDeepCleanScanIfNeeded() {
        guard !deepCleanScanner.isScanning else { return }
        activeScans.insert(.deepClean)
        Task {
            await deepCleanScanner.scan()
            await MainActor.run {
                activeScans.remove(.deepClean)
            }
        }
    }
    
    /// 启动智能清理扫描（如果未在进行中）
    func startSmartCleanScanIfNeeded() {
        guard !smartCleanerService.isScanning else { return }
        activeScans.insert(.smartClean)
        Task {
            await smartCleanerService.scanAll()
            await MainActor.run {
                activeScans.remove(.smartClean)
            }
        }
    }
    
    /// 启动重复文件扫描
    func startDuplicatesScan() {
        guard !smartCleanerService.isScanning else { return }
        activeScans.insert(.duplicates)
        Task {
            await smartCleanerService.scanDuplicates()
            await MainActor.run {
                activeScans.remove(.duplicates)
            }
        }
    }
    
    /// 检查是否有任何扫描正在进行
    var isAnyScanning: Bool {
        junkCleaner.isScanning || 
        largeFileScanner.isScanning || 
        deepCleanScanner.isScanning ||
        smartCleanerService.isScanning
    }
    
    /// 获取正在进行的扫描描述
    var activeScanDescriptions: [String] {
        var descriptions: [String] = []
        if junkCleaner.isScanning { descriptions.append("垃圾扫描") }
        if largeFileScanner.isScanning { descriptions.append("大文件扫描") }
        if deepCleanScanner.isScanning { descriptions.append("深度清理") }
        if smartCleanerService.isScanning { descriptions.append("智能清理") }
        return descriptions
    }
    
    // MARK: - 一键全面扫描
    
    /// 启动全面系统扫描（并行执行所有扫描）
    func startComprehensiveScan() {
        Task {
            await withTaskGroup(of: Void.self) { group in
                // 并行启动所有扫描
                group.addTask {
                    if !self.junkCleaner.isScanning {
                        await MainActor.run { self.activeScans.insert(.junk) }
                        await self.junkCleaner.scanJunk()
                        await MainActor.run { self.activeScans.remove(.junk) }
                    }
                }
                
                group.addTask {
                    if !self.largeFileScanner.isScanning {
                        await MainActor.run { self.activeScans.insert(.largeFiles) }
                        await self.largeFileScanner.scan()
                        await MainActor.run { self.activeScans.remove(.largeFiles) }
                    }
                }
                
                group.addTask {
                    if !self.deepCleanScanner.isScanning {
                        await MainActor.run { self.activeScans.insert(.deepClean) }
                        await self.deepCleanScanner.scan()
                        await MainActor.run { self.activeScans.remove(.deepClean) }
                    }
                }
                
                group.addTask {
                    if !self.smartCleanerService.isScanning {
                        await MainActor.run { self.activeScans.insert(.smartClean) }
                        await self.smartCleanerService.scanAll()
                        await MainActor.run { self.activeScans.remove(.smartClean) }
                    }
                }
            }
        }
    }
    
    // MARK: - 统计信息
    
    /// 获取总共可清理的空间大小
    var totalCleanableSize: Int64 {
        junkCleaner.totalSize +
        deepCleanScanner.totalSize +
        smartCleanerService.totalCleanableSize
    }
    
    /// 获取发现的大文件总大小
    var totalLargeFilesSize: Int64 {
        largeFileScanner.totalSize
    }
    
    /// 获取所有扫描项目数量
    var totalItemsFound: Int {
        junkCleaner.junkItems.count +
        largeFileScanner.foundFiles.count +
        deepCleanScanner.orphanedItems.count +
        smartCleanerService.duplicateGroups.flatMap { $0.files }.count +
        smartCleanerService.localizationFiles.count
    }
}
