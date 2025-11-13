import XCTest
@testable import DisplayLayouts

final class LayoutPresetCaptureTests: XCTestCase {
    var capture: LayoutPresetCapture!
    var mockWindowManager: MockWindowManager!
    var mockDisplayEnumerator: MockDisplayEnumerator!

    override func setUp() {
        super.setUp()
        mockWindowManager = MockWindowManager()
        mockDisplayEnumerator = MockDisplayEnumerator()
        capture = LayoutPresetCapture(
            windowManager: mockWindowManager,
            displayEnumerator: mockDisplayEnumerator
        )
    }

    override func tearDown() {
        capture = nil
        mockWindowManager = nil
        mockDisplayEnumerator = nil
        super.tearDown()
    }

    // MARK: - Basic Capture Tests

    func testCaptureCurrentLayout() throws {
        // Setup mock data
        let display = makeDisplay(x: 0, y: 0, width: 1920, height: 1080)
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let window1 = makeWindowInfo(title: "Window 1", x: 100, y: 100)
        let window2 = makeWindowInfo(title: "Window 2", x: 500, y: 500)
        mockWindowManager.windowsToReturn = [window1, window2]

        // Capture
        let preset = try capture.captureCurrentLayout(name: "Test Preset")

        XCTAssertEqual(preset.name, "Test Preset")
        XCTAssertEqual(preset.displayConfigSignature, config.signature)
        XCTAssertEqual(preset.windowCount, 2)
    }

    func testCaptureEmptyLayout() throws {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config
        mockWindowManager.windowsToReturn = []

        let preset = try capture.captureCurrentLayout(name: "Empty")

        XCTAssertEqual(preset.windowCount, 0)
    }

    func testCaptureExcludesMinimizedWindows() throws {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let window1 = makeWindowInfo(title: "Window 1", isMinimized: false)
        let window2 = makeWindowInfo(title: "Window 2", isMinimized: true)
        let window3 = makeWindowInfo(title: "Window 3", isMinimized: false)
        mockWindowManager.windowsToReturn = [window1, window2, window3]

        let preset = try capture.captureCurrentLayout(name: "Test")

        // Should only capture visible windows
        XCTAssertEqual(preset.windowCount, 2)
    }

    func testCaptureExcludesHiddenWindows() throws {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let window1 = makeWindowInfo(title: "Window 1", isHidden: false)
        let window2 = makeWindowInfo(title: "Window 2", isHidden: true)
        mockWindowManager.windowsToReturn = [window1, window2]

        let preset = try capture.captureCurrentLayout(name: "Test")

        XCTAssertEqual(preset.windowCount, 1)
    }

    // MARK: - Filtering Tests

    func testCaptureWithCustomFilter() throws {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let window1 = makeWindowInfo(title: "Important Window")
        let window2 = makeWindowInfo(title: "Unimportant Window")
        mockWindowManager.windowsToReturn = [window1, window2]

        let preset = try capture.captureCurrentLayout(name: "Test") { window in
            window.identifier.title.contains("Important")
        }

        XCTAssertEqual(preset.windowCount, 1)
    }

    func testCaptureForSpecificApplications() throws {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let app1 = ApplicationIdentifier(bundleIdentifier: "com.app1", name: "App 1")
        let app2 = ApplicationIdentifier(bundleIdentifier: "com.app2", name: "App 2")

        let window1 = makeWindowInfo(title: "Window 1", application: app1)
        let window2 = makeWindowInfo(title: "Window 2", application: app2)
        let window3 = makeWindowInfo(title: "Window 3", application: app1)
        mockWindowManager.windowsToReturn = [window1, window2, window3]

        let preset = try capture.captureLayout(
            name: "Test",
            forApplications: ["com.app1"]
        )

        XCTAssertEqual(preset.windowCount, 2)
    }

