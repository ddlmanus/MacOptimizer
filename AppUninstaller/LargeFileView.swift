import SwiftUI

struct LargeFileView: View {
    @Binding var selectedModule: AppModule
    // 使用共享的服务管理器，切换视图时扫描状态不会丢失
    @ObservedObject private var scanner = ScanServiceManager.shared.largeFileScanner
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var selectedFiles: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var showingDetails = false
    @State private var sortOrder: SortOption = .sizeDesc
    
    enum SortOption: CaseIterable {
        case sizeDesc, sizeAsc, nameAsc, nameDesc
        
        var title: String {
            switch self {
            case .sizeDesc: return "大小 ↓"
            case .sizeAsc: return "大小 ↑"
            case .nameAsc: return "A-Z"
            case .nameDesc: return "Z-A"
            }
        }
    }
    
    var sortedFiles: [FileItem] {
        switch sortOrder {
        case .sizeDesc: return scanner.foundFiles.sorted { $0.size > $1.size }
        case .sizeAsc: return scanner.foundFiles.sorted { $0.size < $1.size }
        case .nameAsc: return scanner.foundFiles.sorted { $0.name < $1.name }
        case .nameDesc: return scanner.foundFiles.sorted { $0.name > $1.name }
        }
    }
    
    var totalSelectedSize: Int64 {
        scanner.foundFiles.filter { selectedFiles.contains($0.id) }.reduce(0) { $0 + $1.size }
    }
    
