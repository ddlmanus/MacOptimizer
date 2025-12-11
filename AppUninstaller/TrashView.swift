import SwiftUI

struct TrashItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let dateDeleted: Date?
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var formattedDate: String {
        guard let date = dateDeleted else { return "未知" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

class TrashScanner: ObservableObject {
    @Published var items: [TrashItem] = []
    @Published var isScanning = false
    @Published var totalSize: Int64 = 0
    @Published var needsPermission = false
    
    private let fileManager = FileManager.default
    private let trashURL: URL
    
    init() {
        // 使用系统 API 获取正确的废纸篓路径
        if let trashURLs = try? fileManager.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            trashURL = trashURLs
        } else {
            // 回退到传统路径
            trashURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        }
    }
    
    func scan() async {
        await MainActor.run {
            isScanning = true
            items = []
            totalSize = 0
            needsPermission = false
        }
        
        var scannedItems: [TrashItem] = []
        var total: Int64 = 0
        
        // 首先尝试直接访问 (需要 Full Disk Access)
        var hasAccess = false
        do {
            let contents = try fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
            hasAccess = true
            
            for fileURL in contents {
                let size = calculateSize(at: fileURL)
                let date = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                
                let item = TrashItem(
                    url: fileURL,
                    name: fileURL.lastPathComponent,
                    size: size,
                    dateDeleted: date
                )
                scannedItems.append(item)
                total += size
            }
        } catch {
            print("Direct access failed: \(error)")
        }
        
        // 如果直接访问失败，尝试使用 shell 命令
        if !hasAccess {
            let result = await scanWithShell()
            scannedItems = result.items
            total = result.total
            
            // 如果 shell 也没有结果，说明需要权限
            if scannedItems.isEmpty {
                await MainActor.run {
                    needsPermission = true
                }
            }
        }
        
        let sortedItems = scannedItems.sorted { $0.size > $1.size }
        let finalTotal = total
        
        await MainActor.run {
            self.items = sortedItems
            self.totalSize = finalTotal
            self.isScanning = false
        }
    }
    
    func openSystemPreferences() {
        // 打开系统设置的隐私与安全性 - 完全磁盘访问权限
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func scanWithShell() async -> (items: [TrashItem], total: Int64) {
        var scannedItems: [TrashItem] = []
        var total: Int64 = 0
        
        // 使用 AppleScript 通过 Finder 获取废纸篓内容
        let script = """
        tell application "Finder"
            set trashItems to items of trash
            set output to ""
            repeat with anItem in trashItems
                set itemPath to POSIX path of (anItem as alias)
                set itemName to name of anItem
                try
                    set itemSize to size of anItem
                on error
                    set itemSize to 0
                end try
                set output to output & itemPath & "|||" & itemName & "|||" & itemSize & "\\n"
            end repeat
            return output
        end tell
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                for line in lines {
                    guard !line.isEmpty else { continue }
                    
                    let parts = line.components(separatedBy: "|||")
                    guard parts.count >= 3 else { continue }
                    
                    let path = parts[0].trimmingCharacters(in: .whitespaces)
                    let name = parts[1].trimmingCharacters(in: .whitespaces)
                    let sizeStr = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
                    let size = Int64(sizeStr) ?? 0
                    
                    let fileURL = URL(fileURLWithPath: path)
                    
                    // 获取修改日期
                    let date = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    
                    let item = TrashItem(
                        url: fileURL,
                        name: name,
                        size: size,
                        dateDeleted: date
                    )
                    scannedItems.append(item)
                    total += size
                }
            }
        } catch {
            print("AppleScript scan failed: \(error)")
        }
        
        return (scannedItems, total)
    }
    
    func emptyTrash() async -> Int64 {
        var removedSize: Int64 = 0
        
        for item in items {
            do {
                try fileManager.removeItem(at: item.url)
                removedSize += item.size
            } catch {
                print("Failed to delete \(item.url.path): \(error)")
            }
        }
        
        await MainActor.run {
            items.removeAll()
            totalSize = 0
            DiskSpaceManager.shared.updateDiskSpace()
        }
        
        return removedSize
    }
    
    private func calculateSize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        var isDirectory: ObjCBool = false
        
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
                for case let fileURL as URL in enumerator {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                        totalSize += Int64(resourceValues.fileSize ?? 0)
                    } catch { continue }
                }
            } else {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: url.path)
                    totalSize = Int64(attributes[.size] as? UInt64 ?? 0)
                } catch { return 0 }
            }
        }
        return totalSize
    }
}

struct TrashView: View {
    @StateObject private var scanner = TrashScanner()
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var showEmptyConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Disk Usage
            DiskUsageView()
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            
            // Content
            if scanner.isScanning {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Text(loc.currentLanguage == .chinese ? "正在扫描废纸篓..." : "Scanning Trash...")
                    .foregroundColor(.secondaryText)
                    .padding(.top, 8)
                Spacer()
            } else if scanner.needsPermission {
                // 需要权限
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 64))
                        .foregroundColor(.orange.opacity(0.6))
                    Text(loc.currentLanguage == .chinese ? "需要访问权限" : "Permission Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                    Text(loc.currentLanguage == .chinese ? "查看废纸篓内容需要「完全磁盘访问权限」" : "Full Disk Access is required to view Trash contents")
                        .font(.subheadline)
                        .foregroundColor(.tertiaryText)
                        .multilineTextAlignment(.center)
                    
                    Button(action: { scanner.openSystemPreferences() }) {
                        HStack {
                            Image(systemName: "gearshape")
                            Text(loc.currentLanguage == .chinese ? "授权访问" : "Grant Access")
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    
                    Text(loc.currentLanguage == .chinese ? "授权后点击「刷新」按钮" : "Click Refresh after granting access")
                        .font(.caption)
                        .foregroundColor(.tertiaryText)
                }
                .padding()
                Spacer()
            } else if scanner.items.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "trash")
                        .font(.system(size: 64))
                        .foregroundColor(.white.opacity(0.2))
                    Text(loc.L("trash_empty"))
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.5))
                    Text(loc.currentLanguage == .chinese ? "已删除的文件会显示在这里" : "Deleted files will appear here")
                        .font(.subheadline)
                        .foregroundColor(.tertiaryText)
                }
                Spacer()
            } else {
                // Item List
                List {
                    ForEach(scanner.items) { item in
                        TrashItemRow(item: item)
                            .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            
            // Footer
            if !scanner.items.isEmpty {
                footerView
            }
        }
        .onAppear {
            Task { await scanner.scan() }
        }
        .confirmationDialog(loc.L("empty_trash"), isPresented: $showEmptyConfirmation) {
            Button(loc.L("empty_trash"), role: .destructive) {
                Task { await scanner.emptyTrash() }
            }
            Button(loc.L("cancel"), role: .cancel) {}
        } message: {
            Text(loc.currentLanguage == .chinese ? "此操作不可撤销，所有文件将被永久删除。" : "This cannot be undone. All files will be permanently deleted.")
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(loc.L("trash"))
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                Text(loc.currentLanguage == .chinese ? "查看并管理已删除的文件" : "View and manage deleted files")
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Button(action: { Task { await scanner.scan() } }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text(loc.L("refresh"))
                }
                .font(.caption)
                .foregroundColor(.secondaryText)
                .padding(8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }
    
    private var footerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.currentLanguage == .chinese ? "\(scanner.items.count) 个项目" : "\(scanner.items.count) items")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(loc.currentLanguage == .chinese ? "共 \(ByteCountFormatter.string(fromByteCount: scanner.totalSize, countStyle: .file))" : "Total: \(ByteCountFormatter.string(fromByteCount: scanner.totalSize, countStyle: .file))")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            Button(action: { showEmptyConfirmation = true }) {
                HStack {
                    Image(systemName: "trash.slash")
                    Text(loc.L("empty_trash"))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(GradientStyles.danger)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(Color.black.opacity(0.2))
    }
}

struct TrashItemRow: View {
    let item: TrashItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                Text("删除于 \(item.formattedDate)")
                    .font(.system(size: 11))
                    .foregroundColor(.tertiaryText)
            }
            
            Spacer()
            
            Text(item.formattedSize)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondaryText)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}