    func testCaptureExcludingApplications() throws {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let app1 = ApplicationIdentifier(bundleIdentifier: "com.app1", name: "App 1")
        let app2 = ApplicationIdentifier(bundleIdentifier: "com.app2", name: "App 2")

        let window1 = makeWindowInfo(title: "Window 1", application: app1)
        let window2 = makeWindowInfo(title: "Window 2", application: app2)
        mockWindowManager.windowsToReturn = [window1, window2]

        let preset = try capture.captureLayout(
            name: "Test",
            excludingApplications: ["com.app1"]
        )

        XCTAssertEqual(preset.windowCount, 1)
    }

    // MARK: - Display Assignment Tests

    func testWindowAssignedToCorrectDisplay() throws {
        // Setup two displays side by side
        let display1 = makeDisplay(x: 0, y: 0, width: 1920, height: 1080, vendorID: 0x1111)
        let display2 = makeDisplay(x: 1920, y: 0, width: 1920, height: 1080, vendorID: 0x2222)
        let config = DisplayConfiguration(displays: [display1, display2])
        mockDisplayEnumerator.configurationToReturn = config

        // Window on first display
        let window1 = makeWindowInfo(title: "Window 1", x: 500, y: 500)
        // Window on second display
        let window2 = makeWindowInfo(title: "Window 2", x: 2500, y: 500)
        mockWindowManager.windowsToReturn = [window1, window2]

        let preset = try capture.captureCurrentLayout(name: "Test")

        XCTAssertEqual(preset.windowCount, 2)

        // Check display assignments
        let layout1 = preset.layout(for: window1.identifier)
        let layout2 = preset.layout(for: window2.identifier)

        XCTAssertEqual(layout1?.displayID, display1.stableID)
        XCTAssertEqual(layout2?.displayID, display2.stableID)
    }

    // MARK: - Error Handling

    func testCaptureThrowsWhenNoDisplays() {
        mockDisplayEnumerator.shouldThrowError = true

        XCTAssertThrowsError(try capture.captureCurrentLayout(name: "Test"))
    }

    func testCaptureThrowsWhenAccessibilityDisabled() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config
        mockWindowManager.shouldThrowAccessibilityError = true

        XCTAssertThrowsError(try capture.captureCurrentLayout(name: "Test"))
    }

    // MARK: - Helpers

    private func makeDisplay(
        x: Double = 0,
        y: Double = 0,
        width: Double = 1920,
        height: Double = 1080,
        vendorID: UInt32 = 0x1234
    ) -> DisplayIdentity {
        return DisplayIdentity(
            displayID: 1,
            serialNumber: "TEST",
            vendorID: vendorID,
            modelID: 0x5678,
            name: "Test Display",
            bounds: DisplayBounds(x: x, y: y, width: width, height: height),
            scale: 1.0,
            isMain: true
        )
    }

    private func makeWindowInfo(
        title: String,
        x: Double = 100,
        y: Double = 100,
        application: ApplicationIdentifier? = nil,
        isMinimized: Bool = false,
        isHidden: Bool = false
    ) -> WindowInfo {
        let app = application ?? ApplicationIdentifier(
            bundleIdentifier: "com.test.app",
            name: "Test App"
        )

        let identifier = WindowIdentifier(
            application: app,
            title: title,
            role: .standard
        )

        return WindowInfo(
            identifier: identifier,
            frame: WindowFrame(x: x, y: y, width: 800, height: 600),
            processID: 12345,
            isMinimized: isMinimized,
            isHidden: isHidden
        )
    }
}

// MARK: - Preset Validation Tests

final class PresetValidationTests: XCTestCase {
    var mockWindowManager: MockWindowManager!

    override func setUp() {
        super.setUp()
        mockWindowManager = MockWindowManager()
    }

    override func tearDown() {
        mockWindowManager = nil
        super.tearDown()
    }

    func testValidateEmptyPreset() {
        let preset = WindowLayoutPreset(
            name: "Empty",
            displayConfigSignature: "sig",
            layouts: []
        )

        let result = PresetValidation.validate(
            preset: preset,
            windowManager: mockWindowManager
        )

        if case .empty = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected .empty result")
        }

