import SwiftUI

struct LargeFileView: View {
    @StateObject private var scanner = LargeFileScanner()
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var selectedFile: FileItem?
    @State private var selectedFiles: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    
    // Sort options
    @State private var sortOrder: SortOption = .sizeDesc
    
    enum SortOption {
        case sizeDesc, sizeAsc, nameAsc, nameDesc
        
        var title: String {
            switch self {
            case .sizeDesc: return "大小 (降序)"
            case .sizeAsc: return "大小 (升序)"
            case .nameAsc: return "名称 (A-Z)"
            case .nameDesc: return "名称 (Z-A)"
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
    
    var body: some View {
        HSplitView {
            // Left: File List
            VStack(spacing: 0) {
                // Disk Usage
                DiskUsageView()
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(loc.L("largeFiles"))
                            .font(.headline)
                            .foregroundColor(.white)
                        if !scanner.isScanning {
                            Text(loc.currentLanguage == .chinese ? "发现 \(scanner.foundFiles.count) 个文件 · \(ByteCountFormatter.string(fromByteCount: scanner.totalSize, countStyle: .file))" : "Found \(scanner.foundFiles.count) files · \(ByteCountFormatter.string(fromByteCount: scanner.totalSize, countStyle: .file))")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                    
                    Spacer()
                    
                    if !scanner.isScanning {
                        Menu {
                            ForEach([SortOption.sizeDesc, .sizeAsc, .nameAsc, .nameDesc], id: \.self) { option in
                                Button(option.title) { sortOrder = option }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    
                    Button(action: { Task { await scanner.scan() } }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(scanner.isScanning ? .secondary : .white)
                            .rotationEffect(.degrees(scanner.isScanning ? 360 : 0))
                            .animation(scanner.isScanning ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: scanner.isScanning)
                    }
                    .buttonStyle(.plain)
                    .disabled(scanner.isScanning)
                }
                .padding(16)
                .background(Color.black.opacity(0.2))
                
                // List
                if scanner.isScanning && scanner.foundFiles.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(loc.currentLanguage == .chinese ? "正在扫描大文件..." : "Scanning large files...")
                            .foregroundColor(.secondaryText)
                        Text(loc.currentLanguage == .chinese ? "已扫描 \(scanner.scannedCount) 个项目" : "Scanned \(scanner.scannedCount) items")
                            .font(.caption)
                            .foregroundColor(.tertiaryText)
                    }
                    Spacer()
                } else if scanner.foundFiles.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondaryText)
                        Text(loc.currentLanguage == .chinese ? "点击刷新开始扫描\n(仅扫描 >50MB 文件)" : "Click refresh to scan\n(Only files >50MB)")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondaryText)
                    }
                    Spacer()
                } else {
                    List(selection: $selectedFiles) {
                        ForEach(sortedFiles) { file in
                            LargeFileRow(file: file, isSelected: selectedFiles.contains(file.id))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedFiles.contains(file.id) {
                                        selectedFiles.remove(file.id)
                                    } else {
                                        selectedFiles.insert(file.id)
                                    }
                                    selectedFile = file
                                }
                                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                
                // Bottom Bar
                HStack {
                    Text(loc.currentLanguage == .chinese ? "已选择: \(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file))" : "Selected: \(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file))")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    Spacer()
                    Button(loc.L("permanently_delete")) {
                        showDeleteConfirmation = true
                    }
                    .buttonStyle(CapsuleButtonStyle(gradient: GradientStyles.danger))
                    .disabled(selectedFiles.isEmpty)
                    .opacity(selectedFiles.isEmpty ? 0.5 : 1)
                }
                .padding(16)
                .background(Color.black.opacity(0.2))
            }
            .frame(minWidth: 300, maxWidth: 450)
            
            // Right: Visualization (Space Lens)
            ZStack {
                Color.black.opacity(0.1) // Slight separate bg
                
                if scanner.isScanning {
                    ScanningPulseView()
                } else if !scanner.foundFiles.isEmpty {
                    BubbleGraphView(files: scanner.foundFiles, selectedId: selectedFile?.id) { file in
                        // On Bubble Click
                        selectedFile = file
                        if !selectedFiles.contains(file.id) {
                            selectedFiles.insert(file.id)
                        }
                    }
                } else {
                     Text("Space Lens")
                        .font(.largeTitle)
                        .fontWeight(.thin)
                        .foregroundColor(.white.opacity(0.1))
                }
            }
            .frame(minWidth: 400)
        }
        .onAppear {
            if scanner.foundFiles.isEmpty {
                Task { await scanner.scan() }
            }
        }
        .confirmationDialog(loc.L("confirm_delete"), isPresented: $showDeleteConfirmation) {
            Button(loc.currentLanguage == .chinese ? "永久删除 \(selectedFiles.count) 个文件" : "Delete \(selectedFiles.count) files permanently", role: .destructive) {
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
            Text(loc.currentLanguage == .chinese ? "此操作不可撤销，文件将被直接删除。" : "This action cannot be undone. Files will be permanently deleted.")
        }
    }
}

// MARK: - Subviews

struct LargeFileRow: View {
    let file: FileItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            FileIconView(filename: file.name)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(file.pathString)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .tertiaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            Text(file.formattedSize)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .white : .secondaryText)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? AnyShapeStyle(BackgroundStyles.largeFiles) : AnyShapeStyle(Color.white.opacity(0.05)))
        )
    }
}

