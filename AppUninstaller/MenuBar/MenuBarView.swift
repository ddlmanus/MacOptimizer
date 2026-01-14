import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var manager: MenuBarManager
    @EnvironmentObject var systemMonitor: SystemMonitorService
    
    var body: some View {
        VStack(spacing: 0) {
            // Header: Recommendations
            VStack(alignment: .leading, spacing: 12) {
                Text("推荐")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 12) {
                    RecommendationCard(
                        icon: "arrow.triangle.2.circlepath",
                        title: "更新应用程序以获得新功能和更高的稳定性。",
                        buttonTitle: "更新应用程序"
                    )
                    
                    RecommendationCard(
                        icon: "puzzlepiece.extension",
                        title: "管理插件、小组件和偏好设置面板。",
                        buttonTitle: "管理扩展程序"
                    )
                }
            }
            .padding()
            .background(LinearGradient(gradient: Gradient(colors: [Color(hex: "4A0E4E"), Color(hex: "2E0836")]), startPoint: .topLeading, endPoint: .bottomTrailing))
            
            // Mac Overview
            VStack(alignment: .leading, spacing: 12) {
                Text("Mac 概览")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Protection Status
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("防护服务提供者：")
                        .font(.system(size: 12))
                    Text("moonlock")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text("受保护")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color(white: 1.0, opacity: 0.05))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Real-time monitor (Mock)
                VStack(alignment: .leading, spacing: 4) {
                    Text("实时恶意软件监控开启")
                        .font(.system(size: 11, weight: .semibold))
                    HStack {
                        Text("上次扫描的文件格式：GoogleUpdater")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    HStack {
                        Text("数据库更新上次检查时间：3 分钟前")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("马上检查")
                            .font(.system(size: 10))
                            .underline()
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Widgets Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StorageWidget()
                        .onTapGesture { manager.showDetail(route: .storage) }
                    MemoryWidget(systemMonitor: systemMonitor)
                        .onTapGesture { manager.showDetail(route: .memory) }
                    BatteryWidget(systemMonitor: systemMonitor)
                        .onTapGesture { manager.showDetail(route: .battery) }
                    CPUWidget(systemMonitor: systemMonitor)
                        .onTapGesture { manager.showDetail(route: .cpu) }
                    NetworkWidget(systemMonitor: systemMonitor)
                        .onTapGesture { manager.showDetail(route: .network) }
                    ConnectedDevicesWidget()
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 20, height: 20)
                Spacer()
                Text("打开 Mac优化大师")
                    .font(.system(size: 12))
                    .onTapGesture {
                        manager.openMainApp()
                    }
                Spacer()
                Menu {
                    Button(action: {
                        manager.openMainApp()
                    }) {
                        Text("关于 Mac优化大师")
                    }
                    Button(action: {
                        // Feedback action placeholder
                    }) {
                        Text("提供反馈...")
                    }
                    Divider()
                    Button(action: {
                        // Open Settings (Placeholder, or implementation if SettingsView exists)
                        // If SettingsView is part of main app, open main app then settings.
                        // Ideally, we open the Settings window directly using Preferences Window Controller.
                        // For now, let's open main app.
                        manager.openMainApp()
                    }) {
                        Text("偏好设置...")
                    }
                    Divider()
                    Button(action: {
                        // Set flag to allow quit
                        UserDefaults.standard.set(true, forKey: "ForceQuitApp")
                        NSApplication.shared.terminate(nil)
                    }) {
                        Text("退出 (Quit)")
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        
            if systemMonitor.showHighMemoryAlert {
                MemoryAlertView(systemMonitor: systemMonitor, openAppAction: {
                    manager.openMainApp()
                })
                    .padding(.top, 10) // Positioned below the icon roughly
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(Color.black.opacity(0.01)) // Catch clicks outside if needed, or just let it overlay
            }
        }
        .frame(width: 380)
        .background(Color(hex: "1C0C24")) // Deep purple background
    }
}

// ... RecommendationCard and MenuBarAlertView remain same ...
struct RecommendationCard: View {
    let icon: String
    let title: String
    let buttonTitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.8))
            
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 40, alignment: .topLeading)
            
            Spacer()
            
            Text(buttonTitle)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.yellow) // CleanMyMac yellow
                .cornerRadius(4)
        }
        .padding(10)
        .frame(height: 120)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
}
struct MenuBarAlertView: View {
    @ObservedObject var systemMonitor: SystemMonitorService
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = systemMonitor.highMemoryApp?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.yellow)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(systemMonitor.highMemoryApp?.name ?? "未知应用")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text("占用大量内存 (\(String(format: "%.1f", systemMonitor.highMemoryApp?.usage ?? 0)) GB)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Button("释放") {
                withAnimation {
                    systemMonitor.terminateHighMemoryApp()
                }
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .cornerRadius(6)
            
            Button(action: {
                withAnimation {
                    systemMonitor.ignoreCurrentHighMemoryApp()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(Color(hex: "2C2C3E")) // Dark popup background
        .cornerRadius(10)
        .shadow(radius: 5)
        .padding(.horizontal, 10)
    }
}


