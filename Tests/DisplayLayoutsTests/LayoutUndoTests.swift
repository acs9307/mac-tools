import XCTest
@testable import DisplayLayouts
@testable import MacToolsCore

final class LayoutUndoTests: XCTestCase {
    var undoManager: LayoutUndoManager!
    var windowManager: WindowManager!

    override func setUp() {
        super.setUp()
        windowManager = WindowManager()
        undoManager = LayoutUndoManager(windowManager: windowManager)
    }

    override func tearDown() {
        undoManager = nil
        windowManager = nil
        super.tearDown()
    }

    // MARK: - Snapshot Tests

    func testCaptureSnapshot() throws {
        let snapshot = try undoManager.captureSnapshot(name: "Test Snapshot")

        XCTAssertEqual(snapshot.name, "Test Snapshot")
        XCTAssertNotNil(snapshot.timestamp)
        // windowStates may be empty if no accessibility permissions
    }

    func testCaptureSnapshotWithCustomName() throws {
        let snapshot = try undoManager.captureSnapshot(name: "Custom Name")

        XCTAssertEqual(snapshot.name, "Custom Name")
    }

    // MARK: - Undo Stack Tests

    func testInitialUndoState() {
        XCTAssertFalse(undoManager.canUndo)
        XCTAssertFalse(undoManager.canRedo)
        XCTAssertNil(undoManager.undoActionName)
        XCTAssertNil(undoManager.redoActionName)
        XCTAssertEqual(undoManager.undoCount, 0)
        XCTAssertEqual(undoManager.redoCount, 0)
    }

    func testSaveStateBeforeChange() throws {
        try undoManager.saveStateBeforeChange(name: "Test Change")

        XCTAssertTrue(undoManager.canUndo)
        XCTAssertEqual(undoManager.undoActionName, "Test Change")
        XCTAssertEqual(undoManager.undoCount, 1)
    }

    func testSaveMultipleStates() throws {
        try undoManager.saveStateBeforeChange(name: "Change 1")
        try undoManager.saveStateBeforeChange(name: "Change 2")
        try undoManager.saveStateBeforeChange(name: "Change 3")

        XCTAssertEqual(undoManager.undoCount, 3)
        XCTAssertEqual(undoManager.undoActionName, "Change 3")
    }

    func testMaxUndoStatesLimit() throws {
        undoManager.maxUndoStates = 5

        // Add more states than the limit
        for i in 1...10 {
            try undoManager.saveStateBeforeChange(name: "Change \(i)")
        }

        // Should only keep the last 5
        XCTAssertEqual(undoManager.undoCount, 5)
        XCTAssertEqual(undoManager.undoActionName, "Change 10")
    }

    // MARK: - Redo Stack Tests

    func testRedoNotAvailableInitially() {
        XCTAssertFalse(undoManager.canRedo)
        XCTAssertNil(undoManager.redoActionName)
    }

    func testSavingStateClearsRedoStack() throws {
        // Create initial state
        try undoManager.saveStateBeforeChange(name: "Change 1")

        // Simulate undo (which would add to redo stack)
        // Since we can't actually undo without windows, we'll test this in integration tests
    }

    // MARK: - Undo Errors

    func testUndoWithEmptyStack() {
        XCTAssertThrowsError(try undoManager.undo()) { error in
            guard let undoError = error as? LayoutUndoError else {
                XCTFail("Expected LayoutUndoError")
                return
            }

            if case .noUndoAvailable = undoError {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected noUndoAvailable error")
            }
        }
    }

    func testRedoWithEmptyStack() {
        XCTAssertThrowsError(try undoManager.redo()) { error in
            guard let undoError = error as? LayoutUndoError else {
                XCTFail("Expected LayoutUndoError")
                return
            }

            if case .noRedoAvailable = undoError {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected noRedoAvailable error")
            }
        }
    }

    // MARK: - Stack Management Tests

