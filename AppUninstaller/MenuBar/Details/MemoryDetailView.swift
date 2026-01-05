import SwiftUI

struct MemoryDetailView: View {
    @ObservedObject var manager: MenuBarManager
    @ObservedObject var systemMonitor: SystemMonitorService
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("内存")
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
                VStack(spacing: 24) {
                    // 1. Gauge and Legend Section
                    HStack(spacing: 20) {
                        // Gauge
                        ZStack {
                            // Background Track
                            Circle()
                                .trim(from: 0.1, to: 0.9)
                                .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                                .rotationEffect(.degrees(90))
                                .frame(width: 160, height: 160)
                            
                            // Used Memory Gradient Arc
                            // Calculate trim end based on used percentage
                            // Used = 1.0 - Available% roughly, or (Total - Available) / Total
                            // For visualization, let's use systemMonitor.memoryUsage (which is Used%)
                            let fillTo = 0.1 + (0.8 * systemMonitor.memoryUsage)
                            
                            Circle()
                                .trim(from: 0.1, to: fillTo)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color(hex: "6A85FC"), Color(hex: "00C7BE")], // Purple-Blue to Cyan
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                                )
                                .rotationEffect(.degrees(90))
                                .frame(width: 160, height: 160)
                                .shadow(color: Color(hex: "6A85FC").opacity(0.3), radius: 10)
                            
                            // Center Text (Available)
                            VStack(spacing: 2) {
                                // Calculate Available: Total * (1 - Usage)
                                // Or use pre-formatted string if we add available property. 
                                // Let's calculate on fly or add helper.
                                let total = ProcessInfo.processInfo.physicalMemory
                                let used = Double(total) * systemMonitor.memoryUsage
                                let available = Double(total) - used
                                
                                Text(formatSimpleGB(available))
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                Text("可用空间")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("(总共 \(systemMonitor.memoryTotalString))")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        
                        // Legend
                        VStack(alignment: .leading, spacing: 12) {
                            MemoryLegendItem(color: Color(hex: "00C7BE"), label: "活跃内存", value: formatGB(systemMonitor.memoryApp))
                            MemoryLegendItem(color: Color(hex: "6A85FC"), label: "联动内存", value: formatGB(systemMonitor.memoryWired))
                            MemoryLegendItem(color: Color(hex: "A358DF"), label: "被压缩", value: formatGB(systemMonitor.memoryCompressed))
                        }
                    }
                    .padding(.top, 10)
                    
                    // 2. Info Cards (Pressure & Swap)
                    HStack(spacing: 12) {
                        // Pressure Card
                        MemoryInfoCard(
                            title: "压力",
                            value: String(format: "%.0f%%", systemMonitor.memoryPressure * 100),
                            desc: "Mac 现在可以随时处理更多任务。",
                            linkText: "了解更多"
                        )
                        
                        // Swap Card
                        MemoryInfoCard(
                            title: "交换文件",
                            value: systemMonitor.memorySwapUsed, // e.g. "2.4 GB"
                            desc: "驱动器上的空间可以帮助您优化 Mac 的内存性能。",
                            linkText: "了解更多"
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    // 3. Top Consumers Header
                    VStack(alignment: .leading, spacing: 16) {
                        Text("占用率排行")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 2) {
                           // Header Row
                            HStack {
                                Text("进程名称")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                                Spacer()
                                Text("占用率")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(width: 60, alignment: .trailing)
                                Text("") // Spacer for button
                                    .frame(width: 40)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 4)
                            
                            ForEach(systemMonitor.topMemoryProcesses) { process in
                                MemoryAppRowPro(
                                    name: process.name,
                                    icon: process.icon,
                                    memory: String(format: "%.2f GB", process.memory)
                                )
                            }
                        }
                        .background(Color(hex: "2A203B")) // Slightly lighter background for list
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color(hex: "1C0C24")) // Main Background
    }
    
    // Helpers
    func formatGB(_ fraction: Double) -> String {
        let total = ProcessInfo.processInfo.physicalMemory
        let bytes = Double(total) * fraction
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
    
    func formatSimpleGB(_ bytes: Double) -> String {
        let gb = bytes / 1024 / 1024 / 1024
        return String(format: "%.2f GB", gb)
    }
}

// Subviews

struct MemoryLegendItem: View {
    let color: Color
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.leading, 14) // Align with text above
        }
    }
}

struct MemoryInfoCard: View {
    let title: String
    let value: String
    let desc: String
    let linkText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            
            Text(desc)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: .infinity, alignment: .topLeading)
            
            HStack {
                Spacer()
                Button(action: {}) {
                    HStack(spacing: 2) {
                        Text(linkText)
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(height: 120) // Fixed height for alignment
        .background(Color(hex: "3A2E55"))
        .cornerRadius(12)
    }
}

struct MemoryAppRowPro: View {
    let name: String
    let icon: NSImage?
    let memory: String
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.fill")
                    .frame(width: 24, height: 24)
                    .foregroundColor(.gray)
            }
            
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(memory)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "FFD700")) // Gold/Yellow color for value
            
            Button(action: {
                // Action
            }) {
                Text("关闭")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 40)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        // Separator handled by VStack spacing or explicit Divider if needed, 
        // but simple list look is clean.
        .background(Color(hex: "2A203B")) // Match container
    }
}
