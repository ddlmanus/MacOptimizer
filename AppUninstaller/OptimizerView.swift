import SwiftUI

struct OptimizerView: View {
    @StateObject private var optimizer = SystemOptimizer()
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var showingUsageAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            if optimizer.isScanning {
                ProgressView(loc.currentLanguage == .chinese ? "正在扫描启动项..." : "Scanning startup items...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if optimizer.launchAgents.isEmpty {
                emptyStateView
            } else {
                List {
                    Section(header: Text(loc.currentLanguage == .chinese ? "用户启动代理 (Launch Agents)" : "User Launch Agents").foregroundColor(.secondaryText)) {
                        ForEach(optimizer.launchAgents) { agent in
                            AgentRow(agent: agent, optimizer: optimizer, loc: loc)
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .onAppear {
            Task { await optimizer.scanLaunchAgents() }
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.L("optimizer"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(loc.currentLanguage == .chinese ? "管理开机启动项，提升系统速度" : "Manage startup items to boost system speed")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            Button(action: { Task { await optimizer.scanLaunchAgents() } }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.secondaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(Color.clear)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "bolt.badge.checkmark.fill")
                .font(.system(size: 64))
                .foregroundStyle(GradientStyles.optimizer)
            Text(loc.currentLanguage == .chinese ? "没有发现用户启动项" : "No user startup items found")
                .font(.title3)
                .foregroundColor(.white)
            Spacer()
        }
    }
}

struct AgentRow: View {
    @ObservedObject var agent: LaunchItem
    @ObservedObject var optimizer: SystemOptimizer
    @ObservedObject var loc: LocalizationManager
    @State private var isPerformAction = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 20))
                .foregroundStyle(GradientStyles.optimizer)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                Text(agent.isEnabled ? (loc.currentLanguage == .chinese ? "已启用" : "Enabled") : (loc.currentLanguage == .chinese ? "已禁用" : "Disabled"))
                    .font(.caption)
                    .foregroundColor(agent.isEnabled ? .success : .secondaryText)
            }
            
            Spacer()
            
            // 启用/禁用开关
            Toggle("", isOn: Binding(
                get: { agent.isEnabled },
                set: { _ in
                    isPerformAction = true
                    Task {
                        _ = await optimizer.toggleAgent(agent)
                        isPerformAction = false
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .orange))
            .disabled(isPerformAction)
            
            // 删除按钮
            Button(action: {
                Task { await optimizer.removeAgent(agent) }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.secondaryText)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(.vertical, 8)
    }
}