    func testClearUndoHistory() throws {
        try undoManager.saveStateBeforeChange(name: "Change 1")
        try undoManager.saveStateBeforeChange(name: "Change 2")

        undoManager.clearUndoHistory()

        XCTAssertFalse(undoManager.canUndo)
        XCTAssertEqual(undoManager.undoCount, 0)
    }

    func testClearRedoHistory() throws {
        try undoManager.saveStateBeforeChange(name: "Change 1")
        // After an undo, we'd have redo stack populated
        // For now, just test the method doesn't crash
        undoManager.clearRedoHistory()

        XCTAssertEqual(undoManager.redoCount, 0)
    }

    func testClearAll() throws {
        try undoManager.saveStateBeforeChange(name: "Change 1")

        undoManager.clearAll()

        XCTAssertFalse(undoManager.canUndo)
        XCTAssertFalse(undoManager.canRedo)
        XCTAssertEqual(undoManager.undoCount, 0)
        XCTAssertEqual(undoManager.redoCount, 0)
    }

    // MARK: - Snapshot Structure Tests

    func testLayoutSnapshotCreation() {
        let windowState = WindowState(
            identifier: WindowIdentifier(
                application: ApplicationIdentifier(
                    bundleIdentifier: "com.test.app",
                    name: "Test App",
                    pid: 123
                ),
                title: "Test Window",
                role: .window
            ),
            frame: WindowFrame(x: 0, y: 0, width: 800, height: 600),
            isMinimized: false,
            isHidden: false
        )

        let snapshot = LayoutSnapshot(
            name: "Test",
            timestamp: Date(),
            windowStates: [windowState]
        )

        XCTAssertEqual(snapshot.name, "Test")
        XCTAssertEqual(snapshot.windowStates.count, 1)
        XCTAssertEqual(snapshot.windowStates.first?.identifier.title, "Test Window")
    }

    func testWindowStateCreation() {
        let appId = ApplicationIdentifier(
            bundleIdentifier: "com.test.app",
            name: "Test App",
            pid: 123
        )

        let windowId = WindowIdentifier(
            application: appId,
            title: "Test Window",
            role: .window
        )

        let frame = WindowFrame(x: 100, y: 200, width: 800, height: 600)

        let windowState = WindowState(
            identifier: windowId,
            frame: frame,
            isMinimized: false,
            isHidden: false
        )

        XCTAssertEqual(windowState.identifier.title, "Test Window")
        XCTAssertEqual(windowState.frame.x, 100)
        XCTAssertEqual(windowState.frame.y, 200)
        XCTAssertEqual(windowState.frame.width, 800)
        XCTAssertEqual(windowState.frame.height, 600)
        XCTAssertFalse(windowState.isMinimized)
        XCTAssertFalse(windowState.isHidden)
    }

    // MARK: - Error Description Tests

    func testNoUndoAvailableErrorDescription() {
        let error = LayoutUndoError.noUndoAvailable

        XCTAssertEqual(error.errorDescription, "No undo actions available")
    }

    func testNoRedoAvailableErrorDescription() {
        let error = LayoutUndoError.noRedoAvailable

        XCTAssertEqual(error.errorDescription, "No redo actions available")
    }

    func testSnapshotFailedErrorDescription() {
        let error = LayoutUndoError.snapshotFailed("Test reason")

        XCTAssertEqual(error.errorDescription, "Failed to capture snapshot: Test reason")
    }

    // MARK: - Codable Tests

    func testLayoutSnapshotCodable() throws {
        let windowState = WindowState(
            identifier: WindowIdentifier(
                application: ApplicationIdentifier(
                    bundleIdentifier: "com.test.app",
                    name: "Test App",
                    pid: 123
                ),
                title: "Test Window",
                role: .window
            ),
            frame: WindowFrame(x: 0, y: 0, width: 800, height: 600),
            isMinimized: false,
            isHidden: false
        )

        let snapshot = LayoutSnapshot(
            name: "Test",
            timestamp: Date(),
            windowStates: [windowState]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(snapshot)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LayoutSnapshot.self, from: data)

        XCTAssertEqual(decoded.name, snapshot.name)
        XCTAssertEqual(decoded.windowStates.count, snapshot.windowStates.count)
        XCTAssertEqual(decoded.windowStates.first?.identifier.title, "Test Window")
    }

