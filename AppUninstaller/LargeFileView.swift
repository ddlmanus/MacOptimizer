import SwiftUI

struct LargeFileView: View {
    @Binding var selectedModule: AppModule
    @ObservedObject private var scanner = ScanServiceManager.shared.largeFileScanner
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var showCleaningFinished = false
    
    // For disk usage bar simulation/real data
    @State private var totalDiskSpace: Int64 = 500 * 1024 * 1024 * 1024 // Fake default
    @State private var usedDiskSpace: Int64 = 100 * 1024 * 1024 * 1024
    
    var body: some View {
        ZStack {
            if scanner.isScanning {
                scanningPage
            } else if scanner.isCleaning {
                cleaningPage
            } else if showCleaningFinished {
                finishedPage
            } else if !scanner.foundFiles.isEmpty {
                resultsPage
            } else if scanner.hasCompletedScan {
                cleanPage
            } else {
                initialPage
                    .onAppear {
                        updateDiskUsage()
                    }
            }
        }
        .animation(.easeInOut, value: scanner.isScanning)
        .animation(.easeInOut, value: scanner.isCleaning)
        .animation(.easeInOut, value: showCleaningFinished)
        .animation(.easeInOut, value: scanner.foundFiles.isEmpty)
    }
    
    private func updateDiskUsage() {
        if let home = FileManager.default.urls(for: .userDirectory, in: .localDomainMask).first,
           let attrs = try? FileManager.default.attributesOfFileSystem(forPath: home.path),
           let size = attrs[.systemSize] as? Int64,
           let free = attrs[.systemFreeSize] as? Int64 {
            totalDiskSpace = size
            usedDiskSpace = size - free
        }
    }
    
