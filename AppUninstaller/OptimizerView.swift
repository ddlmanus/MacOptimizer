import SwiftUI

struct OptimizerView: View {
    @StateObject private var optimizer = SystemOptimizer()
    @State private var showingUsageAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            if optimizer.isScanning {
                ProgressView("正在扫描启动项...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if optimizer.launchAgents.isEmpty {
                emptyStateView
            } else {
                List {
                    Section(header: Text("用户启动代理 (Launch Agents)").foregroundColor(.secondaryText)) {
                        ForEach(optimizer.launchAgents) { agent in
                            AgentRow(agent: agent, optimizer: optimizer)
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
                Text("系统优化")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("管理开机启动项，提升系统速度")
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
            Text("没有发现用户启动项")
                .font(.title3)
                .foregroundColor(.white)
            Spacer()
        }
    }
}

struct AgentRow: View {
    @ObservedObject var agent: LaunchItem
    @ObservedObject var optimizer: SystemOptimizer
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
                
                Text(agent.isEnabled ? "已启用" : "已禁用")
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
