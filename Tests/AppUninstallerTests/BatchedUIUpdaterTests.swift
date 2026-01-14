import XCTest
@testable import AppUninstaller

final class BatchedUIUpdaterTests: XCTestCase {
    
    var updater: BatchedUIUpdater!
    
    override func setUp() {
        super.setUp()
        updater = BatchedUIUpdater(debounceDelay: 0.01) // 10ms for faster tests
    }
    
    override func tearDown() {
        updater = nil
        super.tearDown()
    }
    
    // MARK: - Property 2: Batch Atomicity
    // For any batch of UI updates, all updates in the batch should be applied
    // atomically on the main thread without intermediate renders.
    // Feature: performance-optimization, Property 2: Batch Atomicity
    // Validates: Requirements 2.1, 5.2
    
    func testBatchUpdatesExecuteAtomically() async {
        var updateSequence: [String] = []
        
        // Execute a batch of updates
        _ = await updater.batch {
            updateSequence.append("update1")
            updateSequence.append("update2")
            updateSequence.append("update3")
        }
        
        // All updates should be applied together
        XCTAssertEqual(updateSequence, ["update1", "update2", "update3"], "All batch updates should execute atomically")
    }
    
    func testMultipleBatchesExecuteSequentially() async {
        var executionLog: [String] = []
        
        // Execute multiple batches
        _ = await updater.batch {
            executionLog.append("batch1_start")
            executionLog.append("batch1_end")
        }
        
        _ = await updater.batch {
            executionLog.append("batch2_start")
            executionLog.append("batch2_end")
        }
        
        _ = await updater.batch {
            executionLog.append("batch3_start")
            executionLog.append("batch3_end")
        }
        
        XCTAssertEqual(
            executionLog,
            ["batch1_start", "batch1_end", "batch2_start", "batch2_end", "batch3_start", "batch3_end"],
            "Batches should execute sequentially"
        )
    }
    
    func testBatchUpdatesReturnValue() async {
        let result = await updater.batch {
            return 42
        }
        
        XCTAssertEqual(result, 42, "Batch should return correct value")
    }
    
    func testBatchUpdatesWithComplexState() async {
        var state = (count: 0, name: "", isActive: false)
        
        _ = await updater.batch {
            state.count = 10
            state.name = "test"
            state.isActive = true
        }
        
        XCTAssertEqual(state.count, 10, "Count should be updated")
        XCTAssertEqual(state.name, "test", "Name should be updated")
        XCTAssertTrue(state.isActive, "Active flag should be updated")
    }
    
    // MARK: - Unit Tests
    
    func testSimpleBatchUpdate() async {
        var executed = false
        
        _ = await updater.batch {
            executed = true
        }
        
        XCTAssertTrue(executed, "Batch update should execute")
    }
    
    func testDebounceDelaysExecution() async {
        var executed = false
        let startTime = Date()
        
        await updater.debounce("test", delay: 0.05) {
            executed = true
        }
        
        // Should not execute immediately
        XCTAssertFalse(executed, "Debounce should delay execution")
        
        // Wait for debounce to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertTrue(executed, "Debounce should execute after delay")
        XCTAssertGreaterThanOrEqual(elapsed, 0.05, "Execution should be delayed by at least debounce delay")
    }
    
    func testDebounceCoalesceRapidUpdates() async {
        var executionCount = 0
        
        // Send multiple rapid updates with same key
        for _ in 0..<5 {
            await updater.debounce("counter") {
                executionCount += 1
            }
        }
        
        // Wait for debounce to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Should only execute once despite 5 calls
        XCTAssertEqual(executionCount, 1, "Rapid updates should be coalesced into single execution")
    }
    
    func testDebounceWithDifferentKeys() async {
        var results: [String] = []
        
        // Send updates with different keys
        await updater.debounce("key1") {
            results.append("key1")
        }
        
        await updater.debounce("key2") {
            results.append("key2")
        }
        
        await updater.debounce("key3") {
            results.append("key3")
        }
        
        // Wait for debounce to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // All should execute since they have different keys
        XCTAssertEqual(results.count, 3, "Different keys should execute independently")
        XCTAssertTrue(results.contains("key1"), "key1 should execute")
        XCTAssertTrue(results.contains("key2"), "key2 should execute")
        XCTAssertTrue(results.contains("key3"), "key3 should execute")
    }
    
    func testExecuteImmediatelyBypassesDebounce() async {
        var executed = false
        
        // Schedule a debounced update
        await updater.debounce("test", delay: 1.0) {
            executed = true
        }
        
        // Should not execute yet
        XCTAssertFalse(executed, "Debounce should not execute immediately")
        
        // Execute immediately
        await updater.executeImmediately("test") {
            executed = true
        }
        
        // Should execute immediately
        XCTAssertTrue(executed, "ExecuteImmediately should execute right away")
    }
    
    func testCancelPendingUpdate() async {
        var executed = false
        
        // Schedule a debounced update
        await updater.debounce("test", delay: 0.1) {
            executed = true
        }
        
        // Cancel it
        await updater.cancel("test")
        
        // Wait for original debounce time
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Should not execute
        XCTAssertFalse(executed, "Cancelled update should not execute")
    }
    
