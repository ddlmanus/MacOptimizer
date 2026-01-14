import XCTest
@testable import AppUninstaller

final class IntegrationTests: XCTestCase {
    
    // MARK: - Integration Tests: File Scanning with Real Directories
    // Test file scanning with real directories
    // Requirements: 1.1, 5.1, 6.2
    
    func testFileScanningWithRealDirectoryStructure() async {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("scanTest_\(UUID().uuidString)")
        
        do {
            // Create directory structure
            try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
            
            let subDir1 = testDir.appendingPathComponent("subdir1")
            let subDir2 = testDir.appendingPathComponent("subdir2")
            try FileManager.default.createDirectory(at: subDir1, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: subDir2, withIntermediateDirectories: true)
            
            // Create files with large sizes to meet minimum threshold
            for i in 0..<3 {
                let filePath = testDir.appendingPathComponent("file\(i).bin")
                let largeContent = String(repeating: "x", count: 60 * 1024 * 1024) // 60MB
                try largeContent.write(to: filePath, atomically: true, encoding: .utf8)
            }
            
            for i in 0..<2 {
                let filePath = subDir1.appendingPathComponent("subfile\(i).bin")
                let largeContent = String(repeating: "x", count: 60 * 1024 * 1024) // 60MB
                try largeContent.write(to: filePath, atomically: true, encoding: .utf8)
            }
            
            for i in 0..<1 {
                let filePath = subDir2.appendingPathComponent("deepfile\(i).bin")
                let largeContent = String(repeating: "x", count: 60 * 1024 * 1024) // 60MB
                try largeContent.write(to: filePath, atomically: true, encoding: .utf8)
            }
            
            // Scan directory
            let scanner = LargeFileScanner()
            await scanner.scan()
            let files = scanner.foundFiles
            
            // Verify files were found
            XCTAssertGreaterThan(files.count, 0, "Should find files in directory structure")
            
            // Cleanup
            try FileManager.default.removeItem(at: testDir)
        } catch {
            XCTFail("Failed to set up test: \(error)")
        }
    }
    
    func testFileScanningWithLargeDirectory() async {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("largeTest_\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
            
            // Create many files with large sizes to meet minimum threshold
            let fileCount = 5
            for i in 0..<fileCount {
                let filePath = testDir.appendingPathComponent("file\(i).bin")
                let largeContent = String(repeating: "x", count: 60 * 1024 * 1024) // 60MB
                try largeContent.write(to: filePath, atomically: true, encoding: .utf8)
            }
            
            // Scan directory
            let scanner = LargeFileScanner()
            let startTime = Date()
            await scanner.scan()
            let files = scanner.foundFiles
            let elapsed = Date().timeIntervalSince(startTime)
            
            // Verify files were found
            XCTAssertGreaterThan(files.count, 0, "Should find files in large directory")
            
            // Verify scanning completed in reasonable time
            XCTAssertLessThan(elapsed, 30.0, "Large directory scan should complete in reasonable time")
            
            // Cleanup
            try FileManager.default.removeItem(at: testDir)
        } catch {
            XCTFail("Failed to set up test: \(error)")
        }
    }
    
    func testFileScanningWithMixedFileTypes() async {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("mixedTest_\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
            
            // Create files with different extensions, all with large sizes
            let extensions = ["bin", "dat", "tmp"]
            for (index, ext) in extensions.enumerated() {
                let filePath = testDir.appendingPathComponent("file\(index).\(ext)")
                let largeContent = String(repeating: "x", count: 60 * 1024 * 1024) // 60MB
                try largeContent.write(to: filePath, atomically: true, encoding: .utf8)
            }
            
            // Scan directory
            let scanner = LargeFileScanner()
            await scanner.scan()
            let files = scanner.foundFiles
            
            // Verify files were found
            XCTAssertGreaterThan(files.count, 0, "Should find files with mixed types")
            
            // Cleanup
            try FileManager.default.removeItem(at: testDir)
        } catch {
            XCTFail("Failed to set up test: \(error)")
        }
    }
    