        XCTAssertFalse(result.isValid)
    }

    func testValidateValidPreset() {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let windowID = WindowIdentifier(application: app, title: "Window")
        let spec = WindowLayoutSpec(
            windowID: windowID,
            targetFrame: WindowFrame(x: 0, y: 0, width: 800, height: 600)
        )

        let preset = WindowLayoutPreset(
            name: "Test",
            displayConfigSignature: "sig",
            layouts: [spec]
        )

        // Mock that window exists
        mockWindowManager.windowsToReturn = [
            WindowInfo(
                identifier: windowID,
                frame: WindowFrame(x: 0, y: 0, width: 800, height: 600),
                processID: 12345
            )
        ]

        let result = PresetValidation.validate(
            preset: preset,
            windowManager: mockWindowManager
        )

        if case .valid = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected .valid result, got \(result)")
        }

        XCTAssertTrue(result.isValid)
    }

    func testValidateInvalidFrames() {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let windowID = WindowIdentifier(application: app, title: "Window")

        // Invalid frame (zero width)
        let spec = WindowLayoutSpec(
            windowID: windowID,
            targetFrame: WindowFrame(x: 0, y: 0, width: 0, height: 600)
        )

        let preset = WindowLayoutPreset(
            name: "Test",
            displayConfigSignature: "sig",
            layouts: [spec]
        )

        let result = PresetValidation.validate(
            preset: preset,
            windowManager: mockWindowManager
        )

        if case .invalidFrames(let frames) = result {
            XCTAssertEqual(frames.count, 1)
        } else {
            XCTFail("Expected .invalidFrames result")
        }

        XCTAssertFalse(result.isValid)
    }

    func testValidateMissingWindows() {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let windowID = WindowIdentifier(application: app, title: "Window")
        let spec = WindowLayoutSpec(
            windowID: windowID,
            targetFrame: WindowFrame(x: 0, y: 0, width: 800, height: 600)
        )

        let preset = WindowLayoutPreset(
            name: "Test",
            displayConfigSignature: "sig",
            layouts: [spec]
        )

        // No windows returned
        mockWindowManager.windowsToReturn = []

        let result = PresetValidation.validate(
            preset: preset,
            windowManager: mockWindowManager
        )

        if case .missingWindows(let windows) = result {
            XCTAssertEqual(windows.count, 1)
        } else {
            XCTFail("Expected .missingWindows result")
        }

        XCTAssertFalse(result.isValid)
    }
}

// MARK: - Layout Preset Automation Tests

final class LayoutPresetAutomationTests: XCTestCase {
    var automation: LayoutPresetAutomation!
    var mockWindowManager: MockWindowManager!
    var presetManager: WindowLayoutPresetManager!

    override func setUp() {
        super.setUp()
        mockWindowManager = MockWindowManager()
        presetManager = WindowLayoutPresetManager()
        automation = LayoutPresetAutomation(
            windowManager: mockWindowManager,
            presetManager: presetManager
        )
    }

    override func tearDown() {
        automation.stopAutomation()
        automation = nil
        mockWindowManager = nil
        presetManager = nil
        super.tearDown()
    }

    func testStartStopAutomation() {
        XCTAssertFalse(automation.autoApplyEnabled)

        automation.startAutomation()
        XCTAssertTrue(automation.autoApplyEnabled)

        automation.stopAutomation()
        XCTAssertFalse(automation.autoApplyEnabled)
    }

