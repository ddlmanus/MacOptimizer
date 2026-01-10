import Foundation
import SwiftUI
import Network

// MARK: - Update Checker Service
class UpdateCheckerService: ObservableObject {
    static let shared = UpdateCheckerService()
    
    @Published var hasUpdate = false
    @Published var latestVersion = ""
    @Published var releaseNotes = ""
    @Published var downloadURL: URL?
    @Published var isChecking = false
    @Published var errorMessage: String?
    
    // GitHub Repo Info
    private let repoOwner = "ddlmanus"
    private let repoName = "MacOptimizer"
    
    // 网络状态监控
    private var networkMonitor: NWPathMonitor?
    private var isNetworkAvailable: Bool = true
    
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.4"
    }
    
    private init() {
        setupNetworkMonitor()
    }
    
    deinit {
        networkMonitor?.cancel()
    }
    
    /// 设置网络状态监控
    private func setupNetworkMonitor() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isNetworkAvailable = (path.status == .satisfied)
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor?.start(queue: queue)
    }
    
    func checkForUpdates() async {
        // 延迟检查，确保网络监控器已初始化
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        // 检查网络是否可用
        guard isNetworkAvailable else {
            print("[UpdateChecker] ⚠️ Network not available, skipping update check")
            await MainActor.run {
                self.errorMessage = "无网络连接"
            }
            return
        }
        
        await MainActor.run {
            self.isChecking = true
            self.errorMessage = nil
        }
        
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                self.isChecking = false
                self.errorMessage = "Invalid URL"
            }
            return
        }
        
        do {
            var request = URLRequest(url: url)
            // 使用更短的超时时间，避免在代理/网络问题时长时间挂起
            request.timeoutInterval = 5
            
            // 使用不走代理的配置（可选，如果代理有问题）
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5
            config.timeoutIntervalForResource = 10
            config.waitsForConnectivity = false // 不等待网络恢复
            
            let session = URLSession(configuration: config)
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            
            await MainActor.run {
                self.isChecking = false
                // Remove 'v' prefix if present for comparison
                let serverVer = release.tag_name.replacingOccurrences(of: "v", with: "")
                let localVer = self.currentVersion.replacingOccurrences(of: "v", with: "")
                
                if serverVer.compare(localVer, options: .numeric) == .orderedDescending {
                    self.hasUpdate = true
                    self.latestVersion = release.tag_name
                    self.releaseNotes = release.body
                    self.downloadURL = URL(string: release.html_url)
                } else {
                    self.hasUpdate = false
                    self.latestVersion = release.tag_name
                }
            }
        } catch {
            await MainActor.run {
                self.isChecking = false
                // 在网络错误时静默处理，不影响应用启动
                self.errorMessage = error.localizedDescription
                print("[UpdateChecker] ⚠️ Update check failed (possibly no network): \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - GitHub Release Model
struct GitHubRelease: Codable {
    let tag_name: String
    let html_url: String
    let body: String
}

