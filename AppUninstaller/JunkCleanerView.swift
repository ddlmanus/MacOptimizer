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
    
    var body: some View {
        ZStack {
            switch scanState {
            case .initial:
                initialPage
            case .scanning:
                scanningPage
            case .completed:
                if showingDetails {
                    detailPage // 详情页 (Design 2)
                } else {
                    summaryPage // 结果摘要页 (Design 1)
                }
            case .cleaning:
                cleaningPage
            case .finished:
                finishedPage
            }
        }
        .onAppear {
            if !cleaner.junkItems.isEmpty && !cleaner.isScanning && scanState == .initial {
                scanState = .completed
            } else if cleaner.isScanning {
                scanState = .scanning
            }
        }
        // ... (Alert logic kept same)
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
    
    // ... (Initial Page and Scanning Page logic kept largely same, ensuring consistency)
    
    // MARK: - 1. 初始页面
    private var initialPage: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 240, height: 240)
                    .scaleEffect(pulse ? 1.1 : 1.0)
                    .opacity(pulse ? 0.5 : 0.3)
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) { pulse = true }
                    }
                Circle()
                    .stroke(LinearGradient(colors: [.purple.opacity(0.1), .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(animateScan ? 360 : 0))
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.purple)
            }
            .padding(.bottom, 40)
            
            Text(loc.currentLanguage == .chinese ? "系统垃圾" : "System Junk")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 12)
            
            Text(loc.currentLanguage == .chinese ? "清理系统的临时文件、缓存和日志，释放更多空间。" : "Clean system temporary files, caches, and logs to free up space.")
                .font(.body)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            
            Spacer()
            
            CircularActionButton(
                title: loc.currentLanguage == .chinese ? "扫描" : "Scan",
                gradient: GradientStyles.cleaner,
                action: { startScan() }
            )
            .padding(.bottom, 60)
        }
    }

    // MARK: - 2. 扫描中页面
    private var scanningPage: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { 
                    // 允许返回
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
            
            ZStack {
                // ... Animation same as before
                Circle().fill(Color.purple.opacity(0.1)).frame(width: 200, height: 200)
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(AngularGradient(gradient: Gradient(colors: [.purple, .purple.opacity(0.1)]), center: .center), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(animateScan ? 360 : 0))
                    .onAppear { withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) { animateScan = true } }
                
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.purple)
                }
            }
            .padding(.bottom, 40)
            
            Text(loc.currentLanguage == .chinese ? "正在分析系统..." : "Analyzing System...")
                .font(.title3)
                .foregroundColor(.white)
                .padding(.bottom, 8)
            
            Text("\(Int(cleaner.scanProgress * 100))%")
                .foregroundColor(.secondaryText)
            
            Spacer()
            
            // Stop Button
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
            if !isScanning && scanState == .scanning {
                scanState = .completed
            }
        }
    }
    
    // MARK: - 3. Summary Page (Design 1)
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
                        Circle().fill(Color.blue).frame(width: 8, height: 8)
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
            
            // Main Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "F54EA2"), Color(hex: "FF7676")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 220, height: 220)
                    .shadow(color: Color(hex: "F54EA2").opacity(0.3), radius: 20, x: 0, y: 10)
                
                // Icon (Mouse shape or similar)
                Image(systemName: "magicmouse") // Placeholder, use design asset if available
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 140)
                    .foregroundColor(.white)
                    // Add wire effect if needed
                
                // Outer ring
                 Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .frame(width: 260, height: 260)
            }
            
            Spacer()
                .frame(height: 40)
            
            // Text Info
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
                    .foregroundColor(Color(hex: "4FA5E8")) // Blue color from screenshot
                
                Text(loc.currentLanguage == .chinese ? "智能选择" : "Smart Select")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            .padding(.bottom, 20)
            
            // Includes List (Simplified)
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
            
            // Clean Button
            CircularActionButton(
                title: loc.currentLanguage == .chinese ? "清理" : "Clean",
                gradient: GradientStyles.cleaner, // Uses blue/purple gradient
                scanSize: ByteCountFormatter.string(fromByteCount: cleaner.selectedSize, countStyle: .file),
                action: { startCleaning() }
            )
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - 4. Detail Page (Design 2 - Split View)
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
                // Left Sidebar: Categories
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
                    .frame(minWidth: 250)
                }
                .background(Color.white.opacity(0.02))
                
                // Right Content: Detail Items
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
            
            // Bottom Clean Button Overlay
             ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .frame(height: 80)
                
                 CircularActionButton(
                    title: loc.currentLanguage == .chinese ? "清理" : "Clean",
                    gradient: GradientStyles.cleaner,
                    scanSize: ByteCountFormatter.string(fromByteCount: cleaner.selectedSize, countStyle: .file),
                    action: { startCleaning() }
                )
                .scaleEffect(0.8)
            }
            .frame(height: 80)
        }
        .onAppear {
            // Default select first category
            if selectedCategory == nil, let first = cleaner.junkItems.first {
                selectedCategory = first.type
            }
        }
    }
    
    // MARK: - 5. Cleaning and Finished pages kept mostly same but ensure navigation logic
    
    private var cleaningPage: some View {
       // ... Same logic as before ...
       VStack(spacing: 0) {
            Text(loc.currentLanguage == .chinese ? "正在清理..." : "Cleaning...")
                .font(.title)
                .padding()
            ProgressView()
                .scaleEffect(1.5)
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
                    .foregroundColor(.white)
            }
            
            Text(loc.currentLanguage == .chinese ? "清理完成" : "Cleanup Complete")
                .font(.title)
                .padding()
            
            Text(ByteCountFormatter.string(fromByteCount: cleanResult?.cleaned ?? cleanedAmount, countStyle: .file))
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
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

    // ... MARK: - Actions (startScan, startCleaning) kept same
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
    
    var body: some View {
        HStack {
            // Custom Radio/Check
             Circle()
                .stroke(Color.secondaryText, lineWidth: 1)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle().fill(isSelected ? Color.blue : Color.clear).padding(3)
                )
            
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.8)).frame(width: 24, height: 24)
                Image(systemName: type.icon).font(.caption).foregroundColor(.white)
            }
            
            Text(type.rawValue)
                .foregroundColor(.white)
                .font(.system(size: 13))
            
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
        HStack(spacing: 12) {
            Toggle("", isOn: $item.isSelected)
                .toggleStyle(CheckboxStyle())
                .labelsHidden()
            
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: item.type.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 14))
                    .foregroundColor(.primaryText)
                Text(item.type.description)
                    .font(.system(size: 12))
                    .foregroundColor(.tertiaryText)
            }
            
            Spacer()
            
            Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                .font(.system(size: 13))
                .foregroundColor(.secondaryText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.clear) // Hover effect can be added here
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Helpers

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

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
