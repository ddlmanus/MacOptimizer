cask "macoptimizer" do
  arch arm: "AppleSilicon", intel: "Intel"

  version "3.0.1"
  sha256 arm:   "c8ed6b72c0b01066fedabad8d74f08b8bd66d554d93bdbf0602d8059da0471cc",
         intel: "4c209f8c434108d2abeb18a824c6283b905bff3599a22fc420b77ffdaee480c0"

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
