import SwiftUI
import AppKit

// MARK: - 应用详情视图
struct AppDetailView: View {
    @ObservedObject var app: InstalledApp
    @ObservedObject private var loc = LocalizationManager.shared
    let onDelete: (Bool, Bool) -> Void
    
    @State private var includeApp = true
    @State private var moveToTrash = true
    @State private var selectAll = true
    
    var selectedFilesCount: Int {
        app.residualFiles.filter { $0.isSelected }.count
    }
    
    var selectedFilesSize: Int64 {
        app.residualFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    var totalDeleteSize: Int64 {
        selectedFilesSize + (includeApp ? app.size : 0)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 应用信息头部
            headerView
            
            // 残留文件列表
            if app.isScanning {
                scanningView
            } else if app.residualFiles.isEmpty {
                noResidualView
            } else {
                residualFilesView
            }
            
            // 底部操作栏
            bottomBar
        }
        .onChange(of: selectAll) { newValue in
            for file in app.residualFiles {
                file.isSelected = newValue
            }
        }
    }
    
    // MARK: - 头部视图
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 24) {
                // 应用图标 - 带发光效果
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.uninstallerStart.opacity(0.2), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 110, height: 110)
                    
                    Image(nsImage: app.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
                
                // 应用信息
                VStack(alignment: .leading, spacing: 10) {
                    Text(app.name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.primaryText)
                    
                    if let bundleId = app.bundleIdentifier {
                        Text(bundleId)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.tertiaryText)
                            .lineLimit(1)
                    }
                    
                    // 统计信息
                    HStack(spacing: 12) {
                        StatBadge(
                            icon: "internaldrive.fill",
                            label: loc.text(
    simplifiedChinese: "应用大小",
    traditionalChinese: "應用大小",
    english: "App Size",
    japanese: "アプリサイズ",
    korean: "앱 크기",
    russian: "Размер приложения"
),
                            value: app.formattedSize,
                            color: .uninstallerStart
                        )
                        
                        if !app.residualFiles.isEmpty {
                            StatBadge(
                                icon: "doc.on.doc.fill",
                                label: loc.L("residual_files"),
                                value: loc.text(
    simplifiedChinese: "\(app.residualFiles.count) 个",
    traditionalChinese: "個",
    english: "\(app.residualFiles.count)",
    japanese: "\(app.residualFiles.count)",
    korean: "\(app.residualFiles.count)",
    russian: "\(app.residualFiles.count)"
),
                                color: .warning
                            )
                            
                            StatBadge(
                                icon: "trash.fill",
                                label: loc.text(
    simplifiedChinese: "可清理",
    traditionalChinese: "可清理",
    english: "Cleanable",
    japanese: "清掃可能",
    korean: "청소 가능",
    russian: "очищаемый"
),
                                value: app.formattedResidualSize,
                                color: .danger
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding(28)
            
            // 分隔线
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
        }
        .background(Color.cardBackground.opacity(0.5))
    }
    
    // MARK: - 扫描中视图
    private var scanningView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.uninstallerStart.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .uninstallerStart))
                    .scaleEffect(1.4)
            }
            
            Text(loc.text(
    simplifiedChinese: "正在扫描残留文件...",
    traditionalChinese: "正在掃描殘留檔案...",
    english: "Scanning residual files...",
    japanese: "残りのファイルをスキャンしています...",
    korean: "잔여 파일 검색 중...",
    russian: "Сканирование остаточных файлов..."
))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondaryText)
            
            Spacer()
        }
    }
    
    // MARK: - 无残留文件视图
    private var noResidualView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.success.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.success)
            }
            
            VStack(spacing: 8) {
                Text(loc.text(
    simplifiedChinese: "太棒了！",
    traditionalChinese: "太棒了！",
    english: "Excellent!",
    japanese: "エクセレント！",
    korean: "매우 훌륭!",
    russian: "Отлично!"
))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                Text(loc.text(
    simplifiedChinese: "此应用没有检测到残留文件",
    traditionalChinese: "此應用沒有偵測到殘留文件",
    english: "No residual files detected for this app",
    japanese: "このアプリの残りのファイルは検出されませんでした",
    korean: "이 앱에 대해 감지된 잔여 파일이 없습니다",
    russian: "Для этого приложения не обнаружено остаточных файлов"
))
                    .font(.system(size: 14))
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 残留文件列表
    private var residualFilesView: some View {
        VStack(spacing: 0) {
            // 列表头部
            HStack {
                Toggle(isOn: $selectAll) {
                    Text(loc.L("selectAll"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondaryText)
                }
                .toggleStyle(CheckboxStyle())
                
                Spacer()
                
                // 已选择统计
                HStack(spacing: 6) {
                    Text("\(selectedFilesCount)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(GradientStyles.uninstaller)
                    Text(loc.text(
    simplifiedChinese: "/ \(app.residualFiles.count) 已选择",
    traditionalChinese: "/\(app.residualFiles.count)已選擇",
    english: "/ \(app.residualFiles.count) selected",
    japanese: "選択",
    korean: "/\(app.residualFiles.count) selected",
    russian: "/ \(app.residualFiles.count) выбрано"
))
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryText)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.02))
            
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
            
            // 文件列表
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(FileType.allCases) { type in
                        let filesOfType = app.residualFiles.filter { $0.type == type }
                        if !filesOfType.isEmpty {
                            FileTypeSection(type: type, files: filesOfType, loc: loc)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - 底部操作栏
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
            
            HStack(spacing: 24) {
                // 删除选项
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $includeApp) {
                        HStack(spacing: 6) {
                            Image(systemName: "app.fill")
                                .font(.system(size: 11))
                            Text(loc.text(
    simplifiedChinese: "包含应用本体",
    traditionalChinese: "包含應用本體",
    english: "Include App",
    japanese: "アプリを含める",
    korean: "앱 포함",
    russian: "Включить приложение"
))
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.primaryText.opacity(0.85))
                    }
                    .toggleStyle(CheckboxStyle())
                    
                    Toggle(isOn: $moveToTrash) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text(loc.text(
    simplifiedChinese: "移至废纸篓（可恢复）",
    traditionalChinese: "移至廢紙簍（可恢復）",
    english: "Move to Trash (Recoverable)",
    japanese: "ゴミ箱に移動（回復可能）",
    korean: "휴지통으로 이동 (복구 가능)",
    russian: "Переместить в корзину (восстанавливаемый)"
))
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.primaryText.opacity(0.85))
                    }
                    .toggleStyle(CheckboxStyle())
                }
                
                Spacer()
                
                // 删除统计
                VStack(alignment: .trailing, spacing: 4) {
                    Text(loc.text(
    simplifiedChinese: "将清理",
    traditionalChinese: "將清理",
    english: "To Clean",
    japanese: "クリーンアップ方法",
    korean: "청소 방법:",
    russian: "для чистки"
))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.tertiaryText)
                    
                    Text(ByteCountFormatter.string(fromByteCount: totalDeleteSize, countStyle: .file))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(GradientStyles.uninstaller)
                }
                .padding(.trailing, 20)
                
                // 删除按钮
                Button(action: {
                    onDelete(includeApp, moveToTrash)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: includeApp ? "trash.fill" : "paintbrush.fill")
                            .font(.system(size: 14))
                        Text(includeApp
                            ? loc.text(
                                simplifiedChinese: "卸载应用",
                                traditionalChinese: "解除安裝應用程式",
                                english: "Uninstall",
                                japanese: "アンインストール",
                                korean: "앱 제거",
                                russian: "Удалить приложение"
                            )
                            : loc.text(
                                simplifiedChinese: "清理残留",
                                traditionalChinese: "清理殘留檔案",
                                english: "Clean",
                                japanese: "残留ファイルを削除",
                                korean: "잔여 파일 정리",
                                russian: "Очистить остатки"
                            ))
                    }
                }
                .buttonStyle(PrimaryButtonStyle(isDestructive: includeApp))
                .disabled(selectedFilesCount == 0 && !includeApp)
            }
            .padding(24)
            .background(Color.cardBackground)
        }
    }
}



