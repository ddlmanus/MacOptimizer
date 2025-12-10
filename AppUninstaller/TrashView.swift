import SwiftUI

struct TrashItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let dateDeleted: Date?
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var formattedDate: String {
        guard let date = dateDeleted else { return "未知" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

class TrashScanner: ObservableObject {
    @Published var items: [TrashItem] = []
    @Published var isScanning = false
    @Published var totalSize: Int64 = 0
    
    private let fileManager = FileManager.default
    private let trashURL: URL
    
    init() {
        trashURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
    }
    
    func scan() async {
        await MainActor.run {
            isScanning = true
            items = []
            totalSize = 0
        }
        
        var scannedItems: [TrashItem] = []
        var total: Int64 = 0
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
            
            for fileURL in contents {
                let size = calculateSize(at: fileURL)
                let date = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                
                let item = TrashItem(
                    url: fileURL,
                    name: fileURL.lastPathComponent,
                    size: size,
                    dateDeleted: date
                )
                scannedItems.append(item)
                total += size
            }
        } catch {
            print("Error scanning trash: \(error)")
        }
        
        let sortedItems = scannedItems.sorted { $0.size > $1.size }
        let finalTotal = total
        
        await MainActor.run {
            self.items = sortedItems
            self.totalSize = finalTotal
            self.isScanning = false
        }
    }
    
    func emptyTrash() async -> Int64 {
        var removedSize: Int64 = 0
        
        for item in items {
            do {
                try fileManager.removeItem(at: item.url)
                removedSize += item.size
            } catch {
                print("Failed to delete \(item.url.path): \(error)")
            }
        }
        
        await MainActor.run {
            items.removeAll()
            totalSize = 0
            DiskSpaceManager.shared.updateDiskSpace()
        }
        
        return removedSize
    }
    
    private func calculateSize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        var isDirectory: ObjCBool = false
        
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
                for case let fileURL as URL in enumerator {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                        totalSize += Int64(resourceValues.fileSize ?? 0)
                    } catch { continue }
                }
            } else {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: url.path)
                    totalSize = Int64(attributes[.size] as? UInt64 ?? 0)
                } catch { return 0 }
            }
        }
        return totalSize
    }
}

struct TrashView: View {
    @StateObject private var scanner = TrashScanner()
    @State private var showEmptyConfirmation = false
    
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
                ProgressView()
                    .scaleEffect(0.8)
                Text("正在扫描废纸篓...")
                    .foregroundColor(.secondaryText)
                    .padding(.top, 8)
                Spacer()
            } else if scanner.items.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "trash")
                        .font(.system(size: 64))
                        .foregroundColor(.white.opacity(0.2))
                    Text("废纸篓为空")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.5))
                    Text("已删除的文件会显示在这里")
                        .font(.subheadline)
                        .foregroundColor(.tertiaryText)
                }
                Spacer()
            } else {
                // Item List
                List {
                    ForEach(scanner.items) { item in
                        TrashItemRow(item: item)
                            .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            
            // Footer
            if !scanner.items.isEmpty {
                footerView
            }
        }
        .onAppear {
            Task { await scanner.scan() }
        }
        .confirmationDialog("清空废纸篓", isPresented: $showEmptyConfirmation) {
            Button("清空废纸篓", role: .destructive) {
                Task { await scanner.emptyTrash() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销，所有文件将被永久删除。")
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("废纸篓")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                Text("查看并管理已删除的文件")
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
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
        .padding(24)
    }
    
    private var footerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(scanner.items.count) 个项目")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("共 \(ByteCountFormatter.string(fromByteCount: scanner.totalSize, countStyle: .file))")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            Button(action: { showEmptyConfirmation = true }) {
                HStack {
                    Image(systemName: "trash.slash")
                    Text("清空废纸篓")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(GradientStyles.danger)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(Color.black.opacity(0.2))
    }
}

struct TrashItemRow: View {
    let item: TrashItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                Text("删除于 \(item.formattedDate)")
                    .font(.system(size: 11))
                    .foregroundColor(.tertiaryText)
            }
            
            Spacer()
            
            Text(item.formattedSize)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondaryText)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}
