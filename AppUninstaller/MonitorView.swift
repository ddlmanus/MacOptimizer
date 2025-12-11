import SwiftUI

struct MonitorView: View {
    @StateObject private var systemService = SystemMonitorService()
    @StateObject private var processService = ProcessService()
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var showApps = true // Toggle between Apps and Background Tasks
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(loc.L("monitor"))
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                    Text(loc.L("monitor_desc"))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                
                // Refresh Button
                Button(action: { Task { await processService.scanProcesses(showApps: showApps) } }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(32)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Top Row: CPU & Memory
                    HStack(spacing: 20) {
                        MonitorCard(title: loc.L("cpu_usage"), icon: "cpu", color: .blue) {
                            UsageRing(percentage: systemService.cpuUsage, label: String(format: "%.1f%%", systemService.cpuUsage * 100))
                        }
                        
                        MonitorCard(title: loc.L("memory_usage"), icon: "memorychip", color: .green) {
                            VStack(spacing: 8) {
                                UsageRing(percentage: systemService.memoryUsage, label: String(format: "%.0f%%", systemService.memoryUsage * 100))
                                Text("\(systemService.memoryUsedString) / \(systemService.memoryTotalString)")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                        }
                    }
                    .frame(height: 200)
                    
                    // Disk Usage
                    HStack(spacing: 20) {
                        MonitorCard(title: loc.L("disk_usage"), icon: "internaldrive", color: .purple) {
                             DiskUsageView()
                                 .padding(.top, 20)
                        }
                        .frame(height: 140)
                    }

                    // Process Manager Section
                    VStack(alignment: .leading, spacing: 16) {
                        // Section Header & Tabs
                        HStack(spacing: 16) {
                            Button(action: { 
                                showApps = true 
                                Task { await processService.scanProcesses(showApps: true) }
                            }) {
                                Text(loc.currentLanguage == .chinese ? "运行中应用" : "Running Apps")
                                    .fontWeight(.semibold)
                                    .foregroundColor(showApps ? .white : .white.opacity(0.5))
                                    .padding(.bottom, 4)
                                    .overlay(
                                        Rectangle()
                                            .fill(showApps ? Color.blue : Color.clear)
                                            .frame(height: 2)
                                            .offset(y: 4),
                                        alignment: .bottom
                                    )
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: { 
                                showApps = false 
                                Task { await processService.scanProcesses(showApps: false) }
                            }) {
                                Text(loc.currentLanguage == .chinese ? "后台进程" : "Background")
                                    .fontWeight(.semibold)
                                    .foregroundColor(!showApps ? .white : .white.opacity(0.5))
                                    .padding(.bottom, 4)
                                    .overlay(
                                        Rectangle()
                                            .fill(!showApps ? Color.blue : Color.clear)
                                            .frame(height: 2)
                                            .offset(y: 4),
                                        alignment: .bottom
                                    )
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            Text(loc.currentLanguage == .chinese ? "共 \(processService.processes.count) 个进程" : "\(processService.processes.count) processes")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        
                        // Process List
                        VStack(spacing: 1) {
                            if processService.isScanning {
                                HStack {
                                    Spacer()
                                    ProgressView().scaleEffect(0.6)
                                    Spacer()
                                }
                                .padding(20)
                            } else {
                                ForEach(processService.processes) { item in
                                    HStack {
                                        if let icon = item.icon {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .frame(width: 24, height: 24)
                                        } else {
                                            Image(systemName: "gearshape")
                                                .foregroundColor(.secondaryText)
                                                .frame(width: 24, height: 24)
                                        }
                                        
                                        VStack(alignment: .leading) {
                                            Text(item.name)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.white)
                                            Text("PID: \(item.formattedPID)")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                        
                                        Spacer()
                                        
                                        // Stop Button
                                        Button(action: { processService.terminateProcess(item) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red.opacity(0.8))
                                        }
                                        .buttonStyle(.plain)
                                        .help(loc.L("stop_process"))
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.02))
                                }
                                
                                if processService.processes.isEmpty {
                                    Text("无相关进程")
                                        .foregroundColor(.secondaryText)
                                        .padding(20)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            systemService.startMonitoring()
            Task { await processService.scanProcesses(showApps: showApps) }
        }
        .onDisappear {
            systemService.stopMonitoring()
        }
    }
}

struct MonitorCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

struct UsageRing: View {
    let percentage: Double
    let label: String
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 10)
            
            Circle()
                .trim(from: 0, to: percentage)
                .stroke(
                    AngularGradient(
                        colors: [.blue, .cyan, .green],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0), value: percentage)
            
            Text(label)
                .font(.title2)
                .bold()
                .foregroundColor(.white)
        }
        .padding(10)
    }
}
