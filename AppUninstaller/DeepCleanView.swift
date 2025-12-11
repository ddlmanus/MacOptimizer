import SwiftUI

struct DeepCleanView: View {
    @StateObject private var scanner = DeepCleanScanner()
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var showCleanConfirmation = false
    @State private var cleanResult: (count: Int, size: Int64)?
    @State private var showResult = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Disk Usage
                DiskUsageView()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                
                // Content
                if scanner.isScanning {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(scanner.scanProgress)
                            .foregroundColor(.secondaryText)
                            .font(.subheadline)
                    }
                    Spacer()
                } else if scanner.orphanedItems.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 64))
                            .foregroundColor(.green.opacity(0.6))
                        Text(loc.currentLanguage == .chinese ? "系统很干净!" : "System is Clean!")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.9))
                        Text(loc.L("no_orphaned_files"))
                            .font(.subheadline)
                            .foregroundColor(.tertiaryText)
                        
                        Button(action: { Task { await scanner.scan() } }) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text(loc.currentLanguage == .chinese ? "重新扫描" : "Rescan")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                } else {
                    // Results List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Group by type
                            ForEach(OrphanedType.allCases, id: \.self) { type in
                                let typeItems = scanner.orphanedItems.filter { $0.type == type }
                                if !typeItems.isEmpty {
                                    OrphanedTypeSection(
                                        type: type,
                                        items: typeItems,
                                        loc: loc,
                                        onToggle: { item in
                                            scanner.toggleSelection(for: item)
                                        }
                                    )
                                }
                            }
                            
                            // 底部留白
                            Color.clear.frame(height: 150)
                        }
                        .padding(24)
                    }
                }
            }
            
            // 底部悬浮按钮
            if !scanner.orphanedItems.isEmpty && !scanner.isScanning {
                VStack {
                    Spacer()
                    cleanButton
                        .padding(.bottom, 10)
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
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(loc.L("deep_clean"))
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                Text(loc.L("deepClean_desc"))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            if !scanner.isScanning {
                HStack(spacing: 12) {
                    if !scanner.orphanedItems.isEmpty {
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
                    }
                    
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
    }
    
    // MARK: - 清理按钮 (大圆圈)
    private var cleanButton: some View {
        Button(action: { showCleanConfirmation = true }) {
            ZStack {
                // 外圈光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.0, green: 0.4, blue: 0.3).opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                
                // 主圆圈
                Circle()
                    .fill(GradientStyles.deepClean)
                    .frame(width: 90, height: 90)
                    .shadow(color: Color(red: 0.0, green: 0.4, blue: 0.3).opacity(0.5), radius: 15, x: 0, y: 8)
                
                // 内容
                VStack(spacing: 2) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    Text(loc.L("deep_clean"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Text(ByteCountFormatter.string(fromByteCount: scanner.selectedSize, countStyle: .file))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(scanner.selectedCount == 0)
    }
}

// MARK: - Section View

struct OrphanedTypeSection: View {
    let type: OrphanedType
    let items: [OrphanedItem]
    @ObservedObject var loc: LocalizationManager
    let onToggle: (OrphanedItem) -> Void
    
    @State private var isExpanded = true
    
    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }
    
    // 获取本地化的类型名
    private var localizedTypeName: String {
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: type.icon)
                        .foregroundColor(type.color)
                        .frame(width: 24)
                    
                    Text(localizedTypeName)
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    
                    Text("(\(items.count))")
                        .font(.subheadline)
                        .foregroundColor(.tertiaryText)
                    
                    Spacer()
                    
                    Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.tertiaryText)
                        .font(.caption)
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            // Items
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        OrphanedItemRow(item: item, onToggle: onToggle)
                    }
                }
                .padding(.top, 8)
                .padding(.leading, 36)
            }
        }
    }
}

// MARK: - Item Row

struct OrphanedItemRow: View {
    let item: OrphanedItem
    let onToggle: (OrphanedItem) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: { onToggle(item) }) {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isSelected ? .green : .gray)
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                if let bundleId = item.bundleId {
                    Text(bundleId)
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryText)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(item.formattedSize)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondaryText)
        }
        .padding(10)
        .background(Color.white.opacity(item.isSelected ? 0.08 : 0.03))
        .cornerRadius(8)
    }
}
