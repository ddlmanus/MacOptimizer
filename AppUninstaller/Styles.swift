import SwiftUI
import AppKit

// MARK: - 全局配色方案 (CleanMyMac X 风格)
extension Color {
    // 背景色
    static let mainBackground = Color(red: 0.10, green: 0.10, blue: 0.12) // 深空灰背景
    static let sidebarBackground = Color.black.opacity(0.2) // 透明度侧边栏
    static let cardBackground = Color.white.opacity(0.08) // 更通透的卡片背景
    static let cardHover = Color.white.opacity(0.12)
    
    // 文本颜色
    static let primaryText = Color.white.opacity(0.95)
    static let secondaryText = Color.white.opacity(0.7)
    static let tertiaryText = Color.white.opacity(0.4)
    
    // 功能模块强调色
    // 1. 卸载器 (蓝色系 - 智能/冷静)
    static let uninstallerStart = Color(red: 0.0, green: 0.6, blue: 1.0)
    static let uninstallerEnd = Color(red: 0.0, green: 0.4, blue: 0.9)
    
    // 2. 垃圾清理 (紫色系 - 深度/清理)
    static let cleanerStart = Color(red: 0.8, green: 0.2, blue: 0.8)
    static let cleanerEnd = Color(red: 0.6, green: 0.1, blue: 0.9)
    
    // 3. 系统优化 (橙色系 - 活力/加速)
    static let optimizerStart = Color(red: 1.0, green: 0.6, blue: 0.2)
    static let optimizerEnd = Color(red: 1.0, green: 0.4, blue: 0.1)
    
    // 状态色
    static let danger = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let success = Color(red: 0.2, green: 0.8, blue: 0.5)
    static let warning = Color(red: 1.0, green: 0.8, blue: 0.2)
}