    func testWindowStateCodable() throws {
        let windowState = WindowState(
            identifier: WindowIdentifier(
                application: ApplicationIdentifier(
                    bundleIdentifier: "com.test.app",
                    name: "Test App",
                    pid: 123
                ),
                title: "Test Window",
                role: .window
            ),
            frame: WindowFrame(x: 100, y: 200, width: 800, height: 600),
            isMinimized: false,
            isHidden: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(windowState)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WindowState.self, from: data)

        XCTAssertEqual(decoded.identifier.title, windowState.identifier.title)
        XCTAssertEqual(decoded.frame.x, windowState.frame.x)
        XCTAssertEqual(decoded.frame.y, windowState.frame.y)
        XCTAssertEqual(decoded.isMinimized, windowState.isMinimized)
        XCTAssertEqual(decoded.isHidden, windowState.isHidden)
    }
}

// MARK: - Safety Checker Tests

final class LayoutSafetyCheckerTests: XCTestCase {
    var safetyChecker: LayoutSafetyChecker!
    var displays: [DisplayIdentity]!

    override func setUp() {
        super.setUp()
        safetyChecker = LayoutSafetyChecker()

        // Create test displays
        displays = [
            DisplayIdentity(
                displayID: 1,
                vendorID: 0x1234,
                modelID: 0x5678,
                serialNumber: "TEST123",
                name: "Test Display",
                bounds: DisplayBounds(x: 0, y: 0, width: 1920, height: 1080),
                scale: 1.0,
                isMain: true
            ),
            DisplayIdentity(
                displayID: 2,
                vendorID: 0x1234,
                modelID: 0x5679,
                serialNumber: "TEST456",
                name: "Secondary Display",
                bounds: DisplayBounds(x: 1920, y: 0, width: 1920, height: 1080),
                scale: 1.0,
                isMain: false
            )
        ]
    }

    override func tearDown() {
        safetyChecker = nil
        displays = nil
        super.tearDown()
    }

    // MARK: - Frame Safety Tests

    func testSafeFrameOnMainDisplay() {
        let frame = WindowFrame(x: 100, y: 100, width: 800, height: 600)

        XCTAssertTrue(safetyChecker.isSafeFrame(frame, for: displays))
    }

    func testSafeFrameOnSecondaryDisplay() {
        let frame = WindowFrame(x: 2000, y: 100, width: 800, height: 600)

        XCTAssertTrue(safetyChecker.isSafeFrame(frame, for: displays))
    }

    func testFrameTooSmall() {
        let frame = WindowFrame(x: 100, y: 100, width: 50, height: 50)

        XCTAssertFalse(safetyChecker.isSafeFrame(frame, for: displays))
    }

    func testFrameTooLarge() {
        let frame = WindowFrame(x: 100, y: 100, width: 20000, height: 20000)

        XCTAssertFalse(safetyChecker.isSafeFrame(frame, for: displays))
    }

    func testFrameCompletelyOffscreen() {
        let frame = WindowFrame(x: 5000, y: 5000, width: 800, height: 600)

        XCTAssertFalse(safetyChecker.isSafeFrame(frame, for: displays))
    }

    func testFramePartiallyOffscreen() {
        // Frame that extends beyond display but still intersects
        let frame = WindowFrame(x: 1800, y: 100, width: 800, height: 600)

        // Should still be considered safe as it's partially visible
        XCTAssertTrue(safetyChecker.isSafeFrame(frame, for: displays))
    }

    func testInvalidFrameDimensions() {
        let frame = WindowFrame(x: 100, y: 100, width: 0, height: 600)

        XCTAssertFalse(safetyChecker.isSafeFrame(frame, for: displays))
    }

    func testNegativeDimensions() {
        let frame = WindowFrame(x: 100, y: 100, width: -800, height: 600)

        XCTAssertFalse(safetyChecker.isSafeFrame(frame, for: displays))
    }

