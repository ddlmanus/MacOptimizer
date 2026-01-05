import SwiftUI

struct JunkCleanerView: View {
    // 扫描状态枚举
    enum ScanState {
        case initial    // 初始页面
        case scanning   // 扫描中
        case cleaning   // 清理中
        case completed  // 扫描完成（结果页）
        case finished   // 清理完成（最终页）
    }

    // 使用共享的服务管理器
    @ObservedObject private var cleaner = ScanServiceManager.shared.junkCleaner
    @ObservedObject private var loc = LocalizationManager.shared
    
    // View State
    @State private var scanState: ScanState = .initial
    @State private var showingDetails = false // 控制详情页显示
    @State private var selectedCategory: JunkType? // 选中的分类
    @State private var searchText = ""
    @State private var showingCleanAlert = false
    @State private var cleanedAmount: Int64 = 0
    @State private var failedFiles: [String] = []
    @State private var showRetryWithAdmin = false
    @State private var cleanResult: (cleaned: Int64, failed: Int64, requiresAdmin: Bool)?
    
    // Animation State
    @State private var pulse = false
    @State private var animateScan = false
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Purple Theme Background
            PurpleMeshBackground()
            
            switch scanState {
            case .initial:
                initialPage
            case .scanning:
                scanningPage
            case .completed:
                if showingDetails {
                    detailPage
                } else {
                    summaryPage
                }
            case .cleaning:
                cleaningPage
            case .finished:
                finishedPage
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            if !cleaner.junkItems.isEmpty && !cleaner.isScanning && scanState == .initial {
                scanState = .completed
            } else if cleaner.isScanning {
                scanState = .scanning
            }
        }
        .alert(loc.currentLanguage == .chinese ? "部分文件需要管理员权限" : "Some Files Require Admin Privileges", isPresented: $showRetryWithAdmin) {
            Button(loc.currentLanguage == .chinese ? "使用管理员权限删除" : "Delete with Admin", role: .destructive) {
                 scanState = .finished
            }
            Button(loc.L("cancel"), role: .cancel) {
                scanState = .finished
            }
        } message: {
            Text(loc.currentLanguage == .chinese ?
                 "部分文件因权限不足无法删除。" :
                 "Some files could not be deleted due to insufficient permissions.")
        }
    }
    
    // MARK: - 1. 初始页面
    private var initialPage: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                // Glassy Purple Icon
                GlassyPurpleDisc(scale: 1.0)
                    .scaleEffect(pulse ? 1.05 : 1.0)
                    .animation(Animation.easeInOut(duration: 3).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
            }
            .padding(.bottom, 40)
            
            Text(loc.currentLanguage == .chinese ? "系统垃圾" : "System Junk")
                .font(.system(size: 32, weight: .bold)) // Larger, bolder title
                .foregroundColor(.white)
                .padding(.bottom, 12)
                .shadow(color: .purple.opacity(0.5), radius: 10, x: 0, y: 5)
            
            Text(loc.currentLanguage == .chinese ? "清理系统的临时文件、缓存和日志，释放更多空间。" : "Clean system temporary files, caches, and logs to free up space.")
                .font(.body)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            
            Spacer()
            
            CircularActionButton(
                title: loc.currentLanguage == .chinese ? "扫描" : "Scan",
                gradient: GradientStyles.purple, // Purple Gradient
                action: { startScan() }
            )
            .shadow(color: .purple.opacity(0.4), radius: 15, x: 0, y: 5)
            .padding(.bottom, 60)
        }
    }

    // MARK: - 2. 扫描中页面
    private var scanningPage: some View {
        ZStack {
            // Main Scanning View
            VStack {
                HStack {
                    Button(action: {
                        scanState = .initial
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(loc.currentLanguage == .chinese ? "重新开始" : "Start Over")
                        }
                        .foregroundColor(.secondaryText)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(loc.currentLanguage == .chinese ? "系统垃圾" : "System Junk")
                        .font(.title3)
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 80)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                Spacer()
                
                // Mouse Animation in Center
                ZStack {
                    GlassyPurpleDisc(scale: 1.2)
                    
                    Image(systemName: "magicmouse") // Mouse icon
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .shadow(color: .purple.opacity(0.8), radius: 15)
                    
                    // Scanning Ring
                    Circle()
                        .stroke(
                            AngularGradient(gradient: Gradient(colors: [.purple, .pink, .purple]), center: .center),
                            lineWidth: 4
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(Animation.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
                }
                .onAppear {
                    isAnimating = true
                }
                .padding(.bottom, 40)
                
                Text(loc.currentLanguage == .chinese ? "正在分析系统..." : "Analyzing System...")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(.bottom, 8)
                
                Text(cleaner.currentScanningPath)
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 40)
                    .padding(.top, 4)
                    .frame(height: 20)
                
                Text(cleaner.currentScanningCategory)
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
                    .padding(.top, 2)
                    .transition(.opacity)
                    .id("CategoryText") // Force redraw if needed
                
                Spacer()
                
                // Stop Button (Round with Ring)
                 CircularActionButton(
                    title: loc.currentLanguage == .chinese ? "停止" : "Stop",
                    gradient: CircularActionButton.stopGradient,
                    progress: cleaner.scanProgress,
                    showProgress: true,
                    scanSize: ByteCountFormatter.string(fromByteCount: cleaner.totalSize, countStyle: .file),
                    action: { scanState = .initial }
                )
                .padding(.bottom, 60)
            }
            .onReceive(cleaner.$isScanning) { isScanning in
                if !isScanning && scanState == .scanning && !cleaner.hasPermissionErrors {
                    // Only transition to completed if no permission errors
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        if scanState == .scanning {
                            scanState = .completed
                        }
                    }
                }
            }
            
            // Permission Prompt Overlay (shows when scanning detects permission errors)
            if cleaner.hasPermissionErrors && !cleaner.isScanning {
                VStack(spacing: 24) {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "lock.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.yellow)
                        }
                        
                        Text(loc.currentLanguage == .chinese ? "需要访问权限" : "Access Required")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                        
                        Text(loc.currentLanguage == .chinese ? 
                             "请在系统设置中授予\"完全磁盘访问权限\"后点击继续" : 
                             "Please grant Full Disk Access in System Settings, then tap Continue")
                            .font(.body)
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                scanState = .initial
                            }) {
                                Text(loc.currentLanguage == .chinese ? "取消" : "Cancel")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 120, height: 44)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(22)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                // Reset and retry scan
                                cleaner.hasPermissionErrors = false
                                startScan()
                            }) {
                                Text(loc.currentLanguage == .chinese ? "继续扫描" : "Continue")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 120, height: 44)
                                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .cornerRadius(22)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 8)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 40)
                    
                    Spacer()
                }
                .background(Color.black.opacity(0.5))
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - 3. Summary Page
    private var summaryPage: some View {
        VStack(spacing: 0) {
            // Navbar
            HStack {
                Button(action: { scanState = .initial }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(loc.currentLanguage == .chinese ? "重新开始" : "Start Over")
                    }
                    .foregroundColor(.secondaryText)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(loc.currentLanguage == .chinese ? "系统垃圾" : "System Junk")
                    .foregroundColor(.white)
                Spacer()
                Button(action: { /* Help */ }) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.purple).frame(width: 8, height: 8)
                        Text(loc.currentLanguage == .chinese ? "助手" : "Assistant")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            if cleaner.totalSize == 0 && cleaner.hasPermissionErrors {
                // Permission Issue (Keep partially yellow/orange)
                ZStack {
                    GlassyPurpleDisc(scale: 1.1)
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color.yellow)
                        .shadow(color: .orange, radius: 10)
                }
                
                Spacer().frame(height: 40)
                
                Text(loc.currentLanguage == .chinese ? "需要访问权限" : "Access Required")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.bottom, 8)
                
                Text(loc.currentLanguage == .chinese ? "请在弹窗种允许访问以扫描垃圾文件" : "Please allow access in the system dialog to scan for junk files.")
                    .font(.body)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
            } else {
                // Result State
                ZStack {
                    GlassyPurpleDisc(scale: 1.1)
                    
                    // Overlay Result Icon
                     Image(systemName: "trash.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "E0B0FF")) // Light Lavender
                        .shadow(color: .purple, radius: 10)
                }
                
                Spacer()
                    .frame(height: 40)
                
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(loc.currentLanguage == .chinese ? "扫描完毕" : "Scan Complete")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                }
                .padding(.bottom, 4)
                
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(ByteCountFormatter.string(fromByteCount: cleaner.totalSize, countStyle: .file))
                        .font(.system(size: 60, weight: .light))
                        .foregroundStyle(LinearGradient(colors: [.white, .purple], startPoint: .top, endPoint: .bottom))
                    
                    Text(loc.currentLanguage == .chinese ? "智能选择" : "Smart Select")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .padding(.bottom, 20)
                
                // Includes List
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.currentLanguage == .chinese ? "包括" : "Includes")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    HStack(spacing: 20) {
                        Label(loc.currentLanguage == .chinese ? "用户缓存文件" : "User Cache", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        Label(loc.currentLanguage == .chinese ? "系统缓存文件" : "System Cache", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    Label(loc.currentLanguage == .chinese ? "系统日志文件" : "System Logs", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .padding(.bottom, 30)
                
                // View Items Button
                Button(action: {
                    withAnimation {
                        showingDetails = true
                    }
                }) {
                    Text(loc.currentLanguage == .chinese ? "查看项目" : "Review Details")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 20)
                 
                Text(loc.currentLanguage == .chinese ? "共发现 \(ByteCountFormatter.string(fromByteCount: cleaner.totalSize, countStyle: .file))" : "Found \(ByteCountFormatter.string(fromByteCount: cleaner.totalSize, countStyle: .file))")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                Spacer()
                
                // Start Cleaning Button
                CircularActionButton(
                    title: loc.currentLanguage == .chinese ? "运行" : "Run",
                    gradient: GradientStyles.purple, // Purple
                    scanSize: nil,
                    action: { startCleaning() }
                )
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - 4. Detail Page
    private var detailPage: some View {
        VStack(spacing: 0) {
            // Navbar
            HStack {
                Button(action: {
                    withAnimation {
                        showingDetails = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(loc.currentLanguage == .chinese ? "返回" : "Back")
                    }
                    .foregroundColor(.secondaryText)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(loc.currentLanguage == .chinese ? "系统垃圾" : "System Junk")
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack {
                     Image(systemName: "magnifyingglass").foregroundColor(.secondaryText)
                     TextField(loc.currentLanguage == .chinese ? "搜索" : "Search", text: $searchText)
                         .textFieldStyle(.plain)
                         .frame(width: 100)
                }
                .padding(6)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            Divider().background(Color.white.opacity(0.1))
            
            HSplitView {
                JunkSidebarView(selectedCategory: $selectedCategory, cleaner: cleaner)
                JunkDetailContentView(selectedCategory: selectedCategory, cleaner: cleaner)
            }
            
            // Bottom Clean Button Overlay
             ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .frame(height: 80)
                
                 CircularActionButton(
                    title: loc.currentLanguage == .chinese ? "清理" : "Clean",
                    gradient: GradientStyles.purple, // Purple
                    scanSize: ByteCountFormatter.string(fromByteCount: cleaner.selectedSize, countStyle: .file),
                    action: { startCleaning() }
                )
                .scaleEffect(0.8)
            }
            .frame(height: 80)
        }
        .onAppear {
            if selectedCategory == nil, let first = cleaner.junkItems.first {
                selectedCategory = first.type
            }
        }
    }
    
    private var cleaningPage: some View {
       VStack(spacing: 0) {
            Text(loc.currentLanguage == .chinese ? "正在清理..." : "Cleaning...")
                .font(.title)
                .foregroundColor(.white)
                .padding()
            ProgressView()
                .scaleEffect(1.5)
                .tint(.purple) // Purple Spinner
       }
    }
    
    private var finishedPage: some View {
        VStack {
             HStack {
                Button(action: { scanState = .initial }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(loc.currentLanguage == .chinese ? "重新开始" : "Start Over")
                    }
                    .foregroundColor(.secondaryText)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding()
            Spacer()
            
            ZStack {
                 Circle()
                    .fill(LinearGradient(colors: [.purple.opacity(0.3), .blue.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 200, height: 200)
                 Image(systemName: "checkmark")
                    .font(.system(size: 80))
                    .foregroundColor(Color(hex: "E0B0FF"))
            }
            
            Text(loc.currentLanguage == .chinese ? "清理完成" : "Cleanup Complete")
                .font(.title)
                .foregroundColor(.white)
                .padding()
            
            Text(ByteCountFormatter.string(fromByteCount: cleanResult?.cleaned ?? cleanedAmount, countStyle: .file))
                .font(.system(size: 40))
                .foregroundStyle(LinearGradient(colors: [.white, .purple], startPoint: .top, endPoint: .bottom))
            
            Text(loc.currentLanguage == .chinese ? "已释放空间" : "Space Freed")
                .foregroundColor(.secondaryText)
            
            Spacer()
            
             Button(action: { scanState = .initial }) {
                Text(loc.currentLanguage == .chinese ? "完成" : "Done")
                    .padding(.horizontal, 40)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(20)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
        }
    }

    func startScan() {
        scanState = .scanning
        Task {
            await cleaner.scanJunk()
        }
    }
    
    func startCleaning() {
        scanState = .cleaning
        Task {
            let result = await cleaner.cleanSelected()
            cleanResult = (result.cleaned, result.failed, result.requiresAdmin)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            scanState = .finished
        }
    }
}

// MARK: - Extracted Subviews for Detail Page

struct JunkSidebarView: View {
    @Binding var selectedCategory: JunkType?
    @ObservedObject var cleaner: JunkCleaner
    @ObservedObject private var loc = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    let allSelected = cleaner.junkItems.allSatisfy { $0.isSelected }
                    cleaner.junkItems.forEach { $0.isSelected = !allSelected }
                    cleaner.objectWillChange.send()
                }) {
                    Text(cleaner.junkItems.allSatisfy { $0.isSelected } ? (loc.currentLanguage == .chinese ? "取消全选" : "Deselect All") : (loc.currentLanguage == .chinese ? "全选" : "Select All"))
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(loc.currentLanguage == .chinese ? "排序方式 按大小" : "Sort by Size")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            
            List(selection: $selectedCategory) {
                ForEach(cleaner.junkItems.map { $0.type }.removingDuplicates(), id: \.self) { type in
                    JunkCategoryRow(type: type, 
                                items: cleaner.junkItems.filter { $0.type == type },
                                isSelected: selectedCategory == type)
                        .onTapGesture {
                            selectedCategory = type
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(selectedCategory == type ? Color.white.opacity(0.1) : Color.clear)
                }
            }
            .listStyle(.plain)
            .frame(minWidth: 260)
        }
        .background(Color.black.opacity(0.3)) // Dark sidebar
    }
}

struct JunkDetailContentView: View {
    let selectedCategory: JunkType?
    @ObservedObject var cleaner: JunkCleaner
    @ObservedObject private var loc = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let type = selectedCategory {
                let items = cleaner.junkItems.filter { $0.type == type }
                
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue + (loc.currentLanguage == .chinese ? "" : " Files"))
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .padding(20)
                
                // Items List
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            JunkItemRow(item: item, onTap: {})
                        }
                    }
                }
            } else {
                // Empty State
                Spacer()
                Text(loc.currentLanguage == .chinese ? "选择左侧类别查看详情" : "Select a category to view details")
                    .foregroundColor(.secondaryText)
                Spacer()
            }
        }
        .frame(minWidth: 400)
    }
}


// Helper for Array duplicate removal
extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}

