import SwiftUI

enum MonitorTab: String, CaseIterable {
    case apps = "apps"
    case background = "background"
    case ports = "ports"
}

struct MonitorView: View {
    @StateObject private var systemService = SystemMonitorService()
    @StateObject private var processService = ProcessService()
    @StateObject private var portService = PortScannerService()
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var selectedTab: MonitorTab = .apps
    @State private var searchText = ""
    
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
                Button(action: { refreshCurrentTab() }) {
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

                    // Process/Port Manager Section
                    VStack(alignment: .leading, spacing: 16) {
                        // Section Header & Tabs
                        HStack(spacing: 16) {
                            // 运行中应用 Tab
                            TabButton(
                                title: loc.currentLanguage == .chinese ? "运行中应用" : "Apps",
                                isSelected: selectedTab == .apps
                            ) {
                                selectedTab = .apps
                                Task { await processService.scanProcesses(showApps: true) }
                            }
                            
                            // 后台进程 Tab
                            TabButton(
                                title: loc.currentLanguage == .chinese ? "后台进程" : "Background",
                                isSelected: selectedTab == .background
                            ) {
                                selectedTab = .background
                                Task { await processService.scanProcesses(showApps: false) }
                            }
                            
                            // 端口 Tab
                            TabButton(
                                title: loc.currentLanguage == .chinese ? "端口" : "Ports",
                                isSelected: selectedTab == .ports
                            ) {
                                selectedTab = .ports
                                Task { await portService.scanPorts() }
                            }
                            
                            Spacer()
                            
                            // 计数显示
                            Text(countText)
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondaryText)
                            TextField(loc.currentLanguage == .chinese ? "搜索..." : "Search...", text: $searchText)
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondaryText)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 1)
                        
