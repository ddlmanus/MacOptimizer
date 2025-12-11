import SwiftUI

// MARK: - 优化分类
enum OptimizerCategory: String, CaseIterable, Identifiable {
    case oneClick = "一键优化"
    case runningApps = "运行中应用"
    case memory = "内存优化"
    case system = "系统修复"
    case cleanup = "清理优化"
    case startup = "启动项"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .oneClick: return "bolt.fill"
        case .runningApps: return "app.badge.fill"
        case .memory: return "memorychip"
        case .system: return "gearshape.2.fill"
        case .cleanup: return "trash.fill"
        case .startup: return "power"
        }
    }
}

struct OptimizerView: View {
    @StateObject private var optimizer = SystemOptimizer()
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var selectedCategory: OptimizerCategory = .oneClick
    @State private var showingResult = false
    @State private var resultMessage = ""
    @State private var resultSuccess = false
    
    var body: some View {
        HSplitView {
            // 左侧：分类列表
            categoryListView
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
            
            // 右侧：详情视图
            detailView
                .frame(minWidth: 400)
        }
        .onAppear {
            optimizer.scanRunningApps()
            Task { await optimizer.scanLaunchAgents() }
        }
        .alert(resultSuccess ? (loc.currentLanguage == .chinese ? "优化成功" : "Success") : (loc.currentLanguage == .chinese ? "操作结果" : "Result"), isPresented: $showingResult) {
            Button(loc.L("confirm"), role: .cancel) {}
        } message: {
            Text(resultMessage)
        }
    }
    