// Category Row View
struct JunkCategoryRow: View {
    let type: JunkType
    let items: [JunkItem]
    let isSelected: Bool
    
    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }
    
    var isChecked: Bool {
        !items.isEmpty && items.allSatisfy { $0.isSelected }
    }
    
    var categoryColor: Color {
        // Match specific colors from design if possible, otherwise use specific gradients
        switch type {
        case .unusedDiskImages: return .blue
        case .universalBinaries: return .purple
        case .userCache: return .orange
        case .systemCache: return .pink
        case .systemLogs, .userLogs: return .gray
        case .brokenLoginItems: return .red
        case .oldUpdates: return .green
        case .iosBackups: return .cyan
        case .downloads: return .indigo
        default: return .purple
        }
    }
    
    var body: some View {
        HStack {
            Button(action: {
                let newState = !isChecked
                items.forEach { $0.isSelected = newState }
                ScanServiceManager.shared.junkCleaner.objectWillChange.send()
            }) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isChecked ? .purple : .secondaryText) // Purple checkmark
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [categoryColor.opacity(0.8), categoryColor.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 26, height: 26)
                    .shadow(color: categoryColor.opacity(0.3), radius: 3)
                
                Image(systemName: type.icon)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
            
            Text(type.rawValue)
                .foregroundColor(.white)
                .font(.system(size: 13, weight: .medium))
            
            Spacer()
            
            Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                .foregroundColor(.secondaryText)
                .font(.system(size: 12))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
    }
}


