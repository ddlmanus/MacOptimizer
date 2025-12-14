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
    // 使用共享的服务管理器，切换视图时扫描状态不会丢失
    @ObservedObject private var service = ScanServiceManager.shared.smartCleanerService
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var selectedCategory: CleanerCategory = .systemJunk
    @State private var showDeleteConfirmation = false
    @State private var deleteResult: (success: Int, failed: Int, size: Int64)?
    @State private var showResult = false
    @State private var showCleaningFinished = false
    
    // 管理员权限重试
    @State private var failedFiles: [CleanerFileItem] = []
    @State private var showRetryWithAdmin = false
    
    // View State
    @State private var showDetailSheet = false
    @State private var initialDetailCategory: CleanerCategory? = nil
    
    // 扫描状态
    private var scanState: ScanState {
        if service.isScanning {
            return .scanning
        } else if service.isCleaning {
            return .cleaning
        } else if showRetryWithAdmin {
            return .cleaning // 弹窗时保持清理页面
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
               !service.systemCacheFiles.isEmpty
    }

    // 计算扫描到的总大小
    // 注意：只计算顶级类别，避免重复计算
    // systemJunk 已经包含了 systemCache, oldUpdates, userCache, languageFiles, systemLogs, userLogs, brokenLoginItems
    private var totalScannedSize: Int64 {
        // 只计算顶级类别，不包括 systemJunk 的子类别
        let topLevelCategories: [CleanerCategory] = [
            .systemJunk, .duplicates, .similarPhotos, .localizations, .largeFiles
        ]
        return topLevelCategories.reduce(0) { $0 + service.sizeFor(category: $1) }
    }
    
    var body: some View {
        ZStack {
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
        // 使用 sheet 弹窗显示详情
        .sheet(isPresented: $showDetailSheet) {
            AllCategoriesDetailSheet(
                service: service,
                loc: loc,
                isPresented: $showDetailSheet,
                initialCategory: initialDetailCategory
            )
        }
        .confirmationDialog(
            loc.currentLanguage == .chinese ? "确认删除" : "Confirm Delete",
            isPresented: $showDeleteConfirmation
        ) {
            Button(loc.currentLanguage == .chinese ? "开始清理" : "Start Cleaning", role: .destructive) {
                Task {
                    // Start cleaning
                    let result = await service.cleanAll()
                    deleteResult = (result.success, result.failed, result.size)
                    failedFiles = result.failedFiles
                    
                    if result.failed > 0 && !failedFiles.isEmpty {
                        // 有失败的文件，询问是否使用管理员权限
                        showRetryWithAdmin = true
                    } else {
                        // 清理完成，显示最终结果页
                        showCleaningFinished = true
                    }
                }
            }
            Button(loc.L("cancel"), role: .cancel) {}
        } message: {
            Text(loc.currentLanguage == .chinese ?
                 "将清理所有选中的垃圾文件，释放空间。" :
                 "Clean all selected files to free up space.")
        }
        // 询问是否使用管理员权限重试
        .alert(loc.currentLanguage == .chinese ? "部分文件需要管理员权限" : "Some Files Require Admin Privileges", isPresented: $showRetryWithAdmin) {
            Button(loc.currentLanguage == .chinese ? "使用管理员权限删除" : "Delete with Admin", role: .destructive) {
                Task {
                    let adminResult = await service.cleanWithPrivileges(files: failedFiles)
                    // 合并结果
                    if let currentResult = deleteResult {
                        deleteResult = (
                            currentResult.success + adminResult.success,
                            adminResult.failed,  // 更新失败数
                            currentResult.size + adminResult.size
                        )
                    }
                    failedFiles = []
                    
                    // 管理员清理也完成后，显示最终结果页
                    showCleaningFinished = true
                }
            }
            Button(loc.L("cancel"), role: .cancel) {
                // 用户取消管理员权限，也显示最终结果
                showCleaningFinished = true
            }
        } message: {
            let totalFailedSize = failedFiles.reduce(0) { $0 + $1.size }
            Text(loc.currentLanguage == .chinese ?
                 "有 \(failedFiles.count) 个文件（共 \(ByteCountFormatter.string(fromByteCount: totalFailedSize, countStyle: .file))）因权限不足无法删除。\n\n是否使用管理员权限强制删除？系统将提示您输入密码。" :
                 "\(failedFiles.count) files (\(ByteCountFormatter.string(fromByteCount: totalFailedSize, countStyle: .file))) could not be deleted due to permissions.\n\nWould you like to delete them with admin privileges? You will be prompted for your password.")
        }
        // 清理完成结果
        .alert(loc.currentLanguage == .chinese ? "清理完成" : "Cleanup Complete", isPresented: $showResult) {
            Button(loc.L("confirm"), role: .cancel) {}
        } message: {
            if let result = deleteResult {
                if result.failed > 0 {
                    Text(loc.currentLanguage == .chinese ?
                         "成功删除 \(result.success) 个文件，释放 \(ByteCountFormatter.string(fromByteCount: result.size, countStyle: .file))\n\n⚠️ \(result.failed) 个文件仍无法删除。" :
                         "Deleted \(result.success) files, freed \(ByteCountFormatter.string(fromByteCount: result.size, countStyle: .file))\n\n⚠️ \(result.failed) files could not be deleted.")
                } else {
                    Text(loc.currentLanguage == .chinese ?
                         "成功删除 \(result.success) 个文件，释放 \(ByteCountFormatter.string(fromByteCount: result.size, countStyle: .file))" :
                         "Deleted \(result.success) files, freed \(ByteCountFormatter.string(fromByteCount: result.size, countStyle: .file))")
                }
            }
        }
    }
    
    // MARK: - 初始页面
    private var initialPage: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // 图标
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 180, height: 180)
                
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 80))
                    .foregroundColor(.cyan)
            }
            .padding(.bottom, 40)
            
            // 欢迎文字
            Text(loc.currentLanguage == .chinese ? "欢迎使用 Mac优化大师" : "Welcome to MacOptimizer")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 12)
            
            Text(loc.currentLanguage == .chinese ? "开始全面、仔细扫描您的 Mac。" : "Start a comprehensive scan of your Mac.")
                .font(.body)
                .foregroundColor(.secondaryText)
                .padding(.bottom, 60)
            
            Spacer()
            
            // 扫描按钮
            CircularActionButton(
                title: loc.currentLanguage == .chinese ? "扫描" : "Scan",
                gradient: CircularActionButton.blueGradient,
                action: {
                    Task {
                        await service.scanAll()
                    }
                }
            )
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - 扫描中页面
    private var scanningPage: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(loc.currentLanguage == .chinese ? "智能扫描" : "Smart Scan")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding(.top, 20)
            
            Spacer()
            
            // 进度标题
            Text(loc.currentLanguage == .chinese ? "正在扫描..." : "Scanning...")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 40)
            
            // 真实扫描任务列表
            VStack(alignment: .leading, spacing: 20) {
                // 定义显示顺序
                let categories: [CleanerCategory] = [.systemJunk, .duplicates, .similarPhotos, .localizations, .largeFiles]
                
                ForEach(categories, id: \.self) { category in
                    CleaningTaskRow(
                        icon: category.icon,
                        color: category.color,
                        title: loc.currentLanguage == .chinese ? category.rawValue : category.englishName,
                        status: getScanningStatus(for: category),
                        fileSize: ByteCountFormatter.string(fromByteCount: service.sizeFor(category: category), countStyle: .file)
                    )
                }
            }
            .frame(maxWidth: 400)
            
            Spacer()
            
            // 停止按钮
            HStack(spacing: 20) {
                CircularActionButton(
                    title: loc.currentLanguage == .chinese ? "停止" : "Stop",
                    gradient: CircularActionButton.stopGradient,
                    progress: service.scanProgress,
                    showProgress: true,
                    scanSize: ByteCountFormatter.string(fromByteCount: totalScannedSize, countStyle: .file),
                    action: {
                        service.stopScanning()
                    }
                )
            }
            .padding(.bottom, 40)
            
            // 当前扫描路径
            Text(service.currentScanPath)
                .font(.caption)
                .foregroundColor(.secondaryText.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
        }
    }
    
    // MARK: - 扫描结果页面
    private var resultsPage: some View {
        VStack(spacing: 0) {
            // ... (保持不变)
            // 标题栏
            HStack {
                Button(action: {
                    Task {
                        await service.resetAll()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(loc.currentLanguage == .chinese ? "重新开始" : "Start Over")
                    }
                    .foregroundColor(.secondaryText)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(loc.currentLanguage == .chinese ? "智能扫描" : "Smart Scan")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Spacer()
                
                // 重新扫描按钮
                Button(action: {
                    Task {
                        await service.resetAll()
                        await service.scanAll()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text(loc.currentLanguage == .chinese ? "重新扫描" : "Rescan")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            // 结果标题
            Text(loc.currentLanguage == .chinese ? "好了，我发现的内容都在这里。" : "Done! Here's what I found.")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 8)
            
            Text(loc.currentLanguage == .chinese ? "保持您的 Mac 干净、安全、性能优化的所有任务正在等候，立即运行！" : "All tasks to keep your Mac clean, safe, and optimized are ready!")
                .font(.body)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
                .padding(.bottom, 40)
            
            // 结果概览 (可以优化为显示有问题的项目列表，或保持卡片)
            // 这里保持卡片设计，因为结果页需要概览，不需要太详细
            HStack(spacing: 40) {
                // 清理
                ResultCategoryCard(
                    icon: "internaldrive.fill",
                    iconColor: .blue,
                    title: loc.currentLanguage == .chinese ? "清理" : "Cleanup",
                    subtitle: loc.currentLanguage == .chinese ? "移除不需要的垃圾" : "Remove junk",
                    value: ByteCountFormatter.string(fromByteCount: service.systemJunkTotalSize + service.totalCleanableSize, countStyle: .file),
                    hasDetails: true,
                    onDetailTap: {
                        initialDetailCategory = nil
                        showDetailSheet = true
                    }
                )
                
                // 保护 (Placeholder)
                ResultCategoryCard(
                    icon: "hand.raised.fill",
                    iconColor: .green,
                    title: loc.currentLanguage == .chinese ? "保护" : "Protection",
                    subtitle: loc.currentLanguage == .chinese ? "消除潜在威胁" : "Eliminate threats",
                    value: loc.currentLanguage == .chinese ? "好" : "Good",
                    valueSecondary: loc.currentLanguage == .chinese ? "没有找到威胁" : "No threats found",
                    hasDetails: false,
                    onDetailTap: {}
                )
                
                // 速度 (Placeholder)
                ResultCategoryCard(
                    icon: "gauge.high",
                    iconColor: .pink,
                    title: loc.currentLanguage == .chinese ? "速度" : "Speed",
                    subtitle: loc.currentLanguage == .chinese ? "提升系统性能" : "Boost performance",
                    value: "2",
                    valueSecondary: loc.currentLanguage == .chinese ? "个任务可运行" : "tasks available",
                    hasDetails: false,
                    onDetailTap: {}
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // 运行按钮
            CircularActionButton(
                title: loc.currentLanguage == .chinese ? "清理" : "Cleanup",
                gradient: CircularActionButton.greenGradient,
                action: {
                    showDeleteConfirmation = true
                }
            )
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - 清理中页面
    private var cleaningPage: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(loc.currentLanguage == .chinese ? "智能扫描" : "Smart Scan")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Spacer()
                
                // 助手按钮 (占位)
                HStack(spacing: 4) {
                    Circle().fill(Color.gray).frame(width: 6, height: 6)
                    Text(loc.currentLanguage == .chinese ? "助手" : "Assistant")
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            // 状态标题
            Text(loc.currentLanguage == .chinese ? "正在清理系统..." : "Cleaning System...")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 40)
            
            // 真实清理任务列表 (只显示有需要清理的项)
            VStack(alignment: .leading, spacing: 20) {
                // 计算需要清理的类别列表
                let categoriesToClean: [CleanerCategory] = {
                    let all: [CleanerCategory] = [.systemJunk, .duplicates, .similarPhotos, .localizations, .largeFiles]
                    return all.filter { service.sizeFor(category: $0) > 0 }
                }()
                
                if categoriesToClean.isEmpty {
                    // 如果都为空但还在清理中，显示“准备中...”
                    Text("Preparing...")
                        .foregroundColor(.secondaryText)
                } else {
                    ForEach(categoriesToClean, id: \.self) { category in
                        CleaningTaskRow(
                            icon: category.icon,
                            color: category.color,
                            title: loc.currentLanguage == .chinese ? category.rawValue : category.englishName,
                            status: getCleaningStatus(for: category),
                            fileSize: ByteCountFormatter.string(fromByteCount: service.sizeFor(category: category), countStyle: .file)
                        )
                    }
                }
            }
            .frame(maxWidth: 400)
            
            Spacer()
            
            // 停止按钮 (禁用或占位)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                if service.isCleaning {
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(Double(Date().timeIntervalSince1970 * 360).remainder(dividingBy: 360))) // 简单动画需要state驱动，这里简化
                        .rotationEffect(.degrees(-90))
                }
                
                Button(action: {}) {
                    Text(loc.currentLanguage == .chinese ? "清理中" : "Cleaning")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(true)
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - 清理完成页面
    private var cleaningFinishedPage: some View {
        VStack(spacing: 0) {
            // 顶部导航
            HStack {
                Button(action: {
                    // 返回初始状态
                    Task {
                        await service.resetAll()
                        showCleaningFinished = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(loc.currentLanguage == .chinese ? "重新开始" : "Start Over")
                    }
                    .foregroundColor(.secondaryText)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(loc.currentLanguage == .chinese ? "智能扫描" : "Smart Scan")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Spacer()
                
                // 占位，保持平衡
                HStack(spacing: 4) {
                    Text("     ")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            // 电脑图标 (粉色风格，匹配截图)
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.pink.opacity(0.8))
                    .frame(width: 240, height: 160)
                    .shadow(color: .pink.opacity(0.3), radius: 20, x: 0, y: 10)
                
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.bottom, 40)
            
            // 结果标题
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.currentLanguage == .chinese ? "做得不错！" : "Well Done!")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text(loc.currentLanguage == .chinese ? "您的 Mac 状态很好。" : "Your Mac is in good shape.")
                        .font(.body)
                        .foregroundColor(.secondaryText)
                }
                
                // 结果统计栏
                VStack(alignment: .leading, spacing: 20) {
                    // 已清理大小
                    HStack(spacing: 12) {
                        Image(systemName: "externaldrive.fill") // 硬盘图标
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.blue)
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(ByteCountFormatter.string(fromByteCount: (deleteResult?.size ?? 0), countStyle: .file))
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            Text(loc.currentLanguage == .chinese ? "不需要的垃圾已移除" : "Junk removed")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                    
                    // 深度扫描建议
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill") // 盾牌图标
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.green)
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(loc.currentLanguage == .chinese ? "建议执行深度扫描" : "Deep Scan Recommended")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            Text(loc.currentLanguage == .chinese ? "未发现恶意威胁，但是强烈建议执行深度扫描。" : "No threats found, but deep scan recommended.")
                                .font(.caption2)
                                .foregroundColor(.secondaryText)
                                .lineLimit(2)
                            
                            Button(action: {}) {
                                Text(loc.currentLanguage == .chinese ? "运行深度扫描" : "Run Deep Scan")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                    }
                    
                    // 性能任务
                    HStack(spacing: 12) {
                        Image(systemName: "gauge.high") // 速度图标
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.pink)
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(loc.currentLanguage == .chinese ? "2 个任务" : "2 Tasks")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            Text(loc.currentLanguage == .chinese ? "Mac 的性能能达到极致" : "Mac performance optimized")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }

    
    // MARK: - Helper Functions
    private func getCleaningStatus(for category: CleanerCategory) -> CleaningTaskRow.Status {
        if service.cleanedCategories.contains(category) {
            return .completed
        } else if service.cleaningCurrentCategory == category {
            return .processing
        } else {
            return .waiting
        }
    }
    
    private func getScanningStatus(for category: CleanerCategory) -> CleaningTaskRow.Status {
        let isCurrent = service.currentCategory == category
        // 简单判断完成状态：如果当前正在扫描的类别在列表中位于此类别之后，则认为此类别已完成
        // 注意：这依赖于 scanAll 的执行顺序：SystemJunk -> Duplicates -> Similar -> Localizations -> Large
        let isCompleted = !isCurrent && (
            (category == .systemJunk && [.duplicates, .similarPhotos, .localizations, .largeFiles].contains(service.currentCategory)) ||
            (category == .duplicates && [.similarPhotos, .localizations, .largeFiles].contains(service.currentCategory)) ||
            (category == .similarPhotos && [.localizations, .largeFiles].contains(service.currentCategory)) ||
            (category == .localizations && [.largeFiles].contains(service.currentCategory))
        )
        
        if isCurrent { return .processing }
        if isCompleted { return .completed }
        return .waiting
    }
}

// MARK: - 清理任务行组件
struct CleaningTaskRow: View {
    let icon: String
    let color: Color
    let title: String
    enum Status { case waiting, processing, completed }
    let status: Status
    let fileSize: String?
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(color).frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            }
            
            Text(title)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
            
            if let size = fileSize {
                Text(size)
                    .foregroundColor(.secondaryText)
                    .font(.body)
                    .frame(width: 90, alignment: .trailing)
            }
            
            ZStack {
                switch status {
                case .waiting:
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondaryText)
                case .processing:
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                case .completed:
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .frame(width: 24, height: 24)
        }
        .padding(.horizontal, 16)
        .frame(height: 56) // Fixed height to prevent jitter
    }
}

// MARK: - 扫描中卡片组件
struct ScanCategoryCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let value: String
    let isScanning: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(iconColor)
            }
            
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.title3)
                .foregroundColor(.secondaryText)
        }
        .frame(width: 180)
    }
}

// MARK: - 结果卡片组件
struct ResultCategoryCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let value: String
    var valueSecondary: String? = nil
    let hasDetails: Bool
    let onDetailTap: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(iconColor)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
            
            if let secondary = valueSecondary {
                VStack(spacing: 4) {
                    Text(value)
                        .font(.title)
                        .foregroundColor(.white)
                    Text(secondary)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            } else {
                Text(value)
                    .font(.title)
                    .foregroundColor(.white)
            }
            
            if hasDetails {
                Button(action: onDetailTap) {
                    Text("查看详情...")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 180)
    }
}

// MARK: - 系统垃圾详情弹窗 (支持二级钻取)
struct SystemJunkDetailSheet: View {
    @ObservedObject var service: SmartCleanerService
    @ObservedObject var loc: LocalizationManager
    @Binding var isPresented: Bool
    
    @State private var selectedSubcategory: CleanerCategory? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            HStack {
                Button(action: {
                    if selectedSubcategory != nil {
                        selectedSubcategory = nil
                    } else {
                        isPresented = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(selectedSubcategory != nil ? 
                             (loc.currentLanguage == .chinese ? "返回分类" : "Back") :
                             (loc.currentLanguage == .chinese ? "返回摘要" : "Back"))
                    }
                    .foregroundColor(.secondaryText)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(loc.currentLanguage == .chinese ? "清理详情" : "Cleanup Details")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 4) { Image(systemName: "chevron.left"); Text("Back") }.opacity(0)
            }
            .padding()
            .background(Color.black.opacity(0.3))
            
            if let subcategory = selectedSubcategory {
                // 显示该分类下的具体文件列表
                SubcategoryFileListView(
                    service: service,
                    loc: loc,
                    category: subcategory
                )
            } else {
                // 显示分类概览
                categoryOverviewContent
            }
        }
        .frame(minWidth: 900, minHeight: 650)
        .background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.08, blue: 0.22), Color(red: 0.08, green: 0.12, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private var categoryOverviewContent: some View {
        HStack(spacing: 0) {
            // 左侧分类列表
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button(loc.currentLanguage == .chinese ? "取消全选" : "Deselect All") {}
                    .buttonStyle(.plain)
                    .foregroundColor(.secondaryText)
                    .font(.caption)
                    Spacer()
                    Text(loc.currentLanguage == .chinese ? "排序方式按 大小" : "Sort by Size")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                
                SystemJunkCategoryRow(icon: "trash.fill", title: loc.currentLanguage == .chinese ? "系统垃圾" : "System Junk", size: service.systemJunkTotalSize, isSelected: true, color: .pink)
                    .padding(.horizontal)
                
                Spacer()
            }
            .frame(width: 260)
            .background(Color.black.opacity(0.2))
            
            // 右侧详情区域
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.currentLanguage == .chinese ? "系统垃圾" : "System Junk")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    Text(loc.currentLanguage == .chinese ? "清理您的系统来获得最大的性能和释放自由空间。" : "Clean your system for best performance and free space.")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
                .padding()
                
                HStack {
                    Spacer()
                    Text(loc.currentLanguage == .chinese ? "排序方式按 大小" : "Sort by Size")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                ScrollView {
                    VStack(spacing: 12) {
                        // 用户缓存
                        DrillDownCategoryRow(
                            icon: "person.crop.circle.fill",
                            title: loc.currentLanguage == .chinese ? "用户缓存文件" : "User Cache",
                            size: service.sizeFor(category: .userCache),
                            count: service.countFor(category: .userCache),
                            color: .cyan,
                            onTap: { selectedSubcategory = .userCache }
                        )
                        
                        // 系统缓存
                        DrillDownCategoryRow(
                            icon: "internaldrive.fill",
                            title: loc.currentLanguage == .chinese ? "系统缓存文件" : "System Cache",
                            size: service.sizeFor(category: .systemCache),
                            count: service.countFor(category: .systemCache),
                            color: .blue,
                            onTap: { selectedSubcategory = .systemCache }
                        )
                        
                        // 旧更新
                        DrillDownCategoryRow(
                            icon: "arrow.down.circle.fill",
                            title: loc.currentLanguage == .chinese ? "旧更新" : "Old Updates",
                            size: service.sizeFor(category: .oldUpdates),
                            count: service.countFor(category: .oldUpdates),
                            color: .orange,
                            onTap: { selectedSubcategory = .oldUpdates }
                        )
                        
                        // 语言文件
                        DrillDownCategoryRow(
                            icon: "textformat.abc",
                            title: loc.currentLanguage == .chinese ? "语言文件" : "Language Files",
                            size: service.sizeFor(category: .languageFiles),
                            count: service.countFor(category: .languageFiles),
                            color: .purple,
                            onTap: { selectedSubcategory = .languageFiles }
                        )
                        
                        // 系统日志
                        DrillDownCategoryRow(
                            icon: "doc.text.fill",
                            title: loc.currentLanguage == .chinese ? "系统日志文件" : "System Logs",
                            size: service.sizeFor(category: .systemLogs),
                            count: service.countFor(category: .systemLogs),
                            color: .green,
                            onTap: { selectedSubcategory = .systemLogs }
                        )
                        
                        // 用户日志
                        DrillDownCategoryRow(
                            icon: "person.text.rectangle.fill",
                            title: loc.currentLanguage == .chinese ? "用户日志文件" : "User Logs",
                            size: service.sizeFor(category: .userLogs),
                            count: service.countFor(category: .userLogs),
                            color: .teal,
                            onTap: { selectedSubcategory = .userLogs }
                        )
                        
                        // 损坏的登录项
                        DrillDownCategoryRow(
                            icon: "exclamationmark.triangle.fill",
                            title: loc.currentLanguage == .chinese ? "损坏的登录项" : "Broken Login Items",
                            size: service.sizeFor(category: .brokenLoginItems),
                            count: service.countFor(category: .brokenLoginItems),
                            color: .red,
                            onTap: { selectedSubcategory = .brokenLoginItems }
                        )
                    }
                    .padding()
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 子分类文件列表视图
struct SubcategoryFileListView: View {
    @ObservedObject var service: SmartCleanerService
    @ObservedObject var loc: LocalizationManager
    let category: CleanerCategory
    
    var files: [CleanerFileItem] {
        switch category {
        case .userCache: return service.userCacheFiles
        case .systemCache: return service.systemCacheFiles
        case .oldUpdates: return service.oldUpdateFiles
        case .languageFiles: return service.languageFiles
        case .systemLogs: return service.systemLogFiles
        case .userLogs: return service.userLogFiles
        case .brokenLoginItems: return service.brokenLoginItems
        case .duplicates: return service.duplicateGroups.flatMap { $0.files }
        case .similarPhotos: return service.similarPhotoGroups.flatMap { $0.files }
        case .largeFiles: return service.largeFiles
        case .localizations: return service.localizationFiles
        default: return []
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            VStack(alignment: .leading, spacing: 8) {
                Text(loc.currentLanguage == .chinese ? category.rawValue : category.englishName)
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                
                Text("\(files.count) 个项目，共 \(ByteCountFormatter.string(fromByteCount: files.reduce(0) { $0 + $1.size }, countStyle: .file))")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            .padding()
            
            // 文件列表
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(files.sorted { $0.size > $1.size }, id: \.url) { file in
                        FileItemRow(file: file, showPath: true)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - 文件项行
struct FileItemRow: View {
    let file: CleanerFileItem
    let showPath: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 20))
            
            Image(nsImage: file.icon)
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if showPath {
                    Text(file.url.deletingLastPathComponent().path)
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryText)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(file.formattedSize)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - 可点击的分类行（带钻取）
struct DrillDownCategoryRow: View {
    let icon: String
    let title: String
    let size: Int64
    let count: Int
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 22))
                
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    if count > 0 {
                        Text("\(count) 个文件")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondaryText)
                    .font(.system(size: 14))
                
                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 90, alignment: .trailing)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 系统垃圾卡片组件
struct SystemJunkCard: View {
    let title: String
    let size: Int64
    let itemCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.pink.opacity(0.2))
                        .frame(width: 56, height: 56)
                    Image(systemName: "trash.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.pink)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Text("\(itemCount) 个项目")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondaryText)
            }
            .padding(16)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 小型结果卡片
struct MiniResultCard: View {
    let icon: String
    let title: String
    let size: Int64
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
            }
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondaryText)
            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - 可点击的小型结果卡片
struct ClickableMiniCard: View {
    let icon: String
    let title: String
    let size: Int64
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondaryText)
                }
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 全分类详情弹窗
struct AllCategoriesDetailSheet: View {
    @ObservedObject var service: SmartCleanerService
    @ObservedObject var loc: LocalizationManager
    @Binding var isPresented: Bool
    var initialCategory: CleanerCategory?
    
    @State private var selectedMainCategory: CleanerCategory? = nil
    @State private var selectedSubcategory: CleanerCategory? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            HStack {
                Button(action: {
                    isPresented = false
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(loc.currentLanguage == .chinese ? "返回摘要" : "Back")
                    }
                    .foregroundColor(.secondaryText)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(loc.currentLanguage == .chinese ? "清理详情" : "Cleanup Details")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 4) { Image(systemName: "chevron.left"); Text("Back") }.opacity(0)
            }
            .padding()
            .background(Color.black.opacity(0.3))
            
            // 直接使用左右布局
            allCategoriesOverview
        }
        .frame(width: 900, height: 650)
        .background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.08, blue: 0.22), Color(red: 0.08, green: 0.12, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            if let initial = initialCategory {
                if initial == .systemJunk {
                    selectedMainCategory = .systemJunk
                } else if [.userCache, .systemCache, .oldUpdates, .languageFiles, .systemLogs, .userLogs, .brokenLoginItems].contains(initial) {
                    selectedMainCategory = .systemJunk
                    selectedSubcategory = initial
                } else {
                    selectedMainCategory = initial
                }
            }
        }
    }
    
    // 所有主分类概览 - 左右布局
    private var allCategoriesOverview: some View {
        HStack(spacing: 0) {
            // 左侧分类列表
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(loc.currentLanguage == .chinese ? "扫描结果" : "Scan Results")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 8) {
                        // 系统垃圾
                        MainCategoryRow(
                            icon: "trash.fill",
                            title: loc.currentLanguage == .chinese ? "系统垃圾" : "System Junk",
                            size: service.systemJunkTotalSize,
                            count: service.countFor(category: .systemJunk),
                            color: .pink,
                            isSelected: selectedMainCategory == .systemJunk,
                            onTap: { selectedMainCategory = .systemJunk; selectedSubcategory = nil }
                        )
                        
                        // 重复文件
                        MainCategoryRow(
                            icon: "doc.on.doc",
                            title: loc.currentLanguage == .chinese ? "重复文件" : "Duplicates",
                            size: service.sizeFor(category: .duplicates),
                            count: service.duplicateGroups.flatMap { $0.files }.count,
                            color: .blue,
                            isSelected: selectedMainCategory == .duplicates,
                            onTap: { selectedMainCategory = .duplicates; selectedSubcategory = nil }
                        )
                        
                        // 相似照片
                        MainCategoryRow(
                            icon: "photo.on.rectangle",
                            title: loc.currentLanguage == .chinese ? "相似照片" : "Similar Photos",
                            size: service.sizeFor(category: .similarPhotos),
                            count: service.similarPhotoGroups.flatMap { $0.files }.count,
                            color: .purple,
                            isSelected: selectedMainCategory == .similarPhotos,
                            onTap: { selectedMainCategory = .similarPhotos; selectedSubcategory = nil }
                        )
                        
                        // 大文件
                        MainCategoryRow(
                            icon: "externaldrive.fill",
                            title: loc.currentLanguage == .chinese ? "大文件" : "Large Files",
                            size: service.sizeFor(category: .largeFiles),
                            count: service.largeFiles.count,
                            color: .orange,
                            isSelected: selectedMainCategory == .largeFiles,
                            onTap: { selectedMainCategory = .largeFiles; selectedSubcategory = nil }
                        )
                    }
                    .padding()
                }
                
                Spacer()
            }
            .frame(width: 280)
            .background(Color.black.opacity(0.2))
            
            // 右侧详情区域 - 根据选择的分类显示内容
            if let mainCategory = selectedMainCategory {
                if mainCategory == .systemJunk {
                    // 系统垃圾 - 显示子分类列表
                    systemJunkRightPane
                } else {
                    // 其他分类 - 直接显示文件列表
                    rightPaneFileList(for: mainCategory)
                }
            } else {
                // 未选择时显示提示
                VStack {
                    Spacer()
                    Image(systemName: "arrow.left")
                        .font(.system(size: 48))
                        .foregroundColor(.secondaryText.opacity(0.5))
                    Text(loc.currentLanguage == .chinese ? "选择左侧分类查看详情" : "Select a category to view details")
                        .font(.title3)
                        .foregroundColor(.secondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // 系统垃圾右侧面板 - 显示子分类或具体文件
    private var systemJunkRightPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            VStack(alignment: .leading, spacing: 8) {
                Text(loc.currentLanguage == .chinese ? "系统垃圾" : "System Junk")
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                Text(loc.currentLanguage == .chinese ? "清理您的系统来获得最大的性能和释放自由空间。" : "Clean your system for best performance and free space.")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            .padding()
            
            if let subcategory = selectedSubcategory {
                // 显示该子分类的文件列表
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: { selectedSubcategory = nil }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(loc.currentLanguage == .chinese ? "返回子分类" : "Back")
                        }
                        .foregroundColor(.blue)
                        .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    
                    Text(loc.currentLanguage == .chinese ? subcategory.rawValue : subcategory.englishName)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                }
                
                // 文件列表
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filesFor(category: subcategory).sorted { $0.size > $1.size }, id: \.url) { file in
                            FileItemRow(file: file, showPath: true)
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                // 显示子分类列表
                ScrollView {
                    VStack(spacing: 12) {
                        DrillDownCategoryRow(icon: "person.crop.circle.fill", title: loc.currentLanguage == .chinese ? "用户缓存文件" : "User Cache", size: service.sizeFor(category: .userCache), count: service.countFor(category: .userCache), color: .cyan, onTap: { selectedSubcategory = .userCache })
                        DrillDownCategoryRow(icon: "internaldrive.fill", title: loc.currentLanguage == .chinese ? "系统缓存文件" : "System Cache", size: service.sizeFor(category: .systemCache), count: service.countFor(category: .systemCache), color: .blue, onTap: { selectedSubcategory = .systemCache })
                        DrillDownCategoryRow(icon: "arrow.down.circle.fill", title: loc.currentLanguage == .chinese ? "旧更新" : "Old Updates", size: service.sizeFor(category: .oldUpdates), count: service.countFor(category: .oldUpdates), color: .orange, onTap: { selectedSubcategory = .oldUpdates })
                        DrillDownCategoryRow(icon: "textformat.abc", title: loc.currentLanguage == .chinese ? "语言文件" : "Language Files", size: service.sizeFor(category: .languageFiles), count: service.countFor(category: .languageFiles), color: .purple, onTap: { selectedSubcategory = .languageFiles })
                        DrillDownCategoryRow(icon: "doc.text.fill", title: loc.currentLanguage == .chinese ? "系统日志文件" : "System Logs", size: service.sizeFor(category: .systemLogs), count: service.countFor(category: .systemLogs), color: .green, onTap: { selectedSubcategory = .systemLogs })
                        DrillDownCategoryRow(icon: "person.text.rectangle.fill", title: loc.currentLanguage == .chinese ? "用户日志文件" : "User Logs", size: service.sizeFor(category: .userLogs), count: service.countFor(category: .userLogs), color: .teal, onTap: { selectedSubcategory = .userLogs })
                        DrillDownCategoryRow(icon: "exclamationmark.triangle.fill", title: loc.currentLanguage == .chinese ? "损坏的登录项" : "Broken Login Items", size: service.sizeFor(category: .brokenLoginItems), count: service.countFor(category: .brokenLoginItems), color: .red, onTap: { selectedSubcategory = .brokenLoginItems })
                    }
                    .padding()
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // 右侧文件列表面板
    private func rightPaneFileList(for category: CleanerCategory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            VStack(alignment: .leading, spacing: 8) {
                Text(loc.currentLanguage == .chinese ? category.rawValue : category.englishName)
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                
                let files = filesFor(category: category)
                Text("\(files.count) 个项目，共 \(ByteCountFormatter.string(fromByteCount: files.reduce(0) { $0 + $1.size }, countStyle: .file))")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            .padding()
            
            // 文件列表
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filesFor(category: category).sorted { $0.size > $1.size }, id: \.url) { file in
                        FileItemRow(file: file, showPath: true)
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // 获取分类对应的文件列表
    private func filesFor(category: CleanerCategory) -> [CleanerFileItem] {
        switch category {
        case .userCache: return service.userCacheFiles
        case .systemCache: return service.systemCacheFiles
        case .oldUpdates: return service.oldUpdateFiles
        case .languageFiles: return service.languageFiles
        case .systemLogs: return service.systemLogFiles
        case .userLogs: return service.userLogFiles
        case .brokenLoginItems: return service.brokenLoginItems
        case .duplicates: return service.duplicateGroups.flatMap { $0.files }
        case .similarPhotos: return service.similarPhotoGroups.flatMap { $0.files }
        case .largeFiles: return service.largeFiles
        case .localizations: return service.localizationFiles
        default: return []
        }
    }
    
    // 系统垃圾子分类视图
    private var systemJunkSubcategoriesView: some View {
        HStack(spacing: 0) {
            // 左侧分类列表
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button(loc.currentLanguage == .chinese ? "取消全选" : "Deselect All") {}
                    .buttonStyle(.plain)
                    .foregroundColor(.secondaryText)
                    .font(.caption)
                    Spacer()
                    Text(loc.currentLanguage == .chinese ? "排序方式按 大小" : "Sort by Size")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                
                SystemJunkCategoryRow(icon: "trash.fill", title: loc.currentLanguage == .chinese ? "系统垃圾" : "System Junk", size: service.systemJunkTotalSize, isSelected: true, color: .pink)
                    .padding(.horizontal)
                
                Spacer()
            }
            .frame(width: 260)
            .background(Color.black.opacity(0.2))
            
            // 右侧子分类列表
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.currentLanguage == .chinese ? "系统垃圾" : "System Junk")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    Text(loc.currentLanguage == .chinese ? "清理您的系统来获得最大的性能和释放自由空间。" : "Clean your system for best performance and free space.")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 12) {
                        DrillDownCategoryRow(icon: "person.crop.circle.fill", title: loc.currentLanguage == .chinese ? "用户缓存文件" : "User Cache", size: service.sizeFor(category: .userCache), count: service.countFor(category: .userCache), color: .cyan, onTap: { selectedSubcategory = .userCache })
                        DrillDownCategoryRow(icon: "internaldrive.fill", title: loc.currentLanguage == .chinese ? "系统缓存文件" : "System Cache", size: service.sizeFor(category: .systemCache), count: service.countFor(category: .systemCache), color: .blue, onTap: { selectedSubcategory = .systemCache })
                        DrillDownCategoryRow(icon: "arrow.down.circle.fill", title: loc.currentLanguage == .chinese ? "旧更新" : "Old Updates", size: service.sizeFor(category: .oldUpdates), count: service.countFor(category: .oldUpdates), color: .orange, onTap: { selectedSubcategory = .oldUpdates })
                        DrillDownCategoryRow(icon: "textformat.abc", title: loc.currentLanguage == .chinese ? "语言文件" : "Language Files", size: service.sizeFor(category: .languageFiles), count: service.countFor(category: .languageFiles), color: .purple, onTap: { selectedSubcategory = .languageFiles })
                        DrillDownCategoryRow(icon: "doc.text.fill", title: loc.currentLanguage == .chinese ? "系统日志文件" : "System Logs", size: service.sizeFor(category: .systemLogs), count: service.countFor(category: .systemLogs), color: .green, onTap: { selectedSubcategory = .systemLogs })
                        DrillDownCategoryRow(icon: "person.text.rectangle.fill", title: loc.currentLanguage == .chinese ? "用户日志文件" : "User Logs", size: service.sizeFor(category: .userLogs), count: service.countFor(category: .userLogs), color: .teal, onTap: { selectedSubcategory = .userLogs })
                        DrillDownCategoryRow(icon: "exclamationmark.triangle.fill", title: loc.currentLanguage == .chinese ? "损坏的登录项" : "Broken Login Items", size: service.sizeFor(category: .brokenLoginItems), count: service.countFor(category: .brokenLoginItems), color: .red, onTap: { selectedSubcategory = .brokenLoginItems })
                    }
                    .padding()
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 主分类行
struct MainCategoryRow: View {
    let icon: String
    let title: String
    let size: Int64
    let count: Int
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Text("\(count) 个项目")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondaryText)
                    .font(.system(size: 12))
            }
            .padding(12)
            .background(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 系统垃圾分类行
struct SystemJunkCategoryRow: View {
    let icon: String
    let title: String
    let size: Int64
    let isSelected: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
                .font(.system(size: 20))
            
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - 垃圾分类详情行 (保留兼容)
struct JunkCategoryDetailRow: View {
    let icon: String
    let title: String
    let size: Int64
    let count: Int
    let color: Color
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
                .font(.system(size: 22))
            
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                if count > 0 {
                    Text("\(count) 个文件")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondaryText)
                    .font(.system(size: 12))
                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 80, alignment: .trailing)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Result Card (保留兼容)
struct ResultCard: View {
    let icon: String
    let title: String
    let count: Int
    let size: Int64
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .padding(8)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            Spacer()
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondaryText)
            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: 120)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

// MARK: - 保留的组件
struct CategoryTabButton: View {
    let category: CleanerCategory
    let isSelected: Bool
    let count: Int
    @ObservedObject var loc: LocalizationManager
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                Text(loc.currentLanguage == .chinese ? category.rawValue : category.englishName)
                    .font(.system(size: 13, weight: .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.white.opacity(0.15) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct FileRow: View {
    let file: CleanerFileItem
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .white.opacity(0.3))
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            
            Image(nsImage: file.icon)
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(file.url.deletingLastPathComponent().path)
                    .font(.system(size: 11))
                    .foregroundColor(.tertiaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(file.formattedSize)
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

struct PhotoRow: View {
    let file: CleanerFileItem
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .white.opacity(0.3))
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            
            if let nsImage = NSImage(contentsOf: file.url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .cornerRadius(6)
                    .clipped()
            } else {
                Image(systemName: "photo")
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(file.url.deletingLastPathComponent().path)
                    .font(.system(size: 11))
                    .foregroundColor(.tertiaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(file.formattedSize)
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}