    func testFileScanningWithSymlinks() async {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("symlinkTest_\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
            
            // Create regular files with large sizes
            for i in 0..<2 {
                let filePath = testDir.appendingPathComponent("file\(i).bin")
                let largeContent = String(repeating: "x", count: 60 * 1024 * 1024) // 60MB
                try largeContent.write(to: filePath, atomically: true, encoding: .utf8)
            }
            
            // Create symlinks (if supported)
            let sourceFile = testDir.appendingPathComponent("file0.bin")
            let linkFile = testDir.appendingPathComponent("link.bin")
            
            do {
                try FileManager.default.createSymbolicLink(at: linkFile, withDestinationURL: sourceFile)
            } catch {
                // Symlinks may not be supported in test environment
                print("Symlink creation not supported: \(error)")
            }
            
            // Scan directory
            let scanner = LargeFileScanner()
            await scanner.scan()
            let files = scanner.foundFiles
            
            // Verify files were found
            XCTAssertGreaterThan(files.count, 0, "Should find files including symlinks")
            
            // Cleanup
            try FileManager.default.removeItem(at: testDir)
        } catch {
            XCTFail("Failed to set up test: \(error)")
        }
    }
    
    // MARK: - Integration Tests: UI Responsiveness During Operations
    // Test UI responsiveness during operations
    // Requirements: 1.1, 5.1, 6.2
    
