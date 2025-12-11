import SwiftUI

struct NavigationSidebar: View {
    @Binding var selectedModule: AppModule
    @ObservedObject var localization = LocalizationManager.shared
    
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
                
                Text(localization.currentLanguage == .chinese ? "Mac优化大师" : "MacOptimizer")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // 语言切换按钮
                Button(action: { localization.toggleLanguage() }) {
                    HStack(spacing: 4) {
                        Text(localization.currentLanguage.flag)
                            .font(.system(size: 14))
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(L("switch_language"))
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
                            action: { selectedModule = module },
                            localization: localization
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
            
            Spacer()
            
            // 底部信息
            VStack(alignment: .leading, spacing: 4) {
                Text("v2.1.0")
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
    @ObservedObject var localization: LocalizationManager
    @State private var isHovering = false
    
    // 获取本地化的模块名称
    private var localizedName: String {
        switch module {
        case .monitor: return localization.L("monitor")
        case .uninstaller: return localization.L("uninstaller")
        case .deepClean: return localization.L("deepClean")
        case .cleaner: return localization.L("cleaner")
        case .optimizer: return localization.L("optimizer")
        case .largeFiles: return localization.L("largeFiles")
        case .fileExplorer: return localization.L("fileExplorer")
        case .trash: return localization.L("trash")
        }
    }
    
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
                
                Text(localizedName)
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
