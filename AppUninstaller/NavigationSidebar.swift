import SwiftUI

struct NavigationSidebar: View {
    @Binding var selectedModule: AppModule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部 Logo 区域
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "sparkles")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                }
                
                Text("Mac优化大师")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            
            // 导航菜单
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(AppModule.allCases) { module in
                        SidebarButton(
                            module: module,
                            isSelected: selectedModule == module,
                            action: { selectedModule = module }
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
            
            Spacer()
            
            // 底部信息
            VStack(alignment: .leading, spacing: 4) {
                Text("v2.0.0")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                Text("Pro Version")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .padding(20)
        }
        .frame(width: 240)
        .background(Color.sidebarBackground)
    }
}

struct SidebarButton: View {
    let module: AppModule
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 图标背景
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 28, height: 28)
                    }
                    Image(systemName: module.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                }
                .frame(width: 28)
                
                Text(module.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                
                Spacer()
                
                // 选中指示器
                if isSelected {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .shadow(color: .white.opacity(0.5), radius: 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    if isSelected {
                        module.gradient
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    } else if isHovering {
                        Color.white.opacity(0.05)
                            .cornerRadius(10)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
