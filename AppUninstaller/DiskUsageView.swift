import SwiftUI

struct DiskUsageView: View {
    @StateObject private var diskManager = DiskSpaceManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Macintosh HD") // Could be dynamic if needed
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(diskManager.formattedFree) 可用 / 共 \(diskManager.formattedTotal)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    // Fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(geometry.size.width * CGFloat(diskManager.usagePercentage), geometry.size.width)), height: 8)
                        .animation(.easeOut(duration: 0.5), value: diskManager.usagePercentage)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .onAppear {
            diskManager.updateDiskSpace()
        }
    }
}
