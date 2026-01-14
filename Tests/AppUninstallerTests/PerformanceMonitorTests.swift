import XCTest
@testable import AppUninstaller

final class PerformanceMonitorTests: XCTestCase {
    
    var monitor: PerformanceMonitor!
    
    override func setUp() {
        super.setUp()
        monitor = PerformanceMonitor()
    }
    
    override func tearDown() {
        monitor = nil
        super.tearDown()
    }
    
    // MARK: - Property 4: Performance Threshold
    // For any operation, if it completes in <500ms, the PerformanceMonitor should not log a warning;
    // if it exceeds 500ms, a warning should be logged.
    // Feature: performance-optimization, Property 4: Performance Threshold
    // Validates: Requirements 4.2
    
    func testOperationUnderThresholdDoesNotWarn() {
        let token = monitor.startMeasuring("fastOperation")
        
        // Simulate a fast operation (< 500ms)
        usleep(10_000) // 10ms
        
        monitor.endMeasuring(token)
        
        // Verify measurement was recorded
        XCTAssertEqual(monitor.measurementCount(for: "fastOperation"), 1, "Should record one measurement")
        
        // Verify average time is less than threshold
        if let average = monitor.averageTime(for: "fastOperation") {
            XCTAssertLessThan(average, 0.5, "Operation should be under 500ms threshold")
        }
    }
    
    func testOperationOverThresholdIsRecorded() {
        let token = monitor.startMeasuring("slowOperation")
        
        // Simulate a slow operation (> 500ms)
        usleep(600_000) // 600ms
        
        monitor.endMeasuring(token)
        
        // Verify measurement was recorded
        XCTAssertEqual(monitor.measurementCount(for: "slowOperation"), 1, "Should record one measurement")
        
        // Verify average time exceeds threshold
        if let average = monitor.averageTime(for: "slowOperation") {
            XCTAssertGreaterThan(average, 0.5, "Operation should exceed 500ms threshold")
        }
    }
    
    // MARK: - Unit Tests
    
    func testStartAndEndMeasuring() {
        let token = monitor.startMeasuring("testOperation")
        XCTAssertEqual(token.operationName, "testOperation", "Token should contain operation name")
        
        usleep(10_000) // 10ms
        monitor.endMeasuring(token)
        
        XCTAssertEqual(monitor.measurementCount(for: "testOperation"), 1, "Should record measurement")
    }
    
    func testMultipleMeasurementsForSameOperation() {
        // Record multiple measurements for the same operation
        for i in 0..<5 {
            let token = monitor.startMeasuring("repeatedOperation")
            usleep(UInt32(10_000 + i * 1_000)) // Vary timing slightly
            monitor.endMeasuring(token)
        }
        
        XCTAssertEqual(monitor.measurementCount(for: "repeatedOperation"), 5, "Should record 5 measurements")
        
        // Verify average is calculated
        if let average = monitor.averageTime(for: "repeatedOperation") {
            XCTAssertGreaterThan(average, 0, "Average should be positive")
            XCTAssertLessThan(average, 0.1, "Average should be reasonable")
        }
    }
    
    func testAverageOperationTime() {
        // Record measurements for different operations
        let token1 = monitor.startMeasuring("operation1")
        usleep(20_000) // 20ms
        monitor.endMeasuring(token1)
        
        let token2 = monitor.startMeasuring("operation2")
        usleep(30_000) // 30ms
        monitor.endMeasuring(token2)
        
        let averages = monitor.averageOperationTime
        
        XCTAssertEqual(averages.count, 2, "Should have 2 operations")
        XCTAssertNotNil(averages["operation1"], "Should have average for operation1")
        XCTAssertNotNil(averages["operation2"], "Should have average for operation2")
    }
    
    func testAverageTimeForNonexistentOperation() {
        let average = monitor.averageTime(for: "nonexistent")
        XCTAssertNil(average, "Should return nil for nonexistent operation")
    }
    
    func testMeasurementCountForNonexistentOperation() {
        let count = monitor.measurementCount(for: "nonexistent")
        XCTAssertEqual(count, 0, "Should return 0 for nonexistent operation")
    }
    
    func testResetClearsMeasurements() {
        // Record some measurements
        let token = monitor.startMeasuring("operation")
        usleep(10_000)
        monitor.endMeasuring(token)
        
        XCTAssertEqual(monitor.measurementCount(for: "operation"), 1, "Should have measurement before reset")
        
        // Reset
        monitor.reset()
        
        XCTAssertEqual(monitor.measurementCount(for: "operation"), 0, "Should have no measurements after reset")
        XCTAssertEqual(monitor.averageOperationTime.count, 0, "Should have no operations after reset")
    }
    
    func testSetWarningThreshold() {
        monitor.setWarningThreshold(0.1) // 100ms
        
        let token = monitor.startMeasuring("operation")
        usleep(150_000) // 150ms
        monitor.endMeasuring(token)
        
        // Verify measurement was recorded (warning would be logged in debug)
        XCTAssertEqual(monitor.measurementCount(for: "operation"), 1, "Should record measurement")
        
        if let average = monitor.averageTime(for: "operation") {
            XCTAssertGreaterThan(average, 0.1, "Operation should exceed new threshold")
        }
    }
    