    func testApplyPresetForConfiguration() {
        // Create a preset
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        let preset = makePreset(signature: config.signature)
        presetManager.store(preset)

        // Mock that window exists
        mockWindowManager.windowsToReturn = [
            makeWindowInfo(title: "Test Window")
        ]

        // Apply
        let result = automation.applyPreset(for: config)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.results.count, 1)
    }

    func testApplyPresetWhenNoPresetFound() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])

        // Don't store any preset

        let result = automation.applyPreset(for: config)

        XCTAssertNil(result)
    }

    func testApplyMultipleWindowPreset() {
        // Create preset with multiple windows
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])

        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let window1ID = WindowIdentifier(application: app, title: "Window 1")
        let window2ID = WindowIdentifier(application: app, title: "Window 2")

        let spec1 = WindowLayoutSpec(
            windowID: window1ID,
            targetFrame: WindowFrame(x: 0, y: 0, width: 800, height: 600)
        )
        let spec2 = WindowLayoutSpec(
            windowID: window2ID,
            targetFrame: WindowFrame(x: 900, y: 0, width: 800, height: 600)
        )

        let preset = WindowLayoutPreset(
            name: "Multi",
            displayConfigSignature: config.signature,
            layouts: [spec1, spec2]
        )

        presetManager.store(preset)

        // Mock windows exist
        mockWindowManager.windowsToReturn = [
            WindowInfo(identifier: window1ID, frame: WindowFrame(x: 0, y: 0, width: 800, height: 600), processID: 12345),
            WindowInfo(identifier: window2ID, frame: WindowFrame(x: 0, y: 0, width: 800, height: 600), processID: 12345)
        ]

        let result = automation.applyPreset(for: config)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.results.count, 2)
    }

    func testApplyPresetWithMissingWindows() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        let preset = makePreset(signature: config.signature)
        presetManager.store(preset)

        // No windows returned (window doesn't exist)
        mockWindowManager.windowsToReturn = []

        let result = automation.applyPreset(for: config)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.failureCount, 1)
    }

    // MARK: - Helpers

    private func makeDisplay() -> DisplayIdentity {
        return DisplayIdentity(
            displayID: 1,
            serialNumber: "TEST",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Test Display",
            bounds: DisplayBounds(x: 0, y: 0, width: 1920, height: 1080),
            scale: 1.0,
            isMain: true
        )
    }

    private func makeWindowInfo(title: String) -> WindowInfo {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let identifier = WindowIdentifier(application: app, title: title)
        return WindowInfo(
            identifier: identifier,
            frame: WindowFrame(x: 0, y: 0, width: 800, height: 600),
            processID: 12345
        )
    }

    private func makePreset(signature: String) -> WindowLayoutPreset {
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let windowID = WindowIdentifier(application: app, title: "Test Window")
        let spec = WindowLayoutSpec(
            windowID: windowID,
            targetFrame: WindowFrame(x: 0, y: 0, width: 800, height: 600)
        )

        return WindowLayoutPreset(
            name: "Test Preset",
            displayConfigSignature: signature,
            layouts: [spec]
        )
    }
}

// MARK: - Mock Window Manager

class MockWindowManager: WindowManager {
    var windowsToReturn: [WindowInfo] = []
    var shouldThrowAccessibilityError = false

    override func enumerateAllWindows() throws -> [WindowInfo] {
        if shouldThrowAccessibilityError {
            throw WindowError.accessibilityNotEnabled
        }
        return windowsToReturn
    }

    override func findWindows(matching identifier: WindowIdentifier) throws -> [WindowInfo] {
        return windowsToReturn.filter { $0.identifier == identifier }
    }

    override func applyLayout(_ layout: WindowLayoutSpec) throws -> WindowLayoutResult {
        let windows = try findWindows(matching: layout.windowID)
        guard !windows.isEmpty else {
            return WindowLayoutResult(
                windowID: layout.windowID,
                success: false,
                error: WindowError.windowNotFound(layout.windowID)
            )
        }

        return WindowLayoutResult(
            windowID: layout.windowID,
            success: true,
            error: nil,
            previousFrame: windows.first?.frame,
            newFrame: layout.targetFrame
        )
    }
}

// MARK: - Round-trip Tests

