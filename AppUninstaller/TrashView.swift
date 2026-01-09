import SwiftUI

// MARK: - 扫描状态
enum TrashScanState {
    case initial    // 初始页面
    case scanning   // 扫描中
    case completed  // 扫描完成（结果页）
    case clean      // 扫描完成且无文件
    case cleaning   // 清理中
    case finished   // 清理完成
}

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
    @Published var hasCompletedScan = false
    @Published var needsPermission = false
    
    // 新增属性
    @Published var scannedItemCount: Int = 0
    @Published var isStopped = false
    @Published var currentScanPath: String = ""
    @Published var isCleaning = false // 其实可以通过 scanState 控制，但为了保持逻辑一致性保留
    @Published var cleanedCount: Int = 0
    @Published var cleanedSize: Int64 = 0
    
    private let fileManager = FileManager.default
    let trashURL: URL
    private var shouldStop = false
    
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    init() {
        // 使用系统 API 获取正确的废纸篓路径
        if let trashURLs = try? fileManager.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            trashURL = trashURLs
        } else {
            // 回退到传统路径
            trashURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        }
    }
    
    func stopScan() {
        shouldStop = true
        isScanning = false
        isStopped = true
        // 停止后不需要清空 items，保留已扫描到的
    }
    
    func scan() async {
        await MainActor.run {
            isScanning = true
            isStopped = false
            shouldStop = false
            items = []
            totalSize = 0
            scannedItemCount = 0
            hasCompletedScan = false
            needsPermission = false
        }
        
        var scannedItems: [TrashItem] = []
        var total: Int64 = 0
        
        // 首先尝试直接访问 (需要 Full Disk Access)
        var hasAccess = false
        
        // 简单模拟一下扫描过程中的路径变化，提升用户体验
        await MainActor.run { self.currentScanPath = "Preparing..." }
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s pre-delay
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
            hasAccess = true
            
            for fileURL in contents {
                if shouldStop { break }
                
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
                
                await MainActor.run {
                    self.scannedItemCount += 1
                    self.currentScanPath = fileURL.path
                }
                
                // 稍微延时以便用户看清扫描过程 (对于文件少的情况)
                if contents.count < 50 {
                   try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                }
            }
        } catch {
            print("Direct access failed: \(error)")
        }
        
        // 如果直接访问失败，尝试使用 shell 命令
        if !hasAccess && !shouldStop {
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
            self.scannedItemCount = sortedItems.count
            self.hasCompletedScan = true
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
                    if shouldStop { break }
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
                    
                    await MainActor.run {
                        self.scannedItemCount += 1
                        self.currentScanPath = path
                    }
                }
            }
        } catch {
            print("AppleScript scan failed: \(error)")
        }
        
        return (scannedItems, total)
    }
    
    func emptyTrash() async -> Int64 {
        await MainActor.run {
            self.isCleaning = true
            self.cleanedCount = 0
            self.cleanedSize = 0
        }
        
        var removedSize: Int64 = 0
        
        for item in items {
            do {
                try fileManager.removeItem(at: item.url)
                removedSize += item.size
                await MainActor.run {
                    self.cleanedCount += 1
                    self.cleanedSize += item.size
                }
                // 模拟一点延迟，让用户看到清理过程
                try? await Task.sleep(nanoseconds: 100_000_000)
            } catch {
                print("Failed to delete \(item.url.path): \(error)")
            }
        }
        
        await MainActor.run {
            items.removeAll()
            totalSize = 0
            self.isCleaning = false
            DiskSpaceManager.shared.updateDiskSpace()
            self.scannedItemCount = 0 // Reset count for finish page
        }
        
        return removedSize
    }
    
    func reset() {
        items = []
        isScanning = false
        totalSize = 0
        needsPermission = false
        scannedItemCount = 0
        hasCompletedScan = false
        isStopped = false
        currentScanPath = ""
        isCleaning = false
        cleanedCount = 0
        cleanedSize = 0
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
    @State private var showCleaningFinished = false
    
    // 视图状态 (对应 ScanState)
    private var scanState: TrashScanState {
        if showCleaningFinished {
            return .finished
        } else if scanner.isCleaning {
            return .cleaning
        } else if scanner.isScanning {
            return .scanning
        } else if !scanner.items.isEmpty || scanner.isStopped {
            // 如果已经被停止，也显示结果页（可能是部分结果）
            return .completed
        } else if scanner.hasCompletedScan && scanner.items.isEmpty {
            return .clean
        }
        return .initial
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                switch scanState {
                case .initial:
                    initialPage
                        .background(TealMeshBackground())
                case .scanning:
                    scanningPage
                        .background(TealMeshBackground())
                case .completed:
                    resultsPage
                         .background(TealMeshBackground())
                case .clean:
                    cleanPage
                        .background(TealMeshBackground())
                case .cleaning:
                    cleaningPage
                        .background(TealMeshBackground())
                case .finished:
                    finishedPage
                        .background(TealMeshBackground())
                }
            }
        }
        .confirmationDialog(loc.L("empty_trash"), isPresented: $showEmptyConfirmation) {
            Button(loc.L("empty_trash"), role: .destructive) {
                Task {
                    _ = await scanner.emptyTrash()
                    showCleaningFinished = true
                }
            }
            Button(loc.L("cancel"), role: .cancel) {}
        } message: {
            Text(loc.currentLanguage == .chinese ? "此操作不可撤销，所有文件将被永久删除。" : "This cannot be undone. All files will be permanently deleted.")
        }
    }
    
    // MARK: - 1. 初始页面
    private var initialPage: some View {
        ZStack {
            // Main Content (2 Columns)
            HStack(spacing: 0) {
                // Left Column: Text & Features
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                    
                    // Title
                    Text(loc.currentLanguage == .chinese ? "废纸篓" : "Trash")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.bottom, 16)
                    
                    // Subtitle
                    Text(loc.currentLanguage == .chinese ? "倾倒 Mac 上所有废纸篓，包括邮件和照片图库垃圾。" : "Dump all Trash on Mac, including Mail and Photos trash.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                        .padding(.bottom, 40)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Feature List
                    VStack(alignment: .leading, spacing: 32) {
                        featureRow(
                            icon: "trash",
                            title: loc.currentLanguage == .chinese ? "立即倾倒所有垃圾" : "Dump all trash immediately",
                            subtitle: loc.currentLanguage == .chinese ? "无需浏览所有驱动器和应用查找它们的废纸篓。" : "No need to browse all drives and apps to find their trash."
                        )
                        
                        featureRow(
                            icon: "finder",
                            title: loc.currentLanguage == .chinese ? "避免各种“访达”错误" : "Avoid various Finder errors",
                            subtitle: loc.currentLanguage == .chinese ? "确保倾倒您的废纸篓，不管是否有任何问题。" : "Ensures your Trash is emptied regardless of any issues."
                        )
                    }
                    .padding(.bottom, 100) // Create space for bottom button if needed, or just layout balance
                    
                    Spacer()
                }
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Right Column: Large Icon Only
                VStack {
                    Spacer()
                    
                    // Icon (Direct Image)
                    if let imagePath = Bundle.main.path(forResource: "feizhilou", ofType: "png"),
                       let nsImage = NSImage(contentsOfFile: imagePath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 340, height: 340) // Large size
                            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                    } else {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 200))
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                }
                .frame(width: 400)
            }
            .padding(.bottom, 60) // Space for button
            
            // Scan Button (Bottom Center Overlay)
            VStack {
                Spacer()
                
                CircularActionButton(
                    title: loc.currentLanguage == .chinese ? "扫描" : "Scan",
                    gradient: GradientStyles.fileExplorer,
                    action: {
                        Task { await scanner.scan() }
                    }
                )
                .shadow(color: Color.blue.opacity(0.4), radius: 10, y: 5)
                .padding(.bottom, 60)
            }
        }
    }
    
    // ... featureRow ...
    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            if icon == "finder" {
                 Image(systemName: "face.smiling")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 32)
            } else {
                 Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 32)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 2. 扫描中页面
    private var scanningPage: some View {
        VStack(spacing: 0) {
            // 顶部标题
            HStack {
                Text(loc.currentLanguage == .chinese ? "废纸篓" : "Trash")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding(.top, 20)
            
            Spacer()
            
            // 中心动画图标 (Direct Image) -> Static Size enforcement
            ZStack {
                if let imagePath = Bundle.main.path(forResource: "feizhilou", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 280, height: 280)
                } else {
                     Image(systemName: "trash")
                        .font(.system(size: 100))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 280, height: 280) // Enforce frame container
            .padding(.bottom, 40)
            
            // 状态文字 - Use fixed frame to avoid layout jitter
            VStack(spacing: 8) {
                Text(loc.currentLanguage == .chinese ? "正在计算废纸篓文件夹的大小..." : "Calculating Trash size...")
                    .font(.title) 
                    .foregroundColor(.white)
                
                Text(scanner.currentScanPath) 
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(height: 20) // Fixed text height
                    .padding(.horizontal, 40)
                
                Text(loc.currentLanguage == .chinese ? "系统废纸篓" : "System Trash")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            // 停止按钮 (Bottom Center of Screen)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.75) 
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Button(action: {
                    scanner.stopScan()
                }) {
                    VStack(spacing: 2) {
                        Text(loc.currentLanguage == .chinese ? "停止" : "Stop")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(width: 70, height: 70)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            // Size below stop button
            Text(scanner.formattedTotalSize)
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
                .padding(.top, 10)
                .opacity(scanner.scannedItemCount > 0 ? 1 : 0) // Fade in instead of layout shift? Or just keep space
            
            Spacer()
                .frame(height: 60)
        }
    }
    
    // MARK: - 3. 扫描结果页面
    private var resultsPage: some View {
        VStack(spacing: 0) {
            // Top: Back Button
            HStack {
                Button(action: {
                    scanner.reset()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(loc.currentLanguage == .chinese ? "重新开始" : "Start Over")
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(loc.currentLanguage == .chinese ? "废纸篓" : "Trash")
                    .font(.title3)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Assistant placeholder
                 HStack {
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 6, height: 6)
                    Text(loc.currentLanguage == .chinese ? "助手" : "Assistant")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .opacity(0.8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            // Main Content: Icon Left, Text Right
            HStack(spacing: 60) {
                // Large Icon Circle (Direct Image)
                if let imagePath = Bundle.main.path(forResource: "feizhilou", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 300, height: 300) // Large
                } else {
                     Image(systemName: "trash.fill")
                         .font(.system(size: 150))
                         .foregroundColor(.white)
                }
                
                // Text Info
                VStack(alignment: .leading, spacing: 16) {
                    Text(loc.currentLanguage == .chinese ? "扫描完毕" : "Scan Complete")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(scanner.formattedTotalSize)
                            .font(.system(size: 60, weight: .light)) 
                            .foregroundColor(Color(hex: "60EFFF")) 
                        
                        Text(loc.L("smart_select"))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(loc.currentLanguage == .chinese ? "包括" : "Including")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                        
                        HStack(spacing: 8) {
                            Circle().fill(Color.white.opacity(0.6)).frame(width: 4, height: 4)
                            Text(loc.currentLanguage == .chinese ? "mac 上的废纸篓" : "Trash on mac")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    // View Items Button
                    NavigationLink(destination: TrashDetailsSplitView(scanner: scanner)) {
                        Text(loc.L("view_items")) 
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    HStack {
                         Text(loc.currentLanguage == .chinese ? "共发现" : "Total found")
                         Text(scanner.formattedTotalSize)
                             .foregroundColor(.white)
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Clean Button (Floating circular, Bottom Center)
            ZStack {
                // Outer Glow Ring
                Circle()
                    .stroke(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: 2)
                    .frame(width: 90, height: 90)
                
                Button(action: {
                     showEmptyConfirmation = true
                }) {
                    ZStack {
                        Circle()
                             .fill(Color.white.opacity(0.2))
                             .frame(width: 80, height: 80)
                        
                        Text(loc.currentLanguage == .chinese ? "倾倒" : "Clean")
                             .font(.system(size: 18, weight: .medium))
                             .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - 3.5. Clean Page
    private var cleanPage: some View {
        VStack(spacing: 0) {
            // Top Nav
            HStack {
                Button(action: {
                    scanner.reset()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(loc.currentLanguage == .chinese ? "重新开始" : "Start Over")
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(loc.L("trash"))
                    .font(.title2)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Placeholder
                Text("Start Over")
                    .opacity(0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            // Central Icon (Using feizhilou.png)
            ZStack {
                if let imagePath = Bundle.main.path(forResource: "feizhilou", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 250, height: 250)
                } else {
                     Image(systemName: "trash")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                }
                
                // Checkmark badge
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .background(Circle().fill(Color.white)) // White bg for checkmark to pop
                    .clipShape(Circle())
                    .offset(x: 60, y: 80)
            }
            .padding(.bottom, 30)

            // Text
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title)
                
                Text(loc.currentLanguage == .chinese ? "非常干净！" : "Very Clean!")
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
            }
            .padding(.bottom, 8)
            
            Text(loc.currentLanguage == .chinese ? "任何废纸篓中都没有文件。" : "No files found in any Trash bin.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            // Back/Rescan Button
             CircularActionButton(
                 title: loc.currentLanguage == .chinese ? "返回" : "Back",
                 gradient: CircularActionButton.blueGradient,
                 action: {
                     scanner.reset()
                 }
             )
             .padding(.bottom, 60)
        }
    }
    
    // MARK: - 4. 清理中页面
    private var cleaningPage: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc.L("trash"))
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding(.top, 20)
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(GradientStyles.trash.opacity(0.8))
                    .frame(width: 140, height: 140)
                
                Image(systemName: "trash")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                // 旋转圈
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(Double(scanner.cleanedCount * 20))) // 简单旋转
            }
            .padding(.bottom, 40)
            
            Text(loc.currentLanguage == .chinese ? "正在清理..." : "Cleaning...")
                .font(.title3)
                .foregroundColor(.white)
            
            Text(loc.currentLanguage == .chinese ? "已清理: \(scanner.cleanedCount) 个文件" : "Cleaned: \(scanner.cleanedCount) items")
                .foregroundColor(.secondaryText)
                .padding(.top, 8)
            
            Spacer()
            
            // 占位按钮
             CircularActionButton(
                 title: loc.currentLanguage == .chinese ? "清理中" : "Cleaning",
                 gradient: CircularActionButton.grayGradient,
                 action: {}
             )
             .disabled(true)
             .padding(.bottom, 60)
        }
    }
    
    // MARK: - 5. 清理完成页面
    private var finishedPage: some View {
        VStack(spacing: 0) {
            // 顶部导航
            HStack {
                Button(action: {
                    scanner.reset()
                    showCleaningFinished = false
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                        Text(loc.currentLanguage == .chinese ? "返回" : "Back")
                    }
                    .foregroundColor(.secondaryText)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(loc.L("trash"))
                    .font(.title2)
                    .foregroundColor(.white)
                
                Spacer()
                GridRow { Text("      ") } // Placeholder
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.8)) // 成功绿
                    .frame(width: 160, height: 160)
                    .shadow(color: .green.opacity(0.4), radius: 20, x: 0, y: 10)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 40)
            
            Text(loc.currentLanguage == .chinese ? "清理完成" : "Cleanup Complete")
                .font(.title)
                .bold()
                .foregroundColor(.white)
            
            Text(loc.currentLanguage == .chinese ? "共释放 \(ByteCountFormatter.string(fromByteCount: scanner.cleanedSize, countStyle: .file)) 空间" : "Freed \(ByteCountFormatter.string(fromByteCount: scanner.cleanedSize, countStyle: .file)) space")
                .foregroundColor(.secondaryText)
                .padding(.top, 8)
            
            Spacer()
            
            // 完成按钮
             CircularActionButton(
                 title: loc.currentLanguage == .chinese ? "完成" : "Done",
                 gradient: CircularActionButton.blueGradient,
                 action: {
                     scanner.reset()
                     showCleaningFinished = false
                 }
             )
             .padding(.bottom, 60)
        }
    }
}

// 辅助视图：显示文件列表详情（保留之前的 TrashDirectoryView implementation）
// 虽然后续设计中可能不需要，但为了兼容性保留
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

// MARK: - Teal Mesh Background (Trash Theme)
struct TealMeshBackground: View {
    var body: some View {
        ZStack {
            // 1. Teal/Green Gradient Base
            LinearGradient(
                colors: [
                    Color(hex: "009688"), // Teal Green
                    Color(hex: "2c3e50")  // Deep Blue/Grey
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // 2. Soft Overlays
            GeometryReader { proxy in
                ZStack {
                    // Top-Left Bright Green Glow
                    Circle()
                        .fill(Color(hex: "00F260").opacity(0.3))
                        .frame(width: 800, height: 800)
                        .blur(radius: 100)
                        .offset(x: -200, y: -200)
                    
                    // Bottom-Right Deep Blue Shadow
                    Circle()
                        .fill(Color(hex: "0575E6").opacity(0.5))
                        .frame(width: 900, height: 900)
                        .blur(radius: 120)
                        .offset(x: 200, y: 300)
                }
            }
            
            // 3. Subtle Noise/Texture
             Rectangle()
                .fill(Color.white.opacity(0.03))
                .blendMode(.overlay)
        }
        .ignoresSafeArea()
    }
}
