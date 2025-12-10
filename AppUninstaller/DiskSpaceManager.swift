import Foundation
import Combine

class DiskSpaceManager: ObservableObject {
    @Published var totalSize: Int64 = 0
    @Published var freeSize: Int64 = 0
    @Published var usedSize: Int64 = 0
    
    // Percentage 0.0 - 1.0
    @Published var usagePercentage: Double = 0.0
    
    static let shared = DiskSpaceManager()
    
    private init() {
        updateDiskSpace()
    }
    
    func updateDiskSpace() {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            
            if let total = values.volumeTotalCapacity, let free = values.volumeAvailableCapacity {
                self.totalSize = Int64(total)
                self.freeSize = Int64(free)
                self.usedSize = self.totalSize - self.freeSize
                
                if self.totalSize > 0 {
                    self.usagePercentage = Double(self.usedSize) / Double(self.totalSize)
                }
            }
        } catch {
            print("Error retrieving disk space: \(error)")
        }
    }
    
    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: freeSize, countStyle: .file)
    }
    
    var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: usedSize, countStyle: .file)
    }
}
