import SwiftUI
import AppKit

// MARK: - Legacy Components Support
// These components are used by MonitorView and potentially other parts of the app, 
// originally defined in SmartCleanerView.swift but moved here during redesign.

struct ResultCategoryCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let value: String
    var valueSecondary: String? = nil
    let hasDetails: Bool
    let onDetailTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(iconColor)
            }
            
            // 中间文本
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            // 右侧数值
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                if let secondary = valueSecondary {
                    Text(secondary)
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                }
            }
            
            // 查看详情按钮
            if hasDetails {
                Button(action: onDetailTap) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isHovering ? .white : .secondaryText)
                        .padding(8)
                        .background(isHovering ? Color.white.opacity(0.1) : Color.clear)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .onHover { isHovering = $0 }
            } else {
                // 占位，保持对齐
                Color.clear.frame(width: 30, height: 30)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(isHovering ? 0.2 : 0.05), lineWidth: 1)
        )
        .onHover { isHovering = $0 }
    }
}

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
        .frame(height: 56)
    }
}

// MARK: - All Categories Detail Sheet (Original Three-Column Design)

struct AllCategoriesDetailSheet: View {
    @ObservedObject var service: SmartCleanerService
    @ObservedObject var loc: LocalizationManager
    @Binding var isPresented: Bool
    var initialCategory: CleanerCategory?
    