final class LayoutPresetRoundTripTests: XCTestCase {
    func testSaveAndApplyRoundTrip() throws {
        let mockWindowManager = MockWindowManager()
        let presetManager = WindowLayoutPresetManager()
        let capture = LayoutPresetCapture(
            windowManager: mockWindowManager,
            displayEnumerator: MockDisplayEnumerator()
        )
        let automation = LayoutPresetAutomation(
            windowManager: mockWindowManager,
            presetManager: presetManager
        )

        // Setup: Create windows and display
        let display = DisplayIdentity(
            displayID: 1,
            serialNumber: "TEST",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Test Display",
            bounds: DisplayBounds(x: 0, y: 0, width: 1920, height: 1080),
            scale: 1.0,
            isMain: true
        )
        let config = DisplayConfiguration(displays: [display])

        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let windowID = WindowIdentifier(application: app, title: "Test Window")
        let originalFrame = WindowFrame(x: 100, y: 100, width: 800, height: 600)

        let window = WindowInfo(
            identifier: windowID,
            frame: originalFrame,
            processID: 12345
        )

        mockWindowManager.windowsToReturn = [window]

        // Step 1: Capture current layout
        let preset = try capture.captureCurrentLayout(name: "Test Preset")
        XCTAssertEqual(preset.windowCount, 1)
        XCTAssertEqual(preset.displayConfigSignature, config.signature)

        // Step 2: Store preset
        presetManager.store(preset)

        // Step 3: Simulate window moved
        let movedWindow = WindowInfo(
            identifier: windowID,
            frame: WindowFrame(x: 500, y: 500, width: 800, height: 600),
            processID: 12345
        )
        mockWindowManager.windowsToReturn = [movedWindow]

        // Step 4: Apply preset
        let result = automation.applyPreset(for: config)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.allSucceeded)
        XCTAssertEqual(result!.results.first?.newFrame, originalFrame)
    }

    func testPartialPresetApplication() throws {
        let mockWindowManager = MockWindowManager()
        let presetManager = WindowLayoutPresetManager()
        let automation = LayoutPresetAutomation(
            windowManager: mockWindowManager,
            presetManager: presetManager
        )

        let display = DisplayIdentity(
            displayID: 1,
            serialNumber: "TEST",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: "Test Display",
            bounds: DisplayBounds(x: 0, y: 0, width: 1920, height: 1080),
            scale: 1.0,
            isMain: true
        )
        let config = DisplayConfiguration(displays: [display])

        // Create preset with 3 windows
        let app = ApplicationIdentifier(bundleIdentifier: "com.test.app", name: "Test")
        let window1ID = WindowIdentifier(application: app, title: "Window 1")
        let window2ID = WindowIdentifier(application: app, title: "Window 2")
        let window3ID = WindowIdentifier(application: app, title: "Window 3")

        let spec1 = WindowLayoutSpec(windowID: window1ID, targetFrame: WindowFrame(x: 0, y: 0, width: 800, height: 600))
        let spec2 = WindowLayoutSpec(windowID: window2ID, targetFrame: WindowFrame(x: 900, y: 0, width: 800, height: 600))
        let spec3 = WindowLayoutSpec(windowID: window3ID, targetFrame: WindowFrame(x: 0, y: 700, width: 800, height: 600))

        let preset = WindowLayoutPreset(
            name: "Partial",
            displayConfigSignature: config.signature,
            layouts: [spec1, spec2, spec3]
        )

        presetManager.store(preset)

        // Only 2 out of 3 windows exist
        mockWindowManager.windowsToReturn = [
            WindowInfo(identifier: window1ID, frame: WindowFrame(x: 0, y: 0, width: 800, height: 600), processID: 12345),
            WindowInfo(identifier: window2ID, frame: WindowFrame(x: 0, y: 0, width: 800, height: 600), processID: 12345)
            // window3 is missing
        ]

        let result = automation.applyPreset(for: config)

        XCTAssertNotNil(result)
        XCTAssertEqual(result!.successCount, 2)
        XCTAssertEqual(result!.failureCount, 1)
        XCTAssertFalse(result!.allSucceeded)
    }
}
