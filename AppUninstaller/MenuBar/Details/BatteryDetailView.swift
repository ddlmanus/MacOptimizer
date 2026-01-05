import SwiftUI

struct BatteryDetailView: View {
    @ObservedObject var manager: MenuBarManager
    @ObservedObject var systemMonitor: SystemMonitorService
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("电池")
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
                VStack(spacing: 32) {
                    // Big Gauge
                    ZStack {
                        // Ticks
                        ForEach(0..<60) { i in
                            Rectangle()
                                .fill(Color.white.opacity(i < Int(systemMonitor.batteryLevel * 60) ? 0.8 : 0.1))
                                .frame(width: 2, height: 10)
                                .offset(y: -70)
                                .rotationEffect(.degrees(Double(i) * 6))
                        }
                        
                        VStack(spacing: 2) {
                            Text("\(Int(systemMonitor.batteryLevel * 100))%")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)
                            Text(systemMonitor.isCharging ? "正在充电" : "剩余电量")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .frame(height: 160)
                    .padding(.top, 10)
                    
                    // Info Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        BatteryInfoCard(title: "健康度", value: systemMonitor.batteryHealth, icon: "heart.fill", color: .green)
                        BatteryInfoCard(title: "循环次数", value: "\(systemMonitor.batteryCycleCount)", icon: "repeat", color: .blue)
                        BatteryInfoCard(title: "状态", value: systemMonitor.batteryCondition, icon: "battery.100", color: .orange)
                        BatteryInfoCard(title: "温度", value: "32°C", icon: "thermometer", color: .red) // Mock temp for now
                    }
                    .padding(.horizontal, 20)
                    
                    if systemMonitor.isCharging {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                            Text("电源适配器已连接")
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color(hex: "1C0C24"))
    }
}

struct BatteryInfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}
