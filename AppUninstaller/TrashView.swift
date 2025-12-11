import SwiftUI

struct TrashItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let dateDeleted: Date?
    let isDirectory: Bool
    
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
                let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
                let date = resourceValues?.contentModificationDate
                let isDir = resourceValues?.isDirectory ?? false
                
                let item = TrashItem(
                    url: fileURL,
                    name: fileURL.lastPathComponent,
                    size: size,
                    dateDeleted: date,
                    isDirectory: isDir
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
    
    // 扫描指定文件夹（用于详情查看）
    func scanDirectory(_ url: URL) -> [TrashItem] {
        var items: [TrashItem] = []
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]) else {
            return []
        }
        
        for fileURL in contents {
            let size = calculateSize(at: fileURL)
            let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
            let date = resourceValues?.contentModificationDate
            let isDir = resourceValues?.isDirectory ?? false
            
            items.append(TrashItem(
                url: fileURL,
                name: fileURL.lastPathComponent,
                size: size,
                dateDeleted: date,
                isDirectory: isDir
            ))
        }
        
        return items.sorted { $0.size > $1.size }
    }
    
    // 放回原处
    func putBack(_ item: TrashItem) {
        let script = """
        tell application "Finder"
            activate
            try
                set targetItem to (POSIX file "\(item.url.path)") as alias
                select targetItem
                tell application "System Events"
                    key code 51 using {command down}
                end tell
            on error
                -- ignore
            end try
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
        
        // 稍后刷新
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await scan()
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
                try
                    set itemPath to POSIX path of (anItem as alias)
                    set itemName to name of anItem
                    set itemSize to size of anItem
                on error
                    set itemPath to ""
                    set itemName to ""
                    set itemSize to 0
                end try
                if itemPath is not "" then
                    set isFolder to (class of anItem is folder)
                    set output to output & itemPath & "|||" & itemName & "|||" & itemSize & "|||" & isFolder & "\\n"
                end if
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
                    let isFolder = parts.count > 3 ? (parts[3].trimmingCharacters(in: .whitespacesAndNewlines) == "true") : false
                    
                    let fileURL = URL(fileURLWithPath: path)
                    
                    // 获取修改日期
                    let date = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    
                    let item = TrashItem(
                        url: fileURL,
                        name: name,
                        size: size,
                        dateDeleted: date,
                        isDirectory: isFolder
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
        NavigationStack {
            ZStack {
                mainContent
                
                // Floating Button
                if !scanner.items.isEmpty {
                    VStack {
                        Spacer()
                        emptyButton
                            .padding(.bottom, 10)
                    }
                }
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
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            headerView
            
            DiskUsageView()
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            
            if scanner.isScanning {
                scanningView
            } else if scanner.needsPermission {
                permissionView
            } else if scanner.items.isEmpty {
                emptyStateView
            } else {
                itemListView
            }
        }
    }
    
    private var scanningView: some View {
        VStack {
            Spacer()
            ProgressView().scaleEffect(0.8)
            Text(loc.currentLanguage == .chinese ? "正在扫描废纸篓..." : "Scanning Trash...")
                .foregroundColor(.secondaryText)
                .padding(.top, 8)
            Spacer()
        }
    }
    
    private var permissionView: some View {
        VStack {
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
        }
    }
    
    private var emptyStateView: some View {
        VStack {
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
        }
    }
    
    private var itemListView: some View {
        List {
            ForEach(scanner.items) { item in
                itemRow(for: item)
                    .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            
            Color.clear.frame(height: 150)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    @ViewBuilder
    private func itemRow(for item: TrashItem) -> some View {
        Group {
            if item.isDirectory {
                NavigationLink(destination: TrashDirectoryView(url: item.url)) {
                    TrashItemRow(item: item)
                }
            } else {
                TrashItemRow(item: item)
            }
        }
        .contextMenu {
            Button {
                scanner.putBack(item)
            } label: {
                Label(loc.currentLanguage == .chinese ? "放回原处" : "Put Back", systemImage: "arrow.uturn.backward")
            }
            
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Label(loc.L("show_in_finder"), systemImage: "folder")
            }
            
            Divider()
            
            Button(role: .destructive) {
                try? FileManager.default.removeItem(at: item.url)
                Task { await scanner.scan() }
            } label: {
                Label(loc.currentLanguage == .chinese ? "立即删除" : "Delete Immediately", systemImage: "trash")
            }
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
        // 隐藏主视图的默认导航栏，保留自定义 Header
        #if os(macOS)
        .toolbar(.hidden, for: .windowToolbar)
        #endif
    }
    
    // MARK: - 清空按钮 (大圆圈)
    private var emptyButton: some View {
        Button(action: { showEmptyConfirmation = true }) {
            ZStack {
                // 外圈光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.7, green: 0.1, blue: 0.1).opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                
                // 主圆圈
                Circle()
                    .fill(GradientStyles.trash)
                    .frame(width: 90, height: 90)
                    .shadow(color: Color(red: 0.7, green: 0.1, blue: 0.1).opacity(0.5), radius: 15, x: 0, y: 8)
                
                // 内容
                VStack(spacing: 2) {
                    Image(systemName: "trash.slash.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    Text(loc.L("empty_trash"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Text(ByteCountFormatter.string(fromByteCount: scanner.totalSize, countStyle: .file))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .buttonStyle(.plain)
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

struct TrashDirectoryView: View {
    let url: URL
    @State private var items: [TrashItem] = []
    @StateObject private var scanner = TrashScanner()
    @ObservedObject private var loc = LocalizationManager.shared
    
    var body: some View {
        List {
            if items.isEmpty {
                Text(loc.currentLanguage == .chinese ? "空文件夹" : "Empty Folder")
                    .foregroundColor(.secondaryText)
                    .padding()
            } else {
                ForEach(items) { item in
                    itemRow(for: item)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.mainBackground)
        .navigationTitle(url.lastPathComponent)
        .onAppear {
            items = scanner.scanDirectory(url)
        }
    }
    
    @ViewBuilder
    private func itemRow(for item: TrashItem) -> some View {
        Group {
            if item.isDirectory {
                NavigationLink(destination: TrashDirectoryView(url: item.url)) {
                    TrashItemRow(item: item)
                }
            } else {
                TrashItemRow(item: item)
            }
        }
        .contextMenu {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Label(loc.L("show_in_finder"), systemImage: "folder")
            }
            
            Divider()
            
            Button(role: .destructive) {
                try? FileManager.default.removeItem(at: item.url)
                items = scanner.scanDirectory(url)
            } label: {
                Label(loc.currentLanguage == .chinese ? "立即删除" : "Delete Immediately", systemImage: "trash")
            }
        }
    }
}
