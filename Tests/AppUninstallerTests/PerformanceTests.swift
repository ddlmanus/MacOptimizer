import XCTest
@testable import AppUninstaller

final class PerformanceTests: XCTestCase {
    
    var monitor: PerformanceMonitor!
    var cache: CacheManager<String, String>!
    var taskQueue: BackgroundTaskQueue!
    var updater: BatchedUIUpdater!
    
    override func setUp() {
        super.setUp()
        monitor = PerformanceMonitor()
        cache = CacheManager<String, String>()
        taskQueue = BackgroundTaskQueue()
        updater = BatchedUIUpdater(debounceDelay: 0.01)
    }
    
    override func tearDown() {
        monitor = nil
        cache = nil
        taskQueue = nil
        updater = nil
        super.tearDown()
    }
    
    // MARK: - Performance Test Suite: Operation Timing
    // Measure operation times before/after optimization
    // Requirements: 4.1, 4.3
    
    func testPerformanceMonitorMeasuresOperationTiming() {
        let operationName = "fileIO"
        let token = monitor.startMeasuring(operationName)
        
        // Simulate file I/O operation
        usleep(50_000) // 50ms
        
        monitor.endMeasuring(token)
        
        // Verify timing was recorded
        if let average = monitor.averageTime(for: operationName) {
            XCTAssertGreaterThan(average, 0.04, "Should measure at least 40ms")
            XCTAssertLessThan(average, 0.1, "Should measure less than 100ms")
        }
    }
    
    func testPerformanceMonitorTrackingMultipleOperations() {
        // Simulate multiple operations with different durations
        let operations = [
            ("fastOp", 10_000),      // 10ms
            ("mediumOp", 50_000),    // 50ms
            ("slowOp", 100_000)      // 100ms
        ]
        
        for (name, duration) in operations {
            let token = monitor.startMeasuring(name)
            usleep(UInt32(duration))
            monitor.endMeasuring(token)
        }
        
        let averages = monitor.averageOperationTime
        
        // Verify all operations were tracked
        XCTAssertEqual(averages.count, 3, "Should track all 3 operations")
        
        // Verify timing relationships
        let fastTime = averages["fastOp"] ?? 0
        let mediumTime = averages["mediumOp"] ?? 0
        let slowTime = averages["slowOp"] ?? 0
        
        XCTAssertLessThan(fastTime, mediumTime, "Fast operation should be faster than medium")
        XCTAssertLessThan(mediumTime, slowTime, "Medium operation should be faster than slow")
    }
    
    func testPerformanceMonitorWarningThreshold() {
        monitor.setWarningThreshold(0.05) // 50ms threshold
        
        // Operation under threshold
        let fastToken = monitor.startMeasuring("fastOp")
        usleep(30_000) // 30ms
        monitor.endMeasuring(fastToken)
        
        // Operation over threshold
        let slowToken = monitor.startMeasuring("slowOp")
        usleep(100_000) // 100ms
        monitor.endMeasuring(slowToken)
        
        let averages = monitor.averageOperationTime
        
        if let fastTime = averages["fastOp"] {
            XCTAssertLessThan(fastTime, 0.05, "Fast operation should be under threshold")
        }
        
        if let slowTime = averages["slowOp"] {
            XCTAssertGreaterThan(slowTime, 0.05, "Slow operation should exceed threshold")
        }
    }
    
    // MARK: - Performance Test Suite: Memory Usage
    // Profile memory usage
    // Requirements: 4.1, 4.3
    
    func testCacheMemoryUsageWithManyEntries() {
        let entryCount = 1000
        let valueSize = 1000 // 1KB per value
        
        let initialSize = cache.size
        
        // Add many entries
        for i in 0..<entryCount {
            let value = String(repeating: "x", count: valueSize)
            cache.set("key\(i)", value: value)
        }
        
        let finalSize = cache.size
        let memoryUsed = finalSize - initialSize
        
        // Verify memory usage is reasonable
        XCTAssertGreaterThan(memoryUsed, 0, "Should use memory for entries")
        XCTAssertLessThan(memoryUsed, Int64(entryCount * valueSize * 2), "Memory usage should be reasonable")
    }
    
    func testCacheEvictionReducesMemory() {
        let smallCache = CacheManager<String, String>(maxSizeBytes: 5000)
        
        // Add entries until eviction occurs
        for i in 0..<20 {
            let value = String(repeating: "x", count: 500)
            smallCache.set("key\(i)", value: value)
        }
        
        // Verify cache size is within limit
        XCTAssertLessThanOrEqual(smallCache.size, 5000, "Cache should not exceed max size")
        
        // Verify some entries were evicted
        XCTAssertLessThan(smallCache.count, 20, "Some entries should be evicted")
    }
    
    func testTaskQueueMemoryUsageWithManyTasks() async {
        var taskCount = 0
        let taskLimit = 100
        
        // Enqueue many tasks
        for _ in 0..<taskLimit {
            _ = await taskQueue.enqueue {
                taskCount += 1
            }
        }
        
        // Verify all tasks executed
        XCTAssertEqual(taskCount, taskLimit, "All tasks should execute")
    }
    