    // 按文件类型分组
    var groupedByType: [(type: String, files: [FileItem])] {
        let grouped = Dictionary(grouping: sortedFiles) { $0.type }
        return grouped.map { (type: $0.key, files: $0.value) }
            .sorted { $0.files.reduce(0) { $0 + $1.size } > $1.files.reduce(0) { $0 + $1.size } }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 头部
                headerView
                
                if scanner.isScanning && scanner.foundFiles.isEmpty {
                    scanningView
                } else if scanner.foundFiles.isEmpty {
                    emptyStateView
                } else {
                    // 内容区
                    contentView
                }
            }
        }
        .onAppear {
            if scanner.foundFiles.isEmpty {
                Task { await scanner.scan() }
            }
        }
        .confirmationDialog(loc.L("confirm_delete"), isPresented: $showDeleteConfirmation) {
            Button(loc.currentLanguage == .chinese ? "永久删除 \(selectedFiles.count) 个文件" : "Delete \(selectedFiles.count) files", role: .destructive) {
                Task {
                    await scanner.deleteItems(selectedFiles)
                    selectedFiles.removeAll()
                    await MainActor.run {
                        DiskSpaceManager.shared.updateDiskSpace()
                    }
                }
            }
            Button(loc.L("cancel"), role: .cancel) {}
        } message: {
            Text(loc.currentLanguage == .chinese ? "此操作不可撤销，文件将被直接删除。" : "This action cannot be undone.")
        }
        .sheet(isPresented: $showingDetails) {
            detailSheet
        }
    }
    
    // MARK: - 头部视图
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.L("largeFiles"))
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                Text(loc.currentLanguage == .chinese ? "查找并清理占用空间的大文件" : "Find and clean large files")
                    .foregroundColor(.secondaryText)
            }
            Spacer()
            
            if !scanner.isScanning {
                HStack(spacing: 12) {
                    // 排序菜单
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button(option.title) { sortOrder = option }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(sortOrder.title)
                        }
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                    }
                    .menuStyle(.borderlessButton)
                    
                    // 全选/取消
                    if !scanner.foundFiles.isEmpty {
                        Button(action: { selectAll() }) {
                            Text(loc.L("selectAll"))
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // 刷新
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
            }
        }
        .padding(24)
        .padding(.bottom, 0)
    }
    
    private func selectAll() {
        if selectedFiles.count == scanner.foundFiles.count {
            selectedFiles.removeAll()
        } else {
            selectedFiles = Set(scanner.foundFiles.map { $0.id })
        }
    }
    
    // MARK: - 内容视图
    private var contentView: some View {
        VStack(spacing: 20) {
            // 顶部统计卡片
            statsCardsView
                .padding(.horizontal, 24)
            
            // 左右分栏
            HStack(alignment: .top, spacing: 20) {
                // 左侧列表
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.currentLanguage == .chinese ? "大文件 (\(scanner.foundFiles.count))" : "Large Files (\(scanner.foundFiles.count))")
                        .font(.headline)
                        .foregroundColor(.secondaryText)
                        .padding(.leading, 4)
                    
                    fileListView
                }
                .frame(maxWidth: .infinity)
                
                // 右侧预览区
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.currentLanguage == .chinese ? "空间释放" : "Space Release")
                        .font(.headline)
                        .foregroundColor(.secondaryText)
                    
                    spacePreviewCard
                }
                .frame(width: 280)
            }
            .padding(.horizontal, 24)
            
            // 底部操作栏
            bottomActionBar
        }
        .padding(.top, 10)
    }
    
    // MARK: - 统计卡片
    private var statsCardsView: some View {
        HStack(spacing: 16) {
            LargeFileStatsCard(
                icon: "doc.fill",
                title: loc.currentLanguage == .chinese ? "文件数量" : "File Count",
                count: scanner.foundFiles.count,
                size: scanner.totalSize,
                color: .purple
            )
            
            LargeFileStatsCard(
                icon: "checkmark.circle.fill",
                title: loc.currentLanguage == .chinese ? "已选中" : "Selected",
                count: selectedFiles.count,
                size: totalSelectedSize,
                color: .blue
            )
            
            LargeFileStatsCard(
                icon: "externaldrive.fill",
                title: loc.currentLanguage == .chinese ? "可释放空间" : "Cleanable",
                count: selectedFiles.count,
                size: totalSelectedSize,
                color: .green
            )
        }
    }
    
    // MARK: - 文件列表
    private var fileListView: some View {
        List {
            ForEach(groupedByType, id: \.type) { group in
                Section(header:
                    HStack {
                        Image(systemName: iconForType(group.type))
                            .foregroundColor(.purple)
                        Text(group.type.uppercased())
                        Text("(\(group.files.count))")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: group.files.reduce(0) { $0 + $1.size }, countStyle: .file))
                            .foregroundColor(.gray)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
                ) {
                    ForEach(group.files) { file in
                        LargeFileRowNew(file: file, isSelected: selectedFiles.contains(file.id)) {
                            toggleSelection(file.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedFiles.contains(id) {
            selectedFiles.remove(id)
        } else {
            selectedFiles.insert(id)
        }
    }
    
    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "mp4", "mov", "avi", "mkv": return "film.fill"
        case "mp3", "wav", "aac", "flac": return "music.note"
        case "jpg", "png", "gif", "heic": return "photo.fill"
        case "zip", "rar", "7z", "tar": return "archivebox.fill"
        case "dmg", "iso", "pkg": return "externaldrive.fill"
        case "pdf": return "doc.text.fill"
        default: return "doc.fill"
        }
    }
    
    // MARK: - 预览卡片
    private var spacePreviewCard: some View {
        VStack(spacing: 24) {
            HStack(spacing: 20) {
                // Before
                VStack {
                    Image(systemName: "externaldrive.fill.badge.xmark")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text(loc.currentLanguage == .chinese ? "占用空间" : "Used Space")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(ByteCountFormatter.string(fromByteCount: scanner.totalSize, countStyle: .file))
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                // After
                VStack {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "externaldrive.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .offset(x: 4, y: 4)
                    }
                    Text(loc.currentLanguage == .chinese ? "可释放" : "Cleanable")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file))
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
            .padding(.top, 16)
            
            Divider().background(Color.gray.opacity(0.3))
            
            Button(action: { showingDetails = true }) {
                Text(loc.currentLanguage == .chinese ? "查看详情" : "View Details")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 16)
        }
        .padding(24)
        .background(Color.white)
        .colorScheme(.light)
        .cornerRadius(16)
    }
    
    // MARK: - 底部操作栏
    private var bottomActionBar: some View {
        HStack {
            Button(loc.currentLanguage == .chinese ? "查看详情" : "View Details") {
                showingDetails = true
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
            
            Spacer()
            
            Button(action: {
                if !selectedFiles.isEmpty {
                    showDeleteConfirmation = true
                }
            }) {
                Text(loc.currentLanguage == .chinese ? "删除文件" : "Delete Files")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 200, height: 44)
                    .background(
                        LinearGradient(colors: [Color(red: 0.5, green: 0.0, blue: 0.8), Color(red: 0.3, green: 0.0, blue: 0.6)], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(22)
                    .shadow(color: Color(red: 0.3, green: 0.0, blue: 0.6).opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(selectedFiles.isEmpty)
            .opacity(selectedFiles.isEmpty ? 0.6 : 1.0)
            
            Spacer()
            
            Button(loc.currentLanguage == .chinese ? "跳过" : "Skip") {
                skipToNextModule()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondaryText)
        }
        .padding(24)
        .background(Color.black.opacity(0.2))
    }
    
    // MARK: - 扫描动画
    private var scanningView: some View {
        VStack(spacing: 40) {
            Spacer()
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 10).frame(width: 200, height: 200)
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.purple, lineWidth: 10)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
            }
            VStack(spacing: 8) {
                Text(loc.currentLanguage == .chinese ? "正在扫描大文件..." : "Scanning large files...")
                    .font(.title3)
                    .foregroundColor(.white)
                Text(loc.currentLanguage == .chinese ? "已扫描 \(scanner.scannedCount) 个项目" : "Scanned \(scanner.scannedCount) items")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            Spacer()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            Text(loc.currentLanguage == .chinese ? "没有发现大文件" : "No Large Files Found")
                .font(.title)
                .foregroundColor(.white)
            Text(loc.currentLanguage == .chinese ? "仅扫描 >50MB 的文件" : "Only scanning files >50MB")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            
            Button(action: { Task { await scanner.scan() } }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(loc.currentLanguage == .chinese ? "重新扫描" : "Rescan")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .foregroundColor(.white.opacity(0.7))
            Spacer()
        }
    }
    
    // MARK: - 跳过到下一个模块
    private func skipToNextModule() {
        let allModules = AppModule.allCases
        if let currentIndex = allModules.firstIndex(of: selectedModule),
           currentIndex < allModules.count - 1 {
            selectedModule = allModules[currentIndex + 1]
        } else {
            selectedModule = allModules.first ?? .monitor
        }
    }
    
    // MARK: - 详情 Sheet
    private var detailSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc.currentLanguage == .chinese ? "大文件详情" : "Large File Details")
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: { showingDetails = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            List {
                ForEach(sortedFiles) { file in
                    HStack {
                        FileIconView(filename: file.name)
                            .frame(width: 32, height: 32)
                        VStack(alignment: .leading) {
                            Text(file.name)
                                .font(.system(size: 13, weight: .medium))
                            Text(file.url.path)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Text(file.formattedSize)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - Subviews

struct LargeFileStatsCard: View {
    let icon: String
    let title: String
    let count: Int
    let size: Int64
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 2)
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(count)")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.black)
                    Text("个")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.8))
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .colorScheme(.light)
    }
}

struct LargeFileRowNew: View {
    let file: FileItem
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(CheckboxStyle())
            .labelsHidden()
            
            FileIconView(filename: file.name)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                Text(file.url.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            Text(file.formattedSize)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primaryText)
        }
        .padding(.vertical, 4)
    }
}

struct FileIconView: View {
    let filename: String
    
    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFileType: (filename as NSString).pathExtension))
            .resizable()
    }
}