// MARK: - Subviews
struct JunkItemRow: View {
    @ObservedObject var item: JunkItem
    var onTap: () -> Void
    
    var body: some View {
        let binding = Binding<Bool>(
            get: { item.isSelected },
            set: { newValue in
                item.isSelected = newValue
                ScanServiceManager.shared.junkCleaner.objectWillChange.send()
            }
        )
        
        HStack(spacing: 12) {
            Toggle("", isOn: binding)
                .toggleStyle(CheckboxStyle())
                .labelsHidden()
            
            // File Icon (Real System Icon)
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.path.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    
                Text(item.path.path) // Show full path or partial? Path is good for verification
                    .font(.system(size: 10))
                    .foregroundColor(.tertiaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Helpers

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

// Removed duplicate GradientStyles struct here. Using global one in Styles.swift

// MARK: - Purple Mesh Background (Pro Max Theme)
struct PurpleMeshBackground: View {
    var body: some View {
        ZStack {
            // 1. Deep Space Base
            Color(red: 0.05, green: 0.05, blue: 0.1)
            
            // 2. Mesh Gradients
            GeometryReader { proxy in
                ZStack {
                    // Top-Left Pink/Purple
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: "BF5AF2").opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: 600))
                        .frame(width: 800, height: 800)
                        .offset(x: -200, y: -300)
                        .blur(radius: 60)
                        .blendMode(.screen)
                    
                    // Center-Right Blue/Indigo
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: "5E5CE6").opacity(0.25), .clear], center: .center, startRadius: 0, endRadius: 500))
                        .frame(width: 700, height: 700)
                        .offset(x: 300, y: 100)
                        .blur(radius: 60)
                        .blendMode(.screen)
                    
                    // Bottom Deep Purple
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: "5856D6").opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: 700))
                        .frame(width: 1000, height: 1000)
                        .offset(x: 0, y: 400)
                        .blur(radius: 80)
                }
            }
            
            // 3. Grid/Noise Overlay (Optional, for "Pro" feel)
            Rectangle()
                .fill(Color.white.opacity(0.02))
                .blendMode(.overlay)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glassy Purple Disc (Icon)
