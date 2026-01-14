import SwiftUI
import AppKit
import AVFoundation

struct SpaceLensView: View {
    @StateObject private var scanner = SpaceLensScanner()
    @State private var viewState: Int = 0 // 0: Landing, 1: Scanning, 2: Results, 3: Cleanup Results
    
    // UI State
    @State private var navigationStack: [FileNode] = []
    @State private var currentNode: FileNode?
    @State private var bubblePositions: [UUID: CGPoint] = [:]
    @State private var bubbleSizes: [UUID: CGFloat] = [:]
    
    // Selection for landing page
    @State private var selectedDiskPath: URL = URL(fileURLWithPath: "/")
    @State private var selectedDiskName: String = "mac"
    
    // Remove Functionality
    @State private var showRemoveConfirmation = false
    @State private var itemsToRemove: [FileNode] = []
    @State private var cleanupResults: (success: Int, failed: Int, size: Int64)? = nil
    @State private var failedFiles: [FailedFileInfo] = []
    
    @ObservedObject private var loc = LocalizationManager.shared
    
    // Audio
    @State private var audioPlayer: AVAudioPlayer?
    
    // Selection Stats
    @State private var showSelectedItemsPopover = false
    
    var selectedSize: Int64 {
        guard let current = currentNode else { return 0 }
        return current.children.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    var selectedItems: [FileNode] {
        guard let current = currentNode else { return [] }
        return current.children.filter { $0.isSelected }
    }
    
    var body: some View {
        Group {
            if viewState == 0 {
                landingView
            } else if viewState == 1 {
                scanningView
            } else if viewState == 2 {
                resultsView
            } else if viewState == 3 {
                // Show cleanup results
                if let results = cleanupResults {
                    if failedFiles.isEmpty {
                        CleanupResultsView(
                            cleanedSize: results.size,
                            cleanedCount: results.success,
                            recommendations: [],
                            onDismiss: {
                                resetToLanding()
                            }
                        )
                    } else {
                        CleanupDetailResultsView(
                            cleanedSize: results.size,
                            cleanedCount: results.success,
                            failedFiles: failedFiles,
                            failedCount: results.failed,
                            totalAttempted: results.success + results.failed,
                            onDismiss: {
                                resetToLanding()
                            }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BackgroundStyles.spaceLens) // Use the Teal-Blue gradient
    }
    
    // MARK: - Landing View
    var landingView: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                // Left Column: Text & Features
                VStack(alignment: .leading, spacing: 40) {
                    Spacer() // Push content down to align with bottom center button area
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text(loc.currentLanguage == .chinese ? "空间透镜" : "Space Lens")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(loc.currentLanguage == .chinese ? "对文件夹和文件进行视觉大小比较，方便快速清理。" : "Visually compare folders and files for quick cleanup.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: 30) {
                        featureRow(icon: "circle.hexagongrid", title: "即时尺寸概览", desc: "浏览存储空间，同时查看什么内容占据最多空间。")
                        featureRow(icon: "airplane", title: "快速决策", desc: "不浪费时间检查要删除内容的大小。")
                    }
                    
                    Spacer()
                        .frame(height: 20)

                    // Disk Selector Card
                    diskSelectorCard
                    
                    Spacer()
                        .frame(height: 100) // Space from bottom
                }
                .padding(.leading, 60)
                .padding(.trailing, 20)
                .frame(maxWidth: 400, alignment: .leading)
                
                Spacer()
                
                // Right Column: Planet Image
                ZStack {
                    if let imagePath = Bundle.main.path(forResource: "kongjianshentou", ofType: "png"),
                       let nsImage = NSImage(contentsOfFile: imagePath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 500, maxHeight: 500)
                    } else {
                        // Fallback
                        Circle()
                            .fill(LinearGradient(colors: [.green.opacity(0.8), .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 400, height: 400)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(x: 0, y: -20)
            }
            .padding(.top, 60)
            
            // Floating Scan Button (Bottom Center)
            Button(action: startScan) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .frame(width: 90, height: 90)
                    
                    Circle()
                        .fill(LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    Text(loc.currentLanguage == .chinese ? "扫描" : "Scan")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Disk Selector
    private var diskSelectorCard: some View {
        Menu {
            Button("mac") {
                selectedDiskPath = URL(fileURLWithPath: "/")
                selectedDiskName = "mac"
            }
            Button(loc.currentLanguage == .chinese ? "用户文件夹" : "User Home") {
                selectedDiskPath = FileManager.default.homeDirectoryForCurrentUser
                selectedDiskName = "Users"
            }
            Divider()
            Button(loc.currentLanguage == .chinese ? "选择文件夹..." : "Select Folder...") {
                selectFolder()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.8))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(selectedDiskName == "mac" ? "mac: 245.11 GB" : "\(selectedDiskName): 245.11 GB") // Mock total for now
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    // Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 4)
                            
                            Capsule()
                                .fill(Color.green)
                                .frame(width: geo.size.width * 0.45, height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    Text(loc.currentLanguage == .chinese ? "已使用 110.55 GB" : "Used 110.55 GB")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .menuStyle(.borderlessButton)
        .frame(width: 300)
    }
    

    
    func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.currentLanguage == .chinese ? title : "Instant Overview")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text(loc.currentLanguage == .chinese ? desc : "See what takes up space instantly.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Scanning View
    var scanningView: some View {
        ZStack {
            VStack {
                Spacer()
                
                // Pulsating Planet
                ZStack {
                    if let imagePath = Bundle.main.path(forResource: "kongjianshentou", ofType: "png"),
                       let nsImage = NSImage(contentsOfFile: imagePath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 300, height: 300)
                            .scaleEffect(scanner.isScanning ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: scanner.isScanning)
                    }
                }
                // Scanning Status Text
                Text(loc.currentLanguage == .chinese ? "构建您的存储图..." : "Building your storage map...")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.top, 40)
                
                Text(scanner.currentPath)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .frame(width: 500)
                    .padding(.top, 8)
                
                Spacer()
                
                // Stop Button & Size
                HStack(spacing: 20) {
                    Button(action: stopScan) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                .frame(width: 80, height: 80)
                            
                            // Progress Ring
                            Circle()
                                .trim(from: 0, to: scanner.scanProgress)
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                            
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 70, height: 70)
                            
                            Text(loc.currentLanguage == .chinese ? "停止" : "Stop")
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Text(ByteCountFormatter.string(fromByteCount: scanner.totalSize, countStyle: .file))
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.bottom, 60)
            }
            .onChange(of: scanner.rootNode) { newNode in
                if let root = newNode {
                    self.currentNode = root
                    self.calculateLayout(for: root)
                    
                    // Play sound and wait before showing results
                    playScanCompleteSound {
                        withAnimation {
                            self.viewState = 2
                        }
                    }
                }
            }
        }
    }
    
    func playScanCompleteSound(completion: @escaping () -> Void) {
        guard let soundURL = Bundle.main.url(forResource: "CleanDidFinish", withExtension: "m4a") else {
            completion()
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.play()
            
            // Wait for duration
            let duration = audioPlayer?.duration ?? 0
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                completion()
            }
        } catch {
            print("Failed to play sound: \(error)")
            completion()
        }
    }
    
    // MARK: - Results View
    var resultsView: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Sidebar List
                VStack(spacing: 0) {
                    // Breadcrumbs / Back
                    HStack {
                        Button(action: goBack) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text(navigationStack.isEmpty ? (loc.currentLanguage == .chinese ? "重新开始" : "Restart") : navigationStack.last?.name ?? "Back")
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding()
                    .background(Color.black.opacity(0.2))
                    
                    // Current Dir Info
                    HStack {
                        if let icon = iconForFile(currentNode) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        } else {
                             Image(systemName: "folder.fill")
                                .foregroundColor(.cyan)
                        }
                        Text(currentNode?.name ?? "Mac")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    
                    // List
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(currentNode?.children ?? []) { child in
                                FileListRow(node: child, totalSize: currentNode?.size ?? 1)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        enterNode(child)
                                    }
                            }
                        }
                    }
                }
                .frame(width: 260)
                .background(Color.black.opacity(0.15))
                
                // Bubble Chart Area
                ZStack {
                    // Background Circles
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 2)
                        .frame(width: 600, height: 600)
                    Circle()
                        .stroke(Color.white.opacity(0.03), lineWidth: 30)
                        .frame(width: 800, height: 800)
                    
                    if let node = currentNode {
                         bubbleChart(for: node, size: CGSize(width: geometry.size.width - 260, height: geometry.size.height))
                    }
                    
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
                .clipped()

                 .overlay(alignment: .bottom) {
                     VStack(spacing: 16) {
                         // Control Bar - Select All / Deselect All
                         if let current = currentNode, !current.children.isEmpty {
                             HStack(spacing: 12) {
                                 Button(action: selectAllItems) {
                                     Text(loc.currentLanguage == .chinese ? "全选" : "Select All")
                                         .font(.system(size: 12, weight: .medium))
                                         .foregroundColor(.white)
                                         .padding(.horizontal, 12)
                                         .padding(.vertical, 6)
                                         .background(Color.white.opacity(0.15))
                                         .cornerRadius(6)
                                 }
                                 .buttonStyle(.plain)
                                 
                                 Button(action: deselectAllItems) {
                                     Text(loc.currentLanguage == .chinese ? "取消全选" : "Deselect All")
                                         .font(.system(size: 12, weight: .medium))
                                         .foregroundColor(.white)
                                         .padding(.horizontal, 12)
                                         .padding(.vertical, 6)
                                         .background(Color.white.opacity(0.15))
                                         .cornerRadius(6)
                                 }
                                 .buttonStyle(.plain)
                                 
                                 Spacer()
                             }
                             .padding(.horizontal, 20)
                         }
                         
                         // Main Action Bar
                         HStack(spacing: 20) {
                             // Floating Remove Button
                             Button(action: {
                                  prepareForRemoval()
                             }) {
                                 ZStack {
                                     Circle()
                                         .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                         .frame(width: 90, height: 90)
                                     
                                     Circle()
                                         .fill(LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                                         .frame(width: 80, height: 80)
                                         .overlay(
                                             Circle()
                                                 .stroke(Color.white, lineWidth: 2)
                                         )
                                         .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                                     
                                     Text(loc.currentLanguage == .chinese ? "移除" : "Remove")
                                         .font(.system(size: 16, weight: .semibold))
                                         .foregroundColor(.white)
                                 }
                             }
                             .buttonStyle(.plain)
                             
                             // Stats Bar
                             if selectedSize > 0 {
                                 HStack(spacing: 0) {
                                     Text(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))
                                         .font(.system(size: 14, weight: .regular))
                                         .foregroundColor(.white.opacity(0.8))
                                         .padding(.horizontal, 16)
                                     
                                     Divider()
                                         .background(Color.white.opacity(0.2))
                                         .frame(height: 20)
                                     
                                     Button(action: {
                                         showSelectedItemsPopover.toggle()
                                     }) {
                                         Text(loc.currentLanguage == .chinese ? "查看所选内容" : "View Selected")
                                             .font(.system(size: 13, weight: .medium))
                                             .foregroundColor(.white)
                                             .padding(.horizontal, 16)
                                             .padding(.vertical, 10)
                                             .contentShape(Rectangle())
                                     }
                                     .buttonStyle(.plain)
                                     .popover(isPresented: $showSelectedItemsPopover, arrowEdge: .top) {
                                         SelectedItemsList(items: selectedItems)
                                     }
                                 }
                                 .background(Color.black.opacity(0.6))
                                 .background(.ultraThinMaterial)
                                 .cornerRadius(8)
                                 .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                             }
                             
                             Spacer()
                         }
                         .padding(.horizontal, 20)
                     }
                     .padding(.bottom, 40)
                 }

            }
            .overlay {
                if showRemoveConfirmation {
                    RemoveConfirmationView(
                        items: itemsToRemove,
                        onCancel: {
                            showRemoveConfirmation = false
                        },
                        onConfirm: {
                            deleteSelectedItems()
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Bubble Chart Logic
    func bubbleChart(for node: FileNode, size: CGSize) -> some View {
        ZStack {
            // Central Node (Current Directory)
            bubbleView(node: node, isCenter: true)
                .position(x: size.width / 2, y: size.height / 2)
                .zIndex(100)
            
            // Children Nodes (Orbiting)
            ForEach(node.children.prefix(8)) { child in // Use layout logic here
                if let pos = bubblePositions[child.id], let radius = bubbleSizes[child.id] {
                     bubbleView(node: child, isCenter: false, diameter: radius)
                        .position(x: size.width/2 + pos.x, y: size.height/2 + pos.y) // Offset from center
                        .onTapGesture {
                            withAnimation(.spring()) {
                                enterNode(child)
                            }
                        }
                }
            }
            
            // Handle "Other" or small files?
        }
        .onAppear {
             calculateLayout(for: node)
        }
        .onChange(of: node.id) { _ in
             calculateLayout(for: node)
        }
    }
    
    func bubbleView(node: FileNode, isCenter: Bool, diameter: CGFloat = 200) -> some View {
        let size = isCenter ? 220 : diameter
        return ZStack {
             Circle()
                 .fill(
                    LinearGradient(
                        colors: isCenter ? [Color.cyan.opacity(0.8), Color.blue.opacity(0.8)] : [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                 )
                 .frame(width: size, height: size)
                 .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                 .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            
             if isCenter {
                  // Ripple effect for center?
                 Circle()
                     .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                     .frame(width: size + 20, height: size + 20)
             }
            
            VStack(spacing: 4) {
                 if let icon = iconForFile(node) {
                      Image(nsImage: icon)
                         .resizable()
                         .frame(width: isCenter ? 64 : 48, height: isCenter ? 64 : 48)
                 } else {
                      Image(systemName: isCenter ? "folder.fill" : "doc.fill")
                         .font(.system(size: isCenter ? 40 : 30))
                         .foregroundColor(.white)
                 }
                
                Text(node.name)
                    .font(.system(size: isCenter ? 16 : 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: size - 20)
                
                Text(node.formattedSize)
                    .font(.system(size: isCenter ? 14 : 10))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
    
    // MARK: - Layout Algorithm
    func calculateLayout(for node: FileNode) {
        // Improved layout algorithm to prevent bubble overlaps
        // Uses a force-directed approach with collision detection
        
        let children = node.children.prefix(12) // Limit displayed bubbles
        if children.isEmpty { return }
        
        // Base Unit
        let centerR: CGFloat = 110 // Radius of center bubble
        
        // Normalize sizes for visualization
        // Max bubble size = 180, Min = 60
        let maxSize: CGFloat = 180
        let minSize: CGFloat = 70
        let maxFileSize = children.first?.size ?? 1
        
        var positions: [UUID: CGPoint] = [:]
        var sizes: [UUID: CGFloat] = [:]
        
        // Calculate bubble sizes first
        for child in children {
            let scale = CGFloat(child.size) / CGFloat(maxFileSize)
            let bubSize = minSize + (maxSize - minSize) * sqrt(scale)
            sizes[child.id] = bubSize
        }
        
        // Arrange in concentric circles to prevent overlaps
        // Group bubbles by size and place them in rings
        let sortedChildren = children.sorted { $0.size > $1.size }
        
        var angle: CGFloat = 0
        var currentRing: Int = 0
        var itemsInRing: Int = 0
        let itemsPerRing: Int = 4
        
        for (index, child) in sortedChildren.enumerated() {
            let bubSize = sizes[child.id] ?? 70
            
            // Calculate ring radius based on bubble size
            let ringRadius = centerR + 40 + CGFloat(currentRing) * (bubSize + 40)
            
            // Calculate angle for this position
            let itemsInCurrentRing = min(itemsPerRing, sortedChildren.count - index)
            let angleStep = (2 * .pi) / CGFloat(itemsInCurrentRing)
            let itemAngle = angle + angleStep * CGFloat(itemsInRing)
            
            // Calculate position
            let x = cos(itemAngle) * ringRadius
            let y = sin(itemAngle) * ringRadius
            
            positions[child.id] = CGPoint(x: x, y: y)
            
            // Move to next position
            itemsInRing += 1
            if itemsInRing >= itemsPerRing {
                itemsInRing = 0
                currentRing += 1
                angle += angleStep / 2 // Offset next ring for better distribution
            }
        }
        
        self.bubblePositions = positions
        self.bubbleSizes = sizes
    }
    
    // MARK: - Actions
    func startScan() {
        let path = selectedDiskPath
        Task {
            await scanner.scan(targetURL: path)
        }
        withAnimation {
            viewState = 1
        }
    }
    
    func stopScan() {
        scanner.stopScan()
        viewState = 0
    }
    
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            self.selectedDiskPath = url
            self.selectedDiskName = url.lastPathComponent
        }
    }
    
    func enterNode(_ node: FileNode) {
        if let current = currentNode {
            navigationStack.append(current)
        }
        currentNode = node
    }
    
    func goBack() {
        if let parent = navigationStack.popLast() {
            currentNode = parent
        } else {
            // Reset to Landing?
            stopScan() // Restart
        }
    }
    
    func iconForFile(_ node: FileNode?) -> NSImage? {
        guard let node = node else { return nil }
        return NSWorkspace.shared.icon(forFile: node.url.path)
    }
    
    // MARK: - Remove Logic
    func selectAllItems() {
        guard let current = currentNode else { return }
        for child in current.children {
            child.isSelected = true
        }
    }
    
    func deselectAllItems() {
        guard let current = currentNode else { return }
        for child in current.children {
            child.isSelected = false
        }
    }
    
    func prepareForRemoval() {
        // Collect selected items from current node's children
        // We only support removing what is visible/selected in the list or the node itself?
        // Usually, deletion operates on the selected checkboxes in the list.
        guard let current = currentNode else { return }
        
        // Find visible children that are selected
        let selected = current.children.filter { $0.isSelected }
        
        if !selected.isEmpty {
            self.itemsToRemove = selected
            self.showRemoveConfirmation = true
        } else {
            // Maybe show a tooltip "Select items to remove"?
            print("No items selected")
        }
    }
    
    func deleteSelectedItems() {
        Task {
            let fileManager = FileManager.default
            var deletedIDs: Set<UUID> = []
            var deletedSize: Int64 = 0
            var failedDeletions: [FailedFileInfo] = []
            
            // First attempt: Try direct deletion
            for item in itemsToRemove {
                do {
                    try fileManager.removeItem(at: item.url)
                    deletedIDs.insert(item.id)
                    deletedSize += item.size
                    print("Deleted: \(item.url.path)")
                } catch {
                    print("Failed to delete \(item.url.path): \(error)")
                    // Track failed deletion for retry with admin privileges
                    failedDeletions.append(FailedFileInfo(
                        fileName: item.name,
                        filePath: item.url.path,
                        fileSize: item.size,
                        errorReason: error.localizedDescription
                    ))
                }
            }
            
            // Second attempt: If there are failures, try with admin privileges
            if !failedDeletions.isEmpty {
                let failedPaths = failedDeletions.map { $0.filePath }
                let adminSuccess = await deleteWithAdminPrivileges(paths: failedPaths)
                
                if adminSuccess {
                    // All admin deletions succeeded
                    let adminDeletedSize = failedDeletions.reduce(0) { $0 + $1.fileSize }
                    deletedSize += adminDeletedSize
                    
                    // Mark items as deleted by matching paths
                    for failedItem in failedDeletions {
                        if let matchingItem = itemsToRemove.first(where: { $0.url.path == failedItem.filePath }) {
                            deletedIDs.insert(matchingItem.id)
                        }
                    }
                    
                    failedDeletions.removeAll()
                }
            }
            
            // Update UI on main thread
            await MainActor.run {
                // Remove deleted nodes from current children
                if let current = currentNode {
                    current.children.removeAll { deletedIDs.contains($0.id) }
                    current.size -= deletedSize
                    if current.size < 0 { current.size = 0 } // Safety
                    
                    // Re-layout bubbles
                    calculateLayout(for: current)
                    
                    // Update total scanned size
                    scanner.totalSize -= deletedSize
                }
                
                // Store cleanup results
                self.cleanupResults = (
                    success: deletedIDs.count,
                    failed: failedDeletions.count,
                    size: deletedSize
                )
                self.failedFiles = failedDeletions
                
                // Dismiss confirmation and show results
                showRemoveConfirmation = false
                itemsToRemove = []
                
                // Play success sound and transition to results
                playScanCompleteSound {
                    withAnimation {
                        self.viewState = 3
                    }
                }
            }
        }
    }
    
    /// Attempts to delete files with admin privileges using AppleScript
    private func deleteWithAdminPrivileges(paths: [String]) async -> Bool {
        var safePaths: [String] = []
        
        // Validate paths for safety
        for path in paths {
            if !path.contains("..") && !path.isEmpty {
                safePaths.append(path)
            }
        }
        
        if safePaths.isEmpty {
            return false
        }
        
        // Build rm commands
        let rmCommands = safePaths.map { "rm -rf '\($0)'" }.joined(separator: "; ")
        
        let script = """
        do shell script "\(rmCommands)" with administrator privileges
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            return error == nil
        }
        
        return false
    }
    
    func resetToLanding() {
        viewState = 0
        navigationStack = []
        currentNode = nil
        cleanupResults = nil
        failedFiles = []
        scanner.stopScan()
    }
}

// MARK: - File List Row
struct FileListRow: View {
    @ObservedObject var node: FileNode
    let totalSize: Int64
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if node.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.blue)
                        .font(.system(size: 16))
                        .background(Circle().fill(Color.white).frame(width: 8, height: 8)) // White background for the checkmark
                } else {
                     Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .frame(width: 16, height: 16)
                }
            }
            .frame(width: 20, height: 20) // Consistent hit area
            .contentShape(Rectangle()) // Hit area
            .onTapGesture {
                node.isSelected.toggle()
            }
            
            let icon = NSWorkspace.shared.icon(forFile: node.url.path)
            Image(nsImage: icon)
                .resizable()
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Size Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 3)
                        
                        Rectangle()
                            .fill(Color.cyan) // Teal bar
                            .frame(width: geo.size.width * CGFloat(node.size) / CGFloat(totalSize), height: 3)
                    }
                }
                .frame(height: 3)
            }
            
            Text(node.formattedSize)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
