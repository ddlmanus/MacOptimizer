import SwiftUI
import AppKit

// MARK: - 全局配色方案 (CleanMyMac X 风格)
extension Color {
    // 背景色
    static let mainBackground = Color(red: 0.12, green: 0.12, blue: 0.18) // 更深邃的蓝紫背景
    static let sidebarBackground = Color.black.opacity(0.15)
    static let cardBackground = Color.white.opacity(0.06) // 极简半透明
    static let cardHover = Color.white.opacity(0.10)
    
    // 文本颜色
    static let primaryText = Color.white.opacity(0.95)
    static let secondaryText = Color.white.opacity(0.7)
    static let tertiaryText = Color.white.opacity(0.4)
    
    // 4. 碎纸机 (蓝色系)
    static let shredderStart = Color(red: 0.0, green: 0.5, blue: 1.0)
    static let shredderEnd = Color(red: 0.0, green: 0.3, blue: 0.8)
    
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
    
    // MARK: - Hex Extension
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
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
    
    static let shredder = LinearGradient(
        colors: [.shredderStart, .shredderEnd],
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
        colors: [Color(red: 0.0, green: 0.8, blue: 0.7), Color(red: 0.0, green: 0.4, blue: 0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 6. 控制台 (洋红/紫色 - 与背景协调)
    static let monitor = LinearGradient(
        colors: [Color(red: 0.9, green: 0.2, blue: 0.6), Color(red: 0.6, green: 0.1, blue: 0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 7. 深度清理 (翡翠绿)
    static let deepClean = LinearGradient(
        colors: [Color(red: 0.0, green: 0.6, blue: 0.4), Color(red: 0.0, green: 0.3, blue: 0.2)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 8. 文件管理器 (钢蓝色)
    static let fileExplorer = LinearGradient(
        colors: [Color(red: 0.2, green: 0.4, blue: 0.6), Color(red: 0.1, green: 0.2, blue: 0.4)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 9. 隐私保护 (粉紫渐变 - 匹配设计图)
    static let privacy = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.85, green: 0.45, blue: 0.65), // 粉色
            Color(red: 0.65, green: 0.25, blue: 0.55)  // 紫色
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 10. 智能清理 (蓝绿色)
    static let smartClean = LinearGradient(
        colors: [Color(red: 0.0, green: 0.6, blue: 0.8), Color(red: 0.0, green: 0.4, blue: 0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 侧边栏选中高亮
    static func sidebarSelected(for module: AppModule) -> LinearGradient {
        switch module {
        case .monitor: return monitor
        case .uninstaller: return uninstaller
        case .deepClean: return deepClean
        case .cleaner: return cleaner
        case .maintenance: return optimizer
        case .optimizer: return optimizer
        case .shredder: return shredder
        case .largeFiles: return largeFiles
        case .fileExplorer: return fileExplorer
        case .trash: return trash
        case .privacy: return privacy
        case .smartClean: return smartClean
        }
    }

    // Design-specific gradients
    static let purple = LinearGradient(colors: [Color(hex: "B657FF"), Color(hex: "8A2BE2")], startPoint: .topLeading, endPoint: .bottomTrailing)
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
    
    // 5. 废纸篓 (青绿色 - 清新/整理) - 匹配设计图
    static let trash = LinearGradient(
        stops: [
            .init(color: Color(red: 0.0, green: 0.8, blue: 0.7), location: 0.0), // 青绿
            .init(color: Color(red: 0.0, green: 0.4, blue: 0.5), location: 1.0)  // 深青
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let monitor = LinearGradient(
        stops: [
            .init(color: Color(red: 0.8, green: 0.0, blue: 0.5), location: 0.0), // 洋红 (同系统垃圾)
            .init(color: Color(red: 0.4, green: 0.0, blue: 0.4), location: 1.0)  // 深紫
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 6. 深度清理 (翡翠绿 - 深度/精准)
    static let deepClean = LinearGradient(
        stops: [
            .init(color: Color(red: 0.0, green: 0.4, blue: 0.3), location: 0.0), // 翡翠绿
            .init(color: Color(red: 0.0, green: 0.2, blue: 0.15), location: 1.0) // 深绿
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 7. 文件管理器 (钢蓝色)
    static let fileExplorer = LinearGradient(
        stops: [
            .init(color: Color(red: 0.15, green: 0.3, blue: 0.5), location: 0.0), // 钢蓝
            .init(color: Color(red: 0.08, green: 0.15, blue: 0.3), location: 1.0) // 深蓝
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 8. 隐私保护 (粉紫渐变 - 匹配设计图)
    static let privacy = LinearGradient(
        stops: [
            .init(color: Color(red: 0.85, green: 0.45, blue: 0.65), location: 0.0), // 粉色
            .init(color: Color(red: 0.45, green: 0.2, blue: 0.45), location: 1.0)  // 深紫
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 9. 智能清理 (紫靛色渐变 - 匹配设计图)
    static let smartClean = LinearGradient(
        stops: [
            .init(color: Color(red: 0.40, green: 0.32, blue: 0.62), location: 0.0), // 浅紫向上
            .init(color: Color(red: 0.18, green: 0.16, blue: 0.35), location: 0.7), // 深靛蓝
            .init(color: Color(red: 0.12, green: 0.12, blue: 0.25), location: 1.0)  // 最深底部
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // 11. 扫描分类渐变 (Card Backgrounds)
    static let cardCleaning = LinearGradient( // Cleaning - Green/Teal
        stops: [
            .init(color: Color(red: 0.0, green: 0.6, blue: 0.4).opacity(0.8), location: 0),
            .init(color: Color(red: 0.0, green: 0.4, blue: 0.3).opacity(0.8), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardProtection = LinearGradient( // Protection - Purple/Pink
        stops: [
            .init(color: Color(red: 0.6, green: 0.1, blue: 0.6).opacity(0.8), location: 0),
            .init(color: Color(red: 0.4, green: 0.0, blue: 0.4).opacity(0.8), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardPerformance = LinearGradient( // Performance - Orange/Red
        stops: [
            .init(color: Color(red: 0.8, green: 0.3, blue: 0.1).opacity(0.8), location: 0),
            .init(color: Color(red: 0.6, green: 0.2, blue: 0.1).opacity(0.8), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardApps = LinearGradient( // Applications - Blue
        stops: [
            .init(color: Color(red: 0.0, green: 0.3, blue: 0.7).opacity(0.8), location: 0),
            .init(color: Color(red: 0.0, green: 0.2, blue: 0.5).opacity(0.8), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardClutter = LinearGradient( // Clutter - Cyan/Blue
        stops: [
            .init(color: Color(red: 0.0, green: 0.5, blue: 0.6).opacity(0.8), location: 0),
            .init(color: Color(red: 0.0, green: 0.3, blue: 0.5).opacity(0.8), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    // 10. 碎纸机 (深蓝/紫渐变 - 匹配设计图)
    static let shredder = LinearGradient(
        stops: [
            .init(color: Color(red: 0.1, green: 0.3, blue: 0.6), location: 0.0), // 深蓝
            .init(color: Color(red: 0.2, green: 0.2, blue: 0.5), location: 1.0)  // 蓝紫
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - 模块枚举
enum AppModule: String, CaseIterable, Identifiable {
    case monitor = "控制台"
    case smartClean = "智能扫描"
    case cleaner = "系统垃圾"
    case deepClean = "深度清理"
    case maintenance = "系统维护" // Renamed from optimizer, maps to "Maintenance" UI
    case optimizer = "系统优化"   // New module for "Optimization" UI
    case shredder = "碎纸机"      // New module for "Shredder"
    case privacy = "隐私保护"
    case largeFiles = "大文件查找"
    case uninstaller = "应用卸载"
    case trash = "废纸篓"
    case fileExplorer = "文件管理"
    
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .monitor: return "chart.bar.xaxis"
        case .uninstaller: return "puzzlepiece.extension"
        case .deepClean: return "envelope"
        case .cleaner: return "globe"
        case .maintenance: return "wrench.and.screwdriver"
        case .optimizer: return "bolt.fill"
        case .shredder: return "doc.text.fill"
        case .largeFiles: return "doc"
        case .fileExplorer: return "circle.hexagongrid"
        case .trash: return "trash"
        case .privacy: return "hand.raised.fill"
        case .smartClean: return "display"
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .monitor: return GradientStyles.monitor
        case .uninstaller: return GradientStyles.uninstaller
        case .deepClean: return GradientStyles.deepClean
        case .cleaner: return GradientStyles.cleaner
        case .maintenance: return GradientStyles.optimizer // Reuse Orange for maintenance? Or use Purple?
        case .optimizer: return GradientStyles.optimizer // Use Orange for Optimization
        case .shredder: return GradientStyles.shredder // Blue for Shredder
        case .largeFiles: return GradientStyles.largeFiles
        case .fileExplorer: return GradientStyles.fileExplorer
        case .trash: return GradientStyles.trash
        case .privacy:
            return LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .smartClean: return GradientStyles.smartClean
        }
    }
    
    var backgroundGradient: LinearGradient {
        switch self {
        case .monitor: return BackgroundStyles.monitor
        case .uninstaller: return BackgroundStyles.uninstaller
        case .deepClean: return BackgroundStyles.deepClean
        case .cleaner: return BackgroundStyles.cleaner
        case .maintenance: return BackgroundStyles.privacy // Purple for Maintenance
        case .optimizer: return BackgroundStyles.privacy // Purple for Optimization (match design)
        case .shredder: return BackgroundStyles.shredder // Blue/Purple for Shredder
        case .largeFiles: return BackgroundStyles.largeFiles
        case .fileExplorer: return BackgroundStyles.fileExplorer
        case .trash: return BackgroundStyles.trash
        case .privacy: return BackgroundStyles.privacy
        case .smartClean: return BackgroundStyles.smartClean
        }
    }
    
    var description: String {
        switch self {
        case .monitor: return "CPU、内存、网络端口实时监控"
        case .uninstaller: return "完全删除应用及其残留文件"
        case .deepClean: return "扫描已卸载应用的残留文件"
        case .cleaner: return "清理缓存和系统垃圾"
        case .maintenance: return "运行系统维护脚本"
        case .optimizer: return "管理启动项，释放内存"
        case .shredder: return "安全擦除敏感文件"
        case .largeFiles: return "发现并清理占用空间的大文件"
        case .fileExplorer: return "浏览和管理磁盘文件"
        case .trash: return "查看并清空废纸篷"
        case .privacy: return "保护您的隐私数据安全"

        case .smartClean: return "一键扫描并清理系统垃圾"
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
