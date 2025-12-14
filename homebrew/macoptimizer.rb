cask "macoptimizer" do
  arch arm: "AppleSilicon", intel: "Intel"

  version "3.0.1"
  sha256 arm:   "REPLACE_WITH_ARM64_SHA256",
         intel: "REPLACE_WITH_INTEL_SHA256"

  url "https://github.com/ddlmanus/MacOptimizer/releases/download/v#{version}/MacOptimizer_v#{version}_#{arch}.dmg"
  name "MacOptimizer"
  desc "System cleaner and optimizer for macOS"
  homepage "https://github.com/ddlmanus/MacOptimizer"

  app "Mac优化大师.app", target: "MacOptimizer.app"

  zap trash: [
    "~/Library/Application Support/com.ddlmanus.macoptimizer",
    "~/Library/Caches/com.ddlmanus.macoptimizer",
    "~/Library/Preferences/com.ddlmanus.macoptimizer.plist",
    "~/Library/Saved Application State/com.ddlmanus.macoptimizer.savedState",
  ]
end
