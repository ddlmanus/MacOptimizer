import Foundation

/// Handles disk persistence for cache data
class CachePersistence {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let lock = NSLock()
    
    /// Initialize cache persistence
    /// - Throws: If cache directory cannot be created
    init() throws {
        // Use Application Support directory for cache
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        self.cacheDirectory = appSupportURL.appendingPathComponent("AppUninstaller/Cache", isDirectory: true)
        
        // Create cache directory if it doesn't exist
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// Save cache data to disk
    /// - Parameters:
    ///   - data: The data to save
    ///   - key: Unique identifier for the cache file
    /// - Throws: If save operation fails
    func save<T: Codable>(_ data: T, forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        
        let fileURL = cacheDirectory.appendingPathComponent(sanitizeKey(key))
        let encoded = try JSONEncoder().encode(data)
        try encoded.write(to: fileURL, options: .atomic)
    }
    
    /// Load cache data from disk
    /// - Parameter key: Unique identifier for the cache file
    /// - Returns: The decoded data, or nil if file doesn't exist
    /// - Throws: If load operation fails
    func load<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        let fileURL = cacheDirectory.appendingPathComponent(sanitizeKey(key))
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    /// Delete cache file from disk
    /// - Parameter key: Unique identifier for the cache file
    /// - Throws: If delete operation fails
    func delete(forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        
        let fileURL = cacheDirectory.appendingPathComponent(sanitizeKey(key))
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    /// Clear all cache files from disk
    /// - Throws: If clear operation fails
    func clearAll() throws {
        lock.lock()
        defer { lock.unlock() }
        
        if fileManager.fileExists(atPath: cacheDirectory.path) {
            try fileManager.removeItem(at: cacheDirectory)
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// Get total size of cache on disk
    /// - Returns: Size in bytes
    /// - Throws: If size calculation fails
    func totalSize() throws -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        
        guard fileManager.fileExists(atPath: cacheDirectory.path) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        if let enumerator = fileManager.enumerator(atPath: cacheDirectory.path) {
            for case let file as String in enumerator {
                let filePath = cacheDirectory.appendingPathComponent(file).path
                if let attributes = try? fileManager.attributesOfItem(atPath: filePath),
                   let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            }
        }
        
        return totalSize
    }
    
    // MARK: - Private Helpers
    
    private func sanitizeKey(_ key: String) -> String {
        // Create a safe filename from the key
        let data = key.data(using: .utf8) ?? Data()
        let hash = data.withUnsafeBytes { buffer in
            var hasher = Hasher()
            hasher.combine(bytes: buffer)
            return abs(hasher.finalize())
        }
        return "cache_\(hash).json"
    }
}

/// Extension to CacheManager for disk persistence
extension CacheManager {
    /// Save cache to disk
    /// - Parameter persistence: CachePersistence instance
    /// - Throws: If save operation fails
    func saveToDisk(_ persistence: CachePersistence) throws {
        let cacheData = getSerializableData()
        try persistence.save(cacheData, forKey: "cache_data")
    }
    
    /// Load cache from disk
    /// - Parameter persistence: CachePersistence instance
    /// - Throws: If load operation fails
    func loadFromDisk(_ persistence: CachePersistence) throws {
        guard let cacheData = try persistence.load([String: CacheEntry<Value>].self, forKey: "cache_data") else {
            return
        }
        
        loadSerializableData(cacheData)
    }
}
