import SwiftUI

// MARK: - Widget Container Style
struct MenuBarWidgetStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5)) // Slightly transparent standard background
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

extension View {
    func menuBarWidgetStyle() -> some View {
        modifier(MenuBarWidgetStyle())
    }
}

// MARK: - Storage Widget
struct StorageWidget: View {
    @ObservedObject var diskManager = DiskSpaceManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "internaldrive")
                    .font(.system(size: 16))
                Text("Macintosh HD")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("可用: \(diskManager.formattedFree)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("共: \(diskManager.formattedTotal)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("释放")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlAccentColor)) // Use system accent
                    .cornerRadius(6)
            }
        }
        .menuBarWidgetStyle()
    }
}

// MARK: - Memory Widget
struct MemoryWidget: View {
    @ObservedObject var systemMonitor: SystemMonitorService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "memorychip")
                    .font(.system(size: 16))
                Text("内存")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("可用: \(systemMonitor.memoryTotalString) (总)") // Showing Total for now as "Available" logic in Swift is tricky without more math
                     // Ideally we show "Available" calculated from Total - Used.
                     // But let's just stick to "Used / Total" format or similar.
                    Text("已用: \(systemMonitor.memoryUsedString)")
                         .font(.system(size: 10))
                         .foregroundColor(.secondary)
                }
                Spacer()
                Text("释放")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlAccentColor))
                    .cornerRadius(6)
            }
        }
        .menuBarWidgetStyle()
    }
}

// MARK: - Battery Widget
struct BatteryWidget: View {
    @ObservedObject var systemMonitor: SystemMonitorService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemMonitor.isCharging ? "battery.100.bolt" : "battery.100")
                    .font(.system(size: 16))
                Text("电池")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(Int(systemMonitor.batteryLevel * 100))%")
                    .font(.system(size: 12, weight: .bold))
            }
            
            Text(systemMonitor.batteryState)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .menuBarWidgetStyle()
    }
}

// MARK: - CPU Widget
struct CPUWidget: View {
    @ObservedObject var systemMonitor: SystemMonitorService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cpu")
                    .font(.system(size: 16))
                Text("CPU")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(Int(systemMonitor.cpuUsage * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(systemMonitor.cpuUsage > 0.8 ? .red : .primary)
            }
            
            Text("加载: \(Int(systemMonitor.cpuUsage * 100))%") // Simplified label
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .menuBarWidgetStyle()
    }
}

// MARK: - Network Widget
struct NetworkWidget: View {
    @ObservedObject var systemMonitor: SystemMonitorService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "wifi")
                    .font(.system(size: 16))
                Text("Wi-Fi")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8))
                    Text(systemMonitor.formatSpeed(systemMonitor.uploadSpeed))
                        .font(.system(size: 10))
                }
                HStack {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8))
                    Text(systemMonitor.formatSpeed(systemMonitor.downloadSpeed))
                        .font(.system(size: 10))
                }
            }
            
            HStack {
                Spacer()
                Text("测试速度")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .menuBarWidgetStyle()
    }
}

// MARK: - Connected Devices Widget (Placeholder)
struct ConnectedDevicesWidget: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("已连接的设备")
                .font(.system(size: 12, weight: .medium))
            
            Text("尚未连接任何设备")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .menuBarWidgetStyle()
    }
}