    // MARK: - 1. Initial Page (Image 0 UI)
    var initialPage: some View {
        HStack {
            // Left Content (Text & Features & Disk Bar)
            VStack(alignment: .leading, spacing: 40) {
                // 1. Title & Subtitle
                VStack(alignment: .leading, spacing: 12) {
                    Text(loc.currentLanguage == .chinese ? "大型和旧文件" : "Large and Old Files")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Text(loc.currentLanguage == .chinese ? "查找和移除大型文件和文件夹。" : "Find and remove large files and folders.")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // 2. Features
                VStack(alignment: .leading, spacing: 24) {
                    featureRow(
                        icon: "eyeglasses",
                        title: loc.currentLanguage == .chinese ? "发现文件垃圾场" : "Spot file dumps",
                        desc: loc.currentLanguage == .chinese ? "让您轻松找出大量被遗忘的项目以确定删除它们。" : "Easily find massive forgotten items to decide on their removal."
                    )
                    featureRow(
                        icon: "slider.horizontal.3",
                        title: loc.currentLanguage == .chinese ? "轻松排列文件" : "Sort files easily",
                        desc: loc.currentLanguage == .chinese ? "提供简单、方便的过滤器，快速查看和移除不需要的文件。" : "Simple filters to quickly review and remove unneeded files."
                    )
                }
                
                // 3. Disk Usage Bar (Directly below features, no spacer)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "internaldrive.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.6))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("mac: \(ByteCountFormatter.string(fromByteCount: totalDiskSpace, countStyle: .file))")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            // Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(height: 6)
                                    
                                    Capsule()
                                        .fill(Color.green)
                                        .frame(width: geo.size.width * CGFloat(Double(usedDiskSpace) / Double(totalDiskSpace)), height: 6)
                                }
                            }
                            .frame(height: 6)
                            
                            Text(loc.currentLanguage == .chinese ? "已使用 \(ByteCountFormatter.string(fromByteCount: usedDiskSpace, countStyle: .file))" : "Used \(ByteCountFormatter.string(fromByteCount: usedDiskSpace, countStyle: .file))")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                .frame(maxWidth: 320)
            }
            .padding(.leading, 60)
            
            // Right Content (Big Icon) - Vertically centered
            VStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(
                            LinearGradient(colors: [Color.orange.opacity(0.8), Color.pink.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 250, height: 200)
                        .overlay(
                            Image(systemName: "folder.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.white.opacity(0.9))
                                .padding(40)
                        )
                        .shadow(radius: 20)
                }
                .padding(.trailing, 60)
                Spacer()
            }
        }
        .padding(.vertical, 40)
        .overlay(
            // Bottom Center Scan Button
            VStack {
                Spacer()
                CircularActionButton(
                    title: loc.currentLanguage == .chinese ? "扫描" : "Scan",
                    gradient: GradientStyles.largeFiles,
                    action: {
                        Task { await scanner.scan() }
                    }
                )
                .padding(.bottom, 30)
            }
        )
    }
    
    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    // MARK: - 2. Scanning Page (Image 1 UI)
    var scanningPage: some View {
        VStack(spacing: 40) {
            Text(loc.currentLanguage == .chinese ? "大型和旧文件" : "Large and Old Files")
                .font(.headline)
                .opacity(0.6)
                .padding(.top, 20)
            
            Spacer()
            
            ZStack {
                // Floating Folder Icon similar to Initial but centered
                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(colors: [Color.orange.opacity(0.8), Color.pink.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 200, height: 160)
                    .overlay(
                        Image(systemName: "folder.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.white.opacity(0.9))
                            .padding(30)
                    )
                    .shadow(radius: 20)
            }
            
            VStack(spacing: 16) {
                Text(loc.currentLanguage == .chinese ? "正在寻找大型和旧文件..." : "Finding large and old files...")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Scrolling path simulation - assume scanner has currentPath or similar, or just static for now as scanner is fast
                // Ideally scanner needs to publish `currentScanningPath`.
                // For now, use a placeholder or check if scanner exposes it. (Scanner doesn't Expose it yet? check. It only published count.)
                // Let's add simple progress text.
                Text(loc.currentLanguage == .chinese ? "正在扫描: \(scanner.scannedCount) 个文件" : "Scanning: \(scanner.scannedCount) files")
                     .font(.caption)
                     .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            // Stop button with ring
            CircularActionButton(
                title: loc.currentLanguage == .chinese ? "停止" : "Stop",
                progress: 0.5, // Fake progress or use scanner.progress if available
                showProgress: true,
                scanSize: ByteCountFormatter.string(fromByteCount: scanner.totalSize, countStyle: .file),
                action: {
                    scanner.stopScan()
                }
            )
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - 2.5 Clean Page (No files found)
    var cleanPage: some View {
        VStack(spacing: 30) {
            // Header
            HStack {
                Button(action: {
                    scanner.reset()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(loc.currentLanguage == .chinese ? "重新开始" : "Start Over")
                    }
                    .foregroundColor(.secondaryText)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(loc.currentLanguage == .chinese ? "大型和旧文件" : "Large and Old Files")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Placeholder for symmetry
                Text("Start Over")
                    .opacity(0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            // Central Icon (Whale substitute)
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(colors: [Color.orange.opacity(0.8), Color.pink.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 250, height: 200)
                    .overlay(
                        VStack(spacing: 10) {
                             Image(systemName: "folder.fill")
                                 .font(.system(size: 80))
                                 .foregroundColor(.white.opacity(0.9))
                             Image(systemName: "checkmark")
                                  .font(.system(size: 40))
                                  .foregroundColor(.white)
                                  .padding(8)
                                  .background(Circle().fill(Color.green))
                                  .offset(x: 40, y: 20)
                        }
                    )
                    .shadow(radius: 20)
            }
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(loc.currentLanguage == .chinese ? "非常干净！" : "Very Clean!")
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                Text(loc.currentLanguage == .chinese ? "没有发现大型或旧文件。" : "No large or old files found.")
                    .font(.body)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            // Back or Rescan button
            CircularActionButton(
                title: loc.currentLanguage == .chinese ? "返回" : "Back",
                gradient: GradientStyles.largeFiles,
                action: {
                    scanner.reset()
                }
            )
            .padding(.bottom, 40)
        }
    }

    // MARK: - 3. Results Page (Image 2 UI is DetailsSplitView, so this is just the transition or wrapper)
    // The design shows the SplitView IS the results page effectively.
    // So we should just show LargeFileDetailsSplitView directly here or embed it.
    var resultsPage: some View {
        LargeFileDetailsSplitView(scanner: scanner)
    }
    
    // MARK: - 4. Cleaning Page (Image 3 UI)
    var cleaningPage: some View {
        VStack(spacing: 40) {
            Text(loc.currentLanguage == .chinese ? "大型和旧文件" : "Large and Old Files")
                .font(.headline)
                .opacity(0.6)
                .padding(.top, 20)
            
            Spacer()
            
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.orange.opacity(0.8))
                    .frame(width: 200, height: 160)
                     .overlay(
                        Image(systemName: "folder.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.white.opacity(0.9))
                            .padding(30)
                    )
            }
            
            VStack(spacing: 16) {
                Text(loc.currentLanguage == .chinese ? "正在移除不需要的文件..." : "Removing unwanted files...")
                    .font(.title2)
                
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.orange)
                        .cornerRadius(6)
                    Text(loc.currentLanguage == .chinese ? "大型和旧文件" : "Large and Old Files")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: scanner.cleanedSize, countStyle: .file))
                    // Spinner
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.5)
                }
                .padding()
                .frame(maxWidth: 400)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
            }
            
            Spacer()
            
            CircularActionButton(
                title: loc.currentLanguage == .chinese ? "停止" : "Stop",
                progress: 0.8, // Fake
                showProgress: true,
                action: {
                    // Handle stop cleaning
                }
            )
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - 5. Finished Page (Image 4 UI)
    var finishedPage: some View {
        HStack {
            // Left: Summary
            VStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.white.opacity(0.8)) // Light theme in finished
                        .frame(width: 250, height: 250)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                }
                .shadow(radius: 20)
                
                Spacer()
                
                Button(loc.currentLanguage == .chinese ? "查看日志" : "View Log") {
                    // Log action
                }
                .buttonStyle(.plain)
                .padding(.bottom, 20)
            }
            .frame(width: 300)
            
            // Right: Details & Recommendations
            VStack(alignment: .leading, spacing: 20) {
                Text(loc.currentLanguage == .chinese ? "推荐" : "Recommendations")
                    .font(.headline)
                
                HStack(spacing: 10) {
                    recommendationCard(
                        icon: "ladybug", 
                        title: loc.currentLanguage == .chinese ? "扫描并查找恶意软件" : "Scan for Malware",
                        desc: loc.currentLanguage == .chinese ? "检测可能潜伏在..." : "Detect latent threats...",
                        btn: loc.currentLanguage == .chinese ? "运行深度扫描" : "Run Deep Scan"
                    )
                    
                    recommendationCard(
                        icon: "puzzlepiece.extension", 
                        title: loc.currentLanguage == .chinese ? "管理扩展程序" : "Manage Extensions",
                        desc: loc.currentLanguage == .chinese ? "包括插件、小部件..." : "Includes plugins...",
                        btn: loc.currentLanguage == .chinese ? "查看扩展程序" : "View Extensions"
                    )
                    
                    recommendationCard(
                        icon: "wrench.and.screwdriver", 
                        title: loc.currentLanguage == .chinese ? "维护您的 Mac" : "Maintain your Mac",
                        desc: loc.currentLanguage == .chinese ? "运行一组脚本..." : "Run scripts...",
                        btn: loc.currentLanguage == .chinese ? "运行维护" : "Run Maintenance"
                    )
                }
                
                Spacer()
                
                // Result Summary
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(loc.currentLanguage == .chinese ? "\(ByteCountFormatter.string(fromByteCount: scanner.cleanedSize, countStyle: .file)) 已移除" : "\(ByteCountFormatter.string(fromByteCount: scanner.cleanedSize, countStyle: .file)) Removed")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Text(loc.currentLanguage == .chinese ? "您现在启动磁盘中有更多可用空间。" : "You now have more free space on startup disk.")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                HStack(spacing: 16) {
                    Button(action: {
                         showCleaningFinished = false
                         scanner.reset()
                    }) {
                        Text(loc.currentLanguage == .chinese ? "查看剩余项目" : "View Remaining Items")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        // Share logic
                    }) {
                        Label(loc.currentLanguage == .chinese ? "分享成果" : "Share Result", systemImage: "square.and.arrow.up")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .buttonStyle(.plain)
                
                // Ad section style
                HStack {
                    ZStack {
                        Circle().fill(Color.white).frame(width: 40, height: 40)
                        Text("II").foregroundColor(.black).fontWeight(.bold)
                    }
                    VStack(alignment: .leading) {
                        Text(loc.currentLanguage == .chinese ? "删除重复的文件" : "Remove Duplicate Files")
                            .font(.headline)
                        Text(loc.currentLanguage == .chinese ? "通过 Gemini 移除重复项..." : "Remove duplicates via Gemini...")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.3))
                .cornerRadius(12)
            }
            .padding()
        }
        .padding(40)
        .background(Color.black.opacity(0.2)) // Darker BG for overlay effect
    }
    
    private func recommendationCard(icon: String, title: String, desc: String, btn: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
            Text(title)
                .font(.headline)
                .lineLimit(2)
            Text(desc)
                .font(.caption)
                .foregroundColor(.secondaryText)
                .lineLimit(3)
            Spacer()
            Button(action: {}) {
                Text(btn)
                    .font(.caption)
                    .foregroundColor(.black)
                    .padding(8)
                    .background(Color.yellow)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(width: 140, height: 200)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}