    @State private var selectedMainCategory: MainCategory? = nil
    @State private var selectedSubcategory: CleanerCategory? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            HStack {
                Button(action: {
                    // 关闭前手动触发更新，确保主界面显示最新的选中文件大小
                    service.objectWillChange.send()
                    isPresented = false
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                        Text(loc.currentLanguage == .chinese ? "返回摘要" : "Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(loc.currentLanguage == .chinese ? "清理详情" : "Cleanup Details")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Placeholder for balance
                HStack(spacing: 4) { Image(systemName: "chevron.left"); Text("Back") }
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // 三栏布局
            threeColumnLayout
        }
        .frame(width: 1024, height: 680)
        .background(BackgroundStyles.smartScanSheet)
        .onAppear {
            // 智能默认选择
            if selectedMainCategory == nil {
                selectedMainCategory = .systemJunk
                if let firstSubcat = MainCategory.systemJunk.subcategories.first {
                    selectedSubcategory = firstSubcat
                }
            }
            
            // 处理初始分类
            if let initial = initialCategory {
                if initial == .systemJunk {
                    selectedMainCategory = .systemJunk
                } else if MainCategory.systemJunk.subcategories.contains(initial) {
                    selectedMainCategory = .systemJunk
                    selectedSubcategory = initial
                } else {
                    // 查找属于哪个主分类
                    for mainCat in MainCategory.allCases {
                        if mainCat.subcategories.contains(initial) {
                            selectedMainCategory = mainCat
                            selectedSubcategory = initial
                            break
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 三栏布局主视图
    private var threeColumnLayout: some View {
        HStack(spacing: 0) {
            // 左栏：主分类列表
            MainCategoryListView(
                service: service,
                loc: loc,
                selectedMainCategory: $selectedMainCategory
            )
            .onChange(of: selectedMainCategory) { newValue in
                // 当选择新的主分类时，自动选择第一个子分类
                if let mainCat = newValue {
                    selectedSubcategory = mainCat.subcategories.first
                }
            }
            
            Divider()
                .frame(width: 1)
                .background(Color.white.opacity(0.1))
            
            // 中栏：子分类列表
            if let mainCat = selectedMainCategory {
                SubCategoryListView(
                    mainCategory: mainCat,
                    service: service,
                    loc: loc,
                    selectedSubcategory: $selectedSubcategory
                )
                
                Divider()
                    .frame(width: 1)
                    .background(Color.white.opacity(0.1))
                
                // 右栏：文件详情列表
                if let subcat = selectedSubcategory {
                    if subcat == .startupItems {
                        startupItemsRightPane
                    } else if subcat == .virus {
                        virusRightPane
                    } else if subcat == .performanceApps {
                        performanceAppsRightPane
                    } else if subcat == .appUpdates {
                        appUpdatesRightPane
                    } else {
                        fileDetailPane(for: subcat)
                    }
                } else {
                    emptyStateView
                }
            } else {
                emptyStateView
            }
        }
    }
    
    // 空状态视图
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Image(systemName: "arrow.left")
                .font(.system(size: 48))
                .foregroundColor(.secondaryText.opacity(0.5))
            Text(loc.currentLanguage == .chinese ? "选择分类查看详情" : "Select a category")
                .font(.title3)
                .foregroundColor(.secondaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    //文件详情面板
    private func fileDetailPane(for category: CleanerCategory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题区域
            HStack {
                Text(loc.currentLanguage == .chinese ? category.rawValue : category.englishName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // 全选/取消全选/排序
                HStack(spacing: 12) {
                    Button(action: {
                        service.toggleCategorySelection(category, forceTo: true)
                    }) {
                        Text(loc.currentLanguage == .chinese ? "全选" : "Select All")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        service.toggleCategorySelection(category, forceTo: false)
                    }) {
                        Text(loc.currentLanguage == .chinese ? "取消全选" : "Deselect All")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    
                    Text(loc.currentLanguage == .chinese ? "排序方式 大小 ▼" : "Sort By Size ▼")
                        .font(.system(size: 10))
                        .foregroundColor(.secondaryText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // 文件列表
            ScrollView {
                LazyVStack(spacing: 0) {
                    if category == .userCache {
                        // 特殊处理：按应用分组展示
                        ForEach(service.appCacheGroups) { group in
                            AppCacheGroupRow(group: group, service: service, onToggleFile: { file in
                                service.toggleFileSelection(file: file, in: .userCache)
                            })
                            Divider().background(Color.white.opacity(0.05))
                        }
                        
                        // 其他文件夹
                        let orphanFiles = filesFor(category: .userCache).filter { file in
                            !service.appCacheGroups.flatMap { $0.files }.contains { $0.url == file.url }
                        }
                        
                        if !orphanFiles.isEmpty {
                            ForEach(orphanFiles.sorted { $0.size > $1.size }, id: \.url) { file in
                                FileItemRow(file: file, showPath: true, service: service, category: .userCache) {
                                    service.toggleFileSelection(file: file, in: .userCache)
                                }
                                Divider().background(Color.white.opacity(0.05))
                            }
                        }
                    } else {
                        // 常规列表展示
                        ForEach(filesFor(category: category).sorted { $0.size > $1.size }, id: \.url) { file in
                            FileItemRow(file: file, showPath: true, service: service, category: category) {
                                service.toggleFileSelection(file: file, in: category)
                            }
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // 右侧文件列表面板
    private func rightPaneFileList(for category: CleanerCategory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.currentLanguage == .chinese ? category.rawValue : category.englishName)
                    .font(.system(size: 18, weight: .bold)) // Reduced from Title
                    .foregroundColor(.white)
                
                let files = filesFor(category: category)
                Text("\(files.count) " + (loc.currentLanguage == .chinese ? "个项目，共 " : "items, ") + ByteCountFormatter.string(fromByteCount: files.reduce(0) { $0 + $1.size }, countStyle: .file))
                    .font(.system(size: 12)) // Reduced from subheadline
                    .foregroundColor(.secondaryText)
            }
            .padding()
            
            // 文件列表
            ScrollView {
                LazyVStack(spacing: 0) { // Removed spacing
                    ForEach(filesFor(category: category).sorted { $0.size > $1.size }, id: \.url) { file in
                        FileItemRow(file: file, showPath: true, service: service, category: category) {
                            service.toggleFileSelection(file: file, in: category)
                        }
                        Divider().background(Color.white.opacity(0.05))
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
    
    // MARK: - 病毒威胁右侧面板
    private var virusRightPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.currentLanguage == .chinese ? "病毒威胁" : "Virus Threats")
                    .font(.system(size: 18, weight: .bold)) // Reduced
                    .foregroundColor(.white)
                Text(service.virusThreats.isEmpty ? 
                     (loc.currentLanguage == .chinese ? "未检测到威胁" : "No threats detected") :
                     "\(service.virusThreats.count) " + (loc.currentLanguage == .chinese ? "个威胁" : "threats found"))
                    .font(.system(size: 12)) // Reduced
                    .foregroundColor(service.virusThreats.isEmpty ? .green : .red)
            }
            .padding()
            
            if service.virusThreats.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                    Text(loc.currentLanguage == .chinese ? "您的系统是安全的" : "Your system is safe")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(.top)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(service.virusThreats, id: \.id) { threat in
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.title2)
                                
                                VStack(alignment: .leading) {
                                    Text(threat.name)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(threat.path.path)
                                        .font(.caption)
                                        .foregroundColor(.secondaryText)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Text(threat.type.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.2))
                                    .foregroundColor(.red)
                                    .cornerRadius(4)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 启动项右侧面板
    private var startupItemsRightPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.currentLanguage == .chinese ? "启动项" : "Startup Items")
                    .font(.system(size: 18, weight: .bold)) // Reduced
                    .foregroundColor(.white)
                Text("\(service.startupItems.count) " + (loc.currentLanguage == .chinese ? "个项目会在开机时自动启动" : "items start automatically"))
                    .font(.system(size: 12)) // Reduced
                    .foregroundColor(.secondaryText)
            }
            .padding()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(service.startupItems, id: \.id) { item in
                        HStack(spacing: 12) {
                            // 勾选框
                            Button(action: {
                                item.isSelected.toggle()
                                service.objectWillChange.send()
                            }) {
                                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isSelected ? .blue : .gray)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                            
                            Image(systemName: "power")
                                .foregroundColor(.orange)
                                .font(.title2)
                                .frame(width: 32, height: 32)
                            
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.body)
                                    .foregroundColor(.white)
                                Text(item.url.path)
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(item.isEnabled ? (loc.currentLanguage == .chinese ? "已启用" : "Enabled") : (loc.currentLanguage == .chinese ? "已禁用" : "Disabled"))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(item.isEnabled ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2))
                                .foregroundColor(item.isEnabled ? .orange : .gray)
                                .cornerRadius(4)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                        Divider().background(Color.white.opacity(0.05))
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 性能优化右侧面板
    private var performanceAppsRightPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.currentLanguage == .chinese ? "性能优化" : "Performance")
                    .font(.system(size: 18, weight: .bold)) // Reduced
                    .foregroundColor(.white)
                Text("\(service.performanceApps.count) " + (loc.currentLanguage == .chinese ? "个应用正在消耗资源" : "apps consuming resources"))
                    .font(.system(size: 12)) // Reduced
                    .foregroundColor(.secondaryText)
            }
            .padding()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(service.performanceApps) { app in
                        HStack(spacing: 12) {
                            // 勾选框
                            Button(action: {
                                app.isSelected.toggle()
                                service.objectWillChange.send()
                            }) {
                                Image(systemName: app.isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(app.isSelected ? .blue : .gray)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                            
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 32, height: 32)
                            
                            VStack(alignment: .leading) {
                                Text(app.name)
                                    .font(.body)
                                    .foregroundColor(.white)
                                Text(app.app.bundleIdentifier ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "memorychip")
                                    .foregroundColor(.orange)
                                Text(app.formattedMemory)
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                        Divider().background(Color.white.opacity(0.05))
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 应用更新右侧面板
    private var appUpdatesRightPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.currentLanguage == .chinese ? "应用更新" : "App Updates")
                    .font(.system(size: 18, weight: .bold)) // Reduced
                    .foregroundColor(.white)
                Text(service.hasAppUpdates ? 
                     (loc.currentLanguage == .chinese ? "有可用更新" : "Updates available") :
                     (loc.currentLanguage == .chinese ? "所有应用已是最新" : "All apps up to date"))
                    .font(.system(size: 12)) // Reduced
                    .foregroundColor(service.hasAppUpdates ? .blue : .green)
            }
            .padding()
            
            VStack {
                Spacer()
                Image(systemName: service.hasAppUpdates ? "arrow.down.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(service.hasAppUpdates ? .blue : .green)
                Text(service.hasAppUpdates ? 
                     (loc.currentLanguage == .chinese ? "点击更新按钮检查更新" : "Click update button to check") :
                     (loc.currentLanguage == .chinese ? "无需更新" : "No updates needed"))
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(.top)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 文件项行（支持文件夹钻取）
struct FileItemRow: View {
    let file: CleanerFileItem
    let showPath: Bool
    @ObservedObject var service: SmartCleanerService
    var category: CleanerCategory = .userCache
    var onToggle: (() -> Void)? = nil
    
    @State private var isExpanded: Bool = false
    @State private var subItems: [CleanerFileItem] = []
    @State private var isLoading: Bool = false
    @State private var isHovering: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    
    // 计算属性判断当前行是否应该显示为部分选中
    private var selectionState: SmartCleanerService.SelectionState {
        // 如果是文件夹且已加载子项
        if file.isDirectory && !subItems.isEmpty {
            let selectedCount = subItems.filter { $0.isSelected }.count
            if selectedCount == 0 { return .none }
            if selectedCount == subItems.count { return .all }
            return .partial
        }
        // 默认回退到单个文件的选中状态
        return file.isSelected ? .all : .none
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // 复选框 (三态)
                TriStateCheckbox(state: selectionState) {
                    toggleSelection()
                }
                .frame(width: 18, height: 18)
                .padding(.trailing, 4)
                
                Image(nsImage: file.icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .padding(.trailing, 4)
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(file.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if file.isDirectory {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondaryText)
                        }
                    }
                    
                    if showPath {
                        Text(file.url.deletingLastPathComponent().path)
                            .font(.system(size: 10))
                            .foregroundColor(.tertiaryText)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Text(file.formattedSize)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                
                // (已移除悬停操作按钮：查看与删除)
                /*
                if isHovering {
                    HStack(spacing: 6) { ... }
                }
                */
                
                if file.isDirectory {
                    Button(action: {
                        toggleExpand()
                    }) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle()) // Full area clickable
            .onHover { isHovering = $0 }
            // Tap on row content (except arrow) toggles selection
            .onTapGesture {
                toggleSelection()
            }
            .confirmationDialog(
                LocalizationManager.shared.currentLanguage == .chinese ? "确认删除" : "Confirm Delete",
                isPresented: $showDeleteConfirmation
            ) {
                Button(
                    LocalizationManager.shared.currentLanguage == .chinese ? "删除" : "Delete",
                    role: .destructive
                ) {
                    deleteSingleFile()
                }
                Button(
                    LocalizationManager.shared.currentLanguage == .chinese ? "取消" : "Cancel",
                    role: .cancel
                ) {}
            } message: {
                let fileName = file.name
                Text(LocalizationManager.shared.currentLanguage == .chinese ?
                     "确定要删除\" \(fileName)\" 吗？此操作无法撤销。" :
                     "Are you sure you want to delete \"\(fileName)\"? This action cannot be undone.")
            }
            .contextMenu {
                // 仅在选中时显示"取消选择"
                if file.isSelected {
                    Button {
                        onToggle?()
                    } label: {
                        let fileName = file.name
                        Label(
                            LocalizationManager.shared.currentLanguage == .chinese ? 
                                "取消选择\"\(fileName)\"" : 
                                "Deselect \"\(fileName)\"",
                            systemImage: "checkmark.circle"
                        )
                    }
                    
                    Divider()
                }
                
                // 在访达中显示
                Button {
                    openInFinder()
                } label: {
                    Label(
                        LocalizationManager.shared.currentLanguage == .chinese ? 
                            "在\"访达\"中显示" : 
                            "Show in Finder",
                        systemImage: "folder"
                    )
                }
                
                // 快速查看
                Button {
                    quickLookFile()
                } label: {
                    let fileName = file.name
                    Label(
                        LocalizationManager.shared.currentLanguage == .chinese ? 
                            "快速查看\"\(fileName)\"" : 
                            "Quick Look \"\(fileName)\"",
                        systemImage: "eye"
                    )
                }
                
                Divider()
                
                // 忽略
                Button {
                    // TODO: 实现忽略功能
                    print("忽略: \(file.name)")
                } label: {
                    Label(
                        LocalizationManager.shared.currentLanguage == .chinese ? 
                            "忽略" : 
                            "Ignore",
                        systemImage: "eye.slash"
                    )
                }
            }
            
            // 展开子项
            if isExpanded && !subItems.isEmpty {
                VStack(spacing: 2) {
                    ForEach(subItems, id: \.url) { subFile in
                        FileItemRow(file: subFile, showPath: false, service: service, category: category) {
                            service.toggleFileSelection(file: subFile, in: category)
                        }
                        .padding(.leading, 20)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    // 切换选中逻辑：递归更新本地 subItems 和 Service
    private func toggleSelection() {
        let newState = selectionState == .all ? false : true
        
        if file.isDirectory && !subItems.isEmpty {
             for i in subItems.indices {
                 if subItems[i].isSelected != newState {
                     // Update Service for Child
                     service.toggleFileSelection(file: subItems[i], in: category)
                     // Update Local
                     subItems[i].isSelected = newState
                 }
             }
        } else {
             onToggle?()
        }
    }
    
    private func toggleExpand() {
        if isExpanded {
            isExpanded = false
        } else {
            if subItems.isEmpty {
                isLoading = true
                Task {
                    let items = await service.loadSubItems(for: file)
                    await MainActor.run {
                        subItems = items
                        isLoading = false
                        withAnimation { isExpanded = true }
                    }
                }
            } else {
                withAnimation { isExpanded = true }
            }
        }
    }
    
    private func openInFinder() {
        NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: "")
    }
    
    private func deleteSingleFile() {
        Task {
            let success = await service.deleteSingleFile(file, from: category)
            if !success {
                print("删除文件失败: \(file.url.path)")
            }
        }
    }
    
    private func quickLookFile() {
        // 使用NSWorkspace打开Quick Look
        NSWorkspace.shared.open([file.url], withApplicationAt: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"), configuration: NSWorkspace.OpenConfiguration())
    }
}

// MARK: - 应用缓存分组行
struct AppCacheGroupRow: View {
    @ObservedObject var group: AppCacheGroup
    @ObservedObject var service: SmartCleanerService
    let onToggleFile: (CleanerFileItem) -> Void
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 主行：应用信息
            HStack(spacing: 8) { // Compact spacing 12->8
                // 勾选框 (独立交互)
                TriStateCheckbox(state: selectionState) {
                    service.toggleAppGroupSelection(group)
                }
                .frame(width: 18, height: 18) // Smaller 20->18
                
                // 内容区域
                HStack(spacing: 8) { // Compact spacing 12->8
                    Image(nsImage: group.icon)
                        .resizable()
                        .frame(width: 24, height: 24) // Smaller 32->24
                    
                    VStack(alignment: .leading, spacing: 1) { // Compact spacing
                        Text(group.appName)
                            .font(.system(size: 13, weight: .semibold)) // Smaller 14->13
                            .foregroundColor(.white)
                        
                        Text("\(group.files.count) " + (group.files.count == 1 ? "location" : "locations"))
                            .font(.caption2) // Smaller
                            .foregroundColor(.secondaryText)
                    }
                    
                    Spacer()
                    
                    // 选中数量
                    Text("\(selectedCount)/\(group.files.count)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondaryText)
                    
                    // 选中大小
                    Text(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))
                        .font(.system(size: 12, weight: .medium)) // Smaller 13->12
                        .foregroundColor(.white)
                    
                    Button(action: { withAnimation { isExpanded.toggle() } }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11)) // Smaller 12->11
                            .foregroundColor(.secondaryText)
                            .frame(width: 16, height: 16) // Smaller 24->16
                            .contentShape(Rectangle())
                    }
                }
                // Tap on content area toggles group selection
                .contentShape(Rectangle())
                .onTapGesture {
                    service.toggleAppGroupSelection(group)
                }
            }
            .padding(.vertical, 4) // Compact vertical padding
            
            // 展开内容：具体子文件夹
            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(group.files.sorted { $0.size > $1.size }, id: \.url) { file in
                        FileItemRow(file: file, showPath: false, service: service, category: .userCache) {
                            service.toggleFileSelection(file: file, in: .userCache)
                        }
                        .padding(.leading, 16)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var selectionState: SmartCleanerService.SelectionState {
        let selectedCount = group.files.filter { $0.isSelected }.count
        if selectedCount == 0 { return .none }
        if selectedCount == group.files.count { return .all }
        return .partial
    }
    
    private var selectedSize: Int64 {
        group.files.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    private var selectedCount: Int {
        group.files.filter { $0.isSelected }.count
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
                        Text("\(count) " + (count == 1 ? "file" : "files"))
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
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.vertical, 12) // Slightly more padding for main rows
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helper Views

struct DetailSidebarRow: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? .white : color)
                    .frame(width: 20)
                Text(title)
                    .foregroundColor(isSelected ? .white : .secondaryText)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? color.opacity(0.8) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
//
//  ThreeColumnUIComponents.swift
//  新增的三栏布局UI组件
//
//  Created for Smart Scan Detail View Redesign
//

import SwiftUI

// MARK: - 主分类行（左侧栏）

