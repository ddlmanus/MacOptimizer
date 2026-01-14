import SwiftUI
import AppKit
import AVKit

struct ContentView: View {
    @State private var selectedModule: AppModule = .smartClean
    // @State private var showIntro = false // Video disabled
    
    var body: some View {
        ZStack {
            // 主内容
            mainContent
        }
        .frame(minWidth: 1000, minHeight: 700)
    }
    
    private var mainContent: some View {
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
                            DeepCleanView(selectedModule: $selectedModule)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .cleaner:
                            JunkCleanerView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .maintenance:
                            MaintenanceView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .optimizer:
                            OptimizerView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .largeFiles:
                            LargeFileView(selectedModule: $selectedModule)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .shredder:
                            ShredderView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .fileExplorer:
                            FileExplorerView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .spaceLens:
                            SpaceLensView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .trash:
                            TrashView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .monitor:
                            MonitorView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .privacy:
                            PrivacyView(selectedModule: $selectedModule)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .malware:
                            MalwareView(selectedModule: $selectedModule)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .smartClean:
                            SmartCleanerView(selectedModule: $selectedModule)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .updater:
                            AppUpdaterView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: selectedModule)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - 开场视频视图
struct IntroVideoView: View {
    let onComplete: () -> Void
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                // 使用自定义的 VideoPlayerView 替代 SwiftUI 的 VideoPlayer
                VideoPlayerView(player: player)
                    .ignoresSafeArea()
            }
            
            // 跳过按钮
            VStack {
                HStack {
                    Spacer()
                    Button(action: onComplete) {
                        Text("跳过")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    .padding(20)
                }
                Spacer()
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private func setupPlayer() {
        guard let url = Bundle.main.url(forResource: "Intro", withExtension: "mp4") else {
            // 如果找不到视频，直接完成
            onComplete()
            return
        }
        
        player = AVPlayer(url: url)
        player?.play()
        
        // 视频播放完毕时回调
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            onComplete()
        }
    }
}

// MARK: - 自定义视频播放器视图（使用 AVPlayerLayer 避免兼容性问题）
struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> NSView {
        let view = VideoLayerView()
        view.player = player
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? VideoLayerView {
            view.player = player
        }
    }
}

// 使用 CALayer 的视图来承载 AVPlayerLayer
class VideoLayerView: NSView {
    var player: AVPlayer? {
        didSet {
            playerLayer.player = player
        }
    }
    
    private let playerLayer = AVPlayerLayer()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private func setupLayer() {
        wantsLayer = true
        layer = CALayer()
        playerLayer.videoGravity = .resizeAspect
        layer?.addSublayer(playerLayer)
    }
    
    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}

// 包装现有的 Uninstaller 视图
struct UninstallerMainView: View {
    @StateObject private var appScanner = AppScanner()
    
    var body: some View {
        AppUninstallerView(appScanner: appScanner)
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
