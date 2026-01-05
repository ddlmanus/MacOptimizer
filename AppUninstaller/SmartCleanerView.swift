import SwiftUI

// 扫描状态枚举
enum ScanState {
    case initial    // 初始页面
    case scanning   // 扫描中
    case cleaning   // 清理中
    case completed  // 扫描完成（结果页）
    case finished   // 清理完成（最终页）
}

struct SmartCleanerView: View {
    // 导航绑定 - 用于跳转到其他页面
    @Binding var selectedModule: AppModule
    
    // 使用共享的服务管理器
    @ObservedObject private var service = ScanServiceManager.shared.smartCleanerService
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var selectedCategory: CleanerCategory = .systemJunk
    @State private var showDeleteConfirmation = false
    @State private var deleteResult: (success: Int, failed: Int, size: Int64)?
    @State private var showResult = false
    @State private var showCleaningFinished = false
    @State private var showRunningAppsSafetyAlert = false
    
    // 管理员权限重试
    @State private var failedFiles: [CleanerFileItem] = []
    @State private var showRetryWithAdmin = false
    
    // Detail Sheet State
    @State private var showDetailSheet = false
    @State private var initialDetailCategory: CleanerCategory? = nil
    
    // 扫描状态
    private var scanState: ScanState {
        if service.isScanning {
            return .scanning
        } else if service.isCleaning {
            // cleaningPage UI is simpler, we can reuse simplified scanning layout or keeping it
            return .cleaning
        } else if showRetryWithAdmin {
            return .cleaning 
        } else if showCleaningFinished {
            return .finished
        } else if hasScanResults {
            return .completed
        }
        return .initial
    }
    
    // 计算属性：检查 service 是否已有扫描结果
    private var hasScanResults: Bool {
        return service.systemJunkTotalSize > 0 ||
               !service.duplicateGroups.isEmpty ||
               !service.similarPhotoGroups.isEmpty ||
               !service.largeFiles.isEmpty ||
               !service.userCacheFiles.isEmpty ||
               !service.systemCacheFiles.isEmpty ||
               !service.virusThreats.isEmpty ||
               service.hasAppUpdates ||
               !service.startupItems.isEmpty ||
               !service.performanceApps.isEmpty
    }

    // 计算扫描到的总大小
    private var totalScannedSize: Int64 {
        let topLevelCategories: [CleanerCategory] = [
            .systemJunk, .duplicates, .similarPhotos, .largeFiles, .virus
        ]
        return topLevelCategories.reduce(0) { $0 + service.sizeFor(category: $1) }
    }
    
