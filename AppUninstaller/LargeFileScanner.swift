import Foundation
import SwiftUI

struct FileItem: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let type: String
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

class LargeFileScanner: ObservableObject {
    @Published var foundFiles: [FileItem] = []
    @Published var isScanning = false
    @Published var scannedCount = 0
    @Published var totalSize: Int64 = 0
    
    private let minimumSize: Int64 = 50 * 1024 * 1024 // 50MB
    
    func scan() async {
        await MainActor.run {
            self.isScanning = true
            self.foundFiles = []
            self.scannedCount = 0
            self.totalSize = 0
        }
        
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        var files: [FileItem] = []
        var total: Int64 = 0
        
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        
        // Scan Home Directory directly
        if let enumerator = fileManager.enumerator(at: home, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: options) {
            
            while let fileURL = enumerator.nextObject() as? URL {
                // Check cancellation (omitted for brevity)
                
                // Exclude specific system-like folders in Home to avoid permission spam or system clutter
                let relativePath = String(fileURL.path.dropFirst(home.path.count + 1))
                if relativePath == "Library" || relativePath == "Applications" || relativePath == "Public" {
                    enumerator.skipDescendants()
                    continue
                }
                
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                    
                    if let isDirectory = resourceValues.isDirectory, isDirectory {
                        continue
                    }
                    
                    if let fileSize = resourceValues.fileSize, Int64(fileSize) > minimumSize {
                        let item = FileItem(
                            url: fileURL,
                            name: fileURL.lastPathComponent,
                            size: Int64(fileSize),
                            type: fileURL.pathExtension.isEmpty ? "File" : fileURL.pathExtension.uppercased()
                        )
                        files.append(item)
                        total += Int64(fileSize)
                        
                        if files.count % 10 == 0 {
                            let interimFiles = files
                            let interimTotal = total
                            await MainActor.run {
                                self.foundFiles = interimFiles.sorted(by: { $0.size > $1.size })
                                self.totalSize = interimTotal
                            }
                        }
                    }
                    
                    await MainActor.run {
                        self.scannedCount += 1
                    }
                    
                } catch {
                    // print("Error reading file attributes: \(error)") // Silent fail for permission errors
                }
            }
        }
        
        let finalFiles = files.sorted(by: { $0.size > $1.size })
        let finalTotal = total
        
        await MainActor.run {
            self.foundFiles = finalFiles
            self.totalSize = finalTotal
            self.isScanning = false
        }
    }
    
    // Helper to get relative path
    // Need to add this extension if not exists, or just check simple string containment

    
    func deleteItems(_ items: Set<UUID>) async {
         var successCount = 0
         var recoveredSize: Int64 = 0
         
         for file in foundFiles where items.contains(file.id) {
             do {
                 try FileManager.default.removeItem(at: file.url)
                 successCount += 1
                 recoveredSize += file.size
             } catch {
                 print("Failed to delete \(file.url.path): \(error)")
             }
         }
         
         // Re-scan or just remove directly from array
         let remainingFiles = foundFiles.filter { !items.contains($0.id) }
         let newTotal = remainingFiles.reduce(0) { $0 + $1.size }
         
         await MainActor.run {
             self.foundFiles = remainingFiles
             self.totalSize = newTotal
         }
    }
}
