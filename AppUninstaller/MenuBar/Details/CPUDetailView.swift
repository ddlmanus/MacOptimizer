import SwiftUI

struct CPUDetailView: View {
    @ObservedObject var manager: MenuBarManager
    @ObservedObject var systemMonitor: SystemMonitorService
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("CPU")
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
                    // Load Graph (Simple Bar/Line visualization state)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("系统负载")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                        
                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(0..<20) { _ in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.blue.opacity(0.8))
                                    .frame(width: 8, height: CGFloat.random(in: 10...80))
                            }
                        }
                        .frame(height: 100)
                        
                        Text("\(Int(systemMonitor.cpuUsage * 100))% 总占用")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    
                     // Uptime
                    HStack {
                        VStack(alignment: .leading) {
                            Text("正常运行时间")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            Text(formatUptime(systemMonitor.systemUptime))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    Divider().background(Color.white.opacity(0.1))
                    
// Top Processes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("占用率排行")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        ForEach(systemMonitor.topCPUProcesses) { process in
                            ProcessRow(
                                name: process.name, 
                                icon: process.icon, 
                                cpu: String(format: "%.1f %%", process.cpu)
                            )
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color(hex: "1C0C24"))
    }
    
    func formatUptime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours) 小时 \(minutes) 分钟"
    }
}

struct ProcessRow: View {
    let name: String
    let icon: NSImage?
    let cpu: String
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "gearshape.fill")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Text(name)
                .font(.system(size: 13))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(cpu)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Button(action: {
                // Terminate/Kill Action
            }) {
                Text("关闭")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }
}
