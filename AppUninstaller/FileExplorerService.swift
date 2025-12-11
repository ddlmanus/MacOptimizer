import SwiftUI
import UniformTypeIdentifiers

// MARK: - Models

struct ExplorerFileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date?
    let creationDate: Date?
    let isHidden: Bool
    
    var formattedSize: String {
        if isDirectory { return "--" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var formattedDate: String {
        guard let date = modificationDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var fileExtension: String {
        url.pathExtension.lowercased()
    }
    
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
    
    static func == (lhs: ExplorerFileItem, rhs: ExplorerFileItem) -> Bool {
        lhs.url == rhs.url
    }
}

struct QuickAccessItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let url: URL
}

// MARK: - Service

class FileExplorerService: ObservableObject {
    @Published var currentPath: URL
    @Published var items: [ExplorerFileItem] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var navigationHistory: [URL] = []
    @Published var historyIndex = -1
    @Published var showHiddenFiles = false
    @Published var shellOutput: String = ""
    @Published var isRunningCommand = false
    
    private let fileManager = FileManager.default
    
    // 快捷访问位置
    let quickAccessItems: [QuickAccessItem]
    
    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        currentPath = home
        
        quickAccessItems = [
            QuickAccessItem(name: "主目录", icon: "house.fill", url: home),
            QuickAccessItem(name: "桌面", icon: "menubar.dock.rectangle", url: home.appendingPathComponent("Desktop")),
            QuickAccessItem(name: "文稿", icon: "doc.fill", url: home.appendingPathComponent("Documents")),
            QuickAccessItem(name: "下载", icon: "arrow.down.circle.fill", url: home.appendingPathComponent("Downloads")),
            QuickAccessItem(name: "应用程序", icon: "square.grid.2x2.fill", url: URL(fileURLWithPath: "/Applications")),
            QuickAccessItem(name: "磁盘根目录", icon: "externaldrive.fill", url: URL(fileURLWithPath: "/")),
        ]
        
        navigateTo(home, addToHistory: true)
    }
    
    func navigateTo(_ url: URL, addToHistory: Bool = true) {
        isLoading = true
        error = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var loadedItems: [ExplorerFileItem] = []
            
            do {
                let contents = try self.fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey, .isHiddenKey],
                    options: self.showHiddenFiles ? [] : [.skipsHiddenFiles]
                )
                
                for itemURL in contents {
                    let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey, .isHiddenKey])
                    
                    let item = ExplorerFileItem(
                        url: itemURL,
                        name: itemURL.lastPathComponent,
                        isDirectory: resourceValues.isDirectory ?? false,
                        size: Int64(resourceValues.fileSize ?? 0),
                        modificationDate: resourceValues.contentModificationDate,
                        creationDate: resourceValues.creationDate,
                        isHidden: resourceValues.isHidden ?? false
                    )
                    loadedItems.append(item)
                }
                
                // 排序：文件夹在前，然后按名称
                loadedItems.sort { (a, b) in
                    if a.isDirectory != b.isDirectory {
                        return a.isDirectory
                    }
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }
                
                DispatchQueue.main.async {
                    self.currentPath = url
                    self.items = loadedItems
                    self.isLoading = false
                    
                    if addToHistory {
                        // 清除前进历史
                        if self.historyIndex < self.navigationHistory.count - 1 {
                            self.navigationHistory.removeSubrange((self.historyIndex + 1)...)
                        }
                        self.navigationHistory.append(url)
                        self.historyIndex = self.navigationHistory.count - 1
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = "无法访问此目录: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func goBack() {
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        navigateTo(navigationHistory[historyIndex], addToHistory: false)
    }
    
    func goForward() {
        guard historyIndex < navigationHistory.count - 1 else { return }
        historyIndex += 1
        navigateTo(navigationHistory[historyIndex], addToHistory: false)
    }
    
    func goUp() {
        let parent = currentPath.deletingLastPathComponent()
        navigateTo(parent)
    }
    
    func refresh() {
        navigateTo(currentPath, addToHistory: false)
    }
    
    // MARK: - File Operations
    
    func createFolder(name: String) throws {
        let newFolderURL = currentPath.appendingPathComponent(name)
        try fileManager.createDirectory(at: newFolderURL, withIntermediateDirectories: false)
        refresh()
    }
    
    func createFile(name: String) throws {
        let newFileURL = currentPath.appendingPathComponent(name)
        fileManager.createFile(atPath: newFileURL.path, contents: nil)
        refresh()
    }
    
    func deleteItem(_ item: ExplorerFileItem, moveToTrash: Bool = true) throws {
        if moveToTrash {
            try fileManager.trashItem(at: item.url, resultingItemURL: nil)
        } else {
            try fileManager.removeItem(at: item.url)
        }
        refresh()
    }
    
    func renameItem(_ item: ExplorerFileItem, to newName: String) throws {
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newName)
        try fileManager.moveItem(at: item.url, to: newURL)
        refresh()
    }
    
    func copyItem(_ item: ExplorerFileItem, to destination: URL) throws {
        let destURL = destination.appendingPathComponent(item.name)
        try fileManager.copyItem(at: item.url, to: destURL)
    }
    
    func moveItem(_ item: ExplorerFileItem, to destination: URL) throws {
        let destURL = destination.appendingPathComponent(item.name)
        try fileManager.moveItem(at: item.url, to: destURL)
        refresh()
    }
    
    func openItem(_ item: ExplorerFileItem) {
        NSWorkspace.shared.open(item.url)
    }
    
    func revealInFinder(_ item: ExplorerFileItem) {
        NSWorkspace.shared.selectFile(item.url.path, inFileViewerRootedAtPath: item.url.deletingLastPathComponent().path)
    }
    
    // MARK: - Shell Commands
    
    func runShellCommand(_ command: String) {
        guard !command.isEmpty else { return }
        
        isRunningCommand = true
        shellOutput += "\n$ \(command)\n"
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            process.currentDirectoryURL = self.currentPath
            
            let pipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                DispatchQueue.main.async {
                    if !output.isEmpty {
                        self.shellOutput += output
                    }
                    if !errorOutput.isEmpty {
                        self.shellOutput += "[错误] \(errorOutput)"
                    }
                    self.isRunningCommand = false
                    self.refresh()
                }
            } catch {
                DispatchQueue.main.async {
                    self.shellOutput += "[执行失败] \(error.localizedDescription)\n"
                    self.isRunningCommand = false
                }
            }
        }
    }
    
    func clearShellOutput() {
        shellOutput = ""
    }
    
    // MARK: - Utilities
    
    var canGoBack: Bool {
        historyIndex > 0
    }
    
    var canGoForward: Bool {
        historyIndex < navigationHistory.count - 1
    }
    
    var pathComponents: [(String, URL)] {
        var components: [(String, URL)] = []
        var url = currentPath
        
        while url.path != "/" {
            components.insert((url.lastPathComponent, url), at: 0)
            url = url.deletingLastPathComponent()
        }
        components.insert(("/", URL(fileURLWithPath: "/")), at: 0)
        
        return components
    }
}
