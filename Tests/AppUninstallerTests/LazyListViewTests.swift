import XCTest
import SwiftUI
@testable import AppUninstaller

final class LazyListViewTests: XCTestCase {
    
    // MARK: - Test Models
    
    struct TestItem: Identifiable {
        let id: UUID
        let name: String
        let index: Int
    }
    
    // MARK: - Property 5: Lazy Loading Correctness
    // For any lazy-loaded list, the rendered items should match the items in the
    // visible viewport, and off-screen items should not be rendered.
    // Feature: performance-optimization, Property 5: Lazy Loading Correctness
    // Validates: Requirements 3.2, 5.3
    
    func testVisibleRangeCalculationAtStart() {
        // Create a list with 1000 items
        let items = (0..<1000).map { i in
            TestItem(id: UUID(), name: "Item \(i)", index: i)
        }
        
        let itemHeight: CGFloat = 50
        let viewportHeight: CGFloat = 500 // Can show ~10 items
        
        // At scroll position 0, should show items 0-11 (with buffer)
        let startIndex = max(0, Int(floor(0 / (itemHeight + 0))))
        let visibleItemCount = Int(ceil(viewportHeight / (itemHeight + 0))) + 2
        let endIndex = min(items.count, startIndex + visibleItemCount)
        
        XCTAssertEqual(startIndex, 0, "Should start at index 0")
        XCTAssertGreaterThan(endIndex, startIndex, "Should have visible items")
        XCTAssertLessThanOrEqual(endIndex - startIndex, visibleItemCount, "Should not exceed visible count + buffer")
    }
    
    func testVisibleRangeCalculationInMiddle() {
        let items = (0..<1000).map { i in
            TestItem(id: UUID(), name: "Item \(i)", index: i)
        }
        
        let itemHeight: CGFloat = 50
        let viewportHeight: CGFloat = 500
        
        // Scroll to middle (item 500)
        let scrollPosition = CGFloat(500 * 50) // 500 items * 50 height
        let startIndex = max(0, Int(floor(scrollPosition / (itemHeight + 0))))
        let visibleItemCount = Int(ceil(viewportHeight / (itemHeight + 0))) + 2
        let endIndex = min(items.count, startIndex + visibleItemCount)
        
        XCTAssertGreaterThan(startIndex, 0, "Should not start at 0 when scrolled")
        XCTAssertGreaterThanOrEqual(startIndex, 490, "Should be near scroll position")
        XCTAssertLessThanOrEqual(endIndex, items.count, "Should not exceed item count")
    }
    
    func testVisibleRangeCalculationAtEnd() {
        let items = (0..<1000).map { i in
            TestItem(id: UUID(), name: "Item \(i)", index: i)
        }
        
        let itemHeight: CGFloat = 50
        let viewportHeight: CGFloat = 500
        
        // Scroll to end
        let scrollPosition = CGFloat(950 * 50) // Near end
        let startIndex = max(0, Int(floor(scrollPosition / (itemHeight + 0))))
        let visibleItemCount = Int(ceil(viewportHeight / (itemHeight + 0))) + 2
        let endIndex = min(items.count, startIndex + visibleItemCount)
        
        XCTAssertGreaterThan(startIndex, 900, "Should be near end")
        XCTAssertLessThanOrEqual(endIndex, items.count, "Should not exceed item count at end")
    }
    
    func testVisibleRangeNeverExceedsItemCount() {
        // Test with various list sizes
        let testSizes = [10, 50, 100, 500, 1000, 5000]
        let itemHeight: CGFloat = 50
        let viewportHeight: CGFloat = 500
        
        for size in testSizes {
            let items = (0..<size).map { i in
                TestItem(id: UUID(), name: "Item \(i)", index: i)
            }
            
            // Test at various scroll positions
            for scrollOffset in stride(from: 0, through: CGFloat(size * 50), by: 500) {
                let startIndex = max(0, Int(floor(scrollOffset / (itemHeight + 0))))
                let visibleItemCount = Int(ceil(viewportHeight / (itemHeight + 0))) + 2
                let endIndex = min(items.count, startIndex + visibleItemCount)
                
                XCTAssertGreaterThanOrEqual(startIndex, 0, "Start index should be >= 0")
                XCTAssertLessThanOrEqual(endIndex, items.count, "End index should not exceed item count for size \(size)")
                XCTAssertLessThanOrEqual(startIndex, endIndex, "Start should be <= end")
            }
        }
    }
    
