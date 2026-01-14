import XCTest
@testable import AppUninstaller

final class CachePersistenceTests: XCTestCase {
    
    var persistence: CachePersistence!
    
    override func setUp() {
        super.setUp()
        do {
            persistence = try CachePersistence()
        } catch {
            XCTFail("Failed to initialize CachePersistence: \(error)")
        }
    }
    
    override func tearDown() {
        do {
            try persistence?.clearAll()
        } catch {
            print("Failed to clear cache: \(error)")
        }
        persistence = nil
        super.tearDown()
    }
    
    // MARK: - Unit Tests
    
    func testSaveAndLoad() throws {
        let testData = ["key1": "value1", "key2": "value2"]
        
        try persistence.save(testData, forKey: "testData")
        let loaded = try persistence.load([String: String].self, forKey: "testData")
        
        XCTAssertEqual(loaded, testData, "Should save and load data correctly")
    }
    
    func testLoadNonexistentKey() throws {
        let loaded = try persistence.load([String: String].self, forKey: "nonexistent")
        XCTAssertNil(loaded, "Should return nil for nonexistent key")
    }
    
    func testDelete() throws {
        let testData = ["key": "value"]
        
        try persistence.save(testData, forKey: "deleteTest")
        var loaded = try persistence.load([String: String].self, forKey: "deleteTest")
        XCTAssertNotNil(loaded, "Should have data before delete")
        
        try persistence.delete(forKey: "deleteTest")
        loaded = try persistence.load([String: String].self, forKey: "deleteTest")
        XCTAssertNil(loaded, "Should have no data after delete")
    }
    
    func testDeleteNonexistentKey() throws {
        // Should not throw
        try persistence.delete(forKey: "nonexistent")
        XCTAssertTrue(true, "Should not throw when deleting nonexistent key")
    }
    
    func testClearAll() throws {
        // Save multiple items
        try persistence.save(["data1": "value1"], forKey: "item1")
        try persistence.save(["data2": "value2"], forKey: "item2")
        
        var size = try persistence.totalSize()
        XCTAssertGreaterThan(size, 0, "Should have data before clear")
        
        try persistence.clearAll()
        
        size = try persistence.totalSize()
        XCTAssertEqual(size, 0, "Should have no data after clear")
    }
    
    func testTotalSize() throws {
        let initialSize = try persistence.totalSize()
        
        let testData = String(repeating: "x", count: 1000)
        try persistence.save(testData, forKey: "sizeTest")
        
        let newSize = try persistence.totalSize()
        XCTAssertGreaterThan(newSize, initialSize, "Size should increase after saving data")
    }
    
    func testSaveComplexData() throws {
        struct TestData: Codable, Equatable {
            let id: Int
            let name: String
            let values: [Int]
        }
        
        let testData = TestData(id: 1, name: "Test", values: [1, 2, 3, 4, 5])
        
        try persistence.save(testData, forKey: "complexData")
        let loaded = try persistence.load(TestData.self, forKey: "complexData")
        
        XCTAssertEqual(loaded, testData, "Should save and load complex data")
    }
    
    func testSaveMultipleItems() throws {
        let data1 = ["key1": "value1"]
        let data2 = ["key2": "value2"]
        let data3 = ["key3": "value3"]
        
        try persistence.save(data1, forKey: "item1")
        try persistence.save(data2, forKey: "item2")
        try persistence.save(data3, forKey: "item3")
        
        let loaded1 = try persistence.load([String: String].self, forKey: "item1")
        let loaded2 = try persistence.load([String: String].self, forKey: "item2")
        let loaded3 = try persistence.load([String: String].self, forKey: "item3")
        
        XCTAssertEqual(loaded1, data1)
        XCTAssertEqual(loaded2, data2)
        XCTAssertEqual(loaded3, data3)
    }
    
    func testOverwriteExistingKey() throws {
        let data1 = ["version": "1"]
        let data2 = ["version": "2"]
        
        try persistence.save(data1, forKey: "versionData")
        var loaded = try persistence.load([String: String].self, forKey: "versionData")
        XCTAssertEqual(loaded, data1)
        
        try persistence.save(data2, forKey: "versionData")
        loaded = try persistence.load([String: String].self, forKey: "versionData")
        XCTAssertEqual(loaded, data2, "Should overwrite existing data")
    }
    
    func testLargeData() throws {
        let largeData = String(repeating: "x", count: 10_000_000) // 10MB
        
        try persistence.save(largeData, forKey: "largeData")
        let loaded = try persistence.load(String.self, forKey: "largeData")
        
        XCTAssertEqual(loaded, largeData, "Should handle large data")
    }
    
    // MARK: - Integration Tests
    
    func testCacheManagerPersistence() throws {
        let cache = CacheManager<String, String>()
        
        // Add data to cache
        cache.set("key1", value: "value1")
        cache.set("key2", value: "value2")
        cache.set("key3", value: "value3")
        
        // Save to disk
        try cache.saveToDisk(persistence)
        
        // Create new cache and load from disk
        let newCache = CacheManager<String, String>()
        try newCache.loadFromDisk(persistence)
        
        // Verify data was restored
        XCTAssertEqual(newCache.get("key1"), "value1")
        XCTAssertEqual(newCache.get("key2"), "value2")
        XCTAssertEqual(newCache.get("key3"), "value3")
    }
    
    func testCacheManagerPersistenceWithExpiration() throws {
        let cache = CacheManager<String, String>()
        
        // Add data with different TTLs
        cache.set("persistent", value: "value1", ttl: 1000) // Long TTL
        cache.set("temporary", value: "value2", ttl: 0.1)   // Short TTL
        
        // Wait for temporary to expire
        usleep(150_000) // 150ms
        
        // Save to disk
        try cache.saveToDisk(persistence)
        
        // Create new cache and load from disk
        let newCache = CacheManager<String, String>()
        try newCache.loadFromDisk(persistence)
        
        // Verify only non-expired data was restored
        XCTAssertEqual(newCache.get("persistent"), "value1", "Should restore non-expired data")
        XCTAssertNil(newCache.get("temporary"), "Should not restore expired data")
    }
    
    func testPersistenceWithEmptyCache() throws {
        let cache = CacheManager<String, String>()
        
        // Save empty cache
        try cache.saveToDisk(persistence)
        
        // Load into new cache
        let newCache = CacheManager<String, String>()
        try newCache.loadFromDisk(persistence)
        
        XCTAssertEqual(newCache.count, 0, "Should handle empty cache")
    }
    
    func testPersistenceRoundTrip() throws {
        let cache = CacheManager<String, String>()
        
        // Add data
        for i in 0..<10 {
            cache.set("key\(i)", value: "value\(i)")
        }
        
        let originalSize = cache.size
        let originalCount = cache.count
        
        // Save and load
        try cache.saveToDisk(persistence)
        
        let newCache = CacheManager<String, String>()
        try newCache.loadFromDisk(persistence)
        
        // Verify data integrity
        XCTAssertEqual(newCache.count, originalCount, "Should preserve count")
        XCTAssertEqual(newCache.size, originalSize, "Should preserve size")
        
        for i in 0..<10 {
            XCTAssertEqual(newCache.get("key\(i)"), "value\(i)", "Should preserve data for key\(i)")
        }
    }
}
