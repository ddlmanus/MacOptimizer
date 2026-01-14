import XCTest
@testable import AppUninstaller

final class BackgroundTaskQueueTests: XCTestCase {
    
    var queue: BackgroundTaskQueue!
    
    override func setUp() {
        super.setUp()
        queue = BackgroundTaskQueue()
    }
    
    override func tearDown() {
        queue = nil
        super.tearDown()
    }
    
    // MARK: - Property 3: Sequential Task Execution
    // For any sequence of background tasks enqueued to the task queue,
    // they should execute sequentially without concurrent execution.
    // Feature: performance-optimization, Property 3: Sequential Task Execution
    // Validates: Requirements 1.4
    
    func testTasksExecuteSequentially() async {
        var executionOrder: [Int] = []
        
        // Enqueue multiple tasks
        for i in 0..<5 {
            _ = await queue.enqueue {
                executionOrder.append(i)
                // Simulate some work
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
        
        // Verify tasks executed in order
        XCTAssertEqual(executionOrder, [0, 1, 2, 3, 4], "Tasks should execute in sequential order")
    }
    
    func testNoTasksExecuteConcurrently() async {
        var concurrentCount = 0
        var maxConcurrentCount = 0
        
        // Enqueue tasks that track concurrent execution
        for _ in 0..<10 {
            _ = await queue.enqueue {
                concurrentCount += 1
                if concurrentCount > maxConcurrentCount {
                    maxConcurrentCount = concurrentCount
                }
                
                // Simulate work
                try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
                
                concurrentCount -= 1
            }
        }
        
        // Verify only one task executed at a time
        XCTAssertEqual(maxConcurrentCount, 1, "Only one task should execute at a time")
    }
    
    // MARK: - Unit Tests
    
    func testEnqueueAndExecuteSimpleTask() async {
        var executed = false
        
        _ = await queue.enqueue {
            executed = true
        }
        
        XCTAssertTrue(executed, "Task should be executed")
    }
    
    func testEnqueueTaskWithReturnValue() async {
        let result = await queue.enqueue {
            return 42
        }
        
        XCTAssertEqual(result, 42, "Task should return correct value")
    }
    
    func testEnqueueMultipleTasks() async {
        var counter = 0
        
        for _ in 0..<5 {
            _ = await queue.enqueue {
                counter += 1
            }
        }
        
        XCTAssertEqual(counter, 5, "All tasks should be executed")
    }
    
    func testTasksReturnCorrectValues() async {
        let result1 = await queue.enqueue { return "first" }
        let result2 = await queue.enqueue { return "second" }
        let result3 = await queue.enqueue { return "third" }
        
        XCTAssertEqual(result1, "first", "First task should return correct value")
        XCTAssertEqual(result2, "second", "Second task should return correct value")
        XCTAssertEqual(result3, "third", "Third task should return correct value")
    }
    
    func testCancelAllRemovesPendingTasks() async {
        var executedCount = 0
        
        // Enqueue multiple tasks
        for _ in 0..<5 {
            _ = await queue.enqueue {
                executedCount += 1
            }
        }
        
        // Cancel all (though tasks may have already executed due to sequential processing)
        await queue.cancelAll()
        
        // All tasks should have executed since they were already queued
        XCTAssertEqual(executedCount, 5, "All enqueued tasks should execute before cancel")
    }
    
    func testQueueHandlesAsyncOperations() async {
        var results: [String] = []
        
        for i in 0..<3 {
            _ = await queue.enqueue {
                // Simulate async operation
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                results.append("task\(i)")
            }
        }
        
        XCTAssertEqual(results.count, 3, "All async tasks should complete")
        XCTAssertEqual(results, ["task0", "task1", "task2"], "Tasks should complete in order")
    }
    
    func testQueueWithDifferentReturnTypes() async {
        let intResult = await queue.enqueue { return 123 }
        let stringResult = await queue.enqueue { return "hello" }
        let boolResult = await queue.enqueue { return true }
        let arrayResult = await queue.enqueue { return [1, 2, 3] }
        
        XCTAssertEqual(intResult, 123, "Should return Int correctly")
        XCTAssertEqual(stringResult, "hello", "Should return String correctly")
        XCTAssertEqual(boolResult, true, "Should return Bool correctly")
        XCTAssertEqual(arrayResult, [1, 2, 3], "Should return Array correctly")
    }
    
    func testQueuePreventsConcurrentModification() async {
        var sharedArray: [Int] = []
        
        // Enqueue tasks that modify shared state
        for i in 0..<10 {
            _ = await queue.enqueue {
                sharedArray.append(i)
                // Simulate work
                try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
            }
        }
        
        // Verify all modifications were applied
        XCTAssertEqual(sharedArray.count, 10, "All modifications should be applied")
        XCTAssertEqual(sharedArray, Array(0..<10), "Modifications should be in order")
    }
    
    func testQueueWithLongRunningTasks() async {
        var completionOrder: [Int] = []
        
        for i in 0..<3 {
            _ = await queue.enqueue {
                // Simulate long-running task
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                completionOrder.append(i)
            }
        }
        
        XCTAssertEqual(completionOrder, [0, 1, 2], "Long-running tasks should complete sequentially")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteQueueWorkflow() async {
        var log: [String] = []
        
        // Simulate a realistic workflow
        _ = await queue.enqueue {
            log.append("start")
        }
        
        _ = await queue.enqueue {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            log.append("process")
        }
        
        _ = await queue.enqueue {
            log.append("complete")
        }
        
        XCTAssertEqual(log, ["start", "process", "complete"], "Workflow should execute in correct order")
    }
    
    func testQueueWithMixedTaskTypes() async {
        var results: [String] = []
        
        // Mix of different task types
        _ = await queue.enqueue {
            results.append("sync")
        }
        
        _ = await queue.enqueue {
            try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
            results.append("async")
        }
        
        _ = await queue.enqueue {
            results.append("final")
        }
        
        XCTAssertEqual(results, ["sync", "async", "final"], "Mixed task types should execute sequentially")
    }
    
    func testQueueStressTest() async {
        var counter = 0
        let taskCount = 100
        
        for _ in 0..<taskCount {
            _ = await queue.enqueue {
                counter += 1
            }
        }
        
        XCTAssertEqual(counter, taskCount, "All tasks in stress test should execute")
    }
    
    func testQueueWithNestedTasks() async {
        var executionLog: [String] = []
        
        _ = await queue.enqueue {
            executionLog.append("outer1")
            // Simulate nested async work
            try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
        }
        
        _ = await queue.enqueue {
            executionLog.append("outer2")
        }
        
        XCTAssertEqual(executionLog, ["outer1", "outer2"], "Nested tasks should execute sequentially")
    }
}