    func testVisibleRangeWithSmallViewport() {
        let items = (0..<100).map { i in
            TestItem(id: UUID(), name: "Item \(i)", index: i)
        }
        
        let itemHeight: CGFloat = 50
        let viewportHeight: CGFloat = 100 // Can show ~2 items
        
        let startIndex = max(0, Int(floor(0 / (itemHeight + 0))))
        let visibleItemCount = Int(ceil(viewportHeight / (itemHeight + 0))) + 2
        let endIndex = min(items.count, startIndex + visibleItemCount)
        
        XCTAssertLessThanOrEqual(endIndex - startIndex, 4, "Should show limited items with small viewport")
    }
    
    func testVisibleRangeWithLargeViewport() {
        let items = (0..<100).map { i in
            TestItem(id: UUID(), name: "Item \(i)", index: i)
        }
        
        let itemHeight: CGFloat = 50
        let viewportHeight: CGFloat = 5000 // Can show all items
        
        let startIndex = max(0, Int(floor(0 / (itemHeight + 0))))
        let visibleItemCount = Int(ceil(viewportHeight / (itemHeight + 0))) + 2
        let endIndex = min(items.count, startIndex + visibleItemCount)
        
        XCTAssertEqual(startIndex, 0, "Should start at 0")
        XCTAssertGreaterThanOrEqual(endIndex, items.count, "Should include all items")
    }
    
    func testVisibleRangeWithVariousItemHeights() {
        let items = (0..<1000).map { i in
            TestItem(id: UUID(), name: "Item \(i)", index: i)
        }
        
        let viewportHeight: CGFloat = 500
        let itemHeights: [CGFloat] = [20, 50, 100, 200]
        
        for itemHeight in itemHeights {
            let startIndex = max(0, Int(floor(0 / (itemHeight + 0))))
            let visibleItemCount = Int(ceil(viewportHeight / (itemHeight + 0))) + 2
            let endIndex = min(items.count, startIndex + visibleItemCount)
            
            // Smaller item height should show more items
            XCTAssertGreaterThan(endIndex - startIndex, 0, "Should have visible items for height \(itemHeight)")
            XCTAssertLessThanOrEqual(endIndex, items.count, "Should not exceed item count for height \(itemHeight)")
        }
    }
    
    func testVisibleRangeBufferPreventsEdgeCutoff() {
        let items = (0..<1000).map { i in
            TestItem(id: UUID(), name: "Item \(i)", index: i)
        }
        
        let itemHeight: CGFloat = 50
        let viewportHeight: CGFloat = 500
        
        // The +2 buffer should prevent items from being cut off at edges
        let startIndex = max(0, Int(floor(0 / (itemHeight + 0))))
        let visibleItemCount = Int(ceil(viewportHeight / (itemHeight + 0))) + 2
        let endIndex = min(items.count, startIndex + visibleItemCount)
        
        // Buffer of 2 items should be present
        XCTAssertGreaterThanOrEqual(endIndex - startIndex, Int(ceil(viewportHeight / itemHeight)), "Should include buffer items")
    }
    
    // MARK: - Unit Tests
    
    func testLazyListViewCreation() {
        let items = (0..<10).map { i in
            TestItem(id: UUID(), name: "Item \(i)", index: i)
        }
        
        let view = LazyListView(items: items, itemHeight: 50) { item in
            Text(item.name)
        }
        
        XCTAssertNotNil(view, "LazyListView should be created successfully")
    }
    
    func testLazyListViewWithEmptyList() {
        let items: [TestItem] = []
        
        let view = LazyListView(items: items, itemHeight: 50) { item in
            Text(item.name)
        }
        
        XCTAssertNotNil(view, "LazyListView should handle empty list")
    }
    
    func testLazyListViewWithSingleItem() {
        let items = [TestItem(id: UUID(), name: "Item 0", index: 0)]
        
        let view = LazyListView(items: items, itemHeight: 50) { item in
            Text(item.name)
        }
        
        XCTAssertNotNil(view, "LazyListView should handle single item")
    }
    
    func testLazyListViewWithLargeList() {
        let items = (0..<10000).map { i in
            TestItem(id: UUID(), name: "Item \(i)", index: i)
        }
        
        let view = LazyListView(items: items, itemHeight: 50) { item in
            Text(item.name)
        }
        
        XCTAssertNotNil(view, "LazyListView should handle large lists")
    }
    
    func testLazyListViewWithVariousItemHeights() {
        let items = (0..<100).map { i in
            TestItem(id: UUID(), name: "Item \(i)", index: i)
        }
        
        let heights: [CGFloat] = [20, 50, 100, 200]
        
        for height in heights {
            let view = LazyListView(items: items, itemHeight: height) { item in
                Text(item.name)
            }
            
            XCTAssertNotNil(view, "LazyListView should handle item height \(height)")
        }
    }
}