    // MARK: - Preset Safety Validation Tests

    func testValidatePresetWithSafeFrames() {
        let preset = createTestPreset(frames: [
            WindowFrame(x: 100, y: 100, width: 800, height: 600),
            WindowFrame(x: 2000, y: 100, width: 800, height: 600)
        ])

        let result = safetyChecker.validatePresetSafety(preset, displays: displays)

        XCTAssertTrue(result.isSafe)
    }

    func testValidatePresetWithUnsafeFrames() {
        let preset = createTestPreset(frames: [
            WindowFrame(x: 100, y: 100, width: 800, height: 600),
            WindowFrame(x: 5000, y: 5000, width: 800, height: 600) // Offscreen
        ])

        let result = safetyChecker.validatePresetSafety(preset, displays: displays)

        XCTAssertFalse(result.isSafe)

        if case .unsafe(let unsafeFrames, let offscreenWindows) = result {
            XCTAssertEqual(unsafeFrames.count, 1)
            XCTAssertEqual(offscreenWindows.count, 1)
        } else {
            XCTFail("Expected unsafe result")
        }
    }

    func testValidatePresetWithTooSmallFrames() {
        let preset = createTestPreset(frames: [
            WindowFrame(x: 100, y: 100, width: 50, height: 50) // Too small
        ])

        let result = safetyChecker.validatePresetSafety(preset, displays: displays)

        XCTAssertFalse(result.isSafe)
    }

    // MARK: - Frame Correction Tests

    func testCorrectFrameAlreadySafe() {
        let frame = WindowFrame(x: 100, y: 100, width: 800, height: 600)

        let corrected = safetyChecker.correctFrame(frame, for: displays)

        XCTAssertNotNil(corrected)
        XCTAssertEqual(corrected?.x, frame.x)
        XCTAssertEqual(corrected?.y, frame.y)
        XCTAssertEqual(corrected?.width, frame.width)
        XCTAssertEqual(corrected?.height, frame.height)
    }

    func testCorrectFrameTooSmall() {
        let frame = WindowFrame(x: 100, y: 100, width: 50, height: 50)

        let corrected = safetyChecker.correctFrame(frame, for: displays)

        XCTAssertNotNil(corrected)
        XCTAssertGreaterThanOrEqual(corrected!.width, 200)
        XCTAssertGreaterThanOrEqual(corrected!.height, 200)
    }

    func testCorrectFrameCompletelyOffscreen() {
        let frame = WindowFrame(x: 5000, y: 5000, width: 800, height: 600)

        let corrected = safetyChecker.correctFrame(frame, for: displays)

        XCTAssertNotNil(corrected)

        // Should be moved onto main display
        let mainDisplay = displays.first!
        XCTAssertGreaterThanOrEqual(corrected!.x, mainDisplay.bounds.x)
        XCTAssertLessThanOrEqual(corrected!.x, mainDisplay.bounds.x + mainDisplay.bounds.width)
    }

    func testCorrectFrameWithEmptyDisplays() {
        let frame = WindowFrame(x: 100, y: 100, width: 800, height: 600)

        let corrected = safetyChecker.correctFrame(frame, for: [])

        XCTAssertNil(corrected)
    }

    // MARK: - Helper Methods

    private func createTestPreset(frames: [WindowFrame]) -> WindowLayoutPreset {
        let layouts = frames.enumerated().map { index, frame in
            WindowLayoutSpec(
                windowID: WindowIdentifier(
                    application: ApplicationIdentifier(
                        bundleIdentifier: "com.test.app",
                        name: "Test App",
                        pid: 123
                    ),
                    title: "Window \(index)",
                    role: .window
                ),
                targetFrame: frame,
                displayID: nil,
                restoreIfMinimized: true,
                unhideIfHidden: true
            )
        }

        return WindowLayoutPreset(
            name: "Test Preset",
            displayConfigSignature: "test-signature",
            layouts: layouts,
            createdAt: Date(),
            modifiedAt: Date()
        )
    }
}