    var body: some View {
        ZStack {
            // 背景 - 匹配设计图的紫靛色渐变
            BackgroundStyles.smartClean
                .ignoresSafeArea()
            
            // Main Content
            VStack {
                 // Header
                 headerView
                 
                 // Dynamic Content
                 switch scanState {
                 case .initial:
                     initialPage
                 case .scanning:
                     scanningPage
                 case .completed:
                     resultsPage
                 case .cleaning:
                     cleaningPage
                 case .finished:
                     cleaningFinishedPage
                 }
            }
            .padding(.bottom, 100) // Increase padding to avoid button overlap

            // Floating Main Action Button
            VStack {
                Spacer()
                mainActionButton
                    .padding(.bottom, 30) // Raise button to be fully visible
            }
        }
        // Sheet for details
        .sheet(isPresented: $showDetailSheet) {
            AllCategoriesDetailSheet(
                service: service,
                loc: loc,
                isPresented: $showDetailSheet,
                initialCategory: initialDetailCategory
            )
        }
        // Alerts & Confirmations ... (Keeping existing logic)
        .confirmationDialog(
            loc.currentLanguage == .chinese ? "确认删除" : "Confirm Delete",
            isPresented: $showDeleteConfirmation
        ) {
            Button(loc.currentLanguage == .chinese ? "开始清理" : "Start Cleaning", role: .destructive) {
                Task {
                    let result = await service.cleanAll()
                    deleteResult = (result.success, result.failed, result.size)
                    failedFiles = result.failedFiles
                    if result.failed > 0 && !failedFiles.isEmpty {
                        showRetryWithAdmin = true
                    } else {
                        showCleaningFinished = true
                    }
                }
            }
            Button(loc.L("cancel"), role: .cancel) {}
        } message: {
            Text(loc.currentLanguage == .chinese ? "将清理所有选中的垃圾文件，释放空间。" : "Clean all selected files to free up space.")
        }
        .alert(loc.currentLanguage == .chinese ? "部分文件需要管理员权限" : "Some Files Require Admin Privileges", isPresented: $showRetryWithAdmin) {
             Button(loc.currentLanguage == .chinese ? "使用管理员权限删除" : "Delete with Admin", role: .destructive) {
                 Task {
                     let adminResult = await service.cleanWithPrivileges(files: failedFiles)
                     if let currentResult = deleteResult {
                         deleteResult = (
                             currentResult.success + adminResult.success,
                             adminResult.failed,
                             currentResult.size + adminResult.size
                         )
                     }
                     failedFiles = []
                     showCleaningFinished = true
                 }
             }
             Button(loc.L("cancel"), role: .cancel) { showCleaningFinished = true }
        } message: {

            Text(loc.currentLanguage == .chinese ?
                 "有 \(failedFiles.count) 个文件因权限不足无法删除。" :
                 "\(failedFiles.count) files could not be deleted due to permissions.")
        }
        .alert(loc.currentLanguage == .chinese ? "重要提示：正在运行的应用" : "Important: Running Applications", isPresented: $showRunningAppsSafetyAlert) {
            Button(loc.currentLanguage == .chinese ? "确认并继续" : "Confirm and Continue", role: .destructive) {
                showDeleteConfirmation = true
            }
            Button(loc.L("cancel"), role: .cancel) {}
        } message: {
            Text(loc.currentLanguage == .chinese ?
                 "检测到您已勾选正在运行的应用。关闭它们可能会导致未保存的数据丢失。确认要继续吗？" :
                 "Running applications are selected to be closed. This may cause loss of unsaved data. Do you want to continue?")
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            if scanState == .completed || scanState == .finished {
                Button(action: { Task { service.resetAll() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text(loc.currentLanguage == .chinese ? "重新开始" : "Start Over")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Center Title
             Text(loc.currentLanguage == .chinese ? "智能扫描" : "Smart Scan")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            
            // Right Action -  removed helper/rescan button
            // Placeholder to balance layout
            Text("           ").opacity(0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }
    
    // MARK: - Initial Page (Ready State)
    private var initialPage: some View {
        VStack {
            Spacer()
            
            // 核心图标区域 - 匹配设计图
            ZStack {
                // 底部紫色光晕
                Circle()
                    .fill(Color(red: 0.6, green: 0.3, blue: 0.9).opacity(0.2))
                    .frame(width: 450, height: 450)
                    .blur(radius: 60)
                
                // 显示器主图标
                ZStack {
                    // 主体
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 260, height: 260)
                        .shadow(color: Color.pink.opacity(0.3), radius: 30, x: 0, y: 10)
                    
                    // 扫过光效 (Wipe/Scan animation effect)
                    GeometryReader { geo in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white.opacity(0.4), location: 0.5),
                                        .init(color: .clear, location: 1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 300, height: 20)
                            .rotationEffect(.degrees(-25))
                            .offset(y: -50)
                            .modifier(WipingAnimation())
                    }
                    .frame(width: 260, height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            .padding(.bottom, 60)
            
            VStack(spacing: 12) {
                Text(loc.currentLanguage == .chinese ? "欢迎使用 Mac优化大师" : "Welcome to MacOptimizer")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundColor(.white)
                
                Text(loc.currentLanguage == .chinese ? "开始全面、仔细扫描您的 Mac。" : "Start a comprehensive and thorough scan of your Mac.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.bottom, 100)
            
            Spacer()
        }
    }

    // MARK: - Scanning Page (Block Grid Layout)
    private var scanningPage: some View {
        VStack(spacing: 0) {
            // Grid of scan blocks - 8 categories (4x2)
            VStack(spacing: 16) {
                // Row 1
                let row1: [CleanerCategory] = [.systemJunk, .duplicates, .similarPhotos, .largeFiles]
                HStack(spacing: 16) {
                    ForEach(row1, id: \.self) { cat in
                        createScanBlock(for: cat)
                    }
                }
                
                // Row 2
                let row2: [CleanerCategory] = [.virus, .startupItems, .performanceApps, .appUpdates]
                HStack(spacing: 16) {
                    ForEach(row2, id: \.self) { cat in
                        createScanBlock(for: cat)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Scanning State Helpers
    
    // Get list of already scanned categories based on scan order
    // Order: systemJunk -> duplicates -> similarPhotos -> localizations -> largeFiles -> virus -> appUpdates -> startupItems -> performanceApps
    private var scanOrder: [CleanerCategory] {
        [.systemJunk, .duplicates, .similarPhotos, .localizations, .largeFiles, .virus, .appUpdates, .startupItems, .performanceApps]
    }
    
    private func hasPassed(category: CleanerCategory) -> Bool {
        guard let currentIndex = scanOrder.firstIndex(of: service.currentCategory),
              let targetIndex = scanOrder.firstIndex(of: category) else {
            return false
        }
        return currentIndex > targetIndex
    }
    
    // Cleaning category (systemJunk)
    private var isCleaningCategoryActive: Bool {
        service.currentCategory == .systemJunk && service.isScanning
    }
    private var cleaningCompleted: Bool {
        hasPassed(category: .systemJunk) || (!service.isScanning && service.systemJunkTotalSize > 0)
    }
    private var cleaningResultText: String {
        ByteCountFormatter.string(fromByteCount: service.systemJunkTotalSize, countStyle: .file) + " " + (loc.currentLanguage == .chinese ? "的垃圾" : "Junk")
    }
    
    // Protection category (virus)
    private var isProtectionCategoryActive: Bool {
        service.currentCategory == .virus && service.isScanning
    }
    private var protectionCompleted: Bool {
        hasPassed(category: .virus) || (!service.isScanning && !isProtectionCategoryActive)
    }
    private var protectionResultText: String {
        service.virusThreats.isEmpty ? (loc.currentLanguage == .chinese ? "无潜在威胁" : "No Threats") : "\(service.virusThreats.count) " + (loc.currentLanguage == .chinese ? "个威胁" : "Threats")
    }
    
    // Performance category (startupItems, performanceApps)
    private var isPerformanceCategoryActive: Bool {
        [.startupItems, .performanceApps].contains(service.currentCategory) && service.isScanning
    }
    private var performanceCompleted: Bool {
        hasPassed(category: .performanceApps) || (!service.isScanning && !isPerformanceCategoryActive)
    }
    private var performanceResultText: String {
        let count = service.startupItems.count + service.performanceApps.count
        return "\(count) " + (loc.currentLanguage == .chinese ? "个项目" : "Items")
    }
    
    // Applications category (appUpdates)
    private var isApplicationsCategoryActive: Bool {
        service.currentCategory == .appUpdates && service.isScanning
    }
    private var applicationsCompleted: Bool {
        hasPassed(category: .appUpdates) || (!service.isScanning && !isApplicationsCategoryActive)
    }
    private var applicationsResultText: String {
        service.hasAppUpdates ? (loc.currentLanguage == .chinese ? "有更新可用" : "Updates Available") : (loc.currentLanguage == .chinese ? "无重要更新" : "No Updates")
    }
    
    // Clutter category (duplicates, similarPhotos, largeFiles)
    private var isClutterCategoryActive: Bool {
        [.duplicates, .similarPhotos, .largeFiles].contains(service.currentCategory) && service.isScanning
    }
    private var clutterCompleted: Bool {
        hasPassed(category: .largeFiles) || (!service.isScanning && !isClutterCategoryActive)
    }
    private var clutterResultText: String {
        let size = service.sizeFor(category: .duplicates) + service.sizeFor(category: .similarPhotos) + service.sizeFor(category: .largeFiles)
        return size > 0 ? ByteCountFormatter.string(fromByteCount: size, countStyle: .file) : (loc.currentLanguage == .chinese ? "无杂乱文件" : "No Clutter")
    }

    // MARK: - Cleaning Page (Block Grid Layout)
    private var cleaningPage: some View {
        VStack(spacing: 0) {
            // Grid of cleaning blocks - 8 categories
            VStack(spacing: 16) {
                // Row 1
                let row1: [CleanerCategory] = [.systemJunk, .duplicates, .similarPhotos, .largeFiles]
                HStack(spacing: 16) {
                    ForEach(row1, id: \.self) { cat in
                        createCleaningBlock(for: cat)
                    }
                }
                
                // Row 2
                let row2: [CleanerCategory] = [.virus, .startupItems, .performanceApps, .appUpdates]
                HStack(spacing: 16) {
                    ForEach(row2, id: \.self) { cat in
                        createCleaningBlock(for: cat)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            // Progress indicator
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text(loc.currentLanguage == .chinese ? "正在清理中..." : "Cleaning in progress...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Results Page (Block Grid Layout - Same as Scanning/Cleaning)
    private var resultsPage: some View {
        VStack(spacing: 0) {
            // Grid of result blocks - 8 categories
            VStack(spacing: 16) {
                // Row 1
                let row1: [CleanerCategory] = [.systemJunk, .duplicates, .similarPhotos, .largeFiles]
                HStack(spacing: 16) {
                    ForEach(row1, id: \.self) { cat in
                        createResultBlock(for: cat)
                    }
                }
                
                // Row 2
                let row2: [CleanerCategory] = [.virus, .startupItems, .performanceApps, .appUpdates]
                HStack(spacing: 16) {
                    ForEach(row2, id: \.self) { cat in
                        createResultBlock(for: cat)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Main Action Button (Scan Orb)
    @ViewBuilder
    private var mainActionButton: some View {
        switch scanState {
        case .initial:
            // Start Orb
            Button(action: {
                Task { await service.scanAll() }
            }) {
                ZStack {
                    // Outer Glow
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color.purple.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 90
                        ))
                        .frame(width: 160, height: 160)
                    
                    // Main Orb
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.8, green: 0.2, blue: 0.7), Color(red: 0.5, green: 0.1, blue: 0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: .purple.opacity(0.6), radius: 15, x: 0, y: 8)
                        .overlay(
                            // Glassy reflection
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.7), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                    
                    Text(loc.currentLanguage == .chinese ? "开始" : "Start")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
            }
            .buttonStyle(.plain)
            
        case .scanning:
            // Stop Orb
            Button(action: { service.stopScanning() }) {
                ZStack {
                    // Outer Glow
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color.pink.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 90
                        ))
                        .frame(width: 160, height: 160)
                    
                    // Main Orb
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.9, green: 0.3, blue: 0.5), Color(red: 0.7, green: 0.1, blue: 0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: .pink.opacity(0.6), radius: 15, x: 0, y: 8)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                        )
                    
                    VStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 24))
                        Text(loc.currentLanguage == .chinese ? "停止" : "Stop")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            
        case .completed:
            // Run Orb
            Button(action: {
                if service.performanceApps.contains(where: { $0.isSelected }) {
                    showRunningAppsSafetyAlert = true
                } else {
                    showDeleteConfirmation = true
                }
            }) {
                ZStack {
                    // Outer Glow
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color.blue.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 90
                        ))
                        .frame(width: 160, height: 160)
                    
                    // Main Orb
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.5, blue: 0.9), Color(red: 0.1, green: 0.3, blue: 0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: .blue.opacity(0.6), radius: 15, x: 0, y: 8)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.6), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                    
                    VStack(spacing: 2) {
                        Image(systemName: "rocket.fill")
                            .font(.system(size: 24))
                        Text(loc.currentLanguage == .chinese ? "运行" : "Run")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Finished Page (Block Grid with Success Overlay)
    private var cleaningFinishedPage: some View {
        VStack(spacing: 0) {
            // Grid of finished blocks - 8 categories
            VStack(spacing: 16) {
                // Row 1
                let row1: [CleanerCategory] = [.systemJunk, .duplicates, .similarPhotos, .largeFiles]
                HStack(spacing: 16) {
                    ForEach(row1, id: \.self) { cat in
                        createFinishedBlock(for: cat)
                    }
                }
                
                // Row 2
                let row2: [CleanerCategory] = [.virus, .startupItems, .performanceApps, .appUpdates]
                HStack(spacing: 16) {
                    ForEach(row2, id: \.self) { cat in
                        createFinishedBlock(for: cat)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            // Success message and back button
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.5), radius: 10)
                
                Text(loc.currentLanguage == .chinese ? "清理完成！" : "Cleaning Complete!")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                
                Button(action: {
                    Task { service.resetAll(); showCleaningFinished = false }
                }) {
                    Text(loc.currentLanguage == .chinese ? "返回" : "Back")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(20)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Page Helpers
    @ViewBuilder
    private func createScanBlock(for category: CleanerCategory) -> some View {
        ScanBlockView(
            category: category,
            isActive: service.currentCategory == category && service.isScanning,
            isCompleted: service.scannedCategories.contains(category),
            title: getDisplayTitle(for: category),
            resultText: getResultText(for: category),
            subText: getSubText(for: category),
            icon: category.icon,
            gradient: getGradient(for: category),
            scanningTitle: getScanningTitle(for: category),
            currentPath: service.currentScanPath,
            loc: loc,
            viewDetailsAction: { initialDetailCategory = category; showDetailSheet = true }
        )
    }
    
    @ViewBuilder
    private func createResultBlock(for category: CleanerCategory) -> some View {
        ResultBlockView(
            title: getDisplayTitle(for: category),
            resultText: getResultText(for: category),
            subText: getSubText(for: category),
            icon: category.icon,
            gradient: getGradient(for: category),
            action: { initialDetailCategory = category; showDetailSheet = true }
        )
    }
    
    @ViewBuilder
    private func createCleaningBlock(for category: CleanerCategory) -> some View {
        CleaningBlockView(
            title: getDisplayTitle(for: category),
            resultText: getResultText(for: category),
            subText: getCleaningSubText(for: category),
            icon: category.icon,
            gradient: getGradient(for: category),
            cleaningTitle: getCleaningTitle(for: category),
            isActive: service.cleaningCurrentCategory == category,
            isCompleted: service.cleanedCategories.contains(category),
            currentPath: service.cleaningDescription,
            loc: loc,
            viewDetailsAction: { initialDetailCategory = category; showDetailSheet = true }
        )
    }
    
    @ViewBuilder
    private func createFinishedBlock(for category: CleanerCategory) -> some View {
        FinishedBlockView(
            title: getDisplayTitle(for: category),
            resultText: getFinishedResultText(for: category),
            icon: category.icon,
            gradient: getGradient(for: category),
            viewDetailsAction: { initialDetailCategory = category; showDetailSheet = true }
        )
    }
    
    // MARK: - Display Helpers
    private func getDisplayTitle(for category: CleanerCategory) -> String {
        switch category {
        case .systemJunk: return loc.currentLanguage == .chinese ? "系统垃圾" : "System Junk"
        case .duplicates: return loc.currentLanguage == .chinese ? "重复文件" : "Duplicates"
        case .similarPhotos: return loc.currentLanguage == .chinese ? "相似照片" : "Similar Photos"
        case .largeFiles: return loc.currentLanguage == .chinese ? "大文件" : "Large Files"
        case .virus: return loc.currentLanguage == .chinese ? "病毒防护" : "Virus Protection"
        case .startupItems: return loc.currentLanguage == .chinese ? "启动项" : "Startup Items"
        case .performanceApps: return loc.currentLanguage == .chinese ? "性能优化" : "Performance"
        case .appUpdates: return loc.currentLanguage == .chinese ? "应用更新" : "App Updates"
        default: return ""
        }
    }
    
    private func getResultText(for category: CleanerCategory) -> String {
        let size = service.sizeFor(category: category)
        if size > 0 || [.systemJunk, .duplicates, .similarPhotos, .largeFiles].contains(category) {
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        
        switch category {
        case .virus: return service.virusThreats.isEmpty ? (loc.currentLanguage == .chinese ? "0 个威胁" : "0 Threats") : "\(service.virusThreats.count) \(loc.currentLanguage == .chinese ? "个威胁" : "Threats")"
        case .startupItems: return "\(service.startupItems.count) \(loc.currentLanguage == .chinese ? "个项目" : "Items")"
        case .performanceApps: return "\(service.performanceApps.count) \(loc.currentLanguage == .chinese ? "个应用" : "Apps")"
        case .appUpdates: return service.hasAppUpdates ? (loc.currentLanguage == .chinese ? "有更新" : "Has Update") : (loc.currentLanguage == .chinese ? "无更新" : "No Updates")
        default: return "0 KB"
        }
    }
    
    private func getSubText(for category: CleanerCategory) -> String {
        switch category {
        case .systemJunk, .duplicates, .similarPhotos, .largeFiles: return loc.currentLanguage == .chinese ? "可清理" : "Cleanable"
        case .virus: return service.virusThreats.isEmpty ? (loc.currentLanguage == .chinese ? "已保护" : "Safe") : (loc.currentLanguage == .chinese ? "可移除" : "Removable")
        case .startupItems: return loc.currentLanguage == .chinese ? "可优化" : "Optimizable"
        case .performanceApps: return loc.currentLanguage == .chinese ? "待查看" : "To Review"
        case .appUpdates: return loc.currentLanguage == .chinese ? "要安装" : "To Install"
        default: return ""
        }
    }
    
    private func getScanningTitle(for category: CleanerCategory) -> String {
        switch category {
        case .systemJunk: return loc.currentLanguage == .chinese ? "正在查找垃圾文件......" : "Searching for junk..."
        case .duplicates: return loc.currentLanguage == .chinese ? "正在寻找重复文件..." : "Finding duplicates..."
        case .similarPhotos: return loc.currentLanguage == .chinese ? "正在查找相似照片..." : "Finding similar photos..."
        case .largeFiles: return loc.currentLanguage == .chinese ? "正在扫描大文件..." : "Scanning for large files..."
        case .virus: return loc.currentLanguage == .chinese ? "正在查找潜在威胁..." : "Scanning for threats..."
        case .startupItems: return loc.currentLanguage == .chinese ? "正在分析启动项..." : "Analyzing startup items..."
        case .performanceApps: return loc.currentLanguage == .chinese ? "正在检查后台应用..." : "Checking background apps..."
        case .appUpdates: return loc.currentLanguage == .chinese ? "正在检查应用更新..." : "Checking for updates..."
        default: return ""
        }
    }
    
    private func getGradient(for category: CleanerCategory) -> LinearGradient {
        switch category {
        case .systemJunk:
            return LinearGradient(colors: [Color(red: 0.2, green: 0.9, blue: 0.6), Color(red: 0.1, green: 0.6, blue: 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .duplicates:
            return LinearGradient(colors: [Color(red: 0.3, green: 0.7, blue: 1.0), Color(red: 0.1, green: 0.4, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .similarPhotos:
            return LinearGradient(colors: [Color(red: 0.7, green: 0.5, blue: 1.0), Color(red: 0.4, green: 0.2, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .largeFiles:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.7, blue: 0.3), Color(red: 0.8, green: 0.4, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .virus:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.3, blue: 0.4), Color(red: 0.7, green: 0.1, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .startupItems:
            return LinearGradient(colors: [Color(red: 0.4, green: 0.4, blue: 0.9), Color(red: 0.2, green: 0.2, blue: 0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .performanceApps:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.4, blue: 0.7), Color(red: 0.8, green: 0.2, blue: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .appUpdates:
            return LinearGradient(colors: [Color(red: 0.2, green: 0.8, blue: 1.0), Color(red: 0.1, green: 0.5, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [Color.gray, Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private func getCleaningSubText(for category: CleanerCategory) -> String {
        switch category {
        case .systemJunk, .duplicates, .similarPhotos, .largeFiles: return loc.currentLanguage == .chinese ? "已清理" : "Cleaned"
        case .virus: return loc.currentLanguage == .chinese ? "已防护" : "Protected"
        case .performanceApps, .startupItems: return loc.currentLanguage == .chinese ? "已优化" : "Optimized"
        case .appUpdates: return loc.currentLanguage == .chinese ? "已检查" : "Checked"
        default: return ""
        }
    }
    
    private func getCleaningTitle(for category: CleanerCategory) -> String {
        switch category {
        case .systemJunk: return loc.currentLanguage == .chinese ? "正在清理垃圾文件..." : "Cleaning junk..."
        case .duplicates, .similarPhotos, .largeFiles: return loc.currentLanguage == .chinese ? "正在整理文件..." : "Organizing files..."
        case .virus: return loc.currentLanguage == .chinese ? "正在移除威胁..." : "Removing threats..."
        case .startupItems: return loc.currentLanguage == .chinese ? "正在优化启动项..." : "Optimizing startup..."
        case .performanceApps: return loc.currentLanguage == .chinese ? "正在优化性能..." : "Optimizing performance..."
        case .appUpdates: return loc.currentLanguage == .chinese ? "正在检查更新状态..." : "Checking update status..."
        default: return ""
        }
    }
    
    private func getFinishedResultText(for category: CleanerCategory) -> String {
        if category == .systemJunk && deleteResult != nil {
            return ByteCountFormatter.string(fromByteCount: deleteResult!.size, countStyle: .file) + " " + (loc.currentLanguage == .chinese ? "已清理" : "Cleaned")
        }
        return getCleaningSubText(for: category)
    }
}

// MARK: - Dashboard Card Component
struct DashboardCard: View {
    let title: String
    let mainText: String
    let subText: String
    let icon: String // SF Symbol
    let gradient: LinearGradient
    let action: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                // Header (Checkbox visually represented by Icon for now per design)
                HStack {
                     Image(systemName: "checkmark.square.fill") // Fake checkbox for aesthetic
                        .foregroundColor(.white.opacity(0.6))
                     Text(title)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                Text(mainText)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(subText)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Right Side Graphic (Glassmorphism Icon)
            VStack {
                ZStack {
                    // Glassy background for icon
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 80, height: 80)
                        .shadow(radius: 10)
                    
                    Image(systemName: icon)
                         .resizable()
                         .aspectRatio(contentMode: .fit)
                         .frame(width: 40, height: 40)
                         .foregroundColor(.white)
                }
                
                Spacer()
                
                Button("查看") { action() } // View Button
                .buttonStyle(SmallGlassButtonStyle())
            }
        }
        .padding(20)
        .frame(height: 180)
        .background(
            ZStack {
                gradient.opacity(0.3) // Tint
                Color.black.opacity(0.3) // Darken
                Rectangle().fill(.thinMaterial) // Blur
            }
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Status Pill for Scanning
struct StatusPill: View {
    let label: String
    let active: Bool
    
    var body: some View {
        Text(label)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(active ? Color.purple : Color.white.opacity(0.1))
            .cornerRadius(20)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(active ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .animation(.easeInOut, value: active)
    }
}

// MARK: - Small Glass Button
struct SmallGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// Block state for consistent rendering
enum ScanBlockState {
    case idle       // Not yet scanned
    case active     // Currently scanning/cleaning
    case completed  // Finished
}

// MARK: - Scan Block View (Fixed Size, No Flashing)
struct ScanBlockView: View {
    let category: CleanerCategory
    let isActive: Bool
    let isCompleted: Bool
    let title: String
    let resultText: String
    let subText: String
    let icon: String
    let gradient: LinearGradient
    let scanningTitle: String
    let currentPath: String
    @ObservedObject var loc: LocalizationManager
    var viewDetailsAction: (() -> Void)? = nil
    
    private var state: ScanBlockState {
        if isActive { return .active }
        if isCompleted { return .completed }
        return .idle
    }
    
    var body: some View {
        // Fixed size container - prevents layout shifts
        ZStack {
            // Background based on state
            backgroundView
            
            // Content based on state
            contentView
        }
        .frame(height: 180) // Fixed height to prevent jumping
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: state)
    }
    
    private var borderColor: Color {
        switch state {
        case .active: return Color.white.opacity(0.3)
        case .completed: return Color.white.opacity(0.1)
        case .idle: return Color.white.opacity(0.05)
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch state {
        case .active:
            // 扫描中：半透明背景 + 描边闪烁感
            ZStack {
                Color.black.opacity(0.3)
                gradient.opacity(0.15)
                
                // 动效背景装饰
                RoundedRectangle(cornerRadius: 20)
                    .fill(gradient)
                    .opacity(0.15)
                    .mask(LinearGradient(colors: [.black, .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        case .completed:
            // 完成后：经典的玻璃态 (Glassmorphism)
            ZStack {
                Color.white.opacity(0.06)
                gradient.opacity(0.12)
                LinearGradient(
                    colors: [.white.opacity(0.1), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .idle:
            // 待扫描：纯净极简
            ZStack {
                Color.black.opacity(0.15)
                Color.white.opacity(0.02)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch state {
        case .active:
            activeContent
        case .completed:
            completedContent
        case .idle:
            idleContent
        }
    }
    
    // Active state content
    private var activeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(scanningTitle)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
            
            // Icon with glow
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color.white.opacity(0.25), Color.clear], center: .center, startRadius: 20, endRadius: 60))
                        .frame(width: 100, height: 100)
                    
                    RoundedRectangle(cornerRadius: 18)
                        .fill(gradient)
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(45))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                                .rotationEffect(.degrees(45))
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 8)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            
            Spacer()
            
            Text(currentPath)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(16)
    }
    
    // Completed state content
    private var completedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                // “查看详情”入口
                if let action = viewDetailsAction {
                    Button(action: action) {
                        HStack(spacing: 2) {
                            Text(loc.currentLanguage == .chinese ? "查看详情" : "Details")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(resultText)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(subText)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(gradient.opacity(0.5))
                        .frame(width: 45, height: 45)
                        .rotationEffect(.degrees(45))
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            Spacer()
        }
        .padding(14)
    }
    
    // Idle state content
    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            
            Spacer()
            
            // Faded icon
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(gradient.opacity(0.25))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()
            }
            
            Spacer()
        }
        .padding(14)
    }
}

// MARK: - Cleaning Block View
struct CleaningBlockView: View {
    let title: String
    let resultText: String
    let subText: String
    let icon: String
    let gradient: LinearGradient
    let cleaningTitle: String
    let isActive: Bool
    let isCompleted: Bool
    let currentPath: String
    @ObservedObject var loc: LocalizationManager
    var viewDetailsAction: (() -> Void)? = nil
    
    // Action for "View Details" button
    
    var body: some View {
        ZStack {
            // Background
            ZStack {
                if isActive {
                    gradient.opacity(0.8)
                } else if isCompleted {
                    Color.white.opacity(0.06)
                    gradient.opacity(0.1)
                } else {
                    Color.black.opacity(0.15)
                    Color.white.opacity(0.02)
                }
                
                // 玻璃高光
                LinearGradient(
                    colors: [.white.opacity(0.1), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // Content
            if isActive {
                // Active cleaning
                VStack(alignment: .leading, spacing: 8) {
                    Text(cleaningTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(RadialGradient(colors: [Color.white.opacity(0.25), Color.clear], center: .center, startRadius: 20, endRadius: 50))
                                .frame(width: 80, height: 80)
                            
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Spacer()
                    }
                    
                    Spacer()
                    
                    Text(currentPath)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(14)
            } else if isCompleted {
                // Completed
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        if let action = viewDetailsAction {
                            Button(action: action) {
                                HStack(spacing: 2) {
                                    Text(loc.currentLanguage == .chinese ? "查看详情" : "Details")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(resultText)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            
                            Text(subText)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(gradient.opacity(0.5))
                                .frame(width: 45, height: 45)
                                .rotationEffect(.degrees(45))
                            
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    
                    Spacer()
                }
                .padding(12)
            } else {
                // Idle
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(gradient.opacity(0.2))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        Spacer()
                    }
                    
                    Spacer()
                }
                .padding(12)
            }
        }
        .frame(height: 180)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isActive ? Color.white.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .animation(.easeInOut(duration: 0.3), value: isCompleted)
    }
}

// MARK: - Result Block View (for completed scan results)
struct ResultBlockView: View {
    let title: String
    let resultText: String
    let subText: String
    let icon: String
    let gradient: LinearGradient
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // 玻璃态背景
                ZStack {
                    Color.white.opacity(0.06)
                    gradient.opacity(0.08)
                    LinearGradient(
                        colors: [.white.opacity(0.1), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(gradient.opacity(0.6))
                                .frame(width: 55, height: 55)
                                .rotationEffect(.degrees(45))
                            
                            Image(systemName: icon)
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    
                    Spacer()
                    
                    Text(resultText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(subText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(14)
            }
            .frame(height: 180)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Finished Block View (all blocks completed)
struct FinishedBlockView: View {
    let title: String
    let resultText: String
    let icon: String
    let gradient: LinearGradient
    var viewDetailsAction: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            // 玻璃态背景
            ZStack {
                Color.white.opacity(0.06)
                gradient.opacity(0.05)
                LinearGradient(
                    colors: [.white.opacity(0.08), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    // “查看详情”入口 (可选)
                    if let action = viewDetailsAction {
                        Button(action: action) {
                            HStack(spacing: 2) {
                                let lang = LocalizationManager.shared.currentLanguage
                                Text(lang == .chinese ? "查看详情" : "Details")
                                Image(systemName: "chevron.right")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                HStack(alignment: .bottom) {
                    Text(resultText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(gradient.opacity(0.5))
                            .frame(width: 45, height: 45)
                            .rotationEffect(.degrees(45))
                        
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(14)
        }
        .frame(height: 180)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// 扫过光效动画
struct WipingAnimation: ViewModifier {
    @State private var offset: CGFloat = -300
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                withAnimation(Animation.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    offset = 400
                }
            }
    }
}
