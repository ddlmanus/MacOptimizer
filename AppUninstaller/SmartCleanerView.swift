import SwiftUI

// 扫描状态枚举
enum ScanState {
    case initial    // 初始页面
    case scanning   // 扫描中
    case cleaning   // 清理中
    case completed  // 扫描完成（结果页）
    case finished   // 清理完成（最终页）
}

struct SmartCleanerView: View {
    // 导航绑定 - 用于跳转到其他页面
    @Binding var selectedModule: AppModule
    
    // 使用共享的服务管理器
    @ObservedObject private var service = ScanServiceManager.shared.smartCleanerService
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var selectedCategory: CleanerCategory = .systemJunk
    @State private var showDeleteConfirmation = false
    @State private var deleteResult: (success: Int, failed: Int, size: Int64)?
    @State private var showResult = false
    @State private var showCleaningFinished = false
    @State private var showRunningAppsSafetyAlert = false
    
    // 管理员权限重试
    @State private var failedFiles: [CleanerFileItem] = []
    @State private var showRetryWithAdmin = false
    
    // Running Apps Dialog
    @State private var showRunningAppsDialog = false
    @State private var detectedRunningApps: [(name: String, icon: NSImage?, bundleId: String)] = []
    
    @State private var viewingLog = false
    @State private var showScanningTips = false
    @State private var showFailedFilesPopover = false
    @State private var failedFilesClipboardContent: String = ""
    
    // Detail Sheet State
    @State private var showDetailSheet = false
    @State private var initialDetailCategory: CleanerCategory? = nil
    
    // 扫描状态
    private var scanState: ScanState {
        if service.isScanning {
            return .scanning
        } else if service.isCleaning {
            // cleaningPage UI is simpler, we can reuse simplified scanning layout or keeping it
            return .cleaning
        } else if showRetryWithAdmin {
            return .cleaning 
        } else if showCleaningFinished {
            return .finished
        } else if hasScanResults {
            return .completed
        }
        return .initial
    }
    
    // 计算属性：检查 service 是否已有扫描结果
    private var hasScanResults: Bool {
        return service.systemJunkTotalSize > 0 ||
               !service.duplicateGroups.isEmpty ||
               !service.similarPhotoGroups.isEmpty ||
               !service.largeFiles.isEmpty ||
               !service.userCacheFiles.isEmpty ||
               !service.systemCacheFiles.isEmpty ||
               !service.virusThreats.isEmpty ||
               service.hasAppUpdates ||
               !service.startupItems.isEmpty //||
               // ⚠️ 暂时禁用：!service.performanceApps.isEmpty
    }

    // 计算扫描到的总大小
    private var totalScannedSize: Int64 {
        let topLevelCategories: [CleanerCategory] = [
            .systemJunk, .duplicates, .similarPhotos, .largeFiles, .virus
        ]
        return topLevelCategories.reduce(0) { $0 + service.sizeFor(category: $1) }
    }
    
    var body: some View {
        ZStack {
            // 背景 - 匹配设计图的紫靛色渐变
            BackgroundStyles.smartClean
                .ignoresSafeArea()
            
            // Main Content Area (With top padding for header)
            VStack {
                 // Spacer to account for fixed header + padding
                 Spacer().frame(height: 60)
                 
                 // Dynamic Content
                 if viewingLog {
                     cleaningLogPage
                         .transition(.opacity)
                 } else {
                     switch scanState {
                     case .initial:
                         initialPage
                     case .scanning:
                         scanningPage
                     case .completed:
                         resultsPage
                     case .cleaning:
                         cleaningPage
                     case .finished:
                         cleaningFinishedPage
                     }
                 }
            }
            .padding(.bottom, 100) // Increase padding to avoid button overlap

            // Fixed Header Overlay
            VStack {
                headerView
                Spacer()
            }
            .allowsHitTesting(true) // Ensure buttons in header are clickable

            // Floating Main Action Button
            VStack {
                Spacer()
                mainActionButton
                    .padding(.bottom, 30) // Raise button to be fully visible
            }
            
            if showRunningAppsDialog {
                runningAppsOverlay
            }
        }
        // Sheet for details
        .sheet(isPresented: $showDetailSheet) {
            AllCategoriesDetailSheet(
                service: service,
                loc: loc,
                isPresented: $showDetailSheet,
                initialCategory: initialDetailCategory
            )
        }
        // Alerts & Confirmations ... (Keeping existing logic)
        .confirmationDialog(
            loc.currentLanguage == .chinese ? "确认删除" : "Confirm Delete",
            isPresented: $showDeleteConfirmation
        ) {
            Button(loc.currentLanguage == .chinese ? "开始清理" : "Start Cleaning", role: .destructive) {
                Task {
                    let result = await service.cleanAll()
                    deleteResult = (result.success, result.failed, result.size)
                    failedFiles = result.failedFiles
                    if result.failed > 0 && !failedFiles.isEmpty {
                        showRetryWithAdmin = true
                    } else {
                        showCleaningFinished = true
                    }
                }
            }
            Button(loc.L("cancel"), role: .cancel) {}
        } message: {
            Text(loc.currentLanguage == .chinese ? "将清理所有选中的垃圾文件，释放空间。" : "Clean all selected files to free up space.")
        }
        .alert(loc.currentLanguage == .chinese ? "部分文件需要管理员权限" : "Some Files Require Admin Privileges", isPresented: $showRetryWithAdmin) {
             Button(loc.currentLanguage == .chinese ? "使用管理员权限删除" : "Delete with Admin", role: .destructive) {
                 Task {
                     let adminResult = await service.cleanWithPrivileges(files: failedFiles)
                     if let currentResult = deleteResult {
                         deleteResult = (
                             currentResult.success + adminResult.success,
                             adminResult.failed,
                             currentResult.size + adminResult.size
                         )
                     }
                     failedFiles = []
                     showCleaningFinished = true
                 }
             }
             Button(loc.L("cancel"), role: .cancel) { showCleaningFinished = true }
        } message: {

            Text(loc.currentLanguage == .chinese ?
                 "有 \(failedFiles.count) 个文件因权限不足无法删除。" :
                 "\(failedFiles.count) files could not be deleted due to permissions.")
        }
        }
    
