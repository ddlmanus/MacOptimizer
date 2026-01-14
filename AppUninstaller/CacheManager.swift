import Foundation

/// Represents a cached value with metadata
/// 
/// Each cache entry stores the actual value along with metadata needed for
/// TTL-based expiration and LRU eviction.
/// 
/// **Performance Benefit**: Caching expensive computations (like directory sizes)
/// avoids recalculation and significantly improves performance for repeated operations.
struct CacheEntry<T: Codable>: Codable {
    let value: T
    let timestamp: Date
    let ttl: TimeInterval
    
    /// Check if this entry has expired
    /// 
    /// An entry is considered expired if the time since creation exceeds the TTL.
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
}

/// Generic cache manager with LRU eviction and TTL support
/// 
/// This cache provides:
/// - **LRU Eviction**: Least-recently-used entries are evicted when size limit is exceeded
/// - **TTL Support**: Entries automatically expire after specified time
/// - **Thread Safety**: All operations are protected by NSLock
/// - **Size Tracking**: Monitors total cache size and evicts when necessary
/// - **Serialization**: Cache can be persisted to disk and restored
/// 
/// **Performance Requirements**:
/// - Requirement 6.1: Return cached results for same directory within 5 minutes
/// - Requirement 6.2: Persist cache to disk for recovery after app restart
/// - Requirement 6.3: Automatically invalidate and refresh stale cache
/// - Requirement 6.4: Evict LRU entries when cache exceeds 100MB
/// 
/// **Why Caching Matters**:
/// Directory size calculation can take 100-500ms depending on directory size.
/// Caching these results for 5 minutes provides massive performance improvement
/// for repeated operations (e.g., refreshing the app list).
/// 
/// **Usage Example**:
/// ```swift
/// let cache = CacheManager<String, Int64>(maxSizeBytes: 100 * 1024 * 1024)
/// 
/// // Set a value with 5-minute TTL
/// cache.set("app_size_/Applications/Safari.app", value: 1024000, ttl: 300)
/// 
/// // Get a value (returns nil if expired or not found)
/// if let size = cache.get("app_size_/Applications/Safari.app") {
///     print("Cached size: \(size)")
/// }
/// 
/// // Invalidate specific entry
/// cache.invalidate("app_size_/Applications/Safari.app")
/// 
/// // Clear all entries
/// cache.clear()
/// ```
class CacheManager<Key: Hashable & Codable, Value: Codable> {
    private let lock = NSLock()
    private var cache: [String: CacheEntry<Value>] = [:]
    private var accessOrder: [String] = [] // Track access order for LRU
    private let maxSizeBytes: Int64
    private var currentSizeBytes: Int64 = 0
    
    /// Initialize cache manager
    /// - Parameter maxSizeBytes: Maximum cache size in bytes (default: 100MB)
    init(maxSizeBytes: Int64 = 100 * 1024 * 1024) {
        self.maxSizeBytes = maxSizeBytes
    }
    
    /// Get a value from cache
    /// - Parameter key: The cache key
    /// - Returns: The cached value if it exists and hasn't expired, nil otherwise
    func get(_ key: Key) -> Value? {
        let keyString = keyToString(key)
        
        lock.lock()
        defer { lock.unlock() }
        
        guard let entry = cache[keyString] else {
            return nil
        }
        
        // Check if expired
        if entry.isExpired {
            removeEntry(keyString)
            return nil
        }
        
        // Update access order for LRU
        updateAccessOrder(keyString)
        
        return entry.value
    }
    
    /// Set a value in cache
    /// - Parameters:
    ///   - key: The cache key
    ///   - value: The value to cache
    ///   - ttl: Time to live in seconds (default: 300 seconds / 5 minutes)
    func set(_ key: Key, value: Value, ttl: TimeInterval = 300) {
        let keyString = keyToString(key)
        
        lock.lock()
        defer { lock.unlock() }
        
        let entry = CacheEntry(value: value, timestamp: Date(), ttl: ttl)
        
        // Remove old entry if it exists to recalculate size
        if let oldEntry = cache[keyString] {
            currentSizeBytes -= estimateSize(oldEntry)
        }
        
        // Add new entry
        cache[keyString] = entry
        currentSizeBytes += estimateSize(entry)
        
        // Update access order
        updateAccessOrder(keyString)
        
        // Evict if necessary
        evictIfNeeded()
    }
    
    /// Invalidate a specific cache entry
    /// - Parameter key: The cache key to invalidate
    func invalidate(_ key: Key) {
        let keyString = keyToString(key)
        
        lock.lock()
        defer { lock.unlock() }
        
        removeEntry(keyString)
    }
    
    /// Clear all cache entries
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        cache.removeAll()
        accessOrder.removeAll()
        currentSizeBytes = 0
    }
    
    /// Get current cache size in bytes
    var size: Int64 {
        lock.lock()
        defer { lock.unlock() }
        
        return currentSizeBytes
    }
    
    /// Get number of entries in cache
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        
        return cache.count
    }
    
    /// Get all valid (non-expired) entries
    var allEntries: [Key: Value] {
        lock.lock()
        defer { lock.unlock() }
        
        var result: [Key: Value] = [:]
        
        for (keyString, entry) in cache {
            if !entry.isExpired {
                if let key = stringToKey(keyString) {
                    result[key] = entry.value
                }
            }
        }
        
        return result
    }
    
    /// Get serializable cache data for persistence
    func getSerializableData() -> [String: CacheEntry<Value>] {
        lock.lock()
        defer { lock.unlock() }
        
        return cache
    }
    
    /// Load cache from serializable data
    func loadSerializableData(_ data: [String: CacheEntry<Value>]) {
        lock.lock()
        defer { lock.unlock() }
        
        cache.removeAll()
        accessOrder.removeAll()
        currentSizeBytes = 0
        
        for (key, entry) in data {
            // Only restore non-expired entries
            if !entry.isExpired {
                cache[key] = entry
                accessOrder.append(key)
                currentSizeBytes += estimateSize(entry)
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func keyToString(_ key: Key) -> String {
        // Use JSON encoding for consistent key representation
        if let data = try? JSONEncoder().encode(key),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return String(describing: key)
    }
    
    private func stringToKey(_ string: String) -> Key? {
        if let data = string.data(using: .utf8) {
            return try? JSONDecoder().decode(Key.self, from: data)
        }
        return nil
    }
    
    private func estimateSize<T: Codable>(_ value: T) -> Int64 {
        if let data = try? JSONEncoder().encode(value) {
            return Int64(data.count)
        }
        return 1024 // Fallback estimate
    }
    
    private func updateAccessOrder(_ keyString: String) {
        // Remove if already present
        if let index = accessOrder.firstIndex(of: keyString) {
            accessOrder.remove(at: index)
        }
        // Add to end (most recently used)
        accessOrder.append(keyString)
    }
    
    private func removeEntry(_ keyString: String) {
        if let entry = cache[keyString] {
            currentSizeBytes -= estimateSize(entry)
        }
        cache.removeValue(forKey: keyString)
        
        if let index = accessOrder.firstIndex(of: keyString) {
            accessOrder.remove(at: index)
        }
    }
    
    private func evictIfNeeded() {
        // Evict least recently used entries until size is below limit
        while currentSizeBytes > maxSizeBytes && !accessOrder.isEmpty {
            let lruKey = accessOrder.removeFirst()
            removeEntry(lruKey)
        }
    }
}
