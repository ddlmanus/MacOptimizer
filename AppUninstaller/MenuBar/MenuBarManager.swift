import SwiftUI
import AppKit

public enum MenuBarRoute {
    case overview
    case storage
    case memory
    case battery
    case cpu
    case network
}

class MenuBarManager: NSObject, ObservableObject {
    static let shared = MenuBarManager()
    
    var statusItem: NSStatusItem?
    var popoverWindow: MenuBarWindow?
    var detailWindow: MenuBarWindow?
    var memoryAlertController: MemoryAlertWindowController?
    
    // Shared Source of Truth
    var systemMonitor = SystemMonitorService()
    
    @Published var isOpen: Bool = false
    @Published var currentDetailRoute: MenuBarRoute? = nil
    
    // 标记是否已完成初始化
    private var isSetupComplete = false
    
    override init() {
        super.init()
        // 延迟初始化，确保应用程序完全启动后再创建 status item
        // 这可以防止在 app 启动时访问 NSStatusBar 导致的崩溃
        DispatchQueue.main.async { [weak self] in
            self?.performDelayedSetup()
        }
    }
    
    /// 延迟执行的设置，确保 NSApp 已完全初始化
    private func performDelayedSetup() {
        guard !isSetupComplete else { return }
        isSetupComplete = true
        
        setupStatusItem()
        setupWindow()
        setupAutoClose()
    }
    
    /// 公共方法：确保设置完成（用于需要立即使用的场景）
    func ensureSetup() {
        if !isSetupComplete {
            performDelayedSetup()
        }
    }
    
    private func setupStatusItem() {
        // 确保在主线程且 NSApp 已准备好
        guard Thread.isMainThread, NSApp != nil else {
            print("[MenuBarManager] ⚠️ NSApp not ready, deferring status item setup")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.setupStatusItem()
            }
            return
        }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            // Try to load AppIcon.icns for menu bar
            if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
               let customIcon = NSImage(contentsOfFile: iconPath) {
                customIcon.size = NSSize(width: 18, height: 18)
                // Use template rendering for proper menu bar appearance
                customIcon.isTemplate = true
                button.image = customIcon
            } else {
                // Fallback to SF Symbol
                let fallbackIcon = NSImage(systemSymbolName: "macpro.gen3", accessibilityDescription: "Mac优化大师")
                fallbackIcon?.isTemplate = true
                button.image = fallbackIcon
            }
            
