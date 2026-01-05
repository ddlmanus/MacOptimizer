import SwiftUI

struct NetworkDetailView: View {
    @ObservedObject var manager: MenuBarManager
    @ObservedObject var systemMonitor: SystemMonitorService
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Network")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { 
                    withAnimation { manager.closeDetail() }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            
            ScrollView {
                VStack(spacing: 16) {
                    // 1. Status Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            Image(systemName: "wifi")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(systemMonitor.wifiSSID)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Wi-Fi 连接") // "Wi-Fi Connected"
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Text(systemMonitor.connectionDuration)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        
                        Text("您的网络安全设置使用的是 \(systemMonitor.wifiSecurity)，其被评估为 良好。\n您可以继续使用此网络。")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack {
                            Spacer()
                            Button(action: {
                                // Open Network Settings or similar
                            }) {
                                HStack(spacing: 4) {
                                    Text("了解更多")
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 10))
                                }
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .background(Color(hex: "3A2E55")) // Card Purple
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    
                    // 2. Traffic Cards
                    HStack(spacing: 12) {
                        // Download Card
                        TrafficCard(
                            title: "下载",
                            total: systemMonitor.totalDownload,
                            speed: systemMonitor.formatSpeed(systemMonitor.downloadSpeed),
                            history: systemMonitor.downloadSpeedHistory,
                            color: Color(hex: "6A85FC") // Blueish
                        )
                        
                        // Upload Card
                        TrafficCard(
                            title: "上传",
                            total: systemMonitor.totalUpload,
                            speed: systemMonitor.formatSpeed(systemMonitor.uploadSpeed),
                            history: systemMonitor.uploadSpeedHistory,
                            color: Color(hex: "FD6585") // Pinkish
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    // 3. Speed Test Section
                    VStack(spacing: 20) {
                        Text("测试您的网络连接")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        
                        HStack(spacing: 20) {
                            // Gauge
                            ZStack {
                                // Background Dashes
                                Circle()
                                    .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 10, lineCap: .butt, dash: [2, 4]))
                                    .frame(width: 140, height: 140)
                                
                                // Active Progress Dashes
                                if systemMonitor.isTestingSpeed || systemMonitor.speedTestResult > 0 {
                                    Circle()
                                        .trim(from: 0, to: systemMonitor.isTestingSpeed ? systemMonitor.speedTestProgress : 1.0)
                                        .stroke(
                                            LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                                            style: StrokeStyle(lineWidth: 10, lineCap: .butt, dash: [2, 4])
                                        )
                                        .rotationEffect(.degrees(-90))
                                        .frame(width: 140, height: 140)
                                        .animation(.linear(duration: 0.5), value: systemMonitor.speedTestProgress)
                                }
                                
                                // Center Content
                                VStack {
                                    if systemMonitor.isTestingSpeed {
                                        Text("Testing")
                                            .font(.headline)
                                            .foregroundColor(.cyan)
                                    } else if systemMonitor.speedTestResult > 0 {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.green)
                                        Text("完成")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    } else {
                                        // Idle state
                                        Button(action: {
                                            systemMonitor.runSpeedTest()
                                        }) {
                                           Text("开始")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .padding(20)
                                                .background(Circle().fill(Color.white.opacity(0.1)))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                                // Re-test overlay if done (Full overlay button)
                                if !systemMonitor.isTestingSpeed && systemMonitor.speedTestResult > 0 {
                                     Button(action: {
                                        systemMonitor.runSpeedTest()
                                    }) {
                                        VStack {
                                            Spacer()
                                            Text("再测一次")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.8))
                                                .padding(.bottom, 30)
                                        }
                                        .frame(width: 140, height: 140)
                                        .contentShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            // Results List
                            if systemMonitor.speedTestResult > 0 {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(String(format: "%.1f", systemMonitor.speedTestResult)) Mbps")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("适合：")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        SuitabilityRow(text: "网络游戏")
                                        SuitabilityRow(text: "观看网络视频")
                                        SuitabilityRow(text: "视频通话")
                                        SuitabilityRow(text: "听网络音乐")
                                        SuitabilityRow(text: "语音通话")
                                        SuitabilityRow(text: "通信")
                                    }
                                }
                            } else {
                                // Placeholder when no test result yet
                                Text(systemMonitor.isTestingSpeed ? "正在测速..." : "点击开始测试")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 30)
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color(hex: "1C0C24"))
    }
}

struct TrafficCard: View {
    let title: String
    let total: String
    let speed: String
    let history: [Double]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            HStack(alignment: .bottom) {
                Text(total)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(speed)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Mini Graph
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height))
                    for i in 0..<history.count {
                        let x = width * CGFloat(i) / CGFloat(max(history.count - 1, 1))
                        let val = CGFloat(history[i])
                        let y = height - (min(val / 1024 / 1024 / 2, 1.0) * height) // Normalize
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: [color.opacity(0.5), color.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                
                // Stroke Line
                Path { path in
                    // Re-calculate line without close
                    for i in 0..<history.count {
                        let x = width * CGFloat(i) / CGFloat(max(history.count - 1, 1))
                        let val = CGFloat(history[i])
                        let y = height - (min(val / 1024 / 1024 / 2, 1.0) * height)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, lineWidth: 2)
            }
            .frame(height: 40)
        }
        .padding(12)
        .background(Color(hex: "3A2E55"))
        .cornerRadius(12)
    }
}

struct SuitabilityRow: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white)
        }
    }
}