// MARK: - 渐变样式
struct GradientStyles {
    static let uninstaller = LinearGradient(
        colors: [.uninstallerStart, .uninstallerEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cleaner = LinearGradient(
        colors: [.cleanerStart, .cleanerEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let optimizer = LinearGradient(
        colors: [.optimizerStart, .optimizerEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let danger = LinearGradient(
        colors: [.danger, Color(red: 0.8, green: 0.1, blue: 0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let largeFiles = LinearGradient(
        colors: [Color(red: 0.3, green: 0.0, blue: 0.8), Color(red: 0.2, green: 0.0, blue: 0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let trash = LinearGradient(
        colors: [Color(red: 0.7, green: 0.1, blue: 0.1), Color(red: 0.4, green: 0.0, blue: 0.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 6. 系统监控 (青色 - 数据/科技)
    static let monitor = LinearGradient(
        colors: [Color(red: 0.0, green: 0.5, blue: 0.5), Color(red: 0.0, green: 0.3, blue: 0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 侧边栏选中高亮
    static func sidebarSelected(for module: AppModule) -> LinearGradient {
        switch module {
        case .monitor: return monitor
        case .uninstaller: return uninstaller
        case .cleaner: return cleaner
        case .optimizer: return optimizer
        case .largeFiles: return largeFiles
        case .trash: return trash
        }
    }
}

// MARK: - 背景渐变样式 (全屏)
struct BackgroundStyles {
    // 1. 卸载器 (深邃蓝 - 科技/纯净)
    static let uninstaller = LinearGradient(
        stops: [
            .init(color: Color(red: 0.0, green: 0.5, blue: 1.0), location: 0.0), // 亮蓝
            .init(color: Color(red: 0.0, green: 0.1, blue: 0.4), location: 1.0)  // 深蓝
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 2. 垃圾清理 (洋红/紫 - 参考用户提供的 CleanMyMac 截图)
    static let cleaner = LinearGradient(
        stops: [
            .init(color: Color(red: 0.8, green: 0.0, blue: 0.5), location: 0.0), // 洋红
            .init(color: Color(red: 0.4, green: 0.0, blue: 0.4), location: 1.0)  // 深紫
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 3. 系统优化 (活力橙 - 加速/能量)
    static let optimizer = LinearGradient(
        stops: [
            .init(color: Color(red: 1.0, green: 0.5, blue: 0.0), location: 0.0), // 橙色
            .init(color: Color(red: 0.6, green: 0.2, blue: 0.0), location: 1.0)  // 深褐
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 4. 大文件查找 (深空紫 - 探索/宇宙)
    static let largeFiles = LinearGradient(
        stops: [
            .init(color: Color(red: 0.1, green: 0.0, blue: 0.3), location: 0.0), // 深邃紫
            .init(color: Color(red: 0.3, green: 0.0, blue: 0.6), location: 1.0)  // 亮紫
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 5. 废纸篓 (红色 - 删除/清理)
    static let trash = LinearGradient(
        stops: [
            .init(color: Color(red: 0.7, green: 0.1, blue: 0.1), location: 0.0),
            .init(color: Color(red: 0.4, green: 0.0, blue: 0.0), location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let monitor = LinearGradient(
        stops: [
            .init(color: Color(red: 0.0, green: 0.2, blue: 0.2), location: 0.0), // Deep Teal
            .init(color: Color(red: 0.0, green: 0.4, blue: 0.4), location: 1.0)  // Bright Teal
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - 模块枚举
enum AppModule: String, CaseIterable, Identifiable {
    case monitor = "控制台"
    case uninstaller = "应用卸载"
    case cleaner = "垃圾清理"
    case optimizer = "系统优化"
    case largeFiles = "大文件查找"
    case trash = "废纸篓"
    
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .monitor: return "chart.bar.xaxis"
        case .uninstaller: return "square.grid.2x2.fill"
        case .cleaner: return "trash.fill"
        case .optimizer: return "bolt.fill"
        case .largeFiles: return "magnifyingglass.circle.fill"
        case .trash: return "trash.circle.fill"
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .monitor: return GradientStyles.monitor
        case .uninstaller: return GradientStyles.uninstaller
        case .cleaner: return GradientStyles.cleaner
        case .optimizer: return GradientStyles.optimizer
        case .largeFiles: return GradientStyles.largeFiles
        case .trash: return GradientStyles.trash
        }
    }
    
    var backgroundGradient: LinearGradient {
        switch self {
        case .monitor: return BackgroundStyles.monitor
        case .uninstaller: return BackgroundStyles.uninstaller
        case .cleaner: return BackgroundStyles.cleaner
        case .optimizer: return BackgroundStyles.optimizer
        case .largeFiles: return BackgroundStyles.largeFiles
        case .trash: return BackgroundStyles.trash
        }
    }
    
    var description: String {
        switch self {
        case .monitor: return "CPU、内存、网络端口实时监控"
        case .uninstaller: return "完全删除应用及其残留文件"
        case .cleaner: return "清理缓存和系统垃圾"
        case .optimizer: return "管理启动项，释放内存"
        case .largeFiles: return "发现并清理占用空间的大文件"
        case .trash: return "查看并清空废纸篓"
        }
    }
}

// MARK: - 通用组件修饰符

struct ModernCardStyle: ViewModifier {
    var hoverEffect: Bool = true
    @State private var isHovering = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isHovering && hoverEffect ? Color.cardHover : Color.cardBackground)
                    .animation(.easeInOut(duration: 0.2), value: isHovering)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, y: 4)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

struct GlassEffect: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.thinMaterial)
    }
}

// MARK: - 按钮样式
struct CapsuleButtonStyle: ButtonStyle {
    var gradient: LinearGradient
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(gradient)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    func modernCard() -> some View {
        modifier(ModernCardStyle())
    }
    
    func glassEffect() -> some View {
        modifier(GlassEffect())
    }
}

// MARK: - 复选框样式
struct CheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isOn ? GradientStyles.cleaner : LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 20, height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(configuration.isOn ? Color.clear : Color.white.opacity(0.3), lineWidth: 1)
                    )
                
                if configuration.isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    configuration.isOn.toggle()
                }
            }
            
            configuration.label
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(isDestructive ? GradientStyles.danger : GradientStyles.uninstaller)
                    .shadow(color: (isDestructive ? Color.danger : Color.uninstallerStart).opacity(0.4), radius: 8, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 32
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(configuration.isPressed ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