    // MARK: - 左侧分类列表
    private var categoryListView: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.L("optimizer"))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(loc.currentLanguage == .chinese ? "让 Mac 保持最佳状态" : "Keep your Mac at peak performance")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                Spacer()
            }
            .padding(16)
            .background(Color.black.opacity(0.2))
            
            // 分类列表
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(OptimizerCategory.allCases) { category in
                        CategoryRow(
                            category: category,
                            isSelected: selectedCategory == category,
                            loc: loc,
                            count: getCategoryCount(category)
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(12)
            }
            
            Spacer()
        }
        .background(Color.black.opacity(0.1))
    }
    
    private func getCategoryCount(_ category: OptimizerCategory) -> Int? {
        switch category {
        case .runningApps: return optimizer.runningApps.count
        case .startup: return optimizer.launchAgents.count
        default: return nil
        }
    }
    
    // MARK: - 右侧详情视图
    @ViewBuilder
    private var detailView: some View {
        VStack(spacing: 0) {
            // 详情头部
            HStack {
                Image(systemName: selectedCategory.icon)
                    .font(.title2)
                    .foregroundStyle(GradientStyles.optimizer)
                
                Text(localizedCategoryName(selectedCategory))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                if optimizer.isOptimizing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(24)
            .background(Color.black.opacity(0.2))
            
            // 具体内容
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedCategory {
                    case .oneClick:
                        oneClickDetailView
                    case .runningApps:
                        runningAppsDetailView
                    case .memory:
                        memoryDetailView
                    case .system:
                        systemDetailView
                    case .cleanup:
                        cleanupDetailView
                    case .startup:
                        startupDetailView
                    }
                }
                .padding(24)
                .padding(.bottom, 100) // 为底部按钮留空间
            }
            
            // 底部一键优化大圆圈按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    oneClickButton
                    Spacer()
                    Spacer() // 增加右侧空间，使按钮视觉上偏左
                }
                .padding(.bottom, 10)
            }
        }
    }
    
    // MARK: - 一键优化大圆圈按钮
    private var oneClickButton: some View {
        Button(action: {
            Task {
                let result = await optimizer.performOneClickOptimization()
                resultSuccess = result.success
                resultMessage = loc.currentLanguage == .chinese ? result.message : "Optimization completed"
                showingResult = true
            }
        }) {
            ZStack {
                // 外圈光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                
                // 主圆圈
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .shadow(color: Color.orange.opacity(0.5), radius: 15, x: 0, y: 8)
                
                // 内容
                VStack(spacing: 2) {
                    if optimizer.isOptimizing {
                        ProgressView()
                            .scaleEffect(1.0)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 24))
                        Text(loc.currentLanguage == .chinese ? "优化" : "Optimize")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(optimizer.isOptimizing)
    }
    
    private func localizedCategoryName(_ category: OptimizerCategory) -> String {
        switch category {
        case .oneClick: return loc.currentLanguage == .chinese ? "一键优化" : "One-Click Optimize"
        case .runningApps: return loc.currentLanguage == .chinese ? "运行中应用" : "Running Apps"
        case .memory: return loc.currentLanguage == .chinese ? "内存优化" : "Memory"
        case .system: return loc.currentLanguage == .chinese ? "系统修复" : "System Repair"
        case .cleanup: return loc.currentLanguage == .chinese ? "清理优化" : "Cleanup"
        case .startup: return loc.currentLanguage == .chinese ? "启动项管理" : "Startup Items"
        }
    }
    
    // MARK: - 一键优化详情
    private var oneClickDetailView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(loc.currentLanguage == .chinese ? "一键优化将执行以下操作：" : "One-click optimization will perform:")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                OptimizationItem(icon: "xmark.app.fill", title: loc.currentLanguage == .chinese ? "关闭选中的后台应用" : "Close selected background apps", description: loc.currentLanguage == .chinese ? "释放被占用的系统资源" : "Free up system resources")
                OptimizationItem(icon: "memorychip", title: loc.currentLanguage == .chinese ? "释放系统内存" : "Free system memory", description: loc.currentLanguage == .chinese ? "清理未使用的 RAM" : "Clean unused RAM")
                OptimizationItem(icon: "doc.on.clipboard", title: loc.currentLanguage == .chinese ? "清空剪贴板" : "Clear clipboard", description: loc.currentLanguage == .chinese ? "保护隐私数据" : "Protect privacy")
            }
            
            Spacer()
        }
    }
    
    // MARK: - 运行中应用详情
    private var runningAppsDetailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(loc.currentLanguage == .chinese ? "选择要关闭的应用" : "Select apps to close")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(loc.currentLanguage == .chinese ? "全选" : "All") {
                    optimizer.selectAllApps(true)
                }
                .buttonStyle(.plain)
                .foregroundColor(.orange)
                
                Button(loc.currentLanguage == .chinese ? "取消" : "None") {
                    optimizer.selectAllApps(false)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondaryText)
                
                Button(action: { optimizer.scanRunningApps() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondaryText)
            }
            
            if optimizer.runningApps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(GradientStyles.optimizer)
                    Text(loc.currentLanguage == .chinese ? "没有可关闭的后台应用" : "No background apps to close")
                        .foregroundColor(.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                VStack(spacing: 0) {
                    ForEach(optimizer.runningApps) { appItem in
                        RunningAppRow(appItem: appItem, loc: loc)
                        if appItem.id != optimizer.runningApps.last?.id {
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
                
                let selectedCount = optimizer.runningApps.filter { $0.isSelected }.count
                if selectedCount > 0 {
                    Button(action: {
                        Task {
                            let count = await optimizer.terminateSelectedApps()
                            resultSuccess = true
                            resultMessage = loc.currentLanguage == .chinese ? "已关闭 \(count) 个应用" : "Closed \(count) apps"
                            showingResult = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text(loc.currentLanguage == .chinese ? "关闭选中的 \(selectedCount) 个应用" : "Close \(selectedCount) Selected")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - 内存优化详情
    private var memoryDetailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(loc.currentLanguage == .chinese ? "内存优化选项" : "Memory Optimization Options")
                .font(.headline)
                .foregroundColor(.white)
            
            OptimizationActionCard(type: .freeMemory, loc: loc, optimizer: optimizer) { result in
                resultSuccess = result.success
                resultMessage = result.message
                showingResult = true
            }
        }
    }
    
    // MARK: - 系统修复详情
    private var systemDetailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(loc.currentLanguage == .chinese ? "系统修复选项" : "System Repair Options")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                OptimizationActionCard(type: .flushDNS, loc: loc, optimizer: optimizer) { result in
                    resultSuccess = result.success; resultMessage = result.message; showingResult = true
                }
                OptimizationActionCard(type: .rebuildSpotlight, loc: loc, optimizer: optimizer) { result in
                    resultSuccess = result.success; resultMessage = result.message; showingResult = true
                }
                OptimizationActionCard(type: .rebuildLaunchServices, loc: loc, optimizer: optimizer) { result in
                    resultSuccess = result.success; resultMessage = result.message; showingResult = true
                }
                OptimizationActionCard(type: .repairPermissions, loc: loc, optimizer: optimizer) { result in
                    resultSuccess = result.success; resultMessage = result.message; showingResult = true
                }
                OptimizationActionCard(type: .clearFontCache, loc: loc, optimizer: optimizer) { result in
                    resultSuccess = result.success; resultMessage = result.message; showingResult = true
                }
            }
        }
    }
    
    // MARK: - 清理优化详情
    private var cleanupDetailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(loc.currentLanguage == .chinese ? "清理优化选项" : "Cleanup Options")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                OptimizationActionCard(type: .clearClipboard, loc: loc, optimizer: optimizer) { result in
                    resultSuccess = result.success; resultMessage = result.message; showingResult = true
                }
                OptimizationActionCard(type: .clearRecentItems, loc: loc, optimizer: optimizer) { result in
                    resultSuccess = result.success; resultMessage = result.message; showingResult = true
                }
                OptimizationActionCard(type: .restartFinder, loc: loc, optimizer: optimizer) { result in
                    resultSuccess = result.success; resultMessage = result.message; showingResult = true
                }
                OptimizationActionCard(type: .restartDock, loc: loc, optimizer: optimizer) { result in
                    resultSuccess = result.success; resultMessage = result.message; showingResult = true
                }
            }
        }
    }
    
    // MARK: - 启动项详情
    private var startupDetailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(loc.currentLanguage == .chinese ? "用户启动项" : "User Startup Items")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { Task { await optimizer.scanLaunchAgents() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondaryText)
            }
            
            if optimizer.isScanning {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text(loc.currentLanguage == .chinese ? "正在扫描..." : "Scanning...")
                        .foregroundColor(.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else if optimizer.launchAgents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(GradientStyles.optimizer)
                    Text(loc.currentLanguage == .chinese ? "没有用户启动项" : "No user startup items")
                        .foregroundColor(.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                VStack(spacing: 0) {
                    ForEach(optimizer.launchAgents) { agent in
                        AgentRow(agent: agent, optimizer: optimizer, loc: loc)
                        if agent.id != optimizer.launchAgents.last?.id {
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - 分类行
struct CategoryRow: View {
    let category: OptimizerCategory
    let isSelected: Bool
    @ObservedObject var loc: LocalizationManager
    let count: Int?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? GradientStyles.optimizer : LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                    .frame(width: 24)
                
                Text(localizedName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .secondaryText)
                
                Spacer()
                
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private var localizedName: String {
        switch category {
        case .oneClick: return loc.currentLanguage == .chinese ? "一键优化" : "One-Click"
        case .runningApps: return loc.currentLanguage == .chinese ? "运行中应用" : "Running Apps"
        case .memory: return loc.currentLanguage == .chinese ? "内存优化" : "Memory"
        case .system: return loc.currentLanguage == .chinese ? "系统修复" : "System Repair"
        case .cleanup: return loc.currentLanguage == .chinese ? "清理优化" : "Cleanup"
        case .startup: return loc.currentLanguage == .chinese ? "启动项" : "Startup"
        }
    }
}

// MARK: - 优化项说明
struct OptimizationItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(GradientStyles.optimizer)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
}

// MARK: - 优化操作卡片
struct OptimizationActionCard: View {
    let type: OptimizationType
    @ObservedObject var loc: LocalizationManager
    @ObservedObject var optimizer: SystemOptimizer
    let onComplete: (( success: Bool, message: String)) -> Void
    
    @State private var isLoading = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundStyle(GradientStyles.optimizer)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(localizedName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(localizedDescription)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            if type.requiresAdmin {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Button(action: {
                Task {
                    isLoading = true
                    let result = await optimizer.performOptimization(type)
                    isLoading = false
                    onComplete((result.success, loc.currentLanguage == .chinese ? result.message : getEnglishMessage()))
                }
            }) {
                if isLoading {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Text(loc.currentLanguage == .chinese ? "执行" : "Run")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.orange)
            .disabled(isLoading)
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
    
    private var localizedName: String {
        switch type {
        case .freeMemory: return loc.currentLanguage == .chinese ? "释放内存" : "Free Memory"
        case .flushDNS: return loc.currentLanguage == .chinese ? "刷新 DNS" : "Flush DNS"
        case .rebuildSpotlight: return loc.currentLanguage == .chinese ? "重建 Spotlight 索引" : "Rebuild Spotlight"
        case .rebuildLaunchServices: return loc.currentLanguage == .chinese ? "重建启动服务数据库" : "Rebuild LaunchServices"
        case .clearFontCache: return loc.currentLanguage == .chinese ? "清除字体缓存" : "Clear Font Cache"
        case .repairPermissions: return loc.currentLanguage == .chinese ? "验证磁盘权限" : "Verify Permissions"
        case .killBackgroundApps: return loc.currentLanguage == .chinese ? "关闭后台应用" : "Kill Background Apps"
        case .clearClipboard: return loc.currentLanguage == .chinese ? "清空剪贴板" : "Clear Clipboard"
        case .clearRecentItems: return loc.currentLanguage == .chinese ? "清除最近记录" : "Clear Recent Items"
        case .restartFinder: return loc.currentLanguage == .chinese ? "重启 Finder" : "Restart Finder"
        case .restartDock: return loc.currentLanguage == .chinese ? "重启 Dock" : "Restart Dock"
        }
    }
    
    private var localizedDescription: String {
        switch type {
        case .freeMemory: return loc.currentLanguage == .chinese ? "清理系统内存，释放未使用的 RAM" : "Clean system RAM"
        case .flushDNS: return loc.currentLanguage == .chinese ? "清除 DNS 缓存，解决网络问题" : "Fix network issues"
        case .rebuildSpotlight: return loc.currentLanguage == .chinese ? "重建搜索索引，修复搜索问题" : "Fix search issues"
        case .rebuildLaunchServices: return loc.currentLanguage == .chinese ? "修复打开方式菜单重复项" : "Fix Open With menu"
        case .clearFontCache: return loc.currentLanguage == .chinese ? "清除字体缓存，修复字体显示问题" : "Fix font issues"
        case .repairPermissions: return loc.currentLanguage == .chinese ? "验证并修复系统目录权限" : "Verify permissions"
        case .killBackgroundApps: return loc.currentLanguage == .chinese ? "强制关闭所有后台应用" : "Kill background apps"
        case .clearClipboard: return loc.currentLanguage == .chinese ? "清空系统剪贴板内容" : "Clear clipboard"
        case .clearRecentItems: return loc.currentLanguage == .chinese ? "清除最近使用的文件记录" : "Clear recent files"
        case .restartFinder: return loc.currentLanguage == .chinese ? "重启 Finder 解决卡顿问题" : "Fix Finder issues"
        case .restartDock: return loc.currentLanguage == .chinese ? "重启 Dock 解决图标问题" : "Fix Dock issues"
        }
    }
    
    private func getEnglishMessage() -> String {
        switch type {
        case .freeMemory: return "Memory freed"
        case .flushDNS: return "DNS cache flushed"
        case .rebuildSpotlight: return "Spotlight rebuilding"
        case .rebuildLaunchServices: return "LaunchServices rebuilt"
        case .clearFontCache: return "Font cache cleared"
        case .repairPermissions: return "Permissions verified"
        case .killBackgroundApps: return "Apps closed"
        case .clearClipboard: return "Clipboard cleared"
        case .clearRecentItems: return "Recent items cleared"
        case .restartFinder: return "Finder restarted"
        case .restartDock: return "Dock restarted"
        }
    }
}

// MARK: - 运行中应用行
struct RunningAppRow: View {
    @ObservedObject var appItem: RunningAppItem
    @ObservedObject var loc: LocalizationManager
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: { appItem.isSelected.toggle() }) {
                Image(systemName: appItem.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(appItem.isSelected ? .orange : .gray)
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            
            Image(nsImage: appItem.icon)
                .resizable()
                .frame(width: 28, height: 28)
            
            Text(appItem.name)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            appItem.isSelected.toggle()
        }
    }
}

// MARK: - 启动项行
struct AgentRow: View {
    @ObservedObject var agent: LaunchItem
    @ObservedObject var optimizer: SystemOptimizer
    @ObservedObject var loc: LocalizationManager
    @State private var isPerformAction = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 20))
                .foregroundStyle(GradientStyles.optimizer)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                Text(agent.isEnabled ? (loc.currentLanguage == .chinese ? "已启用" : "Enabled") : (loc.currentLanguage == .chinese ? "已禁用" : "Disabled"))
                    .font(.caption)
                    .foregroundColor(agent.isEnabled ? .success : .secondaryText)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { agent.isEnabled },
                set: { _ in
                    isPerformAction = true
                    Task {
                        _ = await optimizer.toggleAgent(agent)
                        isPerformAction = false
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .orange))
            .disabled(isPerformAction)
            
            Button(action: {
                Task { await optimizer.removeAgent(agent) }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.secondaryText)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(.vertical, 8)
    }
}