struct GlassyPurpleDisc: View {
    var scale: CGFloat = 1.0
    var rotation: Double = 0
    var isSpinning: Bool = false
    
    var body: some View {
        ZStack {
            // Outer Ring
            Circle()
                .fill(
                    LinearGradient(colors: [Color(hex: "BF5AF2").opacity(0.2), Color(hex: "5E5CE6").opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 260 * scale, height: 260 * scale)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            
            // Middle Glass Purple
            Circle()
                .fill(
                    LinearGradient(colors: [Color(hex: "AC44CF").opacity(0.8), Color(hex: "5E5CE6").opacity(0.6)], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 200 * scale, height: 200 * scale)
                .shadow(color: Color(hex: "BF5AF2").opacity(0.5), radius: 25, y: 10)
                .overlay(    
                    Circle().stroke(
                        LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom), 
                        lineWidth: 1
                    )
                )
            
            // Inner Core
            Circle()
                .fill(LinearGradient(colors: [.white, Color(hex: "E0B0FF")], startPoint: .top, endPoint: .bottom))
                .frame(width: 80 * scale, height: 80 * scale)
                .shadow(color: .black.opacity(0.2), radius: 5)
            
            // Spinner Detail
            if isSpinning {
                 Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 140 * scale, height: 140 * scale)
                    .rotationEffect(.degrees(rotation))
            } else {
                 // Static Center (Broom or Trash Icon)
                 Image(systemName: "trash.fill")
                    .font(.system(size: 30 * scale))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "BF5AF2"), Color(hex: "5E5CE6")], startPoint: .top, endPoint: .bottom))
            }
        }
    }
}