                        // Content based on selected tab
                        switch selectedTab {
                        case .apps, .background:
                            processListView
                        case .ports:
                            portListView
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            systemService.startMonitoring()
            Task { await processService.scanProcesses(showApps: true) }
        }
        .onDisappear {
            systemService.stopMonitoring()
        }
    }
    
    // MARK: - Helper Properties
    
    private var countText: String {
        switch selectedTab {
        case .apps, .background:
            return loc.currentLanguage == .chinese ? "共 \(processService.processes.count) 个进程" : "\(processService.processes.count) processes"
        case .ports:
            return loc.currentLanguage == .chinese ? "共 \(portService.ports.count) 个端口" : "\(portService.ports.count) ports"
        }
    }
    
    private func refreshCurrentTab() {
        // Clear search on refresh? Maybe not, user might want to refresh search results.
        Task {
            switch selectedTab {
            case .apps:
                await processService.scanProcesses(showApps: true)
            case .background:
                await processService.scanProcesses(showApps: false)
            case .ports:
                await portService.scanPorts()
            }
        }
    }
    
    // MARK: - Process List View
    
    private var processListView: some View {
        VStack(spacing: 1) {
            if processService.isScanning {
                HStack {
                    Spacer()
                    ProgressView().scaleEffect(0.6)
                    Spacer()
                }
                .padding(20)
            } else {
                // Header Row
                HStack {
                    Text(loc.currentLanguage == .chinese ? "名称" : "Name")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(loc.currentLanguage == .chinese ? "内存" : "Memory")
                        .frame(width: 80, alignment: .trailing)
                    Text("PID")
                        .frame(width: 60, alignment: .trailing)
                    Text("")
                        .frame(width: 30)
                }
                .font(.caption)
                .foregroundColor(.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                
                .background(Color.white.opacity(0.05))
                
                ForEach(processService.processes.filter { 
                    searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) 
                }) { item in
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
                        
                        Text(item.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Memory Usage
                        Text(item.formattedMemory)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(memoryColor(for: item.memoryUsage))
                            .frame(width: 80, alignment: .trailing)
                        
                        // PID
                        Text(item.formattedPID)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 60, alignment: .trailing)
                        
                        // Stop Button
                        Button(action: { processService.terminateProcess(item) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help(loc.L("stop_process"))
                        .frame(width: 30)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.02))
                    .contextMenu {
                         Button(action: {
                             processService.terminateProcess(item)
                         }) {
                             Text(loc.currentLanguage == .chinese ? "结束进程" : "Quit")
                             Image(systemName: "xmark.circle")
                         }
                         
                         Button(action: {
                             processService.forceTerminateProcess(item)
                         }) {
                             Text(loc.currentLanguage == .chinese ? "强制退出" : "Force Quit")
                             Image(systemName: "exclamationmark.octagon")
                         }
                     }
                }
                
                if processService.processes.isEmpty {
                    Text(loc.currentLanguage == .chinese ? "无相关进程" : "No processes")
                        .foregroundColor(.secondaryText)
                        .padding(20)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }
    
    /// 根据内存使用量返回颜色
    private func memoryColor(for bytes: Int64) -> Color {
        let mb = bytes / (1024 * 1024)
        if mb > 1000 { // > 1GB
            return .red
        } else if mb > 500 { // > 500MB
            return .orange
        } else if mb > 200 { // > 200MB
            return .yellow
        } else {
            return .green
        }
    }
    
    // MARK: - Port List View
    
    private var portListView: some View {
        VStack(spacing: 0) {
            if portService.isScanning {
                HStack {
                    Spacer()
                    ProgressView().scaleEffect(0.6)
                    Spacer()
                }
                .padding(20)
            } else {
                // Header Row
                HStack {
                    Text(loc.currentLanguage == .chinese ? "程序" : "Process")
                        .frame(width: 120, alignment: .leading)
                    Text("PID")
                        .frame(width: 60, alignment: .leading)
                    Text(loc.currentLanguage == .chinese ? "端口" : "Port")
                        .frame(width: 80, alignment: .leading)
                    Text(loc.currentLanguage == .chinese ? "协议" : "Protocol")
                        .frame(width: 60, alignment: .leading)
                    Text(loc.currentLanguage == .chinese ? "状态" : "Status")
                        .frame(width: 100, alignment: .leading)
                    Spacer()
                    Text(loc.currentLanguage == .chinese ? "操作" : "Action")
                        .frame(width: 60)
                }
                .font(.caption)
                .foregroundColor(.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                
                // Port Rows
                ForEach(portService.ports.filter {
                    searchText.isEmpty || $0.displayName.localizedCaseInsensitiveContains(searchText) || String($0.pid).contains(searchText) || $0.portString.contains(searchText)
                }) { port in
                    HStack {
                        // Process Name with Icon
                        HStack(spacing: 6) {
                            if let icon = port.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 18, height: 18)
                            } else {
                                Image(systemName: "network")
                                    .foregroundColor(.cyan)
                                    .frame(width: 18, height: 18)
                            }
                            Text(port.displayName)
                                .lineLimit(1)
                        }
                        .frame(width: 120, alignment: .leading)
                        
                        // PID
                        Text(String(port.pid))
                            .frame(width: 60, alignment: .leading)
                            .foregroundColor(.white.opacity(0.7))
                        
                        // Port Number
                        Text(port.portString)
                            .frame(width: 80, alignment: .leading)
                            .foregroundColor(.cyan)
                            .fontWeight(.medium)
                        
                        // Protocol
                        Text(port.protocol)
                            .frame(width: 60, alignment: .leading)
                            .foregroundColor(.white.opacity(0.7))
                        
                        // Status
                        HStack(spacing: 4) {
                            Circle()
                                .fill(port.state == "LISTEN" ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)
                            Text(port.state.isEmpty ? "-" : port.state)
                        }
                        .frame(width: 100, alignment: .leading)
                        .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        // Stop Button
                        Button(action: { portService.terminateProcess(port) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "stop.circle.fill")
                                Text(loc.currentLanguage == .chinese ? "停止" : "Stop")
                            }
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 60)
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.02))
                }
                
                if portService.ports.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "network.slash")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.3))
                        Text(loc.currentLanguage == .chinese ? "没有检测到监听端口" : "No listening ports detected")
                            .foregroundColor(.secondaryText)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - Tab Button Component

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .padding(.bottom, 4)
                .overlay(
                    Rectangle()
                        .fill(isSelected ? Color.blue : Color.clear)
                        .frame(height: 2)
                        .offset(y: 4),
                    alignment: .bottom
                )
        }
        .buttonStyle(.plain)
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