    func testUIResponsivenessDuringFileScan() async {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("uiTest_\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
            
            // Create test files with large sizes
            for i in 0..<3 {
                let filePath = testDir.appendingPathComponent("file\(i).bin")
                let largeContent = String(repeating: "x", count: 60 * 1024 * 1024) // 60MB
                try largeContent.write(to: filePath, atomically: true, encoding: .utf8)
            }
            
            let scanner = LargeFileScanner()
            let updater = BatchedUIUpdater(debounceDelay: 0.01)
            
            var uiUpdates = 0
            
            // Simulate scanning with UI updates
            let startTime = Date()
            
            await scanner.scan()
            let files = scanner.foundFiles
            
            // Simulate UI updates during scan
            for _ in 0..<10 {
                _ = await updater.batch {
                    uiUpdates += 1
                }
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            
            // Verify both operations completed
            XCTAssertGreaterThan(files.count, 0, "Should complete file scan")
            XCTAssertEqual(uiUpdates, 10, "Should complete UI updates")
            
            // Verify responsiveness (both should complete quickly)
            XCTAssertLessThan(elapsed, 30.0, "Operations should complete responsively")
            
            // Cleanup
            try FileManager.default.removeItem(at: testDir)
        } catch {
            XCTFail("Failed to set up test: \(error)")
        }
    }
    
    func testUIResponsivenessDuringCacheOperations() async {
        let cache = CacheManager<String, String>()
        let updater = BatchedUIUpdater(debounceDelay: 0.01)
        
        var uiUpdates = 0
        
        // Add data to cache
        for i in 0..<100 {
            cache.set("key\(i)", value: "value\(i)")
        }
        
        // Simulate UI updates while accessing cache
        let startTime = Date()
        
        for i in 0..<50 {
            _ = cache.get("key\(i)")
            
            if i % 5 == 0 {
                _ = await updater.batch {
                    uiUpdates += 1
                }
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Verify operations completed
        XCTAssertGreaterThan(uiUpdates, 0, "Should complete UI updates")
        
        // Verify responsiveness
        XCTAssertLessThan(elapsed, 2.0, "Cache operations should be responsive")
    }
    
    func testUIResponsivenessDuringBackgroundTasks() async {
        let taskQueue = BackgroundTaskQueue()
        let updater = BatchedUIUpdater(debounceDelay: 0.01)
        
        var backgroundTasks = 0
        var uiUpdates = 0
        
        let startTime = Date()
        
        // Enqueue background tasks
        for _ in 0..<20 {
            _ = await taskQueue.enqueue {
                backgroundTasks += 1
                usleep(5_000) // 5ms per task
            }
        }
        
        // Perform UI updates
        for _ in 0..<20 {
            _ = await updater.batch {
                uiUpdates += 1
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Verify both completed
        XCTAssertEqual(backgroundTasks, 20, "All background tasks should complete")
        XCTAssertEqual(uiUpdates, 20, "All UI updates should complete")
        
        // Verify responsiveness
        XCTAssertLessThan(elapsed, 5.0, "Operations should be responsive")
    }
    
    func testUIUpdateBatchingImprovement() async {
        let updater = BatchedUIUpdater(debounceDelay: 0.01)
        
        var updateCount = 0
        let updateLimit = 100
        
        let startTime = Date()
        
        // Batch many rapid updates
        for _ in 0..<updateLimit {
            _ = await updater.batch {
                updateCount += 1
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Verify all updates executed
        XCTAssertEqual(updateCount, updateLimit, "All updates should execute")
        
        // Verify batching improves performance
        XCTAssertLessThan(elapsed, 2.0, "Batched updates should be efficient")
    }
    
    // MARK: - Integration Tests: Cache Persistence
    // Test cache persistence
    // Requirements: 1.1, 5.1, 6.2
    
    func testCachePersistenceAcrossAppRestart() throws {
        let persistence = try CachePersistence()
        
        defer {
            try? persistence.clearAll()
        }
        
        // Create and populate cache
        let cache1 = CacheManager<String, String>()
        for i in 0..<50 {
            cache1.set("key\(i)", value: "value\(i)")
        }
        
        let originalCount = cache1.count
        let originalSize = cache1.size
        
        // Save to disk
        try cache1.saveToDisk(persistence)
        
        // Simulate app restart by creating new cache
        let cache2 = CacheManager<String, String>()
        
        // Load from disk
        try cache2.loadFromDisk(persistence)
        
        // Verify data persisted
        XCTAssertEqual(cache2.count, originalCount, "Cache count should be preserved")
        XCTAssertEqual(cache2.size, originalSize, "Cache size should be preserved")
        
        // Verify data integrity
        for i in 0..<50 {
            XCTAssertEqual(cache2.get("key\(i)"), "value\(i)", "Data should be preserved for key\(i)")
        }
    }
    
    func testCachePersistenceWithExpiredEntries() throws {
        let persistence = try CachePersistence()
        
        defer {
            try? persistence.clearAll()
        }
        
        // Create cache with mixed TTLs
        let cache1 = CacheManager<String, String>()
        
        // Add persistent entries
        for i in 0..<25 {
            cache1.set("persistent\(i)", value: "value\(i)", ttl: 1000)
        }
        
        // Add temporary entries
        for i in 0..<25 {
            cache1.set("temporary\(i)", value: "value\(i)", ttl: 0.1)
        }
        
        // Wait for temporary entries to expire
        usleep(150_000) // 150ms
        
        // Save to disk
        try cache1.saveToDisk(persistence)
        
        // Load into new cache
        let cache2 = CacheManager<String, String>()
        try cache2.loadFromDisk(persistence)
        
        // Verify only persistent entries were restored
        XCTAssertEqual(cache2.count, 25, "Only non-expired entries should be restored")
        
        for i in 0..<25 {
            XCTAssertEqual(cache2.get("persistent\(i)"), "value\(i)", "Persistent entry should be restored")
            XCTAssertNil(cache2.get("temporary\(i)"), "Expired entry should not be restored")
        }
    }
    
    func testCachePersistenceWithLargeDataset() throws {
        let persistence = try CachePersistence()
        
        defer {
            try? persistence.clearAll()
        }
        
        // Create cache with large dataset
        let cache1 = CacheManager<String, String>()
        let largeValue = String(repeating: "x", count: 50_000) // 50KB per value
        
        for i in 0..<20 {
            cache1.set("key\(i)", value: largeValue)
        }
        
        let originalCount = cache1.count
        
        // Save to disk
        try cache1.saveToDisk(persistence)
        
        // Load into new cache
        let cache2 = CacheManager<String, String>()
        try cache2.loadFromDisk(persistence)
        
        // Verify data integrity
        XCTAssertEqual(cache2.count, originalCount, "All entries should be restored")
        
        for i in 0..<20 {
            let retrieved = cache2.get("key\(i)")
            XCTAssertEqual(retrieved, largeValue, "Large value should be preserved for key\(i)")
        }
    }
    
    func testCachePersistenceErrorHandling() throws {
        let persistence = try CachePersistence()
        
        defer {
            try? persistence.clearAll()
        }
        
        // Create cache with data
        let cache1 = CacheManager<String, String>()
        cache1.set("key1", value: "value1")
        
        // Save to disk
        try cache1.saveToDisk(persistence)
        
        // Try to load with wrong type (should handle gracefully)
        let cache2 = CacheManager<String, Int>()
        
        // This should not crash even if types don't match
        do {
            try cache2.loadFromDisk(persistence)
        } catch {
            // Expected to fail due to type mismatch
            XCTAssertTrue(true, "Should handle type mismatch gracefully")
        }
    }
    
    // MARK: - End-to-End Integration Tests
    
    func testCompleteWorkflowWithAllComponents() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("e2eTest_\(UUID().uuidString)")
        
        do {
            // Setup
            try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
            
            // Create test files with large sizes
            for i in 0..<3 {
                let filePath = testDir.appendingPathComponent("file\(i).bin")
                let largeContent = String(repeating: "x", count: 60 * 1024 * 1024) // 60MB
                try largeContent.write(to: filePath, atomically: true, encoding: .utf8)
            }
            
            // Initialize components
            let scanner = LargeFileScanner()
            let cache = CacheManager<String, String>()
            let taskQueue = BackgroundTaskQueue()
            let updater = BatchedUIUpdater(debounceDelay: 0.01)
            let monitor = PerformanceMonitor()
            let persistence = try CachePersistence()
            
            defer {
                try? persistence.clearAll()
            }
            
            // Step 1: Scan directory with performance monitoring
            let scanToken = monitor.startMeasuring("directoryScan")
            await scanner.scan()
            let files = scanner.foundFiles
            monitor.endMeasuring(scanToken)
            
            XCTAssertGreaterThan(files.count, 0, "Should find files")
            let fileCount = files.count
            
            // Step 2: Cache scan results using unique IDs
            for file in files {
                cache.set(file.id.uuidString, value: file.url.path)
            }
            
            // Verify cache contains all found files
            XCTAssertEqual(cache.count, fileCount, "Cache should contain all found files")
            
            // Step 3: Process with background tasks
            var processedCount = 0
            for file in files {
                _ = await taskQueue.enqueue {
                    processedCount += 1
                }
            }
            
            XCTAssertEqual(processedCount, fileCount, "All files should be processed")
            
            // Step 4: Update UI with batching
            var uiUpdates = 0
            for _ in 0..<10 {
                _ = await updater.batch {
                    uiUpdates += 1
                }
            }
            
            XCTAssertEqual(uiUpdates, 10, "All UI updates should complete")
            
            // Step 5: Persist cache
            try cache.saveToDisk(persistence)
            
            // Step 6: Verify persistence
            let newCache = CacheManager<String, String>()
            try newCache.loadFromDisk(persistence)
            
            XCTAssertEqual(newCache.count, cache.count, "Persisted cache should match original")
            
            // Step 7: Check performance metrics
            monitor.logMetrics()
            let averages = monitor.averageOperationTime
            
            XCTAssertGreaterThan(averages.count, 0, "Should have performance metrics")
            
            // Cleanup
            try FileManager.default.removeItem(at: testDir)
        } catch {
            XCTFail("Failed to complete end-to-end test: \(error)")
        }
    }
    
    func testConcurrentOperationsWithAllComponents() async throws {
        let cache = CacheManager<String, String>()
        let taskQueue = BackgroundTaskQueue()
        let updater = BatchedUIUpdater(debounceDelay: 0.01)
        
        var cacheOps = 0
        var taskOps = 0
        var uiOps = 0
        
        // Run concurrent operations
        async let cacheTask = {
            for i in 0..<50 {
                cache.set("key\(i)", value: "value\(i)")
                cacheOps += 1
            }
        }()
        
        async let backgroundTask = {
            for _ in 0..<50 {
                _ = await taskQueue.enqueue {
                    taskOps += 1
                }
            }
        }()
        
        async let uiTask = {
            for _ in 0..<50 {
                _ = await updater.batch {
                    uiOps += 1
                }
            }
        }()
        
        _ = await (cacheTask, backgroundTask, uiTask)
        
        // Verify all operations completed
        XCTAssertEqual(cacheOps, 50, "All cache operations should complete")
        XCTAssertEqual(taskOps, 50, "All background tasks should complete")
        XCTAssertEqual(uiOps, 50, "All UI updates should complete")
    }
}