fileprivate extension FileItem {
    var pathString: String {
        return url.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }
}

struct FileIconView: View {
    let filename: String
    
    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFileType: (filename as NSString).pathExtension))
            .resizable()
    }
}

// MARK: - Visualization
// 简单的气泡图实现
struct BubbleGraphView: View {
    let files: [FileItem]
    let selectedId: UUID?
    let onSelect: (FileItem) -> Void
    
    // 只展示最大的20个文件，避免过于拥挤
    var displayedFiles: [FileItem] {
        Array(files.prefix(20))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(displayedFiles.enumerated()), id: \.element.id) { index, file in
                    // 简单的随机位置布局算法 (实际生产可以使用力导向图)
                    // 这里我们为了演示效果，使用基于圆心的螺旋分布
                    let bubbleSize = calculateSize(for: file, max: geometry.size.width)
                    let position = calculatePosition(index: index, total: displayedFiles.count, availableSize: geometry.size)
                    
                    CircleBubble(
                        file: file,
                        size: bubbleSize,
                        isSelected: selectedId == file.id
                    )
                    .position(x: position.x, y: position.y)
                    .onTapGesture {
                        withAnimation {
                            onSelect(file)
                        }
                    }
                }
            }
        }
    }
    
    func calculateSize(for file: FileItem, max: CGFloat) -> CGFloat {
        // Logarithmic scale for better visual distribution
        // Min 50, Max 180
        let minSize: CGFloat = 60
        let maxSize: CGFloat = 200
        
        let largestFileSize = files.first?.size ?? 1
        let ratio = Double(file.size) / Double(largestFileSize)
        
        // simple mapping
        return minSize + (maxSize - minSize) * CGFloat(ratio)
    }
    
    func calculatePosition(index: Int, total: Int, availableSize: CGSize) -> CGPoint {
        let center = CGPoint(x: availableSize.width / 2, y: availableSize.height / 2)
        if index == 0 { return center }
        
        // Spiral
        let angle = Double(index) * 2.5 // Golden angle approx
        let radius = 60.0 * Double(index).squareRoot() * 1.5
        
        let x = center.x + CGFloat(cos(angle) * radius)
        let y = center.y + CGFloat(sin(angle) * radius)
        
        return CGPoint(x: x, y: y)
    }
}

struct CircleBubble: View {
    let file: FileItem
    let size: CGFloat
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.8, green: 0.8, blue: 1.0).opacity(0.8),
                            Color(red: 0.4, green: 0.2, blue: 0.9).opacity(0.9)
                        ]),
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 5)
            
            VStack(spacing: 2) {
                Text(file.type)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(file.formattedSize)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(), value: isSelected)
    }
}

struct ScanningPulseView: View {
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                .frame(width: 100, height: 100)
                .scaleEffect(isPulsing ? 2 : 1)
                .opacity(isPulsing ? 0 : 1)
                .onAppear {
                    withAnimation(Animation.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                        isPulsing = true
                    }
                }
            
            Text("Scanning Space...")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