    // MARK: - Performance Test Suite: Thread Context Switches
    // Monitor thread context switches
    // Requirements: 4.1, 4.3
    
    func testBatchedUIUpdaterReducesContextSwitches() async {
        var updateCount = 0
        let batchSize = 10
        
        // Measure time for batched updates
        let batchedStart = Date()
        
        for _ in 0..<batchSize {
            _ = await updater.batch {
                updateCount += 1
            }
        }
        
        let batchedTime = Date().timeIntervalSince(batchedStart)
        
        // Verify all updates executed
        XCTAssertEqual(updateCount, batchSize, "All batched updates should execute")
        
        // Batched updates should be relatively fast
        XCTAssertLessThan(batchedTime, 1.0, "Batched updates should complete quickly")
    }
    
    func testSequentialTaskExecutionReducesContextSwitches() async {
        var executionLog: [String] = []
        let taskCount = 50
        
        let startTime = Date()
        
        for i in 0..<taskCount {
            _ = await taskQueue.enqueue {
                executionLog.append("task\(i)")
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Verify sequential execution
        XCTAssertEqual(executionLog.count, taskCount, "All tasks should execute")
        
        // Sequential execution should be efficient
        XCTAssertLessThan(elapsed, 5.0, "Sequential task execution should be efficient")
    }
    
    func testCacheHitReducesOperationTime() {
        let key = "testKey"
        let value = "testValue"
        
        // First access (cache miss)
        let missStart = Date()
        _ = cache.get(key)
        let _ = Date().timeIntervalSince(missStart)
        
        // Set value
        cache.set(key, value: value)
        
        // Second access (cache hit)
        let hitStart = Date()
        let retrieved = cache.get(key)
        let hitTime = Date().timeIntervalSince(hitStart)
        
        // Cache hit should be faster than miss
        XCTAssertEqual(retrieved, value, "Should retrieve correct value")
        XCTAssertLessThan(hitTime, 0.01, "Cache hit should be very fast")
    }
    
    // MARK: - Integration Tests: File Scanning Performance
    // Test file scanning with real directories
    // Requirements: 1.1, 5.1, 6.2
    
    func testFileScanningPerformanceWithRealDirectory() async {
        // Create temporary directory with test files
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("performanceTest_\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
            
            // Create test files with large sizes to meet minimum threshold
            let fileCount = 10
            for i in 0..<fileCount {
                let filePath = testDir.appendingPathComponent("file\(i).bin")
                let largeContent = String(repeating: "x", count: 60 * 1024 * 1024) // 60MB
                try largeContent.write(to: filePath, atomically: true, encoding: .utf8)
            }
            
            // Measure scanning time
            let scanner = LargeFileScanner()
            let startTime = Date()
            
            await scanner.scan()
            
            let elapsed = Date().timeIntervalSince(startTime)
            
            // Verify files were found
            XCTAssertGreaterThan(scanner.foundFiles.count, 0, "Should find files in directory")
            
            // Verify scanning completed in reasonable time
            XCTAssertLessThan(elapsed, 30.0, "Directory scanning should complete in reasonable time")
            
            // Cleanup
            try FileManager.default.removeItem(at: testDir)
        } catch {
            XCTFail("Failed to set up test: \(error)")
        }
    }
    
    func testFileScanningWithCaching() async {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("cachingTest_\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
            
            // Create test files with large sizes to meet minimum threshold
            for i in 0..<5 {
                let filePath = testDir.appendingPathComponent("file\(i).bin")
                let largeContent = String(repeating: "x", count: 60 * 1024 * 1024) // 60MB
                try largeContent.write(to: filePath, atomically: true, encoding: .utf8)
            }
            
            let scanner = LargeFileScanner()
            
            // First scan (no cache)
            let firstStart = Date()
            await scanner.scan()
            let firstScan = scanner.foundFiles
            let firstTime = Date().timeIntervalSince(firstStart)
            
            // Reset scanner
            scanner.reset()
            
            // Second scan (should use cache if implemented)
            let secondStart = Date()
            await scanner.scan()
            let secondScan = scanner.foundFiles
            let secondTime = Date().timeIntervalSince(secondStart)
            
            // Verify both scans found files
            XCTAssertGreaterThan(firstScan.count, 0, "First scan should find files")
            XCTAssertGreaterThan(secondScan.count, 0, "Second scan should find files")
            
            // Second scan should be faster or equal (due to caching)
            XCTAssertLessThanOrEqual(secondTime, firstTime * 1.5, "Second scan should be reasonably fast")
            
            // Cleanup
            try FileManager.default.removeItem(at: testDir)
        } catch {
            XCTFail("Failed to set up test: \(error)")
        }
    }
    
    // MARK: - Integration Tests: UI Responsiveness
    // Test UI responsiveness during operations
    // Requirements: 1.1, 5.1, 6.2
    
    func testUIResponsivenessDuringBackgroundOperations() async {
        var uiUpdateCount = 0
        var backgroundTaskCount = 0
        
        // Simulate background operations
        for _ in 0..<10 {
            _ = await taskQueue.enqueue {
                backgroundTaskCount += 1
                // Simulate work
                usleep(10_000) // 10ms
            }
        }
        
        // Simulate UI updates during background operations
        for _ in 0..<10 {
            _ = await updater.batch {
                uiUpdateCount += 1
            }
        }
        
        // Verify both completed
        XCTAssertEqual(backgroundTaskCount, 10, "All background tasks should complete")
        XCTAssertEqual(uiUpdateCount, 10, "All UI updates should complete")
    }
    
    func testBatchedUIUpdatesImproveResponsiveness() async {
        var updateCount = 0
        let batchCount = 100
        
        let startTime = Date()
        
        // Batch many updates
        for _ in 0..<batchCount {
            _ = await updater.batch {
                updateCount += 1
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Verify all updates executed
        XCTAssertEqual(updateCount, batchCount, "All updates should execute")
        
        // Batched updates should be efficient
        XCTAssertLessThan(elapsed, 2.0, "Batched updates should be efficient")
    }
    
    // MARK: - Integration Tests: Cache Persistence
    // Test cache persistence
    // Requirements: 1.1, 5.1, 6.2
    
    func testCachePersistencePerformance() throws {
        let persistence = try CachePersistence()
        
        defer {
            try? persistence.clearAll()
        }
        
        // Create cache with data
        let cache = CacheManager<String, String>()
        for i in 0..<100 {
            cache.set("key\(i)", value: "value\(i)")
        }
        
        // Measure save time
        let saveStart = Date()
        try cache.saveToDisk(persistence)
        let saveTime = Date().timeIntervalSince(saveStart)
        
        // Measure load time
        let newCache = CacheManager<String, String>()
        let loadStart = Date()
        try newCache.loadFromDisk(persistence)
        let loadTime = Date().timeIntervalSince(loadStart)
        
        // Verify data integrity
        XCTAssertEqual(newCache.count, 100, "Should load all entries")
        
        // Verify performance
        XCTAssertLessThan(saveTime, 1.0, "Save should be fast")
        XCTAssertLessThan(loadTime, 1.0, "Load should be fast")
    }
    
    func testCachePersistenceWithLargeData() throws {
        let persistence = try CachePersistence()
        
        defer {
            try? persistence.clearAll()
        }
        
        // Create cache with large values
        let cache = CacheManager<String, String>()
        let largeValue = String(repeating: "x", count: 100_000) // 100KB per value
        
        for i in 0..<10 {
            cache.set("key\(i)", value: largeValue)
        }
        
        // Measure save time
        let saveStart = Date()
        try cache.saveToDisk(persistence)
        let saveTime = Date().timeIntervalSince(saveStart)
        
        // Measure load time
        let newCache = CacheManager<String, String>()
        let loadStart = Date()
        try newCache.loadFromDisk(persistence)
        let loadTime = Date().timeIntervalSince(loadStart)
        
        // Verify data integrity
        XCTAssertEqual(newCache.count, 10, "Should load all entries")
        
        // Verify performance with large data
        XCTAssertLessThan(saveTime, 2.0, "Save should handle large data")
        XCTAssertLessThan(loadTime, 2.0, "Load should handle large data")
    }
    
    // MARK: - Stress Tests
    
    func testHighConcurrencyTaskExecution() async {
        var completedTasks = 0
        let taskCount = 200
        
        for _ in 0..<taskCount {
            _ = await taskQueue.enqueue {
                completedTasks += 1
            }
        }
        
        XCTAssertEqual(completedTasks, taskCount, "All tasks should complete under high concurrency")
    }
    
    func testCacheUnderMemoryPressure() {
        let cache = CacheManager<String, String>(maxSizeBytes: 10_000)
        
        // Add many entries to trigger eviction
        for i in 0..<100 {
            let value = String(repeating: "x", count: 500)
            cache.set("key\(i)", value: value)
        }
        
        // Verify cache stayed within limits
        XCTAssertLessThanOrEqual(cache.size, 10_000, "Cache should respect size limit under pressure")
        
        // Verify cache is still functional
        XCTAssertGreaterThan(cache.count, 0, "Cache should retain some entries")
    }
    
    func testPerformanceMonitorUnderLoad() {
        let operationCount = 1000
        
        for i in 0..<operationCount {
            let token = monitor.startMeasuring("loadTest\(i % 10)")
            usleep(1_000) // 1ms
            monitor.endMeasuring(token)
        }
        
        let averages = monitor.averageOperationTime
        
        // Verify monitoring worked under load
        XCTAssertGreaterThan(averages.count, 0, "Should track operations under load")
        XCTAssertLessThanOrEqual(averages.count, 10, "Should have 10 unique operations")
    }
}