    // MARK: - Header
    private var headerView: some View {
        ZStack {
            // Center Title
            Text(loc.currentLanguage == .chinese ? "智能扫描" : "Smart Scan")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
            
            // Left Action
            HStack {
                if viewingLog || scanState == .completed || scanState == .finished {
                    Button(action: { 
                        if viewingLog {
                            withAnimation { viewingLog = false }
                        }
                        Task { service.resetAll() } 
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text(loc.currentLanguage == .chinese ? "重新开始" : "Start Over")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Right Action - Assistant Button
                Button(action: {
                    // Placeholder for Assistant
                }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                        
                        Text(loc.currentLanguage == .chinese ? "助手" : "Assistant")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }
    
    // MARK: - Initial Page (Ready State)
    private var initialPage: some View {
        VStack {
            Spacer()
            
            // 核心图标区域 - 匹配设计图（无圆圈光晕）
            ZStack {
                // 显示器主图标 - 使用自定义图片
                if let imagePath = Bundle.main.path(forResource: "welcome", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 360, height: 360)
                        .shadow(color: Color.pink.opacity(0.2), radius: 20, x: 0, y: 8)
                } else {
                    // 备用：使用应用图标
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 260, height: 260)
                        .shadow(color: Color.pink.opacity(0.2), radius: 20, x: 0, y: 8)
                }
            }
            .padding(.bottom, 60)
            
            VStack(spacing: 12) {
                Text(loc.currentLanguage == .chinese ? "欢迎使用 Mac优化大师" : "Welcome to MacOptimizer")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundColor(.white)
                
                Text(loc.currentLanguage == .chinese ? "开始全面、仔细扫描您的 Mac。" : "Start a comprehensive and thorough scan of your Mac.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.bottom, 100)
            
            Spacer()
        }
    }

    // MARK: - Scanning Page (3-Column Layout)
    private var scanningPage: some View {
        VStack {
            // Title & Subtitle for Scanning - Added per user request
            VStack(spacing: 12) {
                Text(loc.currentLanguage == .chinese ? "正在查看它..." : "Checking it...")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
                
                Text(loc.currentLanguage == .chinese ? "稍等片刻。我们都希望它易如反掌。" : "Just a moment. We hope it's effortless.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
            
            threeColumnLayout(state: .scanning)
            
            Spacer()
        }
        .frame(height: 500) // Fixed height to prevent shifting during authorization alerts
    }
    
    // MARK: - Results Page (3-Column Layout)
    private var resultsPage: some View {
        VStack {
            // Title & Subtitle for Results
            VStack(spacing: 12) {
                Text(loc.currentLanguage == .chinese ? "好了，我发现的内容都在这里。" : "Okay, here's what I found.")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
                
                Text(loc.currentLanguage == .chinese ? "保持您的 Mac 干净、安全、性能优化的所有任务正在等候。立即运行！" : "All tasks to keep your Mac clean, safe, and optimized are waiting. Run now!")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
            
            threeColumnLayout(state: .completed)
            
            Spacer()
        }
    }
    
    // MARK: - Cleaning/Finished Pages
    // MARK: - Cleaning Page (3-Column Layout, similar to Scanning)
    private var cleaningPage: some View {
        VStack {
            Spacer().frame(height: 60)
            
            HStack(spacing: 80) {
                Group {
                    if let category = service.cleaningCurrentCategory {
                        let iconName = getIconFor(category: category)
                        if let imagePath = Bundle.main.path(forResource: iconName, ofType: "png"),
                           let nsImage = NSImage(contentsOfFile: imagePath) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 240, height: 240)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                ))
                                .id(category) // unique ID triggers transition
                                .modifier(CleaningLargeIconAnimation())
                        } else {
                            Image(systemName: "gearshape.2.fill")
                                .font(.system(size: 120))
                                .foregroundColor(.blue)
                        }
                    } else {
                        // Fallback
                        ProgressView()
                            .scaleEffect(2.0)
                            .frame(width: 240, height: 240)
                    }
                }
                .animation(.easeInOut(duration: 0.6), value: service.cleaningCurrentCategory)
                .frame(width: 300)
                
                // Right: Text & Task List
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 12) {
                         Text(loc.currentLanguage == .chinese ? "正在清理系统..." : "Cleaning System...")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(loc.currentLanguage == .chinese ? "正在移除不需要的文件，优化您的 Mac。" : "Removing unwanted files and optimizing your Mac.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    VStack(spacing: 16) {
                        // Dynamically show tasks based on what's cleaning
                        // 刷新的任务列表：系统垃圾, 废纸篓, 恶意程序, DNS, RAM
                        let categories: [CleanerCategory] = [.systemJunk, .largeFiles, .virus, .startupItems, .performanceApps]
                        ForEach(categories, id: \.self) { cat in
                            let isActive = service.cleaningCurrentCategory == cat
                            let isDone = service.cleanedCategories.contains(cat)
                            
                            HStack(spacing: 12) {
                                // Icon Circle
                                ZStack {
                                    Circle()
                                        .fill(getCategoryColor(cat).opacity(0.2))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: getCategoryIcon(cat))
                                        .font(.system(size: 14))
                                        .foregroundColor(getCategoryColor(cat))
                                }
                                
                                Text(cat == .largeFiles ? (loc.currentLanguage == .chinese ? "废纸篓" : "Trash") : getCategoryTitle(cat))
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if isActive {
                                    Text(service.cleaningDescription)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.4))
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 20, height: 20)
                                } else if isDone {
                                    Text(ByteCountFormatter.string(fromByteCount: service.sizeFor(category: cat), countStyle: .file))
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.4))
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.green)
                                } else {
                                    Text("...")
                                        .foregroundColor(.white.opacity(0.2))
                                }
                            }
                            .frame(width: 340)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 500) // Fixed height to prevent shifting during alerts
            
            Spacer()
        }
    }
    
