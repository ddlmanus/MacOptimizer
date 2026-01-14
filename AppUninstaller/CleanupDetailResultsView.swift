import SwiftUI

struct CleanupDetailResultsView: View {
    let cleanedSize: Int64
    let cleanedCount: Int
    let failedFiles: [FailedFileInfo]
    let failedCount: Int
    let totalAttempted: Int
    let onDismiss: () -> Void
    @State private var expandedFailedFile: UUID?
    @State private var showFailedFilesOnly = false
    
    var formattedCleanedSize: String {
        ByteCountFormatter.string(fromByteCount: cleanedSize, countStyle: .file)
    }
    
    var successRate: Double {
        totalAttempted > 0 ? Double(cleanedCount) / Double(totalAttempted) * 100 : 0
    }
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.6, green: 0.4, blue: 0.8),
                    Color(red: 0.4, green: 0.3, blue: 0.7)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onDismiss) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("返回")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                    }
                    Spacer()
                    Text("清理结果")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Summary Section
                        VStack(spacing: 16) {
                            // Title
                            VStack(spacing: 8) {
                                Text("清理完成")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("已清理 \(cleanedCount) 个文件")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            // Stats Cards
                            VStack(spacing: 12) {
                                // Cleaned Size Card
                                CleanupStatCard(
                                    icon: "checkmark.circle.fill",
                                    title: formattedCleanedSize,
                                    subtitle: "已成功清理",
                                    color: Color(red: 0.4, green: 0.9, blue: 0.6),
                                    progress: successRate
                                )
                                
                                // Success Rate Card
                                CleanupStatCard(
                                    icon: "percent",
                                    title: String(format: "%.0f%%", successRate),
                                    subtitle: "成功率",
                                    color: Color(red: 0.4, green: 0.8, blue: 1.0),
                                    progress: successRate
                                )
                                
                                // Failed Count Card
                                if failedCount > 0 {
                                    CleanupStatCard(
                                        icon: "exclamationmark.circle.fill",
                                        title: "\(failedCount) 个",
                                        subtitle: "未能清理",
                                        color: Color(red: 1.0, green: 0.5, blue: 0.6),
                                        progress: Double(failedCount) / Double(totalAttempted) * 100
                                    )
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        
                        // Failed Files Section
                        if failedCount > 0 {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("未能清理的文件")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text("\(failedCount) 个")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                VStack(spacing: 8) {
                                    ForEach(failedFiles) { file in
                                        FailedFileRow(
                                            file: file,
                                            isExpanded: expandedFailedFile == file.id,
                                            onTap: {
                                                withAnimation {
                                                    expandedFailedFile = expandedFailedFile == file.id ? nil : file.id
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(20)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        // Recommendations
                        VStack(alignment: .leading, spacing: 12) {
                            Text("建议")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            VStack(spacing: 8) {
                                RecommendationItem(
                                    icon: "checkmark.circle",
                                    title: "定期清理",
                                    description: "建议每周运行一次清理，保持系统最佳性能",
                                    color: Color(red: 0.4, green: 0.9, blue: 0.6)
                                )
                                
                                if failedCount > 0 {
                                    RecommendationItem(
                                        icon: "exclamationmark.circle",
                                        title: "检查失败文件",
                                        description: "某些文件可能被应用占用或权限不足，请稍后重试",
                                        color: Color(red: 1.0, green: 0.5, blue: 0.6)
                                    )
                                }
                                
                                RecommendationItem(
                                    icon: "arrow.clockwise.circle",
                                    title: "运行深度扫描",
                                    description: "深度扫描可以发现更多隐藏的垃圾文件",
                                    color: Color(red: 0.4, green: 0.8, blue: 1.0)
                                )
                            }
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.vertical, 20)
                }
                
                // Bottom Actions
                VStack(spacing: 12) {
                    Button(action: onDismiss) {
                        Text("返回首页")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {}) {
                        Text("导出清理报告")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
}

struct CleanupStatCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * (progress / 100))
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct FailedFileRow: View {
    let file: FailedFileInfo
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.5, blue: 0.6).opacity(0.2))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.6))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.fileName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(file.filePath)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        DetailRow(label: "文件大小", value: file.formattedSize)
                        DetailRow(label: "错误原因", value: file.errorReason)
                        DetailRow(label: "文件路径", value: file.filePath)
                    }
                    .padding(.top, 8)
                }
                .padding(12)
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
            }
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            Text(value)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
        }
    }
}

struct RecommendationItem: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct FailedFileInfo: Identifiable {
    let id = UUID()
    let fileName: String
    let filePath: String
    let fileSize: Int64
    let errorReason: String
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

#Preview {
    CleanupDetailResultsView(
        cleanedSize: 2_645_000_000,
        cleanedCount: 45,
        failedFiles: [
            FailedFileInfo(
                fileName: "Google Chrome",
                filePath: "/Users/dudianlong/Library/Application Support/Google/Chrome",
                fileSize: 500_000_000,
                errorReason: "应用正在运行，无法删除"
            ),
            FailedFileInfo(
                fileName: "Kuro Cache",
                filePath: "/Users/dudianlong/Library/Caches/Kuro",
                fileSize: 300_000_000,
                errorReason: "权限不足"
            ),
            FailedFileInfo(
                fileName: "com.google.Chrome",
                filePath: "/Users/dudianlong/Library/Application Support/com.google.Chrome",
                fileSize: 200_000_000,
                errorReason: "文件被占用"
            )
        ],
        failedCount: 3,
        totalAttempted: 48,
        onDismiss: {}
    )
}
