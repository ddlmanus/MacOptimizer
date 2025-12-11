import SwiftUI

struct JunkCleanerView: View {
    @StateObject private var cleaner = JunkCleaner()
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var showingCleanAlert = false
    @State private var cleanedAmount: Int64 = 0
    @State private var animateScan = false
    @State private var pulse = false
    
    // 汇总状态
    var totalFoundSize: Int64 {
        cleaner.junkItems.reduce(0) { $0 + $1.size }
    }
    
    var body: some View {
        ZStack {
            // 背景
            // Color.mainBackground.ignoresSafeArea() // Use parent gradient
            
            VStack(spacing: 0) {
                // 头部
                headerView
                
                // 内容区
                if cleaner.isScanning {
                    scanningView
                } else if cleaner.junkItems.isEmpty {
                    emptyStateView
                } else {
                    scanResultView
                }
            }
            
            // 底部悬浮操作栏 (仅在有结果且未扫描时显示)
            if !cleaner.isScanning && !cleaner.junkItems.isEmpty {
                VStack {
                    Spacer()
                    bottomActionBar
                        .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            if cleaner.junkItems.isEmpty {
                Task { await cleaner.scanJunk() }
            }
        }
        .alert(loc.L("clean_complete"), isPresented: $showingCleanAlert) {
            Button(loc.L("confirm"), role: .cancel) {}
        } message: {
            Text(loc.currentLanguage == .chinese ? "成功清理了 \(ByteCountFormatter.string(fromByteCount: cleanedAmount, countStyle: .file)) 的垃圾文件。" : "Cleaned \(ByteCountFormatter.string(fromByteCount: cleanedAmount, countStyle: .file)) of junk files.")
        }
    }
    
    // MARK: - 头部视图
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(loc.currentLanguage == .chinese ? "系统垃圾清理" : "System Junk Cleaner")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                Text(loc.currentLanguage == .chinese ? "移除缓存、日志和临时文件，释放空间" : "Remove cache, logs and temp files to free up space")
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            
            // Disk Usage (Compact)
            DiskUsageView()
                .frame(width: 250)
        }
        .padding(32)
    }
    
    // MARK: - 扫描动画视图 (类似仪表盘)
    private var scanningView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            ZStack {
                // 外层脉冲
                Circle()
                    .fill(GradientStyles.cleaner.opacity(0.1))
                    .frame(width: 240, height: 240)
                    .scaleEffect(pulse ? 1.2 : 1.0)
                    .opacity(pulse ? 0 : 0.5)
                    .onAppear {
                        withAnimation(Animation.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                            pulse = true
                        }
                    }
                
                // 旋转光环
                Circle()
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: [.cleanerStart.opacity(0), .cleanerStart]), center: .center),
                        lineWidth: 4
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(animateScan ? 360 : 0))
                    .animation(Animation.linear(duration: 2).repeatForever(autoreverses: false), value: animateScan)
                    .onAppear { animateScan = true }
                
                // 中心图标
                Image(systemName: "sparkles")
                    .font(.system(size: 64))
                    .foregroundStyle(GradientStyles.cleaner)
            }
            
            VStack(spacing: 12) {
                Text(loc.currentLanguage == .chinese ? "正在深入扫描..." : "Deep Scanning...")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                ProgressView(value: cleaner.scanProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .cleanerStart))
                    .frame(width: 240)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(10)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 扫描结果视图 (分组卡片)
    private var scanResultView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 汇总摘要
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(GradientStyles.cleaner)
                            .frame(width: 64, height: 64)
                        Image(systemName: "trash.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc.currentLanguage == .chinese ? "发现垃圾文件" : "Junk Files Found")
                            .font(.headline)
                            .foregroundColor(.secondaryText)
                        
                        Text(ByteCountFormatter.string(fromByteCount: totalFoundSize, countStyle: .file))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 10)
                
                // 分组列表
                ForEach(JunkType.allCases) { type in
                    let items = cleaner.junkItems.filter { $0.type == type }
                    if !items.isEmpty {
                        JunkGroupCard(type: type, items: items, cleaner: cleaner, loc: loc)
                    }
                }
                
                // 底部留白给悬浮Bar
                Color.clear.frame(height: 100)
            }
            .padding(24)
        }
    }
    
    // MARK: - 底部悬浮操作栏
    private var bottomActionBar: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text(loc.currentLanguage == .chinese ? "即将清理" : "To Clean")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                Text(ByteCountFormatter.string(fromByteCount: cleaner.selectedSize, countStyle: .file))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(GradientStyles.cleaner)
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    cleanedAmount = await cleaner.cleanSelected()
                    showingCleanAlert = true
                }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text(loc.currentLanguage == .chinese ? "立即清理" : "Clean Now")
                }
                .fontWeight(.semibold)
                .frame(minWidth: 140)
            }
            .buttonStyle(CapsuleButtonStyle(gradient: GradientStyles.cleaner))
            .disabled(cleaner.selectedSize == 0)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground.opacity(0.95))
                .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.success.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(GradientStyles.cleaner)
            }
            
            VStack(spacing: 8) {
                Text(loc.currentLanguage == .chinese ? "系统非常干净" : "System is Very Clean")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(loc.currentLanguage == .chinese ? "没有发现需要清理的垃圾文件" : "No junk files found")
                    .foregroundColor(.secondaryText)
            }
            Spacer()
        }
    }
}

