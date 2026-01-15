import SwiftUI
import AppKit

/// 独立的内存警告浮动窗口控制器
/// 当检测到高内存使用时自动从菜单栏图标弹出
class MemoryAlertWindowController: NSObject, ObservableObject {
    private var window: NSWindow?
    private var systemMonitor: SystemMonitorService
    private var statusBarButton: NSStatusBarButton?
    
    init(systemMonitor: SystemMonitorService, statusBarButton: NSStatusBarButton?) {
        self.systemMonitor = systemMonitor
        self.statusBarButton = statusBarButton
        super.init()
        setupObserver()
    }
    
    private func setupObserver() {
        // 监听内存警告状态变化
        systemMonitor.$showHighMemoryAlert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shouldShow in
                if shouldShow {
                    self?.showAlert()
                } else {
                    self?.hideAlert()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    /// 显示内存警告窗口
    private func showAlert() {
        // 如果窗口已存在，直接显示
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // 创建警告视图
        let alertView = MemoryAlertFloatingView(
            systemMonitor: systemMonitor,
            onClose: { [weak self] in
                self?.hideAlert()
            },
            onOpenApp: { [weak self] in
                self?.hideAlert()
                MenuBarManager.shared.openMainApp()
            }
        )
        
        let hostingController = NSHostingController(rootView: alertView)
        
        // 创建浮动窗口（调整尺寸更紧凑）
        let alertWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 280),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        alertWindow.contentViewController = hostingController
        alertWindow.backgroundColor = .clear
        alertWindow.isOpaque = false
        alertWindow.hasShadow = true
        alertWindow.level = .floating  // 保持在其他窗口之上
        alertWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
        alertWindow.isMovableByWindowBackground = false
        
        // 定位在菜单栏图标下方
        positionWindow(alertWindow)
        
        // 动画显示
        alertWindow.alphaValue = 0
        alertWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            alertWindow.animator().alphaValue = 1
        }
        
        self.window = alertWindow
    }
    
    /// 隐藏警告窗口
    private func hideAlert() {
        guard let window = window else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            self?.window = nil
        })
    }
    
    /// 计算窗口位置（菜单栏图标正下方）
    private func positionWindow(_ window: NSWindow) {
        guard let button = statusBarButton ?? MenuBarManager.shared.statusItem?.button,
              let buttonWindow = button.window,
              let screen = NSScreen.main else {
            // 默认位置：右上角
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let windowSize = window.frame.size
                let xPos = screenFrame.maxX - windowSize.width - 20
                let yPos = screenFrame.maxY - windowSize.height - 10
                window.setFrameOrigin(NSPoint(x: xPos, y: yPos))
            }
            return
        }
        
        // 获取菜单栏按钮的屏幕坐标
        let buttonFrame = buttonWindow.convertToScreen(button.frame)
        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size
        
        // 计算窗口位置：在按钮正下方居中
        // buttonFrame.minY 是按钮的底部（屏幕坐标系）
        let xPos = buttonFrame.midX - (windowSize.width / 2)
        let yPos = buttonFrame.minY - windowSize.height - 8  // 8px 间距
        
        // 确保不超出屏幕边界
        let finalX = max(screenFrame.minX + 10, min(xPos, screenFrame.maxX - windowSize.width - 10))
        let finalY = max(screenFrame.minY + 10, yPos)
        
        window.setFrameOrigin(NSPoint(x: finalX, y: finalY))
    }
}

// MARK: - 浮动警告视图（参考 CleanMyMac 设计）
struct MemoryAlertFloatingView: View {
    @ObservedObject var systemMonitor: SystemMonitorService
    let onClose: () -> Void
    let onOpenApp: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 指示三角形（指向菜单栏图标）
            Triangle()
                .fill(Color(hex: "F2F2F7"))
                .frame(width: 20, height: 10)
                .padding(.bottom, -1)
            
            // 主内容区域
            VStack(alignment: .leading, spacing: 16) {
                // 标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("内存占用过高")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.black.opacity(0.85))
                    
                    Text("Mac优化大师 发现您 Mac 的物理内存和虚拟内存占用率过高。让我们为您修复此问题！")
                        .font(.system(size: 13))
                        .foregroundColor(Color.black.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                
                // 启动应用按钮
                Button(action: onOpenApp) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14))
                        Text("启动 Mac优化大师")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(Color.black)
                }
                .buttonStyle(.plain)
                
                // 内存可视化卡片
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "FFFFFF"))
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    
                    HStack(spacing: 12) {
                        // RAM 图标
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "00C7BE"))
                                .frame(width: 40, height: 40)
                            
                            Text("RAM")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .offset(y: -5)
                            
                            // Mock "pins" or chip look
                            VStack(spacing: 2) {
                                Spacer()
                                HStack(spacing: 2) {
                                    ForEach(0..<5) { _ in
                                        Rectangle()
                                            .fill(Color.white.opacity(0.5))
                                            .frame(width: 2, height: 6)
                                    }
                                }
                                .padding(.bottom, 4)
                            }
                            .frame(width: 40, height: 40)
                        }
                        
                        // Progress
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("RAM + Swap")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.black.opacity(0.85))
                                Spacer()
                                Text(systemMonitor.memoryUsage > 0.9 ? "快满了" : "正常")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "FF6B6B"))
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(height: 8)
                                    
                                    Capsule()
                                        .fill(LinearGradient(gradient: Gradient(colors: [Color(hex: "FF9F6B"), Color(hex: "FF6B6B")]), startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geometry.size.width * CGFloat(systemMonitor.memoryUsage), height: 8)
                                        .animation(.easeInOut, value: systemMonitor.memoryUsage)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                    .padding(12)
                }
                .frame(height: 72)
                .background(Color(hex: "F2F2F7"))
                
                Divider()
                    .background(Color.gray.opacity(0.2))
                
                // 底部操作按钮
                HStack {
                    // 忽略菜单
                    Menu {
                        Button("10 分钟后提醒") {
                            systemMonitor.snoozeAlert(minutes: 10)
                            onClose()
                        }
                        Button("1 小时后提醒") {
                            systemMonitor.snoozeAlert(minutes: 60)
                            onClose()
                        }
                        Divider()
                        Button("从不提醒") {
                            systemMonitor.ignoreAppPermanently()
                            onClose()
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Text("忽略")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    Spacer()
                    
                    // 释放按钮
                    Button(action: {
                        systemMonitor.terminateHighMemoryApp()
                        onClose()
                    }) {
                        Text("释放")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.black.opacity(0.8))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(Color(hex: "F2F2F7"))
            .cornerRadius(16)
        }
        .frame(width: 320)
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

import Combine
