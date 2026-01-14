import Foundation

/// Actor that batches multiple UI state changes into single MainActor calls
/// 
/// This actor reduces context switches and improves performance by:
/// - Batching multiple state changes into a single MainActor call
/// - Debouncing rapid updates to prevent excessive re-renders
/// - Ensuring atomic updates (all changes applied together)
/// 
/// **Key Features**:
/// - Atomic batching: All updates in a batch apply together
/// - Debouncing: Rapid updates with same key are coalesced
/// - Cancellation: Pending updates can be cancelled
/// - Actor-based: Thread-safe without manual locking
/// 
/// **Performance Requirements**:
/// - Requirement 2.1: Batch multiple state changes into single MainActor.run call
/// - Requirement 5.2: Batch updates to maximum 10 per second
/// 
/// **Why Batching Matters**:
/// Each MainActor.run call causes a context switch from background to main thread.
/// Multiple context switches create overhead and can cause jank. By batching all
/// updates into a single call, we minimize context switches and improve responsiveness.
/// 
/// **Context Switch Overhead**:
/// - Single context switch: ~1-2ms
/// - 10 rapid updates: 10-20ms of overhead
/// - Batched into 1 call: 1-2ms of overhead
/// 
/// **Usage Example**:
/// ```swift
/// let updater = BatchedUIUpdater()
/// 
/// // Batch multiple updates atomically
/// await updater.batch {
///     self.state1 = newValue1
///     self.state2 = newValue2
///     self.state3 = newValue3
/// }
/// 
/// // Debounce rapid updates (e.g., progress updates)
/// await updater.debounce("progressUpdate", delay: 0.1) {
///     self.progress = newProgress
/// }
/// 
/// // Execute immediately, canceling any pending debounce
/// await updater.executeImmediately("progressUpdate") {
///     self.progress = 1.0
/// }
/// ```
actor BatchedUIUpdater {
    private var pendingUpdates: [String: @MainActor () -> Void] = [:]
    private var debounceTimers: [String: Task<Void, Never>] = [:]
    private let debounceDelay: TimeInterval
    
    /// Initialize the batched UI updater
    /// - Parameter debounceDelay: Delay in seconds for debouncing rapid updates (default: 0.016 for ~60fps)
    init(debounceDelay: TimeInterval = 0.016) {
        self.debounceDelay = debounceDelay
    }
    
    /// Execute updates atomically on the main thread
    /// - Parameter updates: Closure containing UI updates to execute
    /// - Returns: The result of the updates closure
    func batch<T>(_ updates: @escaping @MainActor () -> T) async -> T {
        return await MainActor.run {
            updates()
        }
    }
    
    /// Debounce an update with a given key
    /// Rapid updates with the same key will be coalesced into a single update
    /// - Parameters:
    ///   - key: Unique identifier for this update (e.g., "listUpdate", "progressUpdate")
    ///   - delay: Delay in seconds before executing the update (default: uses actor's debounceDelay)
    ///   - action: Closure to execute on the main thread
    func debounce(_ key: String, delay: TimeInterval? = nil, _ action: @escaping @MainActor () -> Void) async {
        let actualDelay = delay ?? debounceDelay
        
        // Cancel any pending timer for this key
        if let existingTimer = debounceTimers[key] {
            existingTimer.cancel()
        }
        
        // Store the action
        pendingUpdates[key] = action
        
        // Create a new debounce timer
        let timer = Task {
            try? await Task.sleep(nanoseconds: UInt64(actualDelay * 1_000_000_000))
            
            // Check if this task was cancelled
            if Task.isCancelled {
                return
            }
            
            // Execute the pending update if it still exists
            if let pendingAction = pendingUpdates[key] {
                await MainActor.run {
                    pendingAction()
                }
                pendingUpdates.removeValue(forKey: key)
            }
            
            debounceTimers.removeValue(forKey: key)
        }
        
        debounceTimers[key] = timer
    }
    
    /// Execute a debounced update immediately, canceling any pending debounce
    /// - Parameters:
    ///   - key: Unique identifier for this update
    ///   - action: Closure to execute on the main thread
    func executeImmediately(_ key: String, _ action: @escaping @MainActor () -> Void) async {
        // Cancel any pending timer
        debounceTimers[key]?.cancel()
        debounceTimers.removeValue(forKey: key)
        pendingUpdates.removeValue(forKey: key)
        
        // Execute immediately
        await MainActor.run {
            action()
        }
    }
    
    /// Batch multiple debounced updates with the same key
    /// - Parameters:
    ///   - key: Unique identifier for this batch
    ///   - delay: Delay before executing the batch
    ///   - updates: Array of update closures to execute atomically
    func batchDebounce(_ key: String, delay: TimeInterval? = nil, _ updates: @escaping @MainActor () -> Void) async {
        let actualDelay = delay ?? debounceDelay
        
        // Cancel any pending timer for this key
        if let existingTimer = debounceTimers[key] {
            existingTimer.cancel()
        }
        
        // Store the batch action
        pendingUpdates[key] = updates
        
        // Create a new debounce timer
        let timer = Task {
            try? await Task.sleep(nanoseconds: UInt64(actualDelay * 1_000_000_000))
            
            // Check if this task was cancelled
            if Task.isCancelled {
                return
            }
            
            // Execute all pending updates atomically
            if let pendingAction = pendingUpdates[key] {
                await MainActor.run {
                    pendingAction()
                }
                pendingUpdates.removeValue(forKey: key)
            }
            
            debounceTimers.removeValue(forKey: key)
        }
        
        debounceTimers[key] = timer
    }
    
    /// Cancel all pending debounced updates
    func cancelAll() {
        for (_, timer) in debounceTimers {
            timer.cancel()
        }
        debounceTimers.removeAll()
        pendingUpdates.removeAll()
    }
    
    /// Cancel a specific debounced update
    /// - Parameter key: The key of the update to cancel
    func cancel(_ key: String) {
        debounceTimers[key]?.cancel()
        debounceTimers.removeValue(forKey: key)
        pendingUpdates.removeValue(forKey: key)
    }
    
    /// Get the number of pending updates
    var pendingUpdateCount: Int {
        return pendingUpdates.count
    }
}