// MARK: - 垃圾分组卡片
struct JunkGroupCard: View {
    let type: JunkType
    let items: [JunkItem]
    @ObservedObject var cleaner: JunkCleaner
    @ObservedObject var loc: LocalizationManager
    @State private var isExpanded = false
    
    var groupSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }
    
    var isAllSelected: Bool {
        items.allSatisfy { $0.isSelected }
    }
    
    // 获取本地化的类型名
    private var localizedTypeName: String {
        switch type {
        case .userCache:
            return loc.currentLanguage == .chinese ? "用户缓存" : "User Cache"
        case .userLogs:
            return loc.currentLanguage == .chinese ? "用户日志" : "User Logs"
        case .trash:
            return loc.L("trash")
        case .browserCache:
            return loc.currentLanguage == .chinese ? "浏览器缓存" : "Browser Cache"
        case .appCache:
            return loc.currentLanguage == .chinese ? "应用缓存" : "App Cache"
        case .xcodeDerivedData:
            return "Xcode DerivedData"
        }
    }
    
    // 获取本地化的描述
    private var localizedDescription: String {
        switch type {
        case .userCache:
            return loc.currentLanguage == .chinese ? "应用程序产生的临时缓存文件" : "Temporary cache files from applications"
        case .userLogs:
            return loc.currentLanguage == .chinese ? "应用程序运行日志和崩溃报告" : "App logs and crash reports"
        case .trash:
            return loc.currentLanguage == .chinese ? "废纸篓中的已删除文件" : "Deleted files in Trash"
        case .browserCache:
            return loc.currentLanguage == .chinese ? "Chrome、Safari 等浏览器的临时文件" : "Temp files from Chrome, Safari, etc."
        case .appCache:
            return loc.currentLanguage == .chinese ? "邮件附件、微信等应用的缓存文件" : "Cache from Mail, WeChat, etc."
        case .xcodeDerivedData:
            return loc.currentLanguage == .chinese ? "Xcode 编译产生的中间文件" : "Intermediate build files from Xcode"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 卡片头部 (可点击展开)
            HStack(spacing: 16) {
                // 类型图标
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(GradientStyles.cleaner)
                }
                
                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedTypeName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                // 大小
                Text(ByteCountFormatter.string(fromByteCount: groupSize, countStyle: .file))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.trailing, 8)
                
                // 展开箭头
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.cardBackground)
            // 整个头部背景可点击以展开
            .onTapGesture {
                withAnimation { isExpanded.toggle() }
            }
            
            // 展开的详情列表
            if isExpanded {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1)
                    
                    // 全选控制
                    HStack {
                        Toggle("选择全部 \(items.count) 个项目", isOn: Binding(
                            get: { isAllSelected },
                            set: { newValue in
                                for item in items { item.isSelected = newValue }
                                cleaner.objectWillChange.send() // 触发UI刷新
                            }
                        ))
                        .toggleStyle(CheckboxStyle())
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.2))
                    
                    // 文件列表
                    ForEach(items.prefix(10)) { item in // 限制显示数量以防卡顿，或使用LazyVStack
                        HStack(spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { item.isSelected },
                                set: { newValue in
                                    item.isSelected = newValue
                                    cleaner.objectWillChange.send()
                                }
                            ))
                            .toggleStyle(CheckboxStyle())
                            .labelsHidden()
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 13))
                                    .foregroundColor(.primaryText)
                                    .lineLimit(1)
                                Text(item.path.path)
                                    .font(.system(size: 10))
                                    .foregroundColor(.tertiaryText)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.1))
                    }
                    
                    if items.count > 10 {
                        Text("还有 \(items.count - 10) 个项目...")
                            .font(.caption)
                            .foregroundColor(.tertiaryText)
                            .padding(12)
                    }
                }
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isExpanded ? Color.cleanerStart.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
    }
}
