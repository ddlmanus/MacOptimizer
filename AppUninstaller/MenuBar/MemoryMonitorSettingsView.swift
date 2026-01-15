import SwiftUI

/// 内存监控设置视图
/// 用户可以管理忽略列表和监控偏好
struct MemoryMonitorSettingsView: View {
    @ObservedObject var systemMonitor: SystemMonitorService
    @State private var ignoredApps: [String] = []
    @State private var showingClearConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            HStack {
                Image(systemName: "memorychip.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
                
                Text("内存监控设置")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
            }
            
            Divider()
            
            // 说明
            VStack(alignment: .leading, spacing: 8) {
                Text("自动监控")
                    .font(.system(size: 14, weight: .semibold))
                
                Text("系统会自动检测内存占用超过 1 GB 的应用，并在菜单栏弹出提醒。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // 忽略列表
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("已忽略的应用")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Spacer()
                    
                    if !ignoredApps.isEmpty {
                        Button("清除全部") {
                            showingClearConfirmation = true
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                    }
                }
                
                if ignoredApps.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 32))
                                .foregroundColor(.green.opacity(0.6))
                            
                            Text("没有忽略的应用")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 30)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(ignoredApps, id: \.self) { appName in
                                HStack {
                                    Image(systemName: "app.fill")
                                        .foregroundColor(.gray)
                                    
                                    Text(appName)
                                        .font(.system(size: 13))
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        removeApp(appName)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
            
            Spacer()
            
            // 提示信息
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                
                Text("选择「忽略此应用」后，该应用不会再触发内存警告。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(20)
        .frame(width: 400, height: 500)
        .onAppear {
            loadIgnoredApps()
        }
        .alert("确认清除", isPresented: $showingClearConfirmation) {
            Button("取消", role: .cancel) { }
            Button("清除全部", role: .destructive) {
                clearAllApps()
            }
        } message: {
            Text("确定要清除所有已忽略的应用吗？清除后，这些应用如果占用大量内存，将会再次触发警告。")
        }
    }
    
    private func loadIgnoredApps() {
        ignoredApps = systemMonitor.getIgnoredApps()
    }
    
    private func removeApp(_ appName: String) {
        systemMonitor.removeFromIgnoredApps(appName)
        loadIgnoredApps()
    }
    
    private func clearAllApps() {
        systemMonitor.clearAllIgnoredApps()
        loadIgnoredApps()
    }
}

#Preview {
    MemoryMonitorSettingsView(systemMonitor: SystemMonitorService())
}