// MARK: - 统计徽章
struct StatBadge: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .uninstallerStart
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.tertiaryText)
                
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primaryText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - 文件类型分组
struct FileTypeSection: View {
    let type: FileType
    let files: [ResidualFile]
    @ObservedObject var loc: LocalizationManager
    @State private var isExpanded = true
    
    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }
    
    // 获取本地化的类型名
    private var localizedTypeName: String {
        switch type {
        case .preferences:
            return loc.L("preferences")
        case .applicationSupport:
            return loc.L("app_support")
        case .caches:
            return loc.L("cache")
        case .containers:
            return loc.L("containers")
        case .savedState:
            return loc.L("saved_state")
        case .logs:
            return loc.L("logs")
        case .groupContainers:
            return loc.L("group_containers")
        case .cookies:
            return loc.L("cookies")
        case .launchAgents:
            return loc.L("launch_agents")
        case .crashReports:
            return loc.L("crash_reports")
        case .developer:
            return loc.text(
    simplifiedChinese: "开发数据",
    traditionalChinese: "開發數據",
    english: "Developer Data",
    japanese: "デベロッパーデータ",
    korean: "개발자 데이터",
    russian: "Данные разработчика:"
)
        case .httpStorages:
            return loc.text(simplifiedChinese: "网络存储", traditionalChinese: "網路儲存", english: "HTTP Storages", japanese: "HTTPストレージ", korean: "HTTP 저장소", russian: "HTTP-хранилища")
        case .webKit:
            return loc.text(simplifiedChinese: "网页数据", traditionalChinese: "網頁資料", english: "WebKit Data", japanese: "WebKitデータ", korean: "WebKit 데이터", russian: "Данные WebKit")
        case .applicationScripts:
            return loc.text(simplifiedChinese: "应用脚本", traditionalChinese: "應用程式腳本", english: "Application Scripts", japanese: "アプリケーションスクリプト", korean: "응용 프로그램 스크립트", russian: "Сценарии приложения")
        case .privilegedHelpers:
            return loc.text(simplifiedChinese: "特权助手", traditionalChinese: "特權輔助程式", english: "Privileged Helpers", japanese: "特権ヘルパー", korean: "권한 도우미", russian: "Привилегированные помощники")
        case .receipts:
            return loc.text(simplifiedChinese: "安装收据", traditionalChinese: "安裝收據", english: "Install Receipts", japanese: "インストールレシート", korean: "설치 영수증", russian: "Квитанции установки")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 分组头部
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    // 图标
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: type.color).opacity(0.15))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: type.icon)
                            .font(.system(size: 12))
                            .foregroundColor(Color(nsColor: type.color))
                    }
                    
                    Text(localizedTypeName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primaryText)
                    
                    Text("(\(files.count))")
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryText)
                    
                    Spacer()
                    
                    Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondaryText)
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.tertiaryText)
                        .frame(width: 16)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.015))
            
            // 文件列表
            if isExpanded {
                ForEach(files) { file in
                    ResidualFileRow(file: file)
                }
            }
        }
    }
}

// MARK: - 残留文件行
struct ResidualFileRow: View {
    @ObservedObject var file: ResidualFile
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 14) {
            Toggle(isOn: $file.isSelected) {
                EmptyView()
            }
            .toggleStyle(CheckboxStyle())
            .labelsHidden()
            
            Image(systemName: "doc.fill")
                .font(.system(size: 11))
                .foregroundColor(.tertiaryText)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.system(size: 13))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                Text(file.path.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 11))
                    .foregroundColor(.tertiaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(file.formattedSize)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondaryText)
            
            // 在Finder中显示
            Button(action: {
                NSWorkspace.shared.selectFile(file.path.path, inFileViewerRootedAtPath: file.path.deletingLastPathComponent().path)
            }) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
            }
            .buttonStyle(IconButtonStyle(size: 26))
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(isHovering ? Color.white.opacity(0.025) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .scanResultContextMenu(
            isSelected: file.isSelected,
            displayName: file.fileName,
            url: file.path,
            onToggleSelection: { file.isSelected.toggle() }
        )
    }
}
