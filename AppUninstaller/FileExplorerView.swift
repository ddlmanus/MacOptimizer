import SwiftUI

struct FileExplorerView: View {
    @StateObject private var service = FileExplorerService()
    @State private var showNewFolderDialog = false
    @State private var showNewFileDialog = false
    @State private var showRenameDialog = false
    @State private var showDeleteConfirmation = false
    @State private var newItemName = ""
    @State private var selectedItem: ExplorerFileItem?
    @State private var pathInputText = ""
    @State private var isEditingPath = false
    @State private var viewMode: ViewMode = .list
    
    enum ViewMode {
        case list, grid
    }
    
    var body: some View {
        HSplitView {
            // 左侧边栏 - 快捷访问
            sidebarView
                .frame(width: 180)
            
            // 主内容区
            VStack(spacing: 0) {
                // 顶部工具栏
                toolbarView
                
                // 路径栏
                pathBarView
                
                // 文件列表
                if service.isLoading {
                    Spacer()
                    ProgressView()
                    Text("加载中...")
                        .foregroundColor(.secondaryText)
                    Spacer()
                } else if let error = service.error {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                        Button("返回上级目录") {
                            service.goUp()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                    }
                    .padding()
                    Spacer()
                } else {
                    fileListView
                }
            }
        }
        .sheet(isPresented: $showNewFolderDialog) {
            newItemDialog(title: "新建文件夹", placeholder: "文件夹名称") {
                try service.createFolder(name: newItemName)
            }
        }
        .sheet(isPresented: $showNewFileDialog) {
            newItemDialog(title: "新建文件", placeholder: "文件名称") {
                try service.createFile(name: newItemName)
            }
        }
        .sheet(isPresented: $showRenameDialog) {
            renameDialog
        }
        .confirmationDialog("确认删除", isPresented: $showDeleteConfirmation) {
            Button("移至废纸篓", role: .destructive) {
                if let item = selectedItem {
                    try? service.deleteItem(item, moveToTrash: true)
                }
            }
            Button("永久删除", role: .destructive) {
                if let item = selectedItem {
                    try? service.deleteItem(item, moveToTrash: false)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let item = selectedItem {
                Text("确定要删除 \"\(item.name)\" 吗？")
            }
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("快捷访问")
                .font(.caption)
                .foregroundColor(.tertiaryText)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            
            ForEach(service.quickAccessItems) { item in
                Button(action: { service.navigateTo(item.url) }) {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .frame(width: 20)
                            .foregroundColor(.blue)
                        Text(item.name)
                            .font(.system(size: 13))
                            .foregroundColor(.primaryText)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        service.currentPath == item.url
                            ? Color.white.opacity(0.1)
                            : Color.clear
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // 显示隐藏文件开关
            Toggle(isOn: $service.showHiddenFiles) {
                Text("显示隐藏文件")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .padding(16)
            .onChange(of: service.showHiddenFiles) { _ in
                service.refresh()
            }
        }
        .background(Color.black.opacity(0.2))
    }
    
    // MARK: - Toolbar
    
    private var toolbarView: some View {
        HStack(spacing: 12) {
            // 导航按钮
            HStack(spacing: 4) {
                Button(action: { service.goBack() }) {
                    Image(systemName: "chevron.left")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(!service.canGoBack)
                .foregroundColor(service.canGoBack ? .white : .gray)
                
                Button(action: { service.goForward() }) {
                    Image(systemName: "chevron.right")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(!service.canGoForward)
                .foregroundColor(service.canGoForward ? .white : .gray)
                
                Button(action: { service.goUp() }) {
                    Image(systemName: "chevron.up")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
            }
            .padding(4)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 8) {
                Button(action: { showNewFolderDialog = true }) {
                    Label("新建文件夹", systemImage: "folder.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.8))
                
                Button(action: { showNewFileDialog = true }) {
                    Label("新建文件", systemImage: "doc.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.8))
                
                Divider().frame(height: 20)
                
                Button(action: { openTerminalAtCurrentPath() }) {
                    Label("在终端中打开", systemImage: "terminal")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.8))
                
                Button(action: { service.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.15))
    }
    
    // MARK: - Path Bar
    
    private var pathBarView: some View {
        HStack(spacing: 8) {
            if isEditingPath {
                // 编辑模式 - 显示输入框
                TextField("输入路径...", text: $pathInputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(6)
                    .onSubmit {
                        navigateToInputPath()
                    }
                
                Button("跳转") {
                    navigateToInputPath()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.blue)
                
                Button("取消") {
                    isEditingPath = false
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondaryText)
            } else {
                // 正常模式 - 显示面包屑
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(service.pathComponents.enumerated()), id: \.offset) { index, component in
                            Button(action: { service.navigateTo(component.1) }) {
                                Text(component.0)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            
                            if index < service.pathComponents.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.tertiaryText)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 编辑按钮
                Button(action: {
                    pathInputText = service.currentPath.path
                    isEditingPath = true
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.1))
    }
    
    private func navigateToInputPath() {
        let path = pathInputText.trimmingCharacters(in: .whitespaces)
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            service.navigateTo(url)
            isEditingPath = false
        } else {
            service.error = "路径不存在或不是目录: \(path)"
        }
    }
    
    // MARK: - File List
    
    private var fileListView: some View {
        List(service.items) { item in
            HStack(spacing: 0) {
                ExplorerFileRow(item: item, isSelected: selectedItem?.id == item.id)
                
                Spacer()
                
                // 进入目录按钮
                if item.isDirectory {
                    Button(action: { service.navigateTo(item.url) }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.tertiaryText)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if item.isDirectory {
                    service.navigateTo(item.url)
                } else {
                    service.openItem(item)
                }
            }
            .onTapGesture {
                selectedItem = item
            }
            .contextMenu {
                contextMenuContent(for: item)
            }
            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
            .listRowBackground(
                selectedItem?.id == item.id
                    ? Color.blue.opacity(0.3)
                    : Color.clear
            )
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    @ViewBuilder
    private func contextMenuContent(for item: ExplorerFileItem) -> some View {
        let svc = service
        
        Button("打开", systemImage: "arrow.up.forward.square") {
            svc.openItem(item)
        }
        
        if item.isDirectory {
            Button("进入目录", systemImage: "folder") {
                svc.navigateTo(item.url)
            }
        }
        
        Divider()
        
        Button("在 Finder 中显示", systemImage: "folder.badge.gear") {
            svc.revealInFinder(item)
        }
        
        Divider()
        
        Button("重命名", systemImage: "pencil") {
            selectedItem = item
            newItemName = item.name
            showRenameDialog = true
        }
        
        Divider()
        
        Button("删除", systemImage: "trash", role: .destructive) {
            selectedItem = item
            showDeleteConfirmation = true
        }
    }
    
    // MARK: - Open Terminal
    
    private func openTerminalAtCurrentPath() {
        let path = service.currentPath.path
        let escapedPath = path.replacingOccurrences(of: "'", with: "'\\''")
        
        // 使用 osascript 命令 - 尝试在现有窗口执行，如果没有窗口则创建一个
        let script = """
        tell application "Terminal"
            if (count of windows) > 0 then
                do script "cd '\(escapedPath)'" in front window
            else
                do script "cd '\(escapedPath)'"
            end if
            activate
        end tell
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        do {
            try process.run()
        } catch {
            print("Failed to open terminal: \(error)")
        }
    }
    
    // MARK: - Dialogs
    
    private func newItemDialog(title: String, placeholder: String, action: @escaping () throws -> Void) -> some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)
            
            TextField(placeholder, text: $newItemName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            HStack {
                Button("取消") {
                    showNewFolderDialog = false
                    showNewFileDialog = false
                    newItemName = ""
                }
                .keyboardShortcut(.escape)
                
                Button("创建") {
                    do {
                        try action()
                        showNewFolderDialog = false
                        showNewFileDialog = false
                        newItemName = ""
                    } catch {
                        service.error = error.localizedDescription
                    }
                }
                .keyboardShortcut(.return)
                .disabled(newItemName.isEmpty)
            }
        }
        .padding(30)
    }
    
    private var renameDialog: some View {
        VStack(spacing: 20) {
            Text("重命名")
                .font(.headline)
            
            TextField("新名称", text: $newItemName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            HStack {
                Button("取消") {
                    showRenameDialog = false
                    newItemName = ""
                }
                .keyboardShortcut(.escape)
                
                Button("确定") {
                    if let item = selectedItem {
                        try? service.renameItem(item, to: newItemName)
                    }
                    showRenameDialog = false
                    newItemName = ""
                }
                .keyboardShortcut(.return)
                .disabled(newItemName.isEmpty)
            }
        }
        .padding(30)
    }
}

// MARK: - File Item Row

struct ExplorerFileRow: View {
    let item: ExplorerFileItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 24, height: 24)
            
            // 文件名
            Text(item.name)
                .font(.system(size: 13))
                .foregroundColor(.primaryText)
                .lineLimit(1)
            
            Spacer()
            
            // 大小
            Text(item.formattedSize)
                .font(.system(size: 11))
                .foregroundColor(.tertiaryText)
                .frame(width: 70, alignment: .trailing)
            
            // 修改时间
            Text(item.formattedDate)
                .font(.system(size: 11))
                .foregroundColor(.tertiaryText)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
        )
    }
}