            button.action = #selector(toggleWindow)
            button.target = self
        }
    }
    
    private func setupWindow() {
        // Main Overview Window
        // Pass self as EnvironmentObject so Views can call showDetail/closeWindow
        let contentView = MenuBarView()
            .environmentObject(self)
            .environmentObject(systemMonitor)
            .edgesIgnoringSafeArea(.all)
        
        let hostingController = NSHostingController(rootView: contentView)
        let window = MenuBarWindow(contentViewController: hostingController)
        self.popoverWindow = window
        window.level = .floating
        
        // 初始化内存警告控制器
        memoryAlertController = MemoryAlertWindowController(
            systemMonitor: systemMonitor,
            statusBarButton: statusItem?.button
        )
    }
    
    @objc func toggleWindow() {
        guard let _ = popoverWindow, let button = statusItem?.button else { return }
        
        if isOpen {
            closeWindow()
        } else {
            showWindow(relativeTo: button)
        }
    }
    
    private func showWindow(relativeTo button: NSStatusBarButton) {
        guard let window = popoverWindow else { return }
        
        // Position Logic
        let padding: CGFloat = 12
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowSize = window.frame.size
            
            let xPos = screenFrame.maxX - windowSize.width - padding
            let yPos = screenFrame.maxY - windowSize.height - 5
            
            window.setFrameOrigin(NSPoint(x: xPos, y: yPos))
        }
        
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        isOpen = true
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }
    
    func closeWindow() {
        // Close Detail First
        closeDetail()
        
        guard let window = popoverWindow else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            self.isOpen = false
        })
    }
    
    // MARK: - Detail Window Logic
    
    func showDetail(route: MenuBarRoute) {
        // If already open with same route, do nothing or maybe just bring to front
        if currentDetailRoute == route && detailWindow != nil { return }
        
        // Close existing detail if different
        if detailWindow != nil {
             // For smooth transition, maybe just update content?
             // But for now, let's close and reopen or just swap root view if possible.
             // Swapping controller is easier.
             updateDetailWindow(route: route)
             return
        }
        
        createAndShowDetailWindow(route: route)
    }
    
    func closeDetail() {
        guard let window = detailWindow else { return }
        currentDetailRoute = nil
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            self.detailWindow = nil
        })
    }
    
    private func createAndShowDetailWindow(route: MenuBarRoute) {
        let detailView = MenuBarDetailContainer(manager: self, systemMonitor: systemMonitor, route: route)
            .edgesIgnoringSafeArea(.all)
        
        let controller = NSHostingController(rootView: detailView)
        let window = MenuBarWindow(contentViewController: controller)
        self.detailWindow = window
        self.currentDetailRoute = route
        window.level = .floating
        
        // Position: Left of Main Window
        if let mainWindow = popoverWindow {
            let mainFrame = mainWindow.frame
            let gap: CGFloat = 10
            // We need to fetch size from content or set fixed size. 
            // MenuBarDetailContainer has .frame(width: 320, height: 500)
            let detailWidth: CGFloat = 360 
            let detailHeight: CGFloat = 620
            
            // Should align tops? usually.
            // Or center vertically relative to main window?
            // Modern macOS apps usually align top or keep them side-by-side cleanly.
            // Let's align Tops for better visual consistency.
            // Main window height is usually dynamic or ~600.
            
            let xPos = mainFrame.minX - detailWidth - gap
            // Align Tops
            let yPos = mainFrame.maxY - detailHeight
            
            window.setFrame(NSRect(x: xPos, y: yPos, width: detailWidth, height: detailHeight), display: true)
        }
        
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }
    
    private func updateDetailWindow(route: MenuBarRoute) {
        // Just replace the rootViewController
        guard let window = detailWindow else { return }
        
        let detailView = MenuBarDetailContainer(manager: self, systemMonitor: systemMonitor, route: route)
             .edgesIgnoringSafeArea(.all)
        let newController = NSHostingController(rootView: detailView)
        
        window.contentViewController = newController
        currentDetailRoute = route
    }
    
    // MARK: - Open Main App
    
    func openMainApp() {
        // Close menu bar windows
        closeWindow()
        
        // Find and show the main window
        // The main app window usually exists if app is running.
        // We need to bring it to front or open it.
        
        // Option 1: Find existing window by looking for ContentView or similar
        for window in NSApp.windows {
            // Skip our own menu bar windows
            if window == popoverWindow || window == detailWindow {
                continue
            }
            
            // Look for the main app window (usually the one with title or specific content)
            if window.contentViewController != nil && window.isVisible == false {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            
            if window.contentViewController != nil {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
        
        // If no window found, just activate the app (it should open main window automatically)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// Custom NSWindow with auto-close logic
class MenuBarWindow: NSWindow {
    init(contentViewController: NSViewController) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView], 
            backing: .buffered,
            defer: false
        )
        
        self.contentViewController = contentViewController
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .transient]
    }
    
    override var canBecomeKey: Bool { return true }
    
    // Auto-close handler needs to be managed by Manager via delegate or notification
    // But let's keep it simple: MenuBarManager will subscribe to interruptions.
}

extension MenuBarManager {
    func setupAutoClose() {
        // Monitor global clicks to close if clicked outside
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isOpen else { return event }
            
            if let window = event.window, (window == self.popoverWindow || window == self.detailWindow) {
                // Clicked inside one of our windows, do nothing
                return event
            }
            
            // Clicked outside?
            // "transient" collectionBehavior handles some of this, but not perfectly for custom windows.
            // Actually, the main issue usually is focus.
            
            // Let's rely on standard popup behavior: if user clicks elsewhere, we close.
            // But we have TWO windows.
            
            self.closeWindow()
            return event
        }
        
        // Also listen for ResignKey
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self, self.isOpen else { return }
            guard let resignedWindow = notification.object as? NSWindow else { return }
            
            // Only care if one of OUR windows resigned key
            if resignedWindow == self.popoverWindow || resignedWindow == self.detailWindow {
                // Check what the NEW key window is.
                // It might need a slight delay to be set?
                DispatchQueue.main.async {
                    let newKeyWindow = NSApp.keyWindow
                    
                    // If the new key window is one of ours, don't close.
                    if newKeyWindow == self.popoverWindow || newKeyWindow == self.detailWindow {
                        return
                    }
                    
                    // If we are still "active" app but focus shifted to maybe a dialog? 
                    // Or if user clicked desktop (newKeyWindow might be nil or Finder).
                    
                    // Simple rule: If neither of our windows is key, close.
                    self.closeWindow()
                }
            }
        }
        
        // Listen for App Deactivation (switching to another app)
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.closeWindow()
        }
    }
}