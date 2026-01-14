import SwiftUI

struct MemoryAlertView: View {
    @ObservedObject var systemMonitor: SystemMonitorService
    var openAppAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Pointer (Triangle)
            Triangle()
                .fill(Color(hex: "F2F2F7")) // Match background
                .frame(width: 20, height: 10)
                .padding(.bottom, -1) // Overlap slightly to hide seam
            
            VStack(alignment: .leading, spacing: 16) {
                // Header
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
                
                // App Launch Action
                Button(action: {
                    openAppAction()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14))
                        Text("启动 Mac优化大师")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(Color.black)
                }
                .buttonStyle(.plain)
                
                // Memory Visualization Card
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "FFFFFF")) // White background for the card
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    
                    HStack(spacing: 12) {
                        // Icon
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
                
                // Footer Actions
                HStack {
                    Menu {
                        Button("10 分钟后提醒") {
                            systemMonitor.ignoreCurrentHighMemoryApp() // Simplified for now
                        }
                        Button("1 小时后提醒") {
                             systemMonitor.ignoreCurrentHighMemoryApp()
                        }
                        Divider()
                        Button("从不提醒") {
                             systemMonitor.ignoreCurrentHighMemoryApp()
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
                    
                    Button(action: {
                        withAnimation {
                            systemMonitor.terminateHighMemoryApp()
                        }
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
            .background(Color(hex: "F2F2F7")) // Light gray background like standard macOS popovers/CleanMyMac
            .cornerRadius(16)
        }
        .frame(width: 320)
        .compositingGroup() // Ensure shadow applies to the unified shape
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

// Simple Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
