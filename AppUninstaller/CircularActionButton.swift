import SwiftUI

struct CircularActionButton: View {
    let title: String
    var icon: String? = nil
    var gradient: LinearGradient? = nil
    var progress: Double? = nil
    var showProgress: Bool = false
    var scanSize: String? = nil
    let action: () -> Void
    
    // Gradient definitions
    static let blueGradient = LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let greenGradient = LinearGradient(colors: [.green.opacity(0.8), .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let grayGradient = LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let stopGradient = LinearGradient(colors: [Color(red: 0.6, green: 0.5, blue: 0.7), Color(red: 0.5, green: 0.4, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing) // Muted purple for Stop

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                // Progress Ring
                if showProgress {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 4)
                        .frame(width: 90, height: 90)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(progress ?? 0))
                        .stroke(Color.cyan, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.5), value: progress)
                }
                
                // Button Background
                Button(action: action) {
                    ZStack {
                        Circle()
                            .fill(gradient ?? Self.blueGradient)
                            // Add a subtle border/glow
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        
                        Text(title)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(width: 80, height: 80)
                }
                .buttonStyle(.plain)
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            
            // Scan Size Text (only for Stop button usually)
            if let size = scanSize {
                Text(size)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}