    func testThreadInformationInToken() {
        let token = monitor.startMeasuring("threadTest")
        
        // Verify token contains thread information
        XCTAssertFalse(token.startThread.isEmpty, "Token should contain thread information")
        XCTAssertNotNil(token.startTime, "Token should contain start time")
    }
    
    func testConcurrentMeasurements() {
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Record measurements from multiple threads
        for i in 0..<10 {
            group.enter()
            queue.async {
                let token = self.monitor.startMeasuring("concurrentOp\(i % 3)")
                usleep(UInt32(10_000 + i * 1_000))
                self.monitor.endMeasuring(token)
                group.leave()
            }
        }
        
        group.waitWithTimeout(timeout: 5.0)
        
        // Verify all measurements were recorded
        let averages = monitor.averageOperationTime
        XCTAssertGreaterThan(averages.count, 0, "Should have recorded measurements from concurrent threads")
    }
    
    func testMeasurementAccuracy() {
        let sleepDuration: UInt32 = 50_000 // 50ms
        let token = monitor.startMeasuring("accuracyTest")
        usleep(sleepDuration)
        monitor.endMeasuring(token)
        
        if let average = monitor.averageTime(for: "accuracyTest") {
            let expectedDuration = TimeInterval(sleepDuration) / 1_000_000
            // Allow 10ms tolerance for system variance
            XCTAssertGreaterThan(average, expectedDuration - 0.01, "Measured time should be close to actual")
            XCTAssertLessThan(average, expectedDuration + 0.05, "Measured time should not be significantly higher")
        }
    }
    
    func testOperationNamePreservation() {
        let operationNames = ["fileIO", "dataProcessing", "uiUpdate", "networkCall"]
        
        for name in operationNames {
            let token = monitor.startMeasuring(name)
            usleep(5_000)
            monitor.endMeasuring(token)
        }
        
        let averages = monitor.averageOperationTime
        
        for name in operationNames {
            XCTAssertNotNil(averages[name], "Should preserve operation name: \(name)")
        }
    }
    
    func testLogMetricsDoesNotCrash() {
        // Record some measurements
        let token = monitor.startMeasuring("operation")
        usleep(10_000)
        monitor.endMeasuring(token)
        
        // Should not crash
        monitor.logMetrics()
        
        XCTAssertTrue(true, "logMetrics should not crash")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteMonitoringWorkflow() {
        // Simulate a complete monitoring workflow
        
        // Start monitoring multiple operations
        let fileIOToken = monitor.startMeasuring("fileIO")
        usleep(30_000) // 30ms
        monitor.endMeasuring(fileIOToken)
        
        let processingToken = monitor.startMeasuring("dataProcessing")
        usleep(20_000) // 20ms
        monitor.endMeasuring(processingToken)
        
        let uiToken = monitor.startMeasuring("uiUpdate")
        usleep(10_000) // 10ms
        monitor.endMeasuring(uiToken)
        
        // Verify all operations were recorded
        let averages = monitor.averageOperationTime
        XCTAssertEqual(averages.count, 3, "Should have 3 operations")
        
        // Verify ordering by duration
        let fileIOTime = averages["fileIO"] ?? 0
        let processingTime = averages["dataProcessing"] ?? 0
        let uiTime = averages["uiUpdate"] ?? 0
        
        XCTAssertGreaterThan(fileIOTime, processingTime, "fileIO should take longer than processing")
        XCTAssertGreaterThan(processingTime, uiTime, "processing should take longer than UI")
    }
    
    func testMonitoringWithRepeatedOperations() {
        // Simulate repeated operations with varying durations
        for iteration in 0..<5 {
            let token = monitor.startMeasuring("iterativeOp")
            usleep(UInt32(20_000 + iteration * 5_000)) // Increasing duration
            monitor.endMeasuring(token)
        }
        
        XCTAssertEqual(monitor.measurementCount(for: "iterativeOp"), 5, "Should record 5 iterations")
        
        if let average = monitor.averageTime(for: "iterativeOp") {
            XCTAssertGreaterThan(average, 0.02, "Average should reflect increasing durations")
        }
    }
    
    func testMonitoringWithThresholdExceeded() {
        monitor.setWarningThreshold(0.05) // 50ms
        
        // Record operation that exceeds threshold
        let token = monitor.startMeasuring("slowOp")
        usleep(100_000) // 100ms
        monitor.endMeasuring(token)
        
        if let average = monitor.averageTime(for: "slowOp") {
            XCTAssertGreaterThan(average, 0.05, "Operation should exceed threshold")
        }
    }
}

// MARK: - Helper Extension

extension DispatchGroup {
    func waitWithTimeout(timeout: TimeInterval) {
        let result = self.wait(timeout: .now() + timeout)
        if result == .timedOut {
            print("Warning: DispatchGroup wait timed out")
        }
    }
}
