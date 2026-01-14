import XCTest
@testable import AppUninstaller

final class CacheManagerTests: XCTestCase {
    
    var cache: CacheManager<String, String>!
    
    override func setUp() {
        super.setUp()
        cache = CacheManager<String, String>()
    }
    
    override func tearDown() {
        cache = nil
        super.tearDown()
    }
    
    // MARK: - Property 1: Cache Consistency
    // For any cache operation sequence, if a value is set and not invalidated,
    // subsequent gets within the TTL window should return the same value.
    // Feature: performance-optimization, Property 1: Cache Consistency
    // Validates: Requirements 6.1, 6.2
    
    func testCacheConsistencyWithinTTL() {
        let key = "testKey"
        let value = "testValue"
        let ttl: TimeInterval = 10.0
        
        // Set value
        cache.set(key, value: value, ttl: ttl)
        
        // Get value immediately
        let retrieved1 = cache.get(key)
        XCTAssertEqual(retrieved1, value, "Should retrieve same value immediately after set")
        
        // Get value after short delay
        usleep(100_000) // 100ms
        let retrieved2 = cache.get(key)
        XCTAssertEqual(retrieved2, value, "Should retrieve same value within TTL")
        
        // Get value again
        let retrieved3 = cache.get(key)
        XCTAssertEqual(retrieved3, value, "Should consistently return same value")
    }
    
    func testCacheConsistencyAfterExpiration() {
        let key = "expireKey"
        let value = "expireValue"
        let ttl: TimeInterval = 0.1 // 100ms
        
        // Set value with short TTL
        cache.set(key, value: value, ttl: ttl)
        
        // Get value before expiration
        let retrieved1 = cache.get(key)
        XCTAssertEqual(retrieved1, value, "Should retrieve value before expiration")
        
        // Wait for expiration
        usleep(150_000) // 150ms
        
        // Get value after expiration
        let retrieved2 = cache.get(key)
        XCTAssertNil(retrieved2, "Should return nil after expiration")
    }
    
    // MARK: - Property 6: Cache Eviction
    // For any cache that exceeds 100MB, the least-recently-used entries
    // should be evicted until size is below 100MB.
    // Feature: performance-optimization, Property 6: Cache Eviction
    // Validates: Requirements 6.4
    
    func testCacheEvictionWhenSizeExceeded() {
        // Create cache with small max size for testing
        let smallCache = CacheManager<String, String>(maxSizeBytes: 1000)
        
        // Add entries until size exceeds limit
        for i in 0..<10 {
            let key = "key\(i)"
            let value = String(repeating: "x", count: 200) // ~200 bytes per entry
            smallCache.set(key, value: value)
        }
        
        // Verify cache size is within limit
        XCTAssertLessThanOrEqual(smallCache.size, 1000, "Cache size should not exceed limit")
        
        // Verify oldest entries were evicted
        let firstValue = smallCache.get("key0")
        XCTAssertNil(firstValue, "Oldest entry should be evicted")
        
        // Verify newer entries still exist
        let lastValue = smallCache.get("key9")
        XCTAssertNotNil(lastValue, "Newest entry should still exist")
    }
    
    func testLRUEvictionOrder() {
        let smallCache = CacheManager<String, String>(maxSizeBytes: 2000)
        
        // Add initial entries
        for i in 0..<5 {
            let key = "key\(i)"
            let value = String(repeating: "x", count: 200)
            smallCache.set(key, value: value)
        }
        
        // Access key1 to make it recently used
        _ = smallCache.get("key1")
        
        // Add more entries to trigger eviction
        for i in 5..<10 {
            let key = "key\(i)"
            let value = String(repeating: "x", count: 200)
            smallCache.set(key, value: value)
        }
        
        // key0 should be evicted (least recently used)
        XCTAssertNil(smallCache.get("key0"), "Least recently used should be evicted")
        
        // key1 should still exist (was accessed recently)
        XCTAssertNotNil(smallCache.get("key1"), "Recently accessed entry should not be evicted")
    }
    
    // MARK: - Unit Tests
    
    func testSetAndGet() {
        let key = "testKey"
        let value = "testValue"
        
        cache.set(key, value: value)
        let retrieved = cache.get(key)
        
        XCTAssertEqual(retrieved, value, "Should retrieve set value")
    }
    
    func testGetNonexistentKey() {
        let retrieved = cache.get("nonexistent")
        XCTAssertNil(retrieved, "Should return nil for nonexistent key")
    }
    
    func testInvalidateKey() {
        let key = "testKey"
        let value = "testValue"
        
        cache.set(key, value: value)
        XCTAssertNotNil(cache.get(key), "Should have value before invalidation")
        
        cache.invalidate(key)
        XCTAssertNil(cache.get(key), "Should return nil after invalidation")
    }
    
    func testClearAll() {
        // Add multiple entries
        for i in 0..<5 {
            cache.set("key\(i)", value: "value\(i)")
        }
        
        XCTAssertGreaterThan(cache.count, 0, "Should have entries before clear")
        
        cache.clear()
        
        XCTAssertEqual(cache.count, 0, "Should have no entries after clear")
        XCTAssertEqual(cache.size, 0, "Cache size should be 0 after clear")
    }
    
    func testTTLExpiration() {
        let key = "expireKey"
        let value = "expireValue"
        let ttl: TimeInterval = 0.1 // 100ms
        
        cache.set(key, value: value, ttl: ttl)
        
        // Should exist immediately
        XCTAssertNotNil(cache.get(key), "Should exist before expiration")
        
        // Wait for expiration
        usleep(150_000) // 150ms
        
        // Should be expired
        XCTAssertNil(cache.get(key), "Should be expired after TTL")
    }
    
