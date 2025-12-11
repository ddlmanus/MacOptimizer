import SwiftUI

struct DeepCleanView: View {
    @StateObject private var scanner = DeepCleanScanner()
    @State private var showCleanConfirmation = false
    @State private var cleanResult: (count: Int, size: Int64)?
    @State private var showResult = false
    
    var body: some View {
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
                    Text("系统很干净!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                    Text("没有发现已卸载应用的残留文件")
                        .font(.subheadline)
                        .foregroundColor(.tertiaryText)
                    
                    Button(action: { Task { await scanner.scan() } }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("重新扫描")
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
                                    onToggle: { item in
                                        scanner.toggleSelection(for: item)
                                    }
                                )
                            }
                        }
                    }
                    .padding(24)
                }
            }
            
            // Footer
            if !scanner.orphanedItems.isEmpty && !scanner.isScanning {
                footerView
            }
        }
        .onAppear {
            if scanner.orphanedItems.isEmpty && !scanner.isScanning {
                Task { await scanner.scan() }
            }
        }
        .confirmationDialog("确认清理", isPresented: $showCleanConfirmation) {
            Button("清理 \(scanner.selectedCount) 个项目", role: .destructive) {
                Task {
                    let result = await scanner.cleanSelected()
                    cleanResult = result
                    showResult = true
                    DiskSpaceManager.shared.updateDiskSpace()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将清理 \(ByteCountFormatter.string(fromByteCount: scanner.selectedSize, countStyle: .file)) 的残留文件，文件将被移至废纸篓。")
        }
        .alert("清理完成", isPresented: $showResult) {
            Button("确定") { showResult = false }
        } message: {
            if let result = cleanResult {
                Text("已清理 \(result.count) 个项目，释放了 \(ByteCountFormatter.string(fromByteCount: result.size, countStyle: .file)) 空间")
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("深度清理")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                Text("扫描已卸载应用的残留文件")
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            if !scanner.isScanning {
                HStack(spacing: 12) {
                    if !scanner.orphanedItems.isEmpty {
                        Button(action: { scanner.selectAll() }) {
                            Text("全选")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { scanner.deselectAll() }) {
                            Text("取消全选")
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
                            Text("刷新")
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
    
    private var footerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("已选择 \(scanner.selectedCount) / \(scanner.orphanedItems.count) 个项目")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("共 \(ByteCountFormatter.string(fromByteCount: scanner.selectedSize, countStyle: .file))")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            Button(action: { showCleanConfirmation = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text("深度清理")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    scanner.selectedCount > 0 
                        ? GradientStyles.deepClean 
                        : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(scanner.selectedCount == 0)
        }
        .padding(24)
        .background(Color.black.opacity(0.2))
    }
}

// MARK: - Section View

struct OrphanedTypeSection: View {
    let type: OrphanedType
    let items: [OrphanedItem]
    let onToggle: (OrphanedItem) -> Void
    
    @State private var isExpanded = true
    
    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: type.icon)
                        .foregroundColor(type.color)
                        .frame(width: 24)
                    
                    Text(type.rawValue)
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
