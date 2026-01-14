import Foundation

/// Actor that manages sequential execution of background tasks
/// 
/// This actor ensures that tasks execute one at a time to prevent resource contention.
/// It's particularly useful for file I/O operations, network requests, and other
/// expensive computations that should not run concurrently.
/// 
/// **Key Features**:
/// - Sequential task execution prevents resource contention
/// - Actor-based for thread safety (no manual locking needed)
/// - Automatic queue management
/// - Support for cancellation
/// 
/// **Performance Requirements**:
/// - Requirement 1.4: Queue scans sequentially rather than running in parallel
/// 
/// **Why Sequential Execution?**
/// Running multiple file I/O operations concurrently can cause:
/// - Excessive disk head movement (thrashing)
/// - Memory pressure from multiple concurrent operations
/// - Unpredictable performance due to resource contention
/// 
/// Sequential execution ensures predictable, efficient resource usage.
/// 
/// **Usage Example**:
/// ```swift
/// let queue = BackgroundTaskQueue()
/// 
/// // Enqueue a task
/// let result = await queue.enqueue {
///     return await expensiveFileOperation()
/// }
/// 
/// // Cancel all pending tasks
/// await queue.cancelAll()
/// ```
actor BackgroundTaskQueue {
    private var taskQueue: [() async -> Void] = []
    private var isProcessing = false
    
    /// Enqueue a task for sequential execution
    /// - Parameter operation: An async closure to execute
    /// - Returns: The result of the operation
    func enqueue<T>(_ operation: @escaping () async -> T) async -> T {
        var result: T?
        
        // Create a wrapper that captures the result
        let wrappedTask: () async -> Void = {
            result = await operation()
        }
        
        // Add to queue
        taskQueue.append(wrappedTask)
        
        // Process queue if not already processing
        if !isProcessing {
            await processQueue()
        }
        
        return result!
    }
    
    /// Cancel all pending tasks
    func cancelAll() {
        taskQueue.removeAll()
    }
    
    /// Check if queue is currently processing tasks
    var isCurrentlyProcessing: Bool {
        return isProcessing
    }
    
    // MARK: - Private Helpers
    
    private func processQueue() async {
        isProcessing = true
        defer { isProcessing = false }
        
        while !taskQueue.isEmpty {
            let task = taskQueue.removeFirst()
            await task()
        }
    }
}
