import Foundation
import Combine

// MARK: - 启动项模型
class LaunchItem: Identifiable, ObservableObject {
    let id = UUID()
    let url: URL
    let name: String
    
    // 是否启用 (通过判断文件扩展名或是否在 disable 列表中，这里简化处理：如果文件存在且后缀为 .plist 为启用)
    @Published var isEnabled: Bool
    
    init(url: URL) {
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.isEnabled = url.pathExtension == "plist"
    }
}

// MARK: - 系统优化服务
class SystemOptimizer: ObservableObject {
    @Published var launchAgents: [LaunchItem] = []
    @Published var isScanning: Bool = false
    
    private let fileManager = FileManager.default
    private let agentsPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
    
    // 扫描启动项
    func scanLaunchAgents() async {
        await MainActor.run {
            isScanning = true
            launchAgents.removeAll()
        }
        
        guard fileManager.fileExists(atPath: agentsPath.path) else {
            await MainActor.run { isScanning = false }
            return
        }
        
        do {
            let urls = try fileManager.contentsOfDirectory(at: agentsPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            
            let items = urls
                .filter { $0.pathExtension == "plist" || $0.pathExtension == "disabled" }
                .map { LaunchItem(url: $0) }
                .sorted { $0.name < $1.name }
            
            await MainActor.run {
                self.launchAgents = items
                isScanning = false
            }
        } catch {
            print("Error scanning agents: \(error)")
            await MainActor.run { isScanning = false }
        }
    }
    
    // 切换启用状态
    func toggleAgent(_ item: LaunchItem) async -> Bool {
        let currentUrl = item.url
        let newExtension = item.isEnabled ? "disabled" : "plist"
        let newUrl = currentUrl.deletingPathExtension().appendingPathExtension(newExtension)
        
        do {
            try fileManager.moveItem(at: currentUrl, to: newUrl)
            
            // 如果成功，更新模型
            // 注意：实际生产中可能需要 unload/load launchctl 命令
            if item.isEnabled {
                // 尝试卸载服务
                 _ = runCommand("launchctl unload \"\(currentUrl.path)\"")
            } else {
                // 尝试加载服务
                 _ = runCommand("launchctl load \"\(newUrl.path)\"")
            }
            
            // 重新扫描以更新列表（或者直接更新item状态，但路径变了最好重新扫描）
            await scanLaunchAgents()
            return true
        } catch {
            print("Failed to toggle agent: \(error)")
            return false
        }
    }
    
    // 移除启动项
    func removeAgent(_ item: LaunchItem) async {
        do {
            if item.isEnabled {
                _ = runCommand("launchctl unload \"\(item.url.path)\"")
            }
            try fileManager.removeItem(at: item.url)
            await scanLaunchAgents()
        } catch {
            print("Failed to remove agent: \(error)")
        }
    }
    
    private func runCommand(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.launch()
        
        // 不等待过长时间
        // task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
