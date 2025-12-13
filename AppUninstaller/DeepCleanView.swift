import SwiftUI

struct DeepCleanView: View {
    @Binding var selectedModule: AppModule
    // 使用共享的服务管理器，切换视图时扫描状态不会丢失
    @ObservedObject private var scanner = ScanServiceManager.shared.deepCleanScanner
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var showCleanConfirmation = false
    @State private var cleanResult: (count: Int, size: Int64)?
    @State private var showResult = false
    @State private var showingDetails = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 头部
                headerView
                
                if scanner.isScanning {
                    scanningView
                } else if scanner.orphanedItems.isEmpty {
                    emptyStateView
                } else {
                    // 内容区
                    contentView
                }
            }
        }
        .onAppear {
            if scanner.orphanedItems.isEmpty && !scanner.isScanning {
                Task { await scanner.scan() }
            }
        }
        .confirmationDialog(loc.L("confirm_clean"), isPresented: $showCleanConfirmation) {
            Button(loc.currentLanguage == .chinese ? "清理 \(scanner.selectedCount) 个项目" : "Clean \(scanner.selectedCount) items", role: .destructive) {
                Task {
                    let result = await scanner.cleanSelected()
                    cleanResult = result
                    showResult = true
                    DiskSpaceManager.shared.updateDiskSpace()
                }
            }
            Button(loc.L("cancel"), role: .cancel) {}
        } message: {
            Text("将清理 \(ByteCountFormatter.string(fromByteCount: scanner.selectedSize, countStyle: .file)) 的残留文件，文件将被移至废纸篓。")
        }
        .alert(loc.L("clean_complete"), isPresented: $showResult) {
            Button(loc.L("confirm")) { showResult = false }
        } message: {
            if let result = cleanResult {
                Text("已清理 \(result.count) 个项目，释放了 \(ByteCountFormatter.string(fromByteCount: result.size, countStyle: .file)) 空间")
            }
        }
        .sheet(isPresented: $showingDetails) {
            detailSheet
        }
    }
    
    // MARK: - 头部视图
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.L("deep_clean"))
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                Text(loc.L("deepClean_desc"))
                    .foregroundColor(.secondaryText)
            }
            Spacer()
            
            if !scanner.isScanning && !scanner.orphanedItems.isEmpty {
                HStack(spacing: 12) {
                    Button(action: { scanner.selectAll() }) {
                        Text(loc.L("selectAll"))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { scanner.deselectAll() }) {
                        Text(loc.L("deselectAll"))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
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
                    Text(loc.currentLanguage == .chinese ? "残留文件 (\(scanner.orphanedItems.count))" : "Orphaned Files (\(scanner.orphanedItems.count))")
                        .font(.headline)
                        .foregroundColor(.secondaryText)
                        .padding(.leading, 4)
                    
                    orphanedListView
                }
                .frame(maxWidth: .infinity)
                
                // 右侧预览区
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.currentLanguage == .chinese ? "清理效果" : "Cleanup Result")
                        .font(.headline)
                        .foregroundColor(.secondaryText)
                    
                    cleanupPreviewCard
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
            DeepCleanStatsCard(
                icon: "folder.badge.questionmark",
                title: loc.currentLanguage == .chinese ? "应用残留" : "App Leftovers",
                count: count(for: .applicationSupport) + count(for: .containers),
                size: size(for: .applicationSupport) + size(for: .containers),
                color: .orange
            )
            
            DeepCleanStatsCard(
                icon: "internaldrive",
                title: loc.currentLanguage == .chinese ? "缓存文件" : "Cache Files",
                count: count(for: .caches),
                size: size(for: .caches),
                color: .blue
            )
            
            DeepCleanStatsCard(
                icon: "doc.text",
                title: loc.currentLanguage == .chinese ? "日志文件" : "Log Files",
                count: count(for: .logs),
                size: size(for: .logs),
                color: .purple
            )
        }
    }
    
    private func count(for type: OrphanedType) -> Int {
        scanner.orphanedItems.filter { $0.type == type }.count
    }
    
    private func size(for type: OrphanedType) -> Int64 {
        scanner.orphanedItems.filter { $0.type == type }.reduce(0) { $0 + $1.size }
    }
    
    // MARK: - 残留文件列表
    private var orphanedListView: some View {
        List {
            ForEach(OrphanedType.allCases, id: \.self) { type in
                let typeItems = scanner.orphanedItems.filter { $0.type == type }
                if !typeItems.isEmpty {
                    Section(header:
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(type.color)
                            Text(localizedTypeName(for: type))
                            Text("(\(typeItems.count))")
                                .foregroundColor(.gray)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: typeItems.reduce(0) { $0 + $1.size }, countStyle: .file))
                                .foregroundColor(.gray)
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.vertical, 4)
                    ) {
                        ForEach(typeItems) { item in
                            DeepCleanRow(item: item, scanner: scanner)
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
    
    private func localizedTypeName(for type: OrphanedType) -> String {
        switch type {
        case .applicationSupport:
            return loc.L("app_support")
        case .caches:
            return loc.L("cache")
        case .preferences:
            return loc.L("preferences")
        case .containers:
            return loc.currentLanguage == .chinese ? "沙盒容器" : "Sandbox Containers"
        case .savedState:
            return loc.L("saved_state")
        case .logs:
            return loc.L("logs")
        }
    }
    
    // MARK: - 预览卡片
    private var cleanupPreviewCard: some View {
        VStack(spacing: 24) {
            HStack(spacing: 20) {
                // Before
                VStack {
                    Image(systemName: "folder.fill.badge.minus")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text(loc.currentLanguage == .chinese ? "残留文件" : "Leftovers")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(ByteCountFormatter.string(fromByteCount: scanner.totalSize, countStyle: .file))
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                // After
                VStack {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "folder.fill")
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
                    Text(ByteCountFormatter.string(fromByteCount: scanner.selectedSize, countStyle: .file))
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
                if scanner.selectedCount > 0 {
                    showCleanConfirmation = true
                }
            }) {
                Text(loc.currentLanguage == .chinese ? "深度清理" : "Deep Clean")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 200, height: 44)
                    .background(
                        LinearGradient(colors: [Color(red: 0.0, green: 0.6, blue: 0.4), Color(red: 0.0, green: 0.4, blue: 0.3)], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(22)
                    .shadow(color: Color(red: 0.0, green: 0.4, blue: 0.3).opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(scanner.selectedCount == 0)
            
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
                    .stroke(Color.green, lineWidth: 10)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .rotationEffect(.degrees(Double.random(in: 0...360)))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: UUID())
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            }
            Text(scanner.scanProgress)
                .font(.title3)
                .foregroundColor(.white)
            Spacer()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundColor(.green)
            Text(loc.currentLanguage == .chinese ? "系统很干净!" : "System is Clean!")
                .font(.title)
                .foregroundColor(.white)
            Text(loc.L("no_orphaned_files"))
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
                Text(loc.currentLanguage == .chinese ? "扫描详情" : "Scan Details")
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
                ForEach(scanner.orphanedItems) { item in
                    HStack {
                        Image(systemName: item.type.icon)
                            .foregroundColor(item.type.color)
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.system(size: 13, weight: .medium))
                            Text(item.url.path)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Text(item.formattedSize)
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

struct DeepCleanStatsCard: View {
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
                    Text("项")
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

struct DeepCleanRow: View {
    let item: OrphanedItem
    @ObservedObject var scanner: DeepCleanScanner
    
    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { item.isSelected },
                set: { _ in scanner.toggleSelection(for: item) }
            ))
            .toggleStyle(CheckboxStyle())
            .labelsHidden()
            
            Image(systemName: item.type.icon)
                .foregroundColor(item.type.color)
            
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primaryText)
                if let bundleId = item.bundleId {
                    Text(bundleId)
                        .font(.system(size: 11))
                        .foregroundColor(.secondaryText)
                }
            }
            
            Spacer()
            
            Text(item.formattedSize)
                .font(.system(size: 13))
                .foregroundColor(.primaryText)
        }
        .padding(.vertical, 4)
    }
}
