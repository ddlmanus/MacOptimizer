import Foundation

/// Token returned by startMeasuring to track a measurement session
/// 
/// This token captures the operation name, start time, and thread information
/// at the moment measurement begins. It's used to calculate elapsed time when
/// passed to endMeasuring.
/// 
/// **Performance Requirement**: Requirement 4.1 - Track operation timing and thread information
struct MeasurementToken {
    let operationName: String
    let startTime: Date
    let startThread: String
    
    init(operationName: String) {
        self.operationName = operationName
        self.startTime = Date()
        self.startThread = (Thread.current.name?.isEmpty ?? true) ? "Unknown" : Thread.current.name ?? "Unknown"
    }
}

/// Tracks operation timing and identifies performance bottlenecks
/// 
/// This class provides a thread-safe way to measure operation performance and identify
/// bottlenecks. It automatically logs warnings for operations exceeding the threshold
/// (default 500ms) and provides statistics on operation timing.
/// 
/// **Key Features**:
/// - Thread-safe measurement tracking with NSLock
/// - Automatic warning logging for slow operations
/// - Statistics tracking (min, max, average times)
/// - Debug-only logging to avoid production overhead
/// - Thread information capture for context switching analysis
/// 
/// **Performance Requirements**: 
/// - Requirement 4.1: Log execution time and thread information
/// - Requirement 4.2: Log warning when operation exceeds 500ms
/// - Requirement 4.3: Display metrics in debug builds
/// 
/// **Usage Example**:
/// ```swift
/// let monitor = PerformanceMonitor()
/// let token = monitor.startMeasuring("scanApplications")
/// defer { monitor.endMeasuring(token) }
/// 
/// // Perform work...
/// 
/// monitor.logMetrics() // Display all metrics
/// ```
class PerformanceMonitor {
    private let lock = NSLock()
    private var measurements: [String: [TimeInterval]] = [:]
    private var warningThreshold: TimeInterval = 0.5 // 500ms
    
    #if DEBUG
    private let debugLogging = true
    #else
    private let debugLogging = false
    #endif
    
    /// Debug Logging Strategy
    /// 
    /// Logging is controlled by the DEBUG build flag:
    /// - DEBUG builds: Full logging enabled (warnings, metrics)
    /// - Release builds: Logging disabled (zero overhead)
    /// 
    /// This ensures:
    /// 1. Performance metrics are available during development
    /// 2. No logging overhead in production builds
    /// 3. Essential metrics only (no verbose logging)
    /// 4. Requirement 4.1: Log execution time and thread information
    /// 
    /// Logged Information:
    /// - Operation name
    /// - Execution time (milliseconds)
    /// - Thread information (Main/Background)
    /// - Warnings for operations exceeding 500ms threshold
    /// - Statistics (count, min, max, average)
    
    /// Start measuring an operation
    /// - Parameter operationName: Name of the operation to measure
    /// - Returns: A token to pass to endMeasuring
    func startMeasuring(_ operationName: String) -> MeasurementToken {
        return MeasurementToken(operationName: operationName)
    }
    
    /// End measuring an operation and record the timing
    /// - Parameter token: The token returned from startMeasuring
    func endMeasuring(_ token: MeasurementToken) {
        let duration = Date().timeIntervalSince(token.startTime)
        
        lock.lock()
        defer { lock.unlock() }
        
        if measurements[token.operationName] == nil {
            measurements[token.operationName] = []
        }
        measurements[token.operationName]?.append(duration)
        
        // Log warning if operation exceeds threshold
        if duration > warningThreshold {
            let threadInfo = (Thread.current.name?.isEmpty ?? true) ? "Unknown" : Thread.current.name ?? "Unknown"
            let isMainThread = Thread.isMainThread ? "Main" : "Background"
            logWarning(
                operation: token.operationName,
                duration: duration,
                thread: threadInfo,
                threadType: isMainThread
            )
        }
    }
    
    /// Get average operation time for a specific operation
    /// - Parameter operationName: Name of the operation
    /// - Returns: Average time in seconds, or nil if no measurements exist
    func averageTime(for operationName: String) -> TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let times = measurements[operationName], !times.isEmpty else {
            return nil
        }
        
        return times.reduce(0, +) / TimeInterval(times.count)
    }
    
    /// Get all average operation times
    var averageOperationTime: [String: TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        
        var result: [String: TimeInterval] = [:]
        for (operation, times) in measurements {
            if !times.isEmpty {
                result[operation] = times.reduce(0, +) / TimeInterval(times.count)
            }
        }
        return result
    }
    
    /// Get the count of measurements for an operation
    /// - Parameter operationName: Name of the operation
    /// - Returns: Number of measurements recorded
    func measurementCount(for operationName: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        
        return measurements[operationName]?.count ?? 0
    }
    
    /// Log all metrics to console (debug builds only)
    func logMetrics() {
        guard debugLogging else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        print("=== Performance Metrics ===")
        for (operation, times) in measurements.sorted(by: { $0.key < $1.key }) {
            guard !times.isEmpty else { continue }
            
            let average = times.reduce(0, +) / TimeInterval(times.count)
            let min = times.min() ?? 0
            let max = times.max() ?? 0
            
            print("""
            Operation: \(operation)
              Count: \(times.count)
              Average: \(String(format: "%.3f", average * 1000))ms
              Min: \(String(format: "%.3f", min * 1000))ms
              Max: \(String(format: "%.3f", max * 1000))ms
            """)
        }
        print("==========================")
    }
    
    /// Clear all measurements
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        measurements.removeAll()
    }
    
    /// Set the warning threshold for operation duration
    /// - Parameter threshold: Duration in seconds (default: 0.5)
    func setWarningThreshold(_ threshold: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        
        warningThreshold = threshold
    }
    
    // MARK: - Private Helpers
    
    private func logWarning(operation: String, duration: TimeInterval, thread: String, threadType: String) {
        guard debugLogging else { return }
        
        let durationMs = String(format: "%.1f", duration * 1000)
        let thresholdMs = String(format: "%.1f", warningThreshold * 1000)
        
        print("""
        ⚠️ Performance Warning:
           Operation: \(operation)
           Duration: \(durationMs)ms (threshold: \(thresholdMs)ms)
           Thread: \(threadType) (\(thread))
        """)
    }
}
