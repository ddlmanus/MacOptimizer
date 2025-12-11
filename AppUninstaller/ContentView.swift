import SwiftUI
import AppKit

struct ContentView: View {
    @State private var selectedModule: AppModule = .monitor
    
    var body: some View {
        ZStack {
            // 全屏背景 (沉浸式)
            selectedModule.backgroundGradient
                .ignoresSafeArea()
            
            HStack(spacing: 0) {
                // 左侧导航
                NavigationSidebar(selectedModule: $selectedModule)
                    .zIndex(1)
                
                // 右侧内容
                ZStack {
                    // Color.clear // 内容区域背景透明
                    
                    Group {
                        switch selectedModule {
                        case .uninstaller:
                            UninstallerMainView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .deepClean:
                            DeepCleanView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .cleaner:
                            JunkCleanerView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .optimizer:
                            OptimizerView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .largeFiles:
                            LargeFileView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .fileExplorer:
                            FileExplorerView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .trash:
                            TrashView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .monitor:
                            MonitorView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: selectedModule)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
    }
}

// 包装现有的 Uninstaller 视图
struct UninstallerMainView: View {
    @StateObject private var appScanner = AppScanner()
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var selectedApp: InstalledApp?
    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var includeAppInDeletion = true
    @State private var moveToTrash = true
    @State private var deleteResult: RemovalResult?
    @State private var showingResultAlert = false
    
    private let residualScanner = ResidualFileScanner()
    private let fileRemover = FileRemover()
    
    // 计算属性需要在View内部处理，不能直接访问StateObject的published属性进行过滤（虽然可以，但建议解耦）
    var filteredApps: [InstalledApp] {
        if searchText.isEmpty {
            return appScanner.apps
        }
        return appScanner.apps.filter { app in
            app.name.localizedCaseInsensitiveContains(searchText) ||
            (app.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        HSplitView {
            // 应用列表 (中间列)
            AppListView(
                apps: filteredApps,
                selectedApp: selectedApp,
                isScanning: appScanner.isScanning,
                searchText: $searchText,
                onSelect: { app in
                    withAnimation {
                        selectedApp = app
                    }
                    if !app.isScanning && app.residualFiles.isEmpty {
                        Task {
                             await MainActor.run { app.isScanning = true }
                             let residuals = await residualScanner.scanResidualFiles(for: app)
                             await MainActor.run {
                                 app.residualFiles = residuals
                                 app.isScanning = false
                             }
                        }
                    }
                },
                onRefresh: {
                    Task { await appScanner.scanApplications() }
                },
                loc: loc
            )
            .frame(minWidth: 300, maxWidth: 400)
            
            // 详情视图 (右侧列)
            Group {
                if let app = selectedApp {
                    AppDetailView(
                        app: app,
                        onDelete: { includeApp, toTrash in
                            includeAppInDeletion = includeApp
                            moveToTrash = toTrash
                            showingDeleteConfirmation = true
                        }
                    )
                } else {
                    EmptySelectionView()
                }
            }
            .frame(minWidth: 400)
        }
        .onAppear {
            if appScanner.apps.isEmpty {
                Task { await appScanner.scanApplications() }
            }
        }
        .confirmationDialog(
            loc.L("confirm_delete"),
            isPresented: $showingDeleteConfirmation
        ) {
            Button(loc.L("delete"), role: .destructive) {
                guard let app = selectedApp else { return }
                Task {
                    let result = await fileRemover.removeApp(
                        app,
                        includeApp: includeAppInDeletion,
                        moveToTrash: moveToTrash
                    )
                    await MainActor.run {
                        deleteResult = result
                        showingResultAlert = true
                        
                        // 如果删除了应用本身且成功，清除选中状态并刷新列表
                        if includeAppInDeletion && result.failedCount == 0 {
                            selectedApp = nil
                            Task { await appScanner.scanApplications() }
                        } else {
                            // 否则只刷新残留文件
                             Task {
                                 let residuals = await residualScanner.scanResidualFiles(for: app)
                                 await MainActor.run { app.residualFiles = residuals }
                             }
                        }
                    }
                }
            }
            Button(loc.L("cancel"), role: .cancel) {}
        } message: {
            if let app = selectedApp {
                Text(includeAppInDeletion
                     ? "确定要删除 \(app.name) 及其所有残留文件吗？\n此操作\(moveToTrash ? "会将文件移至废纸篓" : "不可撤销")。"
                     : "确定要删除 \(app.name) 的残留文件吗？\n此操作\(moveToTrash ? "会将文件移至废纸篓" : "不可撤销")。")
            }
        }
        .alert(loc.L("clean_complete"), isPresented: $showingResultAlert) {
            Button(loc.L("confirm"), role: .cancel) {}
        } message: {
            if let result = deleteResult {
                Text("成功删除 \(result.successCount) 个项目\n释放空间: \(ByteCountFormatter.string(fromByteCount: result.totalSizeRemoved, countStyle: .file))")
            }
        }
    }
}

// 拆分出来的应用列表视图
struct AppListView: View {
    let apps: [InstalledApp]
    let selectedApp: InstalledApp?
    let isScanning: Bool
    @Binding var searchText: String
    let onSelect: (InstalledApp) -> Void
    let onRefresh: () -> Void
    @ObservedObject var loc: LocalizationManager
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部工具栏
            HStack {
                Text(loc.currentLanguage == .chinese ? "应用列表" : "App List")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.3))
                TextField(loc.L("search_apps"), text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            
            if isScanning {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Text(loc.currentLanguage == .chinese ? "扫描应用中..." : "Scanning apps...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                Spacer()
            } else {
                List(apps) { app in
                    AppListRow(app: app, isSelected: selectedApp?.id == app.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(app)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            
            // 底部统计
            HStack {
                Text(loc.currentLanguage == .chinese ? "\(apps.count) 个应用" : "\(apps.count) apps")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(12)
            .background(Color.black.opacity(0.2))
        }
        .background(Color.black.opacity(0.2))
    }
}

// 拆分出来的空状态视图
struct EmptySelectionView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.square")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.1))
            Text(loc.currentLanguage == .chinese ? "选择一个应用以查看详情" : "Select an app to view details")
                .font(.title3)
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

// 列表行组件 (适配新风格)
struct AppListRow: View {
    @ObservedObject var app: InstalledApp
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primaryText)
                
                Text(app.formattedSize)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondaryText)
            }
            
            Spacer()
            
            if !app.residualFiles.isEmpty {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue : Color.clear)
        )
    }
}