    func testDefaultTTL() {
        let key = "defaultTTLKey"
        let value = "defaultTTLValue"
        
        // Set without specifying TTL (should use default 300s)
        cache.set(key, value: value)
        
        // Should exist immediately
        XCTAssertNotNil(cache.get(key), "Should exist with default TTL")
    }
    
    func testMultipleKeys() {
        let entries = [
            ("key1", "value1"),
            ("key2", "value2"),
            ("key3", "value3")
        ]
        
        for (key, value) in entries {
            cache.set(key, value: value)
        }
        
        for (key, expectedValue) in entries {
            let retrieved = cache.get(key)
            XCTAssertEqual(retrieved, expectedValue, "Should retrieve correct value for \(key)")
        }
    }
    
    func testUpdateExistingKey() {
        let key = "updateKey"
        
        cache.set(key, value: "value1")
        XCTAssertEqual(cache.get(key), "value1", "Should have initial value")
        
        cache.set(key, value: "value2")
        XCTAssertEqual(cache.get(key), "value2", "Should have updated value")
    }
    
    func testCacheSize() {
        XCTAssertEqual(cache.size, 0, "New cache should have size 0")
        
        cache.set("key1", value: "value1")
        XCTAssertGreaterThan(cache.size, 0, "Cache size should increase after adding entry")
        
        let sizeAfterFirst = cache.size
        cache.set("key2", value: "value2")
        XCTAssertGreaterThan(cache.size, sizeAfterFirst, "Cache size should increase with more entries")
    }
    
    func testCacheCount() {
        XCTAssertEqual(cache.count, 0, "New cache should have count 0")
        
        cache.set("key1", value: "value1")
        XCTAssertEqual(cache.count, 1, "Count should be 1 after adding entry")
        
        cache.set("key2", value: "value2")
        XCTAssertEqual(cache.count, 2, "Count should be 2 after adding another entry")
        
        cache.invalidate("key1")
        XCTAssertEqual(cache.count, 1, "Count should decrease after invalidation")
    }
    
    func testAllEntries() {
        cache.set("key1", value: "value1")
        cache.set("key2", value: "value2")
        cache.set("key3", value: "value3")
        
        let allEntries = cache.allEntries
        
        XCTAssertEqual(allEntries.count, 3, "Should return all entries")
        XCTAssertEqual(allEntries["key1"], "value1", "Should have correct value for key1")
        XCTAssertEqual(allEntries["key2"], "value2", "Should have correct value for key2")
        XCTAssertEqual(allEntries["key3"], "value3", "Should have correct value for key3")
    }
    
    func testAllEntriesExcludesExpired() {
        cache.set("key1", value: "value1", ttl: 10.0)
        cache.set("key2", value: "value2", ttl: 0.1) // Will expire
        cache.set("key3", value: "value3", ttl: 10.0)
        
        usleep(150_000) // 150ms - key2 should expire
        
        let allEntries = cache.allEntries
        
        XCTAssertEqual(allEntries.count, 2, "Should exclude expired entries")
        XCTAssertNil(allEntries["key2"], "Should not include expired entry")
    }
    
    func testConcurrentAccess() {
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Concurrent writes
        for i in 0..<20 {
            group.enter()
            queue.async {
                self.cache.set("key\(i)", value: "value\(i)")
                group.leave()
            }
        }
        
        group.wait()
        
        // Verify all entries were added
        XCTAssertEqual(cache.count, 20, "Should have all entries after concurrent writes")
        
        // Concurrent reads
        for i in 0..<20 {
            group.enter()
            queue.async {
                let value = self.cache.get("key\(i)")
                XCTAssertEqual(value, "value\(i)", "Should retrieve correct value")
                group.leave()
            }
        }
        
        group.wait()
    }
    
    func testLargeValues() {
        let key = "largeKey"
        let largeValue = String(repeating: "x", count: 1_000_000) // 1MB
        
        cache.set(key, value: largeValue)
        let retrieved = cache.get(key)
        
        XCTAssertEqual(retrieved, largeValue, "Should handle large values")
    }
    
    func testSpecialCharactersInKeys() {
        let specialKeys = [
            "key-with-dashes",
            "key_with_underscores",
            "key.with.dots",
            "key/with/slashes",
            "key with spaces"
        ]
        
        for key in specialKeys {
            cache.set(key, value: "value")
            let retrieved = cache.get(key)
            XCTAssertEqual(retrieved, "value", "Should handle special characters in key: \(key)")
        }
    }
    
    // MARK: - Integration Tests
    
    func testCompleteWorkflow() {
        // Add entries
        cache.set("user1", value: "Alice")
        cache.set("user2", value: "Bob")
        cache.set("user3", value: "Charlie")
        
        // Verify entries
        XCTAssertEqual(cache.get("user1"), "Alice")
        XCTAssertEqual(cache.get("user2"), "Bob")
        XCTAssertEqual(cache.get("user3"), "Charlie")
        
        // Update entry
        cache.set("user2", value: "Robert")
        XCTAssertEqual(cache.get("user2"), "Robert")
        
        // Invalidate entry
        cache.invalidate("user1")
        XCTAssertNil(cache.get("user1"))
        
        // Verify remaining entries
        XCTAssertEqual(cache.count, 2)
        
        // Clear all
        cache.clear()
        XCTAssertEqual(cache.count, 0)
    }
    
    func testCacheWithDifferentTypes() {
        // Test with Int values
        let intCache = CacheManager<String, Int>()
        intCache.set("count", value: 42)
        XCTAssertEqual(intCache.get("count"), 42)
        
        // Test with Bool values
        let boolCache = CacheManager<String, Bool>()
        boolCache.set("flag", value: true)
        XCTAssertEqual(boolCache.get("flag"), true)
    }
}