    func testCancelAllPendingUpdates() async {
        var count1 = 0
        var count2 = 0
        var count3 = 0
        
        // Schedule multiple debounced updates
        await updater.debounce("key1") {
            count1 += 1
        }
        
        await updater.debounce("key2") {
            count2 += 1
        }
        
        await updater.debounce("key3") {
            count3 += 1
        }
        
        // Cancel all
        await updater.cancelAll()
        
        // Wait for debounce time
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // None should execute
        XCTAssertEqual(count1, 0, "Cancelled update 1 should not execute")
        XCTAssertEqual(count2, 0, "Cancelled update 2 should not execute")
        XCTAssertEqual(count3, 0, "Cancelled update 3 should not execute")
    }
    
    func testBatchDebounceCoalesceUpdates() async {
        var executionCount = 0
        
        // Send multiple rapid batch debounce calls with same key
        for _ in 0..<5 {
            await updater.batchDebounce("batch") {
                executionCount += 1
            }
            // Small delay between calls to ensure they're rapid but not instantaneous
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
        
        // Wait for debounce to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Should only execute once (last update replaces previous ones)
        XCTAssertEqual(executionCount, 1, "Batch debounce should coalesce rapid updates into single execution")
    }
    
    func testPendingUpdateCount() async {
        // Initially no pending updates
        var count = await updater.pendingUpdateCount
        XCTAssertEqual(count, 0, "Should start with no pending updates")
        
        // Schedule some debounced updates
        await updater.debounce("key1") { }
        count = await updater.pendingUpdateCount
        XCTAssertEqual(count, 1, "Should have 1 pending update")
        
        await updater.debounce("key2") { }
        count = await updater.pendingUpdateCount
        XCTAssertEqual(count, 2, "Should have 2 pending updates")
        
        // Cancel one
        await updater.cancel("key1")
        count = await updater.pendingUpdateCount
        XCTAssertEqual(count, 1, "Should have 1 pending update after cancel")
        
        // Cancel all
        await updater.cancelAll()
        count = await updater.pendingUpdateCount
        XCTAssertEqual(count, 0, "Should have no pending updates after cancelAll")
    }
    
    func testDebounceWithCustomDelay() async {
        var executed = false
        let startTime = Date()
        
        // Use custom delay
        await updater.debounce("test", delay: 0.02) {
            executed = true
        }
        
        // Wait for execution
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertTrue(executed, "Should execute after custom delay")
        XCTAssertGreaterThanOrEqual(elapsed, 0.02, "Should respect custom delay")
    }
    
    func testBatchWithMultipleReturnTypes() async {
        let intResult = await updater.batch { return 123 }
        let stringResult = await updater.batch { return "hello" }
        let boolResult = await updater.batch { return true }
        let arrayResult = await updater.batch { return [1, 2, 3] }
        
        XCTAssertEqual(intResult, 123, "Should return Int correctly")
        XCTAssertEqual(stringResult, "hello", "Should return String correctly")
        XCTAssertEqual(boolResult, true, "Should return Bool correctly")
        XCTAssertEqual(arrayResult, [1, 2, 3], "Should return Array correctly")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteUpdateWorkflow() async {
        var state = (count: 0, message: "")
        
        // Batch update
        _ = await updater.batch {
            state.count = 5
            state.message = "initial"
        }
        
        XCTAssertEqual(state.count, 5, "Initial batch should update count")
        XCTAssertEqual(state.message, "initial", "Initial batch should update message")
        
        // Debounced update
        await updater.debounce("update") {
            state.count += 1
            state.message = "updated"
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        XCTAssertEqual(state.count, 6, "Debounced update should increment count")
        XCTAssertEqual(state.message, "updated", "Debounced update should update message")
    }
    
    func testRapidBatchUpdates() async {
        var counter = 0
        
        // Rapid batch updates
        for _ in 0..<10 {
            _ = await updater.batch {
                counter += 1
            }
        }
        
        XCTAssertEqual(counter, 10, "All rapid batch updates should execute")
    }
    
    func testMixedBatchAndDebounceUpdates() async {
        var results: [String] = []
        
        // Mix batch and debounce
        _ = await updater.batch {
            results.append("batch1")
        }
        
        await updater.debounce("debounce1") {
            results.append("debounce1")
        }
        
        _ = await updater.batch {
            results.append("batch2")
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        XCTAssertEqual(results.count, 3, "All updates should execute")
        XCTAssertTrue(results.contains("batch1"), "batch1 should execute")
        XCTAssertTrue(results.contains("debounce1"), "debounce1 should execute")
        XCTAssertTrue(results.contains("batch2"), "batch2 should execute")
    }
    
    func testDebounceReplacesOldUpdate() async {
        var results: [String] = []
        
        // Schedule first update
        await updater.debounce("key") {
            results.append("first")
        }
        
        // Immediately schedule second update with same key
        await updater.debounce("key") {
            results.append("second")
        }
        
        // Wait for execution
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Only the second update should execute
        XCTAssertEqual(results, ["second"], "Second debounce should replace first")
    }
    
    func testStressTestWithManyUpdates() async {
        var counter = 0
        let updateCount = 100
        
        // Rapid batch updates
        for _ in 0..<updateCount {
            _ = await updater.batch {
                counter += 1
            }
        }
        
        XCTAssertEqual(counter, updateCount, "All stress test updates should execute")
    }
}