    // MARK: - Cleaning Log Page
    private var cleaningLogPage: some View {
        ZStack(alignment: .bottomLeading) {
            HStack(spacing: 60) {
                // Left: Hero Image (iMac with wiper)
                if let imagePath = Bundle.main.path(forResource: "welcome.png", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 500, height: 500)
                } else {
                     Image(systemName: "desktopcomputer")
                        .resizable()
                        .frame(width: 300, height: 300)
                        .foregroundColor(.pink)
                }
                
                // Right: Detailed Task List (Log)
                VStack(alignment: .leading, spacing: 24) {
                    Text(loc.currentLanguage == .chinese ? "清理日志" : "Cleaning Log")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 16) {
                        // 1. System Junk
                        let sysJunkSize = service.sizeFor(category: .systemJunk) + service.sizeFor(category: .userCache)
                        let sysJunkState: CleaningTaskState = sysJunkSize > 0 ? .warning : .completed
                        
                        cleaningTaskRow(
                            icon: "trash.circle.fill",
                            color: .pink,
                            title: loc.currentLanguage == .chinese ? "系统垃圾" : "System Junk",
                            size: sysJunkSize > 0 ? sysJunkSize : service.totalCleanedSize, 
                            state: sysJunkState
                        )
                        
                        // 2. Trash
                        cleaningTaskRow(
                            icon: "trash.fill",
                            color: .green,
                            title: loc.currentLanguage == .chinese ? "废纸篓" : "Trash",
                            size: 0,
                            state: .completed
                        )
                        
                        // 3. Malware
                        cleaningTaskRow(
                            icon: "exclamationmark.shield.fill",
                            color: .gray,
                            title: loc.currentLanguage == .chinese ? "可能有害的应用程序" : "Potentially Harmful Apps",
                            size: 0,
                            state: .completed
                        )
                        
                        // 4. Optimization
                        cleaningTaskRow(
                            icon: "network",
                            color: .blue,
                            title: loc.currentLanguage == .chinese ? "刷新 DNS 缓存" : "Refresh DNS Cache",
                            size: 0,
                            state: .completed
                        )
                         
                         cleaningTaskRow(
                             icon: "memorychip",
                             color: .blue,
                             title: loc.currentLanguage == .chinese ? "释放 RAM" : "Free RAM",
                             size: 0,
                             state: .completed
                         )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 60)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Left: Hide Log Button
            Button(action: { withAnimation { viewingLog = false } }) {
                Text(loc.currentLanguage == .chinese ? "隐藏日志" : "Hide Log")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.leading, 60)
            .padding(.bottom, 40)
        }
    }
    private var cleaningFinishedPage: some View {
        VStack {
            Spacer().frame(height: 100)
            
            HStack(spacing: 60) {
                // Left: Hero Image (iMac with wiper)
                if let imagePath = Bundle.main.path(forResource: "welcome", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 500, height: 500)
                } else {
                     Image(systemName: "desktopcomputer")
                        .resizable()
                        .frame(width: 300, height: 300)
                        .foregroundColor(.pink)
                }
                
                // Right: Results
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 8) {
                         Text(loc.currentLanguage == .chinese ? "做得不错！" : "Well done!")
                             .font(.system(size: 36, weight: .bold))
                             .foregroundColor(.white)
                         Text(loc.currentLanguage == .chinese ? "您的 Mac 状态很好。" : "Your Mac is in good shape.")
                             .font(.system(size: 16))
                             .foregroundColor(.white.opacity(0.6))
                    }
                    
                    VStack(spacing: 12) {
                        // 1. Cleanup Result
                        ResultCompactRow(
                            icon: "yinpan_2026",
                            title: loc.currentLanguage == .chinese ? "清理" : "Cleanup",
                            subtitle: loc.currentLanguage == .chinese ? "不需要的垃圾已移除" : "Junk removed",
                            stat: ByteCountFormatter.string(fromByteCount: service.totalCleanedSize, countStyle: .file)
                        )
                        
                        // 2. Protection Result
                        ResultCompactRow(
                            icon: "zhiwendunpai_2026",
                            title: loc.currentLanguage == .chinese ? "保护" : "Protection",
                            subtitle: loc.currentLanguage == .chinese ? "潜在问题已解决" : "Resolved",
                            stat: "\(service.totalResolvedThreats) " + (loc.currentLanguage == .chinese ? "个威胁" : "Threats")
                        )
                        
                        // 3. Speed Result
                        ResultCompactRow(
                            icon: "yibiaopan_2026",
                            title: loc.currentLanguage == .chinese ? "速度" : "Speed",
                            subtitle: loc.currentLanguage == .chinese ? "Mac 的性能达到极致" : "Optimized",
                            stat: "\(service.totalOptimizedItems) " + (loc.currentLanguage == .chinese ? "个任务" : "Tasks")
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 550)
            
            Spacer()
        }
        .overlay(
            // Bottom Left: View Log
            VStack {
                Spacer()
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 14))
                        Button(loc.currentLanguage == .chinese ? "查看日志" : "View Log") {
                            withAnimation { viewingLog = true }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.yellow)
                        .buttonStyle(.plain)
                    }
                    .padding(.leading, 60)
                    .padding(.bottom, 40)
                    Spacer()
                }
            }
        )
    }


    // MARK: - UI Helpers
    
    enum CleaningTaskState {
        case pending, cleaning, completed, warning
    }
    
    @ViewBuilder
    private func cleaningTaskRow(icon: String, color: Color, title: String, size: Int64, state: CleaningTaskState) -> some View {
        HStack(spacing: 16) {
            // Icon in Solid Circle
            ZStack {
                Circle()
                    .fill(color) // Solid background color
                    .frame(width: 32, height: 32)
                
                // Extract base icon name if it contains .circle.fill to avoid double circle
                let baseIcon = icon.replacingOccurrences(of: ".circle.fill", with: "")
                                  .replacingOccurrences(of: ".fill", with: "")
                
                Image(systemName: baseIcon == "trash" ? "trash.fill" : (baseIcon == "exclamationmark.shield" ? "exclamationmark.shield.fill" : baseIcon))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Title
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.white)
            
            Spacer()
            
            // Check if warning state, move size to title side or keep? 
            // Design shows: 3.37 GB [Warning Icon]
            if state == .warning {
                 Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                  
                  Button(action: { showFailedFilesPopover = true }) {
                      Image(systemName: "exclamationmark.triangle.fill")
                         .foregroundColor(.yellow)
                         .font(.system(size: 14))
                  }
                  .buttonStyle(.plain)
                  .popover(isPresented: $showFailedFilesPopover, arrowEdge: .top) {
                      VStack(alignment: .leading, spacing: 12) {
                          Text(loc.currentLanguage == .chinese ? "此项目清理了一部分。" : "This item was partially cleaned.")
                              .font(.system(size: 13, weight: .bold))
                          
                          VStack(alignment: .leading, spacing: 4) {
                              Text(loc.currentLanguage == .chinese ? "错误：" : "Errors:")
                                  .font(.system(size: 12, weight: .semibold))
                                  .foregroundColor(.gray)
                              
                              ScrollView {
                                  VStack(alignment: .leading, spacing: 4) {
                                      ForEach(failedFiles, id: \.id) { item in
                                          Text(loc.currentLanguage == .chinese ? 
                                              "无法移除 \"\(item.url.lastPathComponent)\"，因为它的关联应用程序正在运行。" :
                                              "Could not remove \"\(item.url.lastPathComponent)\" because its associated application is running.")
                                              .font(.system(size: 11))
                                              .foregroundColor(.white.opacity(0.8))
                                      }
                                  }
                              }
                              .frame(maxHeight: 150)
                          }
                          
                          Button(action: {
                              let errorText = failedFiles.map { item in
                                  loc.currentLanguage == .chinese ? 
                                  "无法移除 \"\(item.url.lastPathComponent)\"，因为它的关联应用程序正在运行。" :
                                  "Could not remove \"\(item.url.lastPathComponent)\" because its associated application is running."
                              }.joined(separator: "\n")
                              let pasteboard = NSPasteboard.general
                              pasteboard.clearContents()
                              pasteboard.setString(errorText, forType: .string)
                          }) {
                              Text(loc.currentLanguage == .chinese ? "拷贝至剪贴板" : "Copy to Clipboard")
                                  .font(.system(size: 12))
                                  .foregroundColor(.white.opacity(0.9))
                                  .padding(.horizontal, 12)
                                  .padding(.vertical, 4)
                                  .background(Color.white.opacity(0.1))
                                  .cornerRadius(6)
                          }
                          .buttonStyle(.plain)
                      }
                      .padding()
                      .frame(width: 300)
                      .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
                  }
            } else {
                // Normal Size (if > 0 and not cleaning?)
                if size > 0 && state != .cleaning {
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Status Indicator
                if state == .cleaning {
                   ProgressView()
                       .scaleEffect(0.5)
                       .frame(width: 16, height: 16)
                       .colorScheme(.dark)
                } else if state == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                } else if state == .pending {
                    // Pending dot (empty circle or similar)
                     Circle()
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                }
            }
        }
        .frame(height: 44) // Increased height for better touch target
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func resultRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            // Large Icon
             ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(colors: [color.opacity(0.8), color.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 54, height: 54)
                
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            
            // Checkmark
            ZStack {
                Circle().fill(Color.white).frame(width: 18, height: 18)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            }
            
            // Texts
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - 3-Column Layout Implementation
    // MARK: - 3-Column Layout Implementation
    private func threeColumnLayout(state: ScanState) -> some View {
        HStack(spacing: 40) {
            // 1. Cleanup Group
            // State Logic:
            // - Active if cleaning any junk category
            // - Done if systemJunk (primary) is cleaned OR if we moved past junk
            // - Pending if not started
            let cleanupActive = state == .cleaning && [.systemJunk, .duplicates, .similarPhotos, .largeFiles, .appUpdates].contains(service.cleaningCurrentCategory)
            let cleanupDone = state == .finished || (state == .cleaning && service.cleanedCategories.contains(.systemJunk) && !cleanupActive)
            
            itemColumn(
                title: loc.currentLanguage == .chinese ? "清理" : "Cleanup",
                iconName: "yinpan_2026",
                description: state == .scanning ? (loc.currentLanguage == .chinese ? "正在查找不需要的文件..." : "Searching for unwanted files...") : (loc.currentLanguage == .chinese ? "移除不需要的垃圾" : "Remove unwanted junk"),
                categories: [.systemJunk, .duplicates, .similarPhotos, .largeFiles],
                state: state,
                isActive: (state == .scanning && [.systemJunk, .duplicates, .similarPhotos, .largeFiles].contains(service.currentCategory)) || cleanupActive,
                isDone: cleanupDone,
                color: Color(red: 0.1, green: 0.6, blue: 0.9), // Blue
                currentPath: (state == .scanning && [.systemJunk, .duplicates, .similarPhotos, .largeFiles].contains(service.currentCategory)) ? service.currentScanPath : (cleanupActive ? service.currentScanPath : nil)
            )
            
            // 2. Protection Group
            let protectionActive = state == .cleaning && service.cleaningCurrentCategory == .virus
            let protectionDone = state == .finished || (state == .cleaning && service.cleanedCategories.contains(.virus))
            
            itemColumn(
                title: loc.currentLanguage == .chinese ? "保护" : "Protection",
                iconName: "zhiwendunpai_2026",
                description: state == .scanning ? (loc.currentLanguage == .chinese ? "正在确定潜在威胁..." : "Determining potential threats...") : (loc.currentLanguage == .chinese ? "消除潜在威胁" : "Eliminate potential threats"),
                categories: [.virus],
                state: state,
                isActive: (state == .scanning && service.currentCategory == .virus) || protectionActive,
                isDone: protectionDone,
                color: Color(red: 0.2, green: 0.8, blue: 0.5), // Green
                currentPath: (state == .scanning && service.currentCategory == .virus) ? service.currentScanPath : (protectionActive ? service.currentScanPath : nil)
            )
            
            // 3. Speed Group
            let speedActive = state == .cleaning && [.startupItems, .performanceApps].contains(service.cleaningCurrentCategory)
            let speedDone = state == .finished || (state == .cleaning && service.cleanedCategories.contains(.startupItems))
            
            // ⚠️ 暂时禁用 performanceApps：用户反馈智能扫描清理会把应用搞废
            itemColumn(
                title: loc.currentLanguage == .chinese ? "速度" : "Speed",
                iconName: "yibiaopan_2026", // Speedometer
                description: state == .scanning ? (loc.currentLanguage == .chinese ? "定义合适的任务..." : "Defining suitable tasks...") : (loc.currentLanguage == .chinese ? "提升系统性能" : "Boost system performance"),
                categories: [.startupItems, .performanceApps, .appUpdates],
                state: state,
                isActive: (state == .scanning && [.startupItems, .performanceApps, .appUpdates].contains(service.currentCategory)) || speedActive,
                isDone: speedDone,
                color: Color(red: 0.9, green: 0.3, blue: 0.5), // Pink
                currentPath: (state == .scanning && [.startupItems, .performanceApps, .appUpdates].contains(service.currentCategory)) ? service.currentScanPath : (speedActive ? service.currentScanPath : nil)
            )
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Column Item View
    @ViewBuilder
    private func itemColumn(
        title: String,
        iconName: String,
        description: String,
        categories: [CleanerCategory],
        state: ScanState,
        isActive: Bool,
        isDone: Bool,
        color: Color,
        currentPath: String? = nil
    ) -> some View {
        VStack(spacing: 16) {
            // Icon Area
            ZStack {
                // Background Glow/Shape - Enlarged
                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.8), color.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 150, height: 150)
                    .shadow(color: color.opacity(0.4), radius: 10, y: 5)
                
                // Image Icon - Direct path to resource subdirectory
                let resourcePath = "/Users/dudianlong/tool/mac应用程序卸载/AppUninstaller/resource/\(iconName).png"
                if let nsImage = NSImage(contentsOfFile: resourcePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 96, height: 96)
                        .modifier(ScanningAnimationModifier(isScanning: isActive))
                } else if let imagePath = Bundle.main.path(forResource: iconName, ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .modifier(ScanningAnimationModifier(isScanning: isActive))
                } else {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                }
            }
            .frame(height: 160)
            
            // Status Check + Title
            HStack(spacing: 6) {
                if isActive {
                   if currentPath != nil {
                       ProgressView()
                           .scaleEffect(0.6)
                           .frame(width: 16, height: 16)
                   } else {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 8, height: 8)
                   }
                } else if isDone || state == .completed { // Scan Completed also shows Checkmark if finished
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                } else {
                     Circle()
                         .fill(Color.white.opacity(0.2))
                         .frame(width: 8, height: 8)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Description
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(minHeight: 36)
            
            Spacer().frame(height: 8)
            
            // MARK: - Dynamic Content Area (Scanning Path or Results)
            VStack(spacing: 8) {
                if isActive {
                    // Scanning: Show real-time path
                    if let path = currentScanPathInColumn(title) {
                        Text(path)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.3))
                            )
                            .frame(maxWidth: 280)
                    } else {
                        Text("")
                            .frame(height: 28)
                    }
                } else if state == .completed {
                    // Completed: Show result size
                    VStack(spacing: 6) {
                        if title == (loc.currentLanguage == .chinese ? "清理" : "Cleanup") {
                            let size = categories.reduce(0) { $0 + service.sizeFor(category: $1) }
                            if size > 0 {
                                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundColor(color)
                                
                                // View Details Button (Only if count > 0)
                                Button(action: {
                                    initialDetailCategory = .systemJunk
                                    showDetailSheet = true
                                }) {
                                    Text(loc.currentLanguage == .chinese ? "查看详情..." : "View Details...")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.15))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text(loc.currentLanguage == .chinese ? "好" : "Good")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundColor(Color.green)
                            }
                        } else if title == (loc.currentLanguage == .chinese ? "保护" : "Protection") {
                            let threats = service.virusThreats.count
                            if threats > 0 {
                                Text("\(threats)")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundColor(.red)
                                
                                // View Details Button (Only if threats > 0)
                                Button(action: {
                                    initialDetailCategory = .virus
                                    showDetailSheet = true
                                }) {
                                    Text(loc.currentLanguage == .chinese ? "查看详情..." : "View Details...")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.15))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text(loc.currentLanguage == .chinese ? "好" : "Good")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundColor(Color.green)
                            }
                        } else if title == (loc.currentLanguage == .chinese ? "速度" : "Speed") {
                            let count = service.startupItems.count
                            if count > 0 {
                                VStack(spacing: 0) {
                                    Text("\(count)")
                                        .font(.system(size: 28, weight: .light))
                                        .foregroundColor(.white)
                                    
                                    // Text Description instead of Button (matched reference)
                                    Text(loc.currentLanguage == .chinese ? "个任务可运行" : "tasks to run")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                        .padding(.top, 2)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    initialDetailCategory = .startupItems
                                    showDetailSheet = true
                                }
                                
                            } else {
                                Text(loc.currentLanguage == .chinese ? "好" : "Good")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundColor(Color.green)
                            }
                        }
                    }
                } else {
                    // Pending: Empty space
                    Text("")
                        .frame(height: 60)
                }
            }
            // Removed fixed minHeight to reduce whitespace gap

            
        }
        .frame(maxWidth: 320)
    }

    // MARK: - Animation Modifier
    struct ScanningAnimationModifier: ViewModifier {
        let isScanning: Bool
        @State private var isAnimating = false
        
        func body(content: Content) -> some View {
            content
                .scaleEffect(isScanning && isAnimating ? 1.1 : 1.0)
                .animation(isScanning ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: isAnimating)
                .onAppear {
                    if isScanning { isAnimating = true }
                }
                .onChange(of: isScanning) { newValue in
                    isAnimating = newValue
                }
        }
    }
    
    // MARK: - Rotating Ring Component
    struct RotatingCircleRing: View {
        @State private var rotation: Double = 0
        
        var body: some View {
            Circle()
                .trim(from: 0.2, to: 1)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.white.opacity(0.8), .white.opacity(0.1)]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
        }
    }

    // MARK: - Main Action Button (Scan Orb)
    @ViewBuilder
    private var mainActionButton: some View {
        if viewingLog {
            EmptyView()
        } else {
            switch scanState {
        case .initial:
            // Start Orb
            Button(action: {
                Task { await service.scanAll() }
            }) {
                ZStack {
                    // Outer Glow
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color.purple.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 90
                        ))
                        .frame(width: 160, height: 160)
                    
                    // Main Orb
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.8, green: 0.2, blue: 0.7), Color(red: 0.5, green: 0.1, blue: 0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: .purple.opacity(0.6), radius: 15, x: 0, y: 8)
                        .overlay(
                            // Glassy reflection
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.7), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                    
                    Text(loc.currentLanguage == .chinese ? "开始" : "Start")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
            }
            .buttonStyle(.plain)
            
        case .scanning:
            // New Stop Button with Rotating Ring and Real-time Size
            HStack(spacing: 20) {
                // Stop Button Group
                Button(action: { service.stopScanning() }) {
                    ZStack {
                        // Background Circle
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 80, height: 80)
                        
                        // Rotating Progress Ring
                        RotatingCircleRing()
                            .frame(width: 80, height: 80)
                        
                        // Inner Button (Stop)
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 64, height: 64)
                        
                        Text(loc.currentLanguage == .chinese ? "停止" : "Stop")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                
                // Real-time Size Display
                Text(ByteCountFormatter.string(fromByteCount: totalScannedSize, countStyle: .file))
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.bottom, 20)
                         
        case .cleaning:
            // Stop Button for Cleaning Page
            Button(action: { service.stopCleaning() }) {
                ZStack {
                     Circle()
                         .fill(Color.white.opacity(0.1))
                         .frame(width: 80, height: 80)
                         .overlay(
                             Circle()
                                 .trim(from: 0, to: 0.7) // Mock progress Ring
                                 .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                 .rotationEffect(Angle(degrees: -90))
                         )
                    
                    VStack(spacing: 2) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        Text(loc.currentLanguage == .chinese ? "停止" : "Stop")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
        case .completed:
            // Run Orb (Updated text)
            // Run Button (Simple Blue Button - No Glow/Orb)
            Button(action: {
                // Check for running apps
                let selectedFiles = service.getAllSelectedFiles()
                let runningApps = service.checkRunningApps(for: selectedFiles)
                
                if !runningApps.isEmpty {
                    detectedRunningApps = runningApps
                    showRunningAppsDialog = true
                } else {
                    showDeleteConfirmation = true
                }
            }) {
                ZStack {
                    // Simple Circular Button with Gradient
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(red: 0.2, green: 0.5, blue: 0.9), Color(red: 0.1, green: 0.3, blue: 0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.blue.opacity(0.4), radius: 10, x: 0, y: 5)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    Text(loc.currentLanguage == .chinese ? "运行" : "Run")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            
        case .finished:
             // Back/Done Orb
             // Back/Done Button (Simple Green Button)
             Button(action: {
                 Task { service.resetAll(); showCleaningFinished = false }
             }) {
                 ZStack {
                     Circle()
                         .fill(LinearGradient(
                             colors: [Color(red: 0.2, green: 0.8, blue: 0.4), Color(red: 0.1, green: 0.6, blue: 0.3)],
                             startPoint: .top,
                             endPoint: .bottom
                         ))
                         .frame(width: 80, height: 80)
                         .shadow(color: Color.green.opacity(0.4), radius: 10, x: 0, y: 5)
                         .overlay(
                             Circle()
                                 .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                         )
                     
                     Text(loc.currentLanguage == .chinese ? "返回" : "Back")
                         .font(.system(size: 16, weight: .semibold))
                         .foregroundColor(.white)
                 }
             }
             .buttonStyle(.plain)
             
        }
    }
}

}

extension SmartCleanerView {
    private func getFinishedResultText(for category: CleanerCategory) -> String {
        if category == .systemJunk && deleteResult != nil {
            return ByteCountFormatter.string(fromByteCount: deleteResult!.size, countStyle: .file) + " " + (loc.currentLanguage == .chinese ? "已清理" : "Cleaned")
        }
        return getCleaningSubText(for: category)
    }
}

// MARK: - Result Compact Row (For Finished Page)
struct ResultCompactRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let stat: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Square Icon
            let resourcePath = "/Users/dudianlong/tool/mac应用程序卸载/AppUninstaller/resource/\(icon).png"
            if let nsImage = NSImage(contentsOfFile: resourcePath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.black.opacity(0.2), radius: 4)
            } else if let imagePath = Bundle.main.path(forResource: icon, ofType: "png"),
               let nsImage = NSImage(contentsOfFile: imagePath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.black.opacity(0.2), radius: 4)
            } else {
                 Image(systemName: "app.fill")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.blue)
            }
            
            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 18))
            
            // Texts
            VStack(alignment: .leading, spacing: 2) {
                Text(stat)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Cleaning Large Icon Animation
struct CleaningLargeIconAnimation: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Helper Functions Extension
extension SmartCleanerView {
    
    // MARK: - Custom Running Apps Dialog (Pro Max)
    private var runningAppsOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Close dialog if tapped outside
                    withAnimation { showRunningAppsDialog = false }
                }
            
            // Dark "Pro Max" Dialog
            VStack(spacing: 0) {
                runningAppsHeader
                
                // Content Divider
                Divider()
                    .background(Color.white.opacity(0.1))
                
                runningAppsList
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                runningAppsFooter
            }
            .frame(width: 440) // Slightly wider
            .background(Color(red: 0.12, green: 0.12, blue: 0.13)) // Dark background
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: 15)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1) // Thin border
            )
        }
        .transition(.opacity)
    }
    
    private var runningAppsHeader: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.orange)
            }
            .padding(.top, 8)
            
            VStack(spacing: 6) {
                Text(loc.currentLanguage == .chinese ? "一些应用程序应该退出" : "Some Applications Should Quit")
                    .font(.system(size: 18, weight: .bold)) // Slightly larger
                    .foregroundColor(.white) // White text
                
                Text(loc.currentLanguage == .chinese ? "请退出以下应用程序，以清理所有与之相关的项目：" : "Please quit the following applications to clear all related items:")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7)) // Secondary text
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .lineLimit(2)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    private var runningAppsList: some View {
        ScrollView {
            VStack(spacing: 1) { // 1px spacing for list feel
                ForEach(detectedRunningApps, id: \.bundleId) { app in
                    HStack(spacing: 12) {
                        // App Icon
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "app.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.blue)
                        }
                        
                        // App Name
                        Text(app.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white) // White
                        
                        Spacer()
                        
                        // Close Button
                        Button(action: {
                            // 1. Close the app
                            if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == app.bundleId }) {
                                runningApp.terminate()
                            }
                            
                            // 2. Remove from list
                            withAnimation {
                                detectedRunningApps.removeAll(where: { $0.bundleId == app.bundleId })
                                // If list becomes empty, close dialog and show confirmation
                                if detectedRunningApps.isEmpty {
                                    showRunningAppsDialog = false
                                    showDeleteConfirmation = true
                                }
                            }
                        }) {
                            Text(loc.currentLanguage == .chinese ? "关闭" : "Close")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1)) // Dark pill
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.02)) // Slight highlight on row
                    
                    // Separator
                    if app.bundleId != detectedRunningApps.last?.bundleId {
                        Divider()
                            .background(Color.white.opacity(0.05))
                            .padding(.leading, 68)
                    }
                }
            }
        }
        .frame(maxHeight: 220) // Slightly taller
        .background(Color.black.opacity(0.2)) // Darker inner background
    }
    
    private var runningAppsFooter: some View {
        HStack(spacing: 16) {
            // Ignore Button
            Button(action: {
                withAnimation {
                    showRunningAppsDialog = false
                    showDeleteConfirmation = true
                }
            }) {
                Text(loc.currentLanguage == .chinese ? "忽略" : "Ignore")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            // Force Quit All Button
            Button(action: {
                // Close all apps in the list
                for app in detectedRunningApps {
                    if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == app.bundleId }) {
                        runningApp.terminate()
                    }
                }
                
                // Proceed to cleaning
                withAnimation {
                    detectedRunningApps.removeAll()
                    showRunningAppsDialog = false
                    showDeleteConfirmation = true
                }
            }) {
                Text(loc.currentLanguage == .chinese ? "全部退出" : "Quit All")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(8)
                    .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

private func currentScanPathInColumn(_ title: String) -> String? {
    if title == (loc.currentLanguage == .chinese ? "清理" : "Cleanup") {
        if [.systemJunk, .duplicates, .similarPhotos, .largeFiles].contains(service.currentCategory) {
            return service.currentScanPath
        }
    } else if title == (loc.currentLanguage == .chinese ? "保护" : "Protection") {
        if service.currentCategory == .virus {
            return service.currentScanPath
        }
    } else if title == (loc.currentLanguage == .chinese ? "速度" : "Speed") {
        if [.startupItems, .performanceApps, .appUpdates].contains(service.currentCategory) {
            return service.currentScanPath
        }
    }
    return nil
}


    private func getDisplayTitle(for category: CleanerCategory) -> String {
        switch category {
        case .systemJunk: return loc.currentLanguage == .chinese ? "系统垃圾" : "System Junk"
        case .duplicates: return loc.currentLanguage == .chinese ? "重复文件" : "Duplicates"
        case .similarPhotos: return loc.currentLanguage == .chinese ? "相似照片" : "Similar Photos"
        case .largeFiles: return loc.currentLanguage == .chinese ? "大文件" : "Large Files"
        case .virus: return loc.currentLanguage == .chinese ? "病毒防护" : "Virus Protection"
        case .startupItems: return loc.currentLanguage == .chinese ? "启动项" : "Startup Items"
        case .performanceApps: return loc.currentLanguage == .chinese ? "性能优化" : "Performance"
        case .appUpdates: return loc.currentLanguage == .chinese ? "应用更新" : "App Updates"
        default: return ""
        }
    }
    
    private func getResultText(for category: CleanerCategory) -> String {
        let size = service.sizeFor(category: category)
        if size > 0 || [.systemJunk, .duplicates, .similarPhotos, .largeFiles].contains(category) {
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        
        switch category {
        case .virus: return service.virusThreats.isEmpty ? (loc.currentLanguage == .chinese ? "0 个威胁" : "0 Threats") : "\(service.virusThreats.count) \(loc.currentLanguage == .chinese ? "个威胁" : "Threats")"
        case .startupItems: return "\(service.startupItems.count) \(loc.currentLanguage == .chinese ? "个项目" : "Items")"
        case .performanceApps: return "\(service.performanceApps.count) \(loc.currentLanguage == .chinese ? "个应用" : "Apps")"
        case .appUpdates: return service.hasAppUpdates ? (loc.currentLanguage == .chinese ? "有更新" : "Has Update") : (loc.currentLanguage == .chinese ? "无更新" : "No Updates")
        default: return "0 KB"
        }
    }
    
    private func getSubText(for category: CleanerCategory) -> String {
        switch category {
        case .systemJunk, .duplicates, .similarPhotos, .largeFiles: return loc.currentLanguage == .chinese ? "可清理" : "Cleanable"
        case .virus: return service.virusThreats.isEmpty ? (loc.currentLanguage == .chinese ? "已保护" : "Safe") : (loc.currentLanguage == .chinese ? "可移除" : "Removable")
        case .startupItems: return loc.currentLanguage == .chinese ? "可优化" : "Optimizable"
        case .performanceApps: return loc.currentLanguage == .chinese ? "待查看" : "To Review"
        case .appUpdates: return loc.currentLanguage == .chinese ? "要安装" : "To Install"
        default: return ""
        }
    }
    
    private func getScanningTitle(for category: CleanerCategory) -> String {
        switch category {
        case .systemJunk: return loc.currentLanguage == .chinese ? "正在查找垃圾文件......" : "Searching for junk..."
        case .duplicates: return loc.currentLanguage == .chinese ? "正在寻找重复文件..." : "Finding duplicates..."
        case .similarPhotos: return loc.currentLanguage == .chinese ? "正在查找相似照片..." : "Finding similar photos..."
        case .largeFiles: return loc.currentLanguage == .chinese ? "正在扫描大文件..." : "Scanning for large files..."
        case .virus: return loc.currentLanguage == .chinese ? "正在查找潜在威胁..." : "Scanning for threats..."
        case .startupItems: return loc.currentLanguage == .chinese ? "正在分析启动项..." : "Analyzing startup items..."
        case .performanceApps: return loc.currentLanguage == .chinese ? "正在检查后台应用..." : "Checking background apps..."
        case .appUpdates: return loc.currentLanguage == .chinese ? "正在检查应用更新..." : "Checking for updates..."
        default: return ""
        }
    }
    
    private func getGradient(for category: CleanerCategory) -> LinearGradient {
        switch category {
        case .systemJunk:
            return LinearGradient(colors: [Color(red: 0.2, green: 0.9, blue: 0.6), Color(red: 0.1, green: 0.6, blue: 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .duplicates:
            return LinearGradient(colors: [Color(red: 0.3, green: 0.7, blue: 1.0), Color(red: 0.1, green: 0.4, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .similarPhotos:
            return LinearGradient(colors: [Color(red: 0.7, green: 0.5, blue: 1.0), Color(red: 0.4, green: 0.2, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .largeFiles:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.7, blue: 0.3), Color(red: 0.8, green: 0.4, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .virus:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.3, blue: 0.4), Color(red: 0.7, green: 0.1, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .startupItems:
            return LinearGradient(colors: [Color(red: 0.4, green: 0.4, blue: 0.9), Color(red: 0.2, green: 0.2, blue: 0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .performanceApps:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.4, blue: 0.7), Color(red: 0.8, green: 0.2, blue: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .appUpdates:
            return LinearGradient(colors: [Color(red: 0.2, green: 0.8, blue: 1.0), Color(red: 0.1, green: 0.5, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [Color.gray, Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private func getCleaningSubText(for category: CleanerCategory) -> String {
        switch category {
        case .systemJunk, .duplicates, .similarPhotos, .largeFiles: return loc.currentLanguage == .chinese ? "已清理" : "Cleaned"
        case .virus: return loc.currentLanguage == .chinese ? "已防护" : "Protected"
        case .performanceApps, .startupItems: return loc.currentLanguage == .chinese ? "已优化" : "Optimized"
        case .appUpdates: return loc.currentLanguage == .chinese ? "已检查" : "Checked"
        default: return ""
        }
    }
    
    private func getCleaningTitle(for category: CleanerCategory) -> String {
        switch category {
        case .systemJunk: return loc.currentLanguage == .chinese ? "正在清理垃圾文件..." : "Cleaning junk..."
        case .duplicates, .similarPhotos, .largeFiles: return loc.currentLanguage == .chinese ? "正在整理文件..." : "Organizing files..."
        case .virus: return loc.currentLanguage == .chinese ? "正在移除威胁..." : "Removing threats..."
        case .startupItems: return loc.currentLanguage == .chinese ? "正在优化启动项..." : "Optimizing startup..."
        case .performanceApps: return loc.currentLanguage == .chinese ? "正在优化性能..." : "Optimizing performance..."
        case .appUpdates: return loc.currentLanguage == .chinese ? "正在检查更新状态..." : "Checking update status..."
        default: return ""
        }
    }

    private func getIconFor(category: CleanerCategory) -> String {
        switch category {
        case .systemJunk, .userCache, .systemCache, .userLogs, .systemLogs, .languageFiles:
            return "system_clean"
        case .duplicates, .similarPhotos:
            return "kongjianshentou"
        case .virus:
            return "yinsi"
        case .startupItems, .performanceApps:
            return "youhua"
        default:
            return "system_clean"
        }
    }
    
    private func getCategoryIcon(_ category: CleanerCategory) -> String {
        switch category {
        case .systemJunk: return "trash.circle.fill"
        case .largeFiles: return "trash.fill"
        case .virus: return "exclamationmark.shield.fill"
        case .startupItems: return "network"
        case .performanceApps: return "memorychip"
        default: return "circle.fill"
        }
    }
    
    private func getCategoryColor(_ category: CleanerCategory) -> Color {
        switch category {
        case .systemJunk: return .pink
        case .largeFiles: return .green
        case .virus: return .gray
        case .startupItems, .performanceApps: return .blue
        default: return .gray
        }
    }
    
    private func getCategoryTitle(_ category: CleanerCategory) -> String {
        switch category {
        case .systemJunk: return loc.currentLanguage == .chinese ? "系统垃圾" : "System Junk"
        case .largeFiles: return loc.currentLanguage == .chinese ? "废纸篓" : "Trash"
        case .virus: return loc.currentLanguage == .chinese ? "可能有害的应用程序" : "Potentially Harmful Apps"
        case .startupItems: return loc.currentLanguage == .chinese ? "刷新 DNS 缓存" : "Refresh DNS Cache"
        case .performanceApps: return loc.currentLanguage == .chinese ? "释放 RAM" : "Free RAM"
        default: return "Task"
        }
    }
}
struct DashboardCard: View {
    let title: String
    let mainText: String
    let subText: String
    let icon: String // SF Symbol
    let gradient: LinearGradient
    let action: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                // Header (Checkbox visually represented by Icon for now per design)
                HStack {
                     Image(systemName: "checkmark.square.fill") // Fake checkbox for aesthetic
                        .foregroundColor(.white.opacity(0.6))
                     Text(title)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                Text(mainText)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(subText)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Right Side Graphic (Glassmorphism Icon)
            VStack {
                ZStack {
                    // Glassy background for icon
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 80, height: 80)
                        .shadow(radius: 10)
                    
                    Image(systemName: icon)
                         .resizable()
                         .aspectRatio(contentMode: .fit)
                         .frame(width: 40, height: 40)
                         .foregroundColor(.white)
                }
                
                Spacer()
                
                Button("查看") { action() } // View Button
                .buttonStyle(SmallGlassButtonStyle())
            }
        }
        .padding(20)
        .frame(height: 180)
        .background(
            ZStack {
                gradient.opacity(0.3) // Tint
                Color.black.opacity(0.3) // Darken
                Rectangle().fill(.thinMaterial) // Blur
            }
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Status Pill for Scanning
struct StatusPill: View {
    let label: String
    let active: Bool
    
    var body: some View {
        Text(label)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(active ? Color.purple : Color.white.opacity(0.1))
            .cornerRadius(20)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(active ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .animation(.easeInOut, value: active)
    }
}

// MARK: - Small Glass Button
struct SmallGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// Block state for consistent rendering
enum ScanBlockState {
    case idle       // Not yet scanned
    case active     // Currently scanning/cleaning
    case completed  // Finished
}

// MARK: - Scan Block View (Fixed Size, No Flashing)
struct ScanBlockView: View {
    let category: CleanerCategory
    let isActive: Bool
    let isCompleted: Bool
    let title: String
    let resultText: String
    let subText: String
    let icon: String
    let gradient: LinearGradient
    let scanningTitle: String
    let currentPath: String
    @ObservedObject var loc: LocalizationManager
    var viewDetailsAction: (() -> Void)? = nil
    
    private var state: ScanBlockState {
        if isActive { return .active }
        if isCompleted { return .completed }
        return .idle
    }
    
    var body: some View {
        // Fixed size container - prevents layout shifts
        ZStack {
            // Background based on state
            backgroundView
            
            // Content based on state
            contentView
        }
        .frame(height: 180) // Fixed height to prevent jumping
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: state)
    }
    
    private var borderColor: Color {
        switch state {
        case .active: return Color.white.opacity(0.3)
        case .completed: return Color.white.opacity(0.1)
        case .idle: return Color.white.opacity(0.05)
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch state {
        case .active:
            // 扫描中：半透明背景 + 描边闪烁感
            ZStack {
                Color.black.opacity(0.3)
                gradient.opacity(0.15)
                
                // 动效背景装饰
                RoundedRectangle(cornerRadius: 20)
                    .fill(gradient)
                    .opacity(0.15)
                    .mask(LinearGradient(colors: [.black, .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        case .completed:
            // 完成后：经典的玻璃态 (Glassmorphism)
            ZStack {
                Color.white.opacity(0.06)
                gradient.opacity(0.12)
                LinearGradient(
                    colors: [.white.opacity(0.1), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .idle:
            // 待扫描：纯净极简
            ZStack {
                Color.black.opacity(0.15)
                Color.white.opacity(0.02)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch state {
        case .active:
            activeContent
        case .completed:
            completedContent
        case .idle:
            idleContent
        }
    }
    
    // Active state content
    private var activeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(scanningTitle)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
            
            // Icon with glow
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color.white.opacity(0.25), Color.clear], center: .center, startRadius: 20, endRadius: 60))
                        .frame(width: 100, height: 100)
                    
                    RoundedRectangle(cornerRadius: 18)
                        .fill(gradient)
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(45))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                                .rotationEffect(.degrees(45))
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 8)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            
            Spacer()
            
            Text(currentPath)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(16)
    }
    
    // Completed state content
    private var completedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                // “查看详情”入口
                if let action = viewDetailsAction {
                    Button(action: action) {
                        HStack(spacing: 2) {
                            Text(loc.currentLanguage == .chinese ? "查看详情" : "Details")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(resultText)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(subText)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(gradient.opacity(0.5))
                        .frame(width: 45, height: 45)
                        .rotationEffect(.degrees(45))
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            Spacer()
        }
        .padding(14)
    }
    
    // Idle state content
    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            
            Spacer()
            
            // Faded icon
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(gradient.opacity(0.25))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()
            }
            
            Spacer()
        }
        .padding(14)
    }
}

// MARK: - Cleaning Block View
struct CleaningBlockView: View {
    let title: String
    let resultText: String
    let subText: String
    let icon: String
    let gradient: LinearGradient
    let cleaningTitle: String
    let isActive: Bool
    let isCompleted: Bool
    let currentPath: String
    @ObservedObject var loc: LocalizationManager
    var viewDetailsAction: (() -> Void)? = nil
    
    // Action for "View Details" button
    
    var body: some View {
        ZStack {
            // Background
            ZStack {
                if isActive {
                    gradient.opacity(0.8)
                } else if isCompleted {
                    Color.white.opacity(0.06)
                    gradient.opacity(0.1)
                } else {
                    Color.black.opacity(0.15)
                    Color.white.opacity(0.02)
                }
                
                // 玻璃高光
                LinearGradient(
                    colors: [.white.opacity(0.1), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // Content
            if isActive {
                // Active cleaning
                VStack(alignment: .leading, spacing: 8) {
                    Text(cleaningTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(RadialGradient(colors: [Color.white.opacity(0.25), Color.clear], center: .center, startRadius: 20, endRadius: 50))
                                .frame(width: 80, height: 80)
                            
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Spacer()
                    }
                    
                    Spacer()
                    
                    Text(currentPath)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(14)
            } else if isCompleted {
                // Completed
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        if let action = viewDetailsAction {
                            Button(action: action) {
                                HStack(spacing: 2) {
                                    Text(loc.currentLanguage == .chinese ? "查看详情" : "Details")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(resultText)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            
                            Text(subText)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(gradient.opacity(0.5))
                                .frame(width: 45, height: 45)
                                .rotationEffect(.degrees(45))
                            
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    
                    Spacer()
                }
                .padding(12)
            } else {
                // Idle
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(gradient.opacity(0.2))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        Spacer()
                    }
                    
                    Spacer()
                }
                .padding(12)
            }
        }
        .frame(height: 180)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isActive ? Color.white.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .animation(.easeInOut(duration: 0.3), value: isCompleted)
    }
}

// MARK: - Result Block View (for completed scan results)
struct ResultBlockView: View {
    let title: String
    let resultText: String
    let subText: String
    let icon: String
    let gradient: LinearGradient
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // 玻璃态背景
                ZStack {
                    Color.white.opacity(0.06)
                    gradient.opacity(0.08)
                    LinearGradient(
                        colors: [.white.opacity(0.1), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(gradient.opacity(0.6))
                                .frame(width: 55, height: 55)
                                .rotationEffect(.degrees(45))
                            
                            Image(systemName: icon)
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    
                    Spacer()
                    
                    Text(resultText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(subText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(14)
            }
            .frame(height: 180)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Finished Block View (all blocks completed)
struct FinishedBlockView: View {
    let title: String
    let resultText: String
    let icon: String
    let gradient: LinearGradient
    var viewDetailsAction: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            // 玻璃态背景
            ZStack {
                Color.white.opacity(0.06)
                gradient.opacity(0.05)
                LinearGradient(
                    colors: [.white.opacity(0.08), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    // “查看详情”入口 (可选)
                    if let action = viewDetailsAction {
                        Button(action: action) {
                            HStack(spacing: 2) {
                                let lang = LocalizationManager.shared.currentLanguage
                                Text(lang == .chinese ? "查看详情" : "Details")
                                Image(systemName: "chevron.right")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                HStack(alignment: .bottom) {
                    Text(resultText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(gradient.opacity(0.5))
                            .frame(width: 45, height: 45)
                            .rotationEffect(.degrees(45))
                        
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(14)
        }
        .frame(height: 180)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// 扫过光效动画
struct WipingAnimation: ViewModifier {
    @State private var offset: CGFloat = -300
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                withAnimation(Animation.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    offset = 400
                }
            }
    }
}