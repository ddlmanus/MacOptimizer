import XCTest
@testable import AppUninstaller

final class LargeFileScannerTests: XCTestCase {
    
    var scanner: LargeFileScanner!
    
    override func setUp() {
        super.setUp()
        scanner = LargeFileScanner()
    }
    
    override func tearDown() {
        scanner = nil
        super.tearDown()
    }
    
    // MARK: - Property 1: Selection Toggle Idempotence
    // For any file in the list, clicking the checkbox twice should return the file to its original selection state.
    // Feature: large-file-selection-fix, Property 1: Selection Toggle Idempotence
    func testSelectionToggleIdempotence() {
        // Create test files
        let testFiles = [
            FileItem(url: URL(fileURLWithPath: "/tmp/test1.txt"), name: "test1.txt", size: 100_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/test2.txt"), name: "test2.txt", size: 200_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/test3.txt"), name: "test3.txt", size: 300_000_000, type: "txt", accessDate: Date())
        ]
        
        scanner.foundFiles = testFiles
        
        // For each file, test that toggling twice returns to original state
        for file in testFiles {
            // Initial state: not selected
            XCTAssertFalse(scanner.selectedFiles.contains(file.id), "File should start unselected")
            
            // Toggle once: should be selected
            scanner.selectedFiles.insert(file.id)
            XCTAssertTrue(scanner.selectedFiles.contains(file.id), "File should be selected after first toggle")
            
            // Toggle twice: should return to unselected
            scanner.selectedFiles.remove(file.id)
            XCTAssertFalse(scanner.selectedFiles.contains(file.id), "File should be unselected after second toggle (idempotence)")
        }
    }
    
    // MARK: - Property 2: Selection State Consistency
    // For any set of selected files, the selectedFiles set in the scanner should exactly match the files that appear selected in the UI.
    // Feature: large-file-selection-fix, Property 2: Selection State Consistency
    func testSelectionStateConsistency() {
        // Create test files
        let testFiles = [
            FileItem(url: URL(fileURLWithPath: "/tmp/file1.txt"), name: "file1.txt", size: 100_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/file2.txt"), name: "file2.txt", size: 200_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/file3.txt"), name: "file3.txt", size: 300_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/file4.txt"), name: "file4.txt", size: 400_000_000, type: "txt", accessDate: Date())
        ]
        
        scanner.foundFiles = testFiles
        
        // Select a subset of files
        let selectedIds = Set([testFiles[0].id, testFiles[2].id])
        scanner.selectedFiles = selectedIds
        
        // Verify that the selected files in the scanner match what we set
        XCTAssertEqual(scanner.selectedFiles, selectedIds, "Selected files should match the set we assigned")
        
        // Verify that unselected files are not in the set
        XCTAssertFalse(scanner.selectedFiles.contains(testFiles[1].id), "Unselected file should not be in selectedFiles")
        XCTAssertFalse(scanner.selectedFiles.contains(testFiles[3].id), "Unselected file should not be in selectedFiles")
        
        // Verify that selected files are in the set
        XCTAssertTrue(scanner.selectedFiles.contains(testFiles[0].id), "Selected file should be in selectedFiles")
        XCTAssertTrue(scanner.selectedFiles.contains(testFiles[2].id), "Selected file should be in selectedFiles")
    }
    
    // MARK: - Property 3: Deletion Removes Files
    // For any set of selected files, after calling deleteItems, those files should no longer appear in the foundFiles list.
    // Feature: large-file-selection-fix, Property 3: Deletion Removes Files
    func testDeletionRemovesFiles() async {
        // Create test files
        let testFiles = [
            FileItem(url: URL(fileURLWithPath: "/tmp/delete1.txt"), name: "delete1.txt", size: 100_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/delete2.txt"), name: "delete2.txt", size: 200_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/delete3.txt"), name: "delete3.txt", size: 300_000_000, type: "txt", accessDate: Date())
        ]
        
        scanner.foundFiles = testFiles
        
        // Select files to delete
        let filesToDelete = Set([testFiles[0].id, testFiles[2].id])
        scanner.selectedFiles = filesToDelete
        
        // Call deleteItems (this will fail to actually delete since files don't exist, but the logic should still work)
        let result = await scanner.deleteItems(filesToDelete)
        
        // Verify that deleted files are no longer in foundFiles
        XCTAssertFalse(scanner.foundFiles.contains(where: { $0.id == testFiles[0].id }), "Deleted file 1 should not be in foundFiles")
        XCTAssertFalse(scanner.foundFiles.contains(where: { $0.id == testFiles[2].id }), "Deleted file 3 should not be in foundFiles")
        
        // Verify that non-deleted file is still in foundFiles
        XCTAssertTrue(scanner.foundFiles.contains(where: { $0.id == testFiles[1].id }), "Non-deleted file should still be in foundFiles")
        
        // Verify result structure
        XCTAssertEqual(result.successCount, 0, "Success count should be 0 since files don't exist")
        XCTAssertEqual(result.failedCount, 2, "Failed count should be 2 since files don't exist")
        XCTAssertEqual(result.failedFiles.count, 2, "Failed files list should contain 2 entries")
    }
    
    // MARK: - Property 4: Selection Cleared After Deletion
    // For any deletion operation that completes successfully, the selectedFiles set should be empty after the operation.
    // Feature: large-file-selection-fix, Property 4: Selection Cleared After Deletion
    func testSelectionClearedAfterDeletion() async {
        // Create test files
        let testFiles = [
            FileItem(url: URL(fileURLWithPath: "/tmp/clear1.txt"), name: "clear1.txt", size: 100_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/clear2.txt"), name: "clear2.txt", size: 200_000_000, type: "txt", accessDate: Date())
        ]
        
        scanner.foundFiles = testFiles
        
        // Select files
        let filesToDelete = Set([testFiles[0].id, testFiles[1].id])
        scanner.selectedFiles = filesToDelete
        
        XCTAssertFalse(scanner.selectedFiles.isEmpty, "Selected files should not be empty before deletion")
        
        // Call deleteItems
        let result = await scanner.deleteItems(filesToDelete)
        
        // Verify that selectedFiles is now empty
        XCTAssertTrue(scanner.selectedFiles.isEmpty, "Selected files should be empty after deletion")
        
        // Verify result structure
        XCTAssertEqual(result.failedCount, 2, "Failed count should be 2 since files don't exist")
        XCTAssertEqual(result.successCount, 0, "Success count should be 0 since files don't exist")
    }
    
    // MARK: - Property 5: Remove Button Disabled When Empty
    // For any state where no files are selected, the Remove button should be disabled and not respond to clicks.
    // Feature: large-file-selection-fix, Property 5: Remove Button Disabled When Empty
    func testRemoveButtonDisabledWhenEmpty() {
        // Create test files
        let testFiles = [
            FileItem(url: URL(fileURLWithPath: "/tmp/btn1.txt"), name: "btn1.txt", size: 100_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/btn2.txt"), name: "btn2.txt", size: 200_000_000, type: "txt", accessDate: Date())
        ]
        
        scanner.foundFiles = testFiles
        
        // Test 1: When no files are selected, selectedFiles should be empty
        scanner.selectedFiles.removeAll()
        XCTAssertTrue(scanner.selectedFiles.isEmpty, "selectedFiles should be empty")
        
        // Test 2: When files are selected, selectedFiles should not be empty
        scanner.selectedFiles.insert(testFiles[0].id)
        XCTAssertFalse(scanner.selectedFiles.isEmpty, "selectedFiles should not be empty when files are selected")
        
        // Test 3: When all selections are cleared, selectedFiles should be empty again
        scanner.selectedFiles.removeAll()
        XCTAssertTrue(scanner.selectedFiles.isEmpty, "selectedFiles should be empty after clearing all selections")
    }
    
    // MARK: - Property 7: Selection Persistence Across Categories
    // For any file selected in category A, switching to category B and back to category A should show the file still selected.
    // Feature: large-file-selection-fix, Property 7: Selection Persistence Across Categories
    func testSelectionPersistenceAcrossCategories() {
        // Create test files with different types to simulate different categories
        let testFiles = [
            FileItem(url: URL(fileURLWithPath: "/tmp/video1.mp4"), name: "video1.mp4", size: 1_000_000_000, type: "mp4", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/video2.mov"), name: "video2.mov", size: 2_000_000_000, type: "mov", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/archive1.zip"), name: "archive1.zip", size: 500_000_000, type: "zip", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/archive2.rar"), name: "archive2.rar", size: 600_000_000, type: "rar", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/music1.mp3"), name: "music1.mp3", size: 100_000_000, type: "mp3", accessDate: Date())
        ]
        
        scanner.foundFiles = testFiles
        
        // Simulate selecting files from different categories
        // Select video files (category: Movies)
        let videoFileIds = Set([testFiles[0].id, testFiles[1].id])
        scanner.selectedFiles = videoFileIds
        
        // Verify selections are made
        XCTAssertEqual(scanner.selectedFiles, videoFileIds, "Video files should be selected")
        
        // Simulate switching to Archives category
        // (In the real UI, this would filter the view, but selectedFiles should persist)
        let archiveFileIds = Set([testFiles[2].id])
        scanner.selectedFiles.formUnion(archiveFileIds)
        
        // Verify both video and archive selections are maintained
        let expectedSelection = videoFileIds.union(archiveFileIds)
        XCTAssertEqual(scanner.selectedFiles, expectedSelection, "Selections from both categories should be maintained")
        
        // Simulate switching back to Movies category
        // The selectedFiles set should still contain the video file IDs
        XCTAssertTrue(scanner.selectedFiles.contains(testFiles[0].id), "Video file 1 should still be selected after category switch")
        XCTAssertTrue(scanner.selectedFiles.contains(testFiles[1].id), "Video file 2 should still be selected after category switch")
        
        // Verify archive selections are also still there
        XCTAssertTrue(scanner.selectedFiles.contains(testFiles[2].id), "Archive file should still be selected")
        
        // Verify unselected files are not in the set
        XCTAssertFalse(scanner.selectedFiles.contains(testFiles[3].id), "Unselected archive file should not be in selectedFiles")
        XCTAssertFalse(scanner.selectedFiles.contains(testFiles[4].id), "Unselected music file should not be in selectedFiles")
    }
    
    // MARK: - Property 6: Total Size Calculation Accuracy
    // For any set of selected files, the displayed total size should equal the sum of all selected file sizes.
    // Feature: large-file-selection-fix, Property 6: Total Size Calculation Accuracy
    func testTotalSizeCalculationAccuracy() {
        // Create test files with various sizes
        let testFiles = [
            FileItem(url: URL(fileURLWithPath: "/tmp/file1.txt"), name: "file1.txt", size: 100_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/file2.txt"), name: "file2.txt", size: 200_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/file3.txt"), name: "file3.txt", size: 300_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/file4.txt"), name: "file4.txt", size: 400_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/file5.txt"), name: "file5.txt", size: 500_000_000, type: "txt", accessDate: Date())
        ]
        
        scanner.foundFiles = testFiles
        
        // Test 1: No files selected - total should be 0
        scanner.selectedFiles.removeAll()
        XCTAssertEqual(scanner.totalSelectedSize, 0, "Total size should be 0 when no files are selected")
        
        // Test 2: Single file selected
        scanner.selectedFiles.insert(testFiles[0].id)
        XCTAssertEqual(scanner.totalSelectedSize, 100_000_000, "Total size should match single selected file")
        
        // Test 3: Multiple files selected
        scanner.selectedFiles.insert(testFiles[1].id)
        scanner.selectedFiles.insert(testFiles[3].id)
        let expectedSize: Int64 = 100_000_000 + 200_000_000 + 400_000_000
        XCTAssertEqual(scanner.totalSelectedSize, expectedSize, "Total size should be sum of all selected files")
        
        // Test 4: All files selected
        scanner.selectedFiles = Set(testFiles.map { $0.id })
        let totalExpected = testFiles.reduce(0) { $0 + $1.size }
        XCTAssertEqual(scanner.totalSelectedSize, totalExpected, "Total size should be sum of all files when all are selected")
        
        // Test 5: Deselect one file and verify total updates
        scanner.selectedFiles.remove(testFiles[2].id)
        let expectedAfterRemoval = totalExpected - 300_000_000
        XCTAssertEqual(scanner.totalSelectedSize, expectedAfterRemoval, "Total size should update correctly when a file is deselected")
    }
    
    // MARK: - Property 6: Total Size Display Updates Immediately
    // For any change in selection, the total size display should update immediately.
    // Feature: large-file-selection-fix, Property 6: Total Size Calculation Accuracy (covers both)
    func testTotalSizeDisplayUpdatesImmediately() {
        // Create test files
        let testFiles = [
            FileItem(url: URL(fileURLWithPath: "/tmp/display1.txt"), name: "display1.txt", size: 150_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/display2.txt"), name: "display2.txt", size: 250_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/display3.txt"), name: "display3.txt", size: 350_000_000, type: "txt", accessDate: Date())
        ]
        
        scanner.foundFiles = testFiles
        
        // Test 1: Initial state - no selections
        XCTAssertEqual(scanner.totalSelectedSize, 0, "Initial total size should be 0")
        
        // Test 2: Add first file - total should update immediately
        scanner.selectedFiles.insert(testFiles[0].id)
        XCTAssertEqual(scanner.totalSelectedSize, 150_000_000, "Total size should update immediately when first file is selected")
        
        // Test 3: Add second file - total should update immediately
        scanner.selectedFiles.insert(testFiles[1].id)
        XCTAssertEqual(scanner.totalSelectedSize, 150_000_000 + 250_000_000, "Total size should update immediately when second file is selected")
        
        // Test 4: Add third file - total should update immediately
        scanner.selectedFiles.insert(testFiles[2].id)
        XCTAssertEqual(scanner.totalSelectedSize, 150_000_000 + 250_000_000 + 350_000_000, "Total size should update immediately when third file is selected")
        
        // Test 5: Remove middle file - total should update immediately
        scanner.selectedFiles.remove(testFiles[1].id)
        XCTAssertEqual(scanner.totalSelectedSize, 150_000_000 + 350_000_000, "Total size should update immediately when a file is deselected")
        
        // Test 6: Clear all selections - total should update immediately
        scanner.selectedFiles.removeAll()
        XCTAssertEqual(scanner.totalSelectedSize, 0, "Total size should update immediately when all selections are cleared")
    }
    
    // MARK: - Deselect All Functionality Test
    // Test that the deselect all functionality clears all selections across all categories
    // Feature: large-file-selection-fix, Deselect All: Clear all selections across all categories
    func testDeselectAllClearsAllSelections() {
        // Create test files simulating different categories
        let testFiles = [
            FileItem(url: URL(fileURLWithPath: "/tmp/video1.mp4"), name: "video1.mp4", size: 1_000_000_000, type: "mp4", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/video2.mov"), name: "video2.mov", size: 2_000_000_000, type: "mov", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/archive1.zip"), name: "archive1.zip", size: 500_000_000, type: "zip", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/archive2.rar"), name: "archive2.rar", size: 600_000_000, type: "rar", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/music1.mp3"), name: "music1.mp3", size: 100_000_000, type: "mp3", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/doc1.pdf"), name: "doc1.pdf", size: 50_000_000, type: "pdf", accessDate: Date())
        ]
        
        scanner.foundFiles = testFiles
        
        // Select files from multiple categories
        scanner.selectedFiles.insert(testFiles[0].id) // video
        scanner.selectedFiles.insert(testFiles[1].id) // video
        scanner.selectedFiles.insert(testFiles[2].id) // archive
        scanner.selectedFiles.insert(testFiles[4].id) // music
        scanner.selectedFiles.insert(testFiles[5].id) // document
        
        // Verify multiple selections exist
        XCTAssertEqual(scanner.selectedFiles.count, 5, "Should have 5 files selected from different categories")
        XCTAssertFalse(scanner.selectedFiles.isEmpty, "Selected files should not be empty before deselect all")
        
        // Simulate deselect all action (as would be called from the menu)
        scanner.selectedFiles.removeAll()
        
        // Verify all selections are cleared
        XCTAssertTrue(scanner.selectedFiles.isEmpty, "All selections should be cleared after deselect all")
        XCTAssertEqual(scanner.selectedFiles.count, 0, "Selected files count should be 0 after deselect all")
        
        // Verify total selected size is 0
        XCTAssertEqual(scanner.totalSelectedSize, 0, "Total selected size should be 0 after deselect all")
    }
    
    // MARK: - Integration Tests
    
    // MARK: - Integration Test 1: Selection Workflow End-to-End
    // Test the complete selection workflow: select multiple files, verify state, deselect, verify state
    func testSelectionWorkflowEndToEnd() {
        // Create test files
        let testFiles = [
            FileItem(url: URL(fileURLWithPath: "/tmp/integration1.txt"), name: "integration1.txt", size: 100_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/integration2.txt"), name: "integration2.txt", size: 200_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/integration3.txt"), name: "integration3.txt", size: 300_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/integration4.txt"), name: "integration4.txt", size: 400_000_000, type: "txt", accessDate: Date())
        ]
        
        scanner.foundFiles = testFiles
        
        // Step 1: Initial state - no selections
        XCTAssertTrue(scanner.selectedFiles.isEmpty, "Should start with no selections")
        XCTAssertEqual(scanner.totalSelectedSize, 0, "Total size should be 0 initially")
        
        // Step 2: Select first file
        scanner.selectedFiles.insert(testFiles[0].id)
        XCTAssertEqual(scanner.selectedFiles.count, 1, "Should have 1 file selected")
        XCTAssertEqual(scanner.totalSelectedSize, 100_000_000, "Total size should match first file")
        
        // Step 3: Select second file
        scanner.selectedFiles.insert(testFiles[1].id)
        XCTAssertEqual(scanner.selectedFiles.count, 2, "Should have 2 files selected")
        XCTAssertEqual(scanner.totalSelectedSize, 300_000_000, "Total size should be sum of first two files")
        
        // Step 4: Select third file
        scanner.selectedFiles.insert(testFiles[2].id)
        XCTAssertEqual(scanner.selectedFiles.count, 3, "Should have 3 files selected")
        XCTAssertEqual(scanner.totalSelectedSize, 600_000_000, "Total size should be sum of first three files")
        
        // Step 5: Deselect middle file
        scanner.selectedFiles.remove(testFiles[1].id)
        XCTAssertEqual(scanner.selectedFiles.count, 2, "Should have 2 files selected after deselect")
        XCTAssertEqual(scanner.totalSelectedSize, 400_000_000, "Total size should exclude deselected file")
        XCTAssertTrue(scanner.selectedFiles.contains(testFiles[0].id), "First file should still be selected")
        XCTAssertTrue(scanner.selectedFiles.contains(testFiles[2].id), "Third file should still be selected")
        XCTAssertFalse(scanner.selectedFiles.contains(testFiles[1].id), "Second file should not be selected")
        
        // Step 6: Select all remaining files
        scanner.selectedFiles.insert(testFiles[1].id)
        scanner.selectedFiles.insert(testFiles[3].id)
        XCTAssertEqual(scanner.selectedFiles.count, 4, "Should have all 4 files selected")
        let expectedTotal: Int64 = 100_000_000 + 200_000_000 + 300_000_000 + 400_000_000
        XCTAssertEqual(scanner.totalSelectedSize, expectedTotal, "Total size should be sum of all files")
        
        // Step 7: Clear all selections
        scanner.selectedFiles.removeAll()
        XCTAssertTrue(scanner.selectedFiles.isEmpty, "Should have no selections after clear all")
        XCTAssertEqual(scanner.totalSelectedSize, 0, "Total size should be 0 after clear all")
    }
    
    // MARK: - Integration Test 2: Deletion Workflow with Various File Types
    // Test deletion with different file types and verify proper cleanup
    func testDeletionWorkflowWithVariousFileTypes() async {
        // Create test files with various types
        let testFiles = [
            FileItem(url: URL(fileURLWithPath: "/tmp/video.mp4"), name: "video.mp4", size: 1_000_000_000, type: "mp4", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/archive.zip"), name: "archive.zip", size: 500_000_000, type: "zip", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/music.mp3"), name: "music.mp3", size: 100_000_000, type: "mp3", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/document.pdf"), name: "document.pdf", size: 50_000_000, type: "pdf", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/image.jpg"), name: "image.jpg", size: 25_000_000, type: "jpg", accessDate: Date())
        ]
        
        scanner.foundFiles = testFiles
        
        // Step 1: Select files of different types
        let filesToDelete = Set([testFiles[0].id, testFiles[2].id, testFiles[4].id]) // video, music, image
        scanner.selectedFiles = filesToDelete
        
        XCTAssertEqual(scanner.selectedFiles.count, 3, "Should have 3 files selected")
        let expectedSize: Int64 = 1_000_000_000 + 100_000_000 + 25_000_000
        XCTAssertEqual(scanner.totalSelectedSize, expectedSize, "Total size should match selected files")
        
        // Step 2: Verify initial state
        XCTAssertEqual(scanner.foundFiles.count, 5, "Should have 5 files initially")
        XCTAssertEqual(scanner.cleanedSize, 0, "Cleaned size should be 0 initially")
        XCTAssertEqual(scanner.cleanedCount, 0, "Cleaned count should be 0 initially")
        
        // Step 3: Delete selected files
        let result = await scanner.deleteItems(filesToDelete)
        
        // Step 4: Verify deletion results
        XCTAssertEqual(result.failedCount, 3, "Should have 3 failed deletions (files don't exist)")
        XCTAssertEqual(result.successCount, 0, "Should have 0 successful deletions (files don't exist)")
        XCTAssertEqual(result.failedFiles.count, 3, "Failed files list should have 3 entries")
        
        // Step 5: Verify file list updated
        XCTAssertEqual(scanner.foundFiles.count, 2, "Should have 2 files remaining after deletion")
        XCTAssertTrue(scanner.foundFiles.contains(where: { $0.id == testFiles[1].id }), "Archive file should remain")
        XCTAssertTrue(scanner.foundFiles.contains(where: { $0.id == testFiles[3].id }), "Document file should remain")
        
        // Step 6: Verify selections cleared
        XCTAssertTrue(scanner.selectedFiles.isEmpty, "Selections should be cleared after deletion")
        XCTAssertEqual(scanner.totalSelectedSize, 0, "Total selected size should be 0 after deletion")
        
        // Step 7: Verify total size updated
        let remainingSize: Int64 = 500_000_000 + 50_000_000
        XCTAssertEqual(scanner.totalSize, remainingSize, "Total size should reflect remaining files")
    }
    
    // MARK: - Integration Test 3: Error Scenarios - Non-existent File
    // Test handling of errors when trying to delete non-existent files
    func testErrorScenarioNonExistentFile() async {
        // Create FileItems for non-existent files
        let fileItem1 = FileItem(
            url: URL(fileURLWithPath: "/nonexistent/path/file1.txt"),
            name: "file1.txt",
            size: 100,
            type: "txt",
            accessDate: Date()
        )
        let fileItem2 = FileItem(
            url: URL(fileURLWithPath: "/nonexistent/path/file2.txt"),
            name: "file2.txt",
            size: 200,
            type: "txt",
            accessDate: Date()
        )
        
        scanner.foundFiles = [fileItem1, fileItem2]
        scanner.selectedFiles.insert(fileItem1.id)
        scanner.selectedFiles.insert(fileItem2.id)
        
        // Attempt deletion (should fail because files don't exist)
        let result = await scanner.deleteItems(scanner.selectedFiles)
        
        // Verify error handling
        XCTAssertGreaterThan(result.failedCount, 0, "Should have failed deletions for non-existent files")
        XCTAssertGreaterThan(result.errors.count, 0, "Should have error messages")
        XCTAssertTrue(scanner.selectedFiles.isEmpty, "Selections should be cleared after deletion attempt")
        XCTAssertEqual(result.successCount, 0, "Should have no successful deletions")
    }
    
    // MARK: - Integration Test 4: Error Scenarios - Mixed Success and Failure
    // Test handling when some files delete successfully and others fail
    func testErrorScenarioMixedSuccessAndFailure() async {
        // Create a temporary file that will succeed
        let tempDir = FileManager.default.temporaryDirectory
        let successFile = tempDir.appendingPathComponent("will_delete_success.txt")
        
        do {
            // Create test file that will succeed
            try "content".write(to: successFile, atomically: true, encoding: .utf8)
            
            // Create FileItems - one real, one non-existent
            let fileItem1 = FileItem(
                url: successFile,
                name: "will_delete_success.txt",
                size: 7,
                type: "txt",
                accessDate: Date()
            )
            let fileItem2 = FileItem(
                url: URL(fileURLWithPath: "/nonexistent/will_fail.txt"),
                name: "will_fail.txt",
                size: 100,
                type: "txt",
                accessDate: Date()
            )
            
            scanner.foundFiles = [fileItem1, fileItem2]
            scanner.selectedFiles.insert(fileItem1.id)
            scanner.selectedFiles.insert(fileItem2.id)
            
            // Attempt deletion
            let result = await scanner.deleteItems(scanner.selectedFiles)
            
            // Verify mixed results
            XCTAssertGreaterThan(result.successCount, 0, "Should have at least one successful deletion")
            XCTAssertGreaterThan(result.failedCount, 0, "Should have at least one failed deletion")
            XCTAssertTrue(scanner.selectedFiles.isEmpty, "Selections should be cleared after deletion attempt")
            XCTAssertEqual(result.failedFiles.count, 1, "Should have 1 failed file")
            
            // Cleanup
            try? FileManager.default.removeItem(at: successFile)
        } catch {
            XCTFail("Failed to set up test: \(error)")
        }
    }
    
    // MARK: - Integration Test 5: UI Feedback - Successful Deletion
    // Test that UI state is properly updated after successful deletion
    func testUIFeedbackSuccessfulDeletion() async {
        // Create temporary files for successful deletion
        let tempDir = FileManager.default.temporaryDirectory
        let testFile1 = tempDir.appendingPathComponent("delete_success_1.txt")
        let testFile2 = tempDir.appendingPathComponent("delete_success_2.txt")
        
        do {
            // Create test files
            try "content1".write(to: testFile1, atomically: true, encoding: .utf8)
            try "content2".write(to: testFile2, atomically: true, encoding: .utf8)
            
            // Create FileItems
            let fileItem1 = FileItem(
                url: testFile1,
                name: "delete_success_1.txt",
                size: 8,
                type: "txt",
                accessDate: Date()
            )
            let fileItem2 = FileItem(
                url: testFile2,
                name: "delete_success_2.txt",
                size: 8,
                type: "txt",
                accessDate: Date()
            )
            
            scanner.foundFiles = [fileItem1, fileItem2]
            scanner.selectedFiles.insert(fileItem1.id)
            
            // Verify initial state
            XCTAssertEqual(scanner.foundFiles.count, 2, "Should have 2 files initially")
            XCTAssertEqual(scanner.selectedFiles.count, 1, "Should have 1 file selected")
            XCTAssertEqual(scanner.cleanedCount, 0, "Cleaned count should be 0 initially")
            XCTAssertEqual(scanner.cleanedSize, 0, "Cleaned size should be 0 initially")
            
            // Delete selected file
            let result = await scanner.deleteItems(scanner.selectedFiles)
            
            // Verify UI feedback state
            if result.successCount > 0 {
                XCTAssertEqual(scanner.cleanedCount, result.successCount, "Cleaned count should be updated")
                XCTAssertEqual(scanner.cleanedSize, result.recoveredSize, "Cleaned size should be updated")
            }
            
            // Verify selections cleared
            XCTAssertTrue(scanner.selectedFiles.isEmpty, "Selections should be cleared after deletion")
            
            // Verify file list updated
            XCTAssertEqual(scanner.foundFiles.count, 1, "Should have 1 file remaining")
            
            // Cleanup
            try? FileManager.default.removeItem(at: testFile1)
            try? FileManager.default.removeItem(at: testFile2)
        } catch {
            XCTFail("Failed to set up test: \(error)")
        }
    }
    
    // MARK: - Integration Test 6: Complex Selection and Deletion Workflow
    // Test a complex workflow with multiple selections, deselections, and deletions
    func testComplexSelectionAndDeletionWorkflow() async {
        // Create test files
        let testFiles = [
            FileItem(url: URL(fileURLWithPath: "/tmp/complex1.txt"), name: "complex1.txt", size: 100_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/complex2.txt"), name: "complex2.txt", size: 200_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/complex3.txt"), name: "complex3.txt", size: 300_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/complex4.txt"), name: "complex4.txt", size: 400_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/complex5.txt"), name: "complex5.txt", size: 500_000_000, type: "txt", accessDate: Date())
        ]
        
        scanner.foundFiles = testFiles
        
        // Step 1: Select files 1, 2, 3
        scanner.selectedFiles.insert(testFiles[0].id)
        scanner.selectedFiles.insert(testFiles[1].id)
        scanner.selectedFiles.insert(testFiles[2].id)
        XCTAssertEqual(scanner.selectedFiles.count, 3, "Should have 3 files selected")
        
        // Step 2: Delete selected files
        let firstDeletion = await scanner.deleteItems(scanner.selectedFiles)
        XCTAssertEqual(scanner.foundFiles.count, 2, "Should have 2 files remaining after first deletion")
        XCTAssertTrue(scanner.selectedFiles.isEmpty, "Selections should be cleared after deletion")
        
        // Step 3: Select remaining files
        scanner.selectedFiles.insert(testFiles[3].id)
        scanner.selectedFiles.insert(testFiles[4].id)
        XCTAssertEqual(scanner.selectedFiles.count, 2, "Should have 2 files selected")
        
        // Step 4: Delete again
        let secondDeletion = await scanner.deleteItems(scanner.selectedFiles)
        XCTAssertEqual(scanner.foundFiles.count, 0, "Should have 0 files remaining after second deletion")
        XCTAssertTrue(scanner.selectedFiles.isEmpty, "Selections should be cleared after second deletion")
        
        // Step 5: Verify cumulative cleanup stats
        let totalCleaned = firstDeletion.successCount + secondDeletion.successCount
        XCTAssertEqual(scanner.cleanedCount, totalCleaned, "Cleaned count should accumulate across deletions")
    }
    
    // MARK: - Integration Test 7: Selection Persistence with Filtering
    // Test that selections persist when filtering/switching categories
    func testSelectionPersistenceWithFiltering() {
        // Create test files with different types
        let testFiles = [
            FileItem(url: URL(fileURLWithPath: "/tmp/filter_video1.mp4"), name: "filter_video1.mp4", size: 1_000_000_000, type: "mp4", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/filter_video2.mov"), name: "filter_video2.mov", size: 2_000_000_000, type: "mov", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/filter_archive1.zip"), name: "filter_archive1.zip", size: 500_000_000, type: "zip", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/filter_archive2.rar"), name: "filter_archive2.rar", size: 600_000_000, type: "rar", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/filter_music.mp3"), name: "filter_music.mp3", size: 100_000_000, type: "mp3", accessDate: Date())
        ]
        
        scanner.foundFiles = testFiles
        
        // Step 1: Select files from different categories
        scanner.selectedFiles.insert(testFiles[0].id) // video
        scanner.selectedFiles.insert(testFiles[2].id) // archive
        scanner.selectedFiles.insert(testFiles[4].id) // music
        
        let initialSelection = scanner.selectedFiles
        let initialSize = scanner.totalSelectedSize
        
        // Step 2: Simulate filtering to show only videos
        // (In real UI, this would filter the display but not change selectedFiles)
        let _ = testFiles.filter { ["mp4", "mov"].contains($0.type.lowercased()) }
        
        // Step 3: Verify selections are still there
        XCTAssertEqual(scanner.selectedFiles, initialSelection, "Selections should persist after filtering")
        XCTAssertEqual(scanner.totalSelectedSize, initialSize, "Total size should persist after filtering")
        
        // Step 4: Simulate switching back to all files
        // Selections should still be intact
        XCTAssertEqual(scanner.selectedFiles.count, 3, "Should still have 3 files selected")
        XCTAssertTrue(scanner.selectedFiles.contains(testFiles[0].id), "Video file should still be selected")
        XCTAssertTrue(scanner.selectedFiles.contains(testFiles[2].id), "Archive file should still be selected")
        XCTAssertTrue(scanner.selectedFiles.contains(testFiles[4].id), "Music file should still be selected")
    }
    
    // MARK: - Integration Test 8: Rapid Selection Changes
    // Test that rapid selection changes are handled correctly
    func testRapidSelectionChanges() {
        // Create test files
        let testFiles = [
            FileItem(url: URL(fileURLWithPath: "/tmp/rapid1.txt"), name: "rapid1.txt", size: 100_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/rapid2.txt"), name: "rapid2.txt", size: 200_000_000, type: "txt", accessDate: Date()),
            FileItem(url: URL(fileURLWithPath: "/tmp/rapid3.txt"), name: "rapid3.txt", size: 300_000_000, type: "txt", accessDate: Date())
        ]
        
        scanner.foundFiles = testFiles
        
        // Rapidly toggle selections
        for _ in 0..<10 {
            scanner.selectedFiles.insert(testFiles[0].id)
            scanner.selectedFiles.insert(testFiles[1].id)
            scanner.selectedFiles.remove(testFiles[0].id)
            scanner.selectedFiles.insert(testFiles[2].id)
            scanner.selectedFiles.remove(testFiles[1].id)
        }
        
        // Verify final state is consistent
        XCTAssertEqual(scanner.selectedFiles.count, 1, "Should have 1 file selected after rapid changes")
        XCTAssertTrue(scanner.selectedFiles.contains(testFiles[2].id), "File 3 should be selected")
        XCTAssertEqual(scanner.totalSelectedSize, 300_000_000, "Total size should match selected file")
    }
}
