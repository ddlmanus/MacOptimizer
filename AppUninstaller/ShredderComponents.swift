import SwiftUI
import AppKit

// MARK: - 1. Landing View
struct ShredderLandingView: View {
    @Binding var showFileImporter: Bool // Kept for signature compatibility if needed, but unused for logic now
    @Environment(\.localization) var loc
    var selectFiles: () -> Void
    
    var body: some View {
        HStack(spacing: 60) {
            // Left Content
            VStack(alignment: .leading, spacing: 30) {
                // Branding Header (统一风格)
                HStack(spacing: 8) {
                    Text(loc.L("shredder_title"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    // Shredder Icon
                    HStack(spacing: 4) {
                        Image(systemName: "doc.badge.gearshape")
                        Text(loc.currentLanguage == .chinese ? "安全擦除" : "Secure Erase")
                            .font(.system(size: 20, weight: .heavy))
                    }
                    .foregroundColor(.white)
                }
                
                Text(loc.L("shredder_subtitle"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Feature Rows (统一样式)
                VStack(alignment: .leading, spacing: 24) {
                    featureRow(
                        icon: "lock.shield",
                        title: loc.L("secure_erase"),
                        subtitle: loc.L("secure_erase_desc")
                    )
                    
                    featureRow(
                        icon: "exclamationmark.triangle",
                        title: loc.L("resolve_finder_errors"),
                        subtitle: loc.L("resolve_finder_errors_desc")
                    )
                }
                
                // Action Button (统一颜色)
                Button(action: { selectFiles() }) {
                    Text(loc.L("select_files"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "4DDEE8")) // Teal - 与废纸篓统一
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
            .frame(maxWidth: 400)
            
            // Right Icon (统一大小和阴影)
            ZStack {
                ShredderIconView(isAnimating: false)
                    .frame(width: 320, height: 320)
                    .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
            }
        }
        .padding(48)
    }
    
    // 统一的 Feature Row 样式
    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "4DDEE8"))
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 2. Selection View
struct ShredderSelectionView: View {
    @ObservedObject var service: ShredderService
    @Binding var showFileImporter: Bool
    @Environment(\.localization) var loc
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { service.reset() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(loc.L("restart"))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(loc.L("shredder_title"))
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 13))
                
                Spacer()
                
                // 移除助手按钮（与智能扫描统一）
                Color.clear.frame(width: 80)
            }
            .padding(16)
            
            HStack(spacing: 0) {
                // List
                List {
                    ForEach(service.items) { item in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: "4DDEE8")) // 统一颜色
                            
                            Image(nsImage: item.icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                            
                            Text(item.name)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text(item.formattedSize)
                                .foregroundColor(.white.opacity(0.6))
                                .font(.system(size: 12))
                        }
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { indexSet in
                        // service.items.remove(atOffsets: indexSet) // Need to implement delete in service
                    }
                }
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity)
                
                Spacer()
            }
            
            // Bottom Action Bar
            HStack {
                Menu {
                    Button(loc.L("remove_now")) {
                        Task { await service.startShredding() }
                    }
                } label: {
                    Text(loc.L("remove_now"))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
                Spacer()
                
                // Start Button
                Button(action: {
                    Task { await service.startShredding() }
                }) {
                    ZStack {
                        Circle()
                        .fill(LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text(loc.L("shred"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(ByteCountFormatter.string(fromByteCount: service.items.reduce(0) { $0 + $1.size }, countStyle: .file))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(24)
        }
    }
}

// MARK: - 3. Progress View
struct ShreddingProgressView: View {
    @ObservedObject var service: ShredderService
    @Environment(\.localization) var loc
    
    var body: some View {
        VStack {
            Spacer()
            
            ShredderIconView(isAnimating: true)
                .frame(width: 200, height: 200)
            
            Spacer()
            
            Text(loc.L("cleaning_system"))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.bottom, 16)
            
            // Current Item
            if !service.currentItemName.isEmpty {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.white)
                    Text(service.currentItemName)
                        .foregroundColor(.white)
                    Spacer()
                }
                .frame(maxWidth: 400)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Stop button
            Button(action: { /* Stop logic? */ }) {
                ZStack {
                    Circle()
                        .stroke(Color.green, lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Text(loc.L("stop"))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - 4. Result View
struct ShredderResultView: View {
    @ObservedObject var service: ShredderService
    @Environment(\.localization) var loc
    
    var body: some View {
        HStack {
            ShredderIconView(isAnimating: false)
                .frame(width: 300, height: 300)
                .padding(.leading, 40)
            
            VStack(alignment: .leading, spacing: 16) {
                Text(loc.L("cleaning_complete"))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 24))
                    
                    Text(ByteCountFormatter.string(fromByteCount: service.totalSizeCleared, countStyle: .file))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(loc.L("cleaned"))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Text(String(format: loc.L("free_space_available"), Double(Helpers.getFreeDiskSpace()) / 1_000_000_000))
                    .foregroundColor(.white.opacity(0.7))
                
                Button(action: { /* Share? */ }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text(loc.L("share_results"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
            .padding(.leading, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomLeading) {
            Button(loc.L("view_log")) {
                // View log
            }
            .foregroundColor(.white.opacity(0.7))
            .buttonStyle(.plain)
            .padding(24)
        }
        .overlay(alignment: .topLeading) {
             Button(action: { service.reset() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text(loc.L("restart"))
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }
}

// MARK: - Components

struct ShredderIconView: View {
    let isAnimating: Bool
    
    @State private var dripOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.6, blue: 1.0), Color(red: 0.1, green: 0.4, blue: 0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(radius: 10)
            
            // Paper
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                
                ZStack {
                    // Main Paper Body
                    Path { path in
                        let paperW = w * 0.5
                        let paperH = h * 0.6
                        let x = w * 0.25
                        let y = h * 0.2
                        
                        // Main Rect
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + paperW - 40, y: y)) // Top edge minus fold
                        path.addLine(to: CGPoint(x: x + paperW, y: y + 40)) // Fold diagonal end
                        path.addLine(to: CGPoint(x: x + paperW, y: y + paperH)) // Right edge
                        path.addLine(to: CGPoint(x: x, y: y + paperH)) // Bottom edge
                        path.closeSubpath()
                    }
                    .fill(Color.white)
                    
                    // Folded Corner
                    Path { path in
                        let paperW = w * 0.5
                        let x = w * 0.25
                        let y = h * 0.2
                        
                        path.move(to: CGPoint(x: x + paperW - 40, y: y))
                        path.addLine(to: CGPoint(x: x + paperW - 40, y: y + 40))
                        path.addLine(to: CGPoint(x: x + paperW, y: y + 40))
                        path.closeSubpath()
                    }
                    .fill(Color.white.opacity(0.8))
                    .shadow(radius: 2)
                    
                    // Shredding/Melting Effect at Bottom
                    // We mask the bottom of the paper with "drips"
                    if isAnimating {
                        ForEach(0..<6) { i in
                             RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(width: (w * 0.5) / 9, height: 40)
                                .offset(x: (CGFloat(i) - 2.5) * ((w * 0.5) / 7), y: (h * 0.4) + (isAnimating ? 20 : 0))
                                .animation(Animation.linear(duration: 0.8).repeatForever(autoreverses: true).delay(Double(i) * 0.1), value: isAnimating)
                        }
                    } else {
                         // Static drips for design match
                         HStack(alignment: .top, spacing: 8) {
                             ForEach(0..<5) { i in
                                 RoundedRectangle(cornerRadius: 3)
                                     .fill(Color.white)
                                     .frame(width: 15, height: [30.0, 50.0, 20.0, 60.0, 40.0][i])
                             }
                         }
                         .offset(y: h * 0.3)
                    }
                }
            }
        }
    }
}

struct Helpers {
    static func getFreeDiskSpace() -> Int64 {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) {
             return attrs[.systemFreeSize] as? Int64 ?? 0
        }
        return 0
    }
}
