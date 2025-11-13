import XCTest
@testable import DisplayLayouts
@testable import MacToolsCore

@MainActor
final class DisplayLayoutsViewModelTests: XCTestCase {
    var viewModel: DisplayLayoutsViewModel!
    var mockWindowManager: MockWindowManager!
    var mockDisplayEnumerator: MockDisplayEnumerator!
    var presetManager: WindowLayoutPresetManager!

    override func setUp() async throws {
        try await super.setUp()
        mockWindowManager = MockWindowManager()
        mockDisplayEnumerator = MockDisplayEnumerator()
        presetManager = WindowLayoutPresetManager()

        viewModel = DisplayLayoutsViewModel(
            windowManager: mockWindowManager,
            displayEnumerator: mockDisplayEnumerator,
            presetManager: presetManager
        )
    }

    override func tearDown() async throws {
        viewModel = nil
        mockWindowManager = nil
        mockDisplayEnumerator = nil
        presetManager = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.autoApplyEnabled)
        XCTAssertNil(viewModel.lastApplyResult)
    }

    // MARK: - Load State Tests

    func testLoadCurrentState() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let window = makeWindowInfo(title: "Test Window")
        mockWindowManager.windowsToReturn = [window]

        viewModel.loadCurrentState()

        XCTAssertNotNil(viewModel.currentConfiguration)
        XCTAssertEqual(viewModel.currentConfiguration?.signature, config.signature)
        XCTAssertEqual(viewModel.allWindows.count, 1)
        XCTAssertNil(viewModel.error)
    }

    func testLoadStateWithError() {
        mockDisplayEnumerator.shouldThrowError = true

        viewModel.loadCurrentState()

        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.error?.contains("Failed to load state") ?? false)
    }

    func testRefresh() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        viewModel.refresh()

        XCTAssertNotNil(viewModel.currentConfiguration)
    }

    // MARK: - Preset Creation Tests

    func testCreatePreset() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let window = makeWindowInfo(title: "Test Window")
        mockWindowManager.windowsToReturn = [window]

        viewModel.loadCurrentState()

        XCTAssertEqual(viewModel.presets.count, 0)

        viewModel.createPreset(name: "Test Preset")

        XCTAssertEqual(viewModel.presets.count, 1)
        XCTAssertEqual(viewModel.presets.first?.name, "Test Preset")
        XCTAssertNil(viewModel.error)
    }

    func testCreatePresetWithFilter() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let window1 = makeWindowInfo(title: "Important")
        let window2 = makeWindowInfo(title: "Unimportant")
        mockWindowManager.windowsToReturn = [window1, window2]

        viewModel.loadCurrentState()

        viewModel.createPreset(name: "Filtered") { window in
            window.identifier.title.contains("Important")
        }

        XCTAssertEqual(viewModel.presets.count, 1)
        XCTAssertEqual(viewModel.presets.first?.windowCount, 1)
    }

    func testCreatePresetForApplications() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let app1 = ApplicationIdentifier(bundleIdentifier: "com.app1", name: "App 1")
        let app2 = ApplicationIdentifier(bundleIdentifier: "com.app2", name: "App 2")

        let window1 = makeWindowInfo(title: "Window 1", application: app1)
        let window2 = makeWindowInfo(title: "Window 2", application: app2)
        mockWindowManager.windowsToReturn = [window1, window2]

        viewModel.loadCurrentState()

        viewModel.createPreset(name: "App Specific", forApplications: ["com.app1"])

        XCTAssertEqual(viewModel.presets.count, 1)
        XCTAssertEqual(viewModel.presets.first?.windowCount, 1)
    }

    func testCreatePresetWithoutConfiguration() {
        viewModel.createPreset(name: "Test")

        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.error?.contains("No display configuration") ?? false)
    }

    // MARK: - Preset Management Tests

    func testDeletePreset() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let window = makeWindowInfo(title: "Test")
        mockWindowManager.windowsToReturn = [window]

        viewModel.loadCurrentState()
        viewModel.createPreset(name: "To Delete")

        XCTAssertEqual(viewModel.presets.count, 1)

        viewModel.deletePreset(viewModel.presets.first!)

        XCTAssertEqual(viewModel.presets.count, 0)
    }

    func testRenamePreset() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let window = makeWindowInfo(title: "Test")
        mockWindowManager.windowsToReturn = [window]

        viewModel.loadCurrentState()
        viewModel.createPreset(name: "Old Name")

        XCTAssertEqual(viewModel.presets.first?.name, "Old Name")

        viewModel.renamePreset(viewModel.presets.first!, to: "New Name")

        XCTAssertEqual(viewModel.presets.count, 1)
        XCTAssertEqual(viewModel.presets.first?.name, "New Name")
    }

    // MARK: - Preset Application Tests

    func testApplyPreset() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let app = ApplicationIdentifier(bundleIdentifier: "com.test", name: "Test")
        let windowID = WindowIdentifier(application: app, title: "Test")
        let window = WindowInfo(
            identifier: windowID,
            frame: WindowFrame(x: 0, y: 0, width: 800, height: 600),
            processID: 12345
        )
        mockWindowManager.windowsToReturn = [window]

        viewModel.loadCurrentState()
        viewModel.createPreset(name: "Test")

        let preset = viewModel.presets.first!
        viewModel.applyPreset(preset)

        XCTAssertNotNil(viewModel.lastApplyResult)
        XCTAssertNil(viewModel.error)
    }

    func testApplyPresetWithFailures() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let window = makeWindowInfo(title: "Test")
        mockWindowManager.windowsToReturn = [window]

        viewModel.loadCurrentState()
        viewModel.createPreset(name: "Test")

        // Remove windows so apply fails
        mockWindowManager.windowsToReturn = []

        let preset = viewModel.presets.first!
        viewModel.applyPreset(preset)

        XCTAssertNotNil(viewModel.lastApplyResult)
        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.error?.contains("failed to apply") ?? false)
    }

    func testSimulatePresetApplication() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let window = makeWindowInfo(title: "Test")
        mockWindowManager.windowsToReturn = [window]

        viewModel.loadCurrentState()
        viewModel.createPreset(name: "Test")

        let preset = viewModel.presets.first!
        let result = viewModel.simulatePresetApplication(preset)

        if case .valid = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected valid result")
        }
    }

    func testApplyCurrentPreset() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let window = makeWindowInfo(title: "Test")
        mockWindowManager.windowsToReturn = [window]

        viewModel.loadCurrentState()
        viewModel.createPreset(name: "Test")

        viewModel.applyCurrentPreset()

        XCTAssertNotNil(viewModel.lastApplyResult)
    }

    func testApplyCurrentPresetWithoutPresets() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        viewModel.loadCurrentState()

        viewModel.applyCurrentPreset()

        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.error?.contains("No presets available") ?? false)
    }

    // MARK: - Automation Tests

    func testToggleAutoApply() {
        XCTAssertFalse(viewModel.autoApplyEnabled)

        viewModel.toggleAutoApply()
        XCTAssertTrue(viewModel.autoApplyEnabled)

        viewModel.toggleAutoApply()
        XCTAssertFalse(viewModel.autoApplyEnabled)
    }

    func testSetAutoApplyDelay() {
        // Should not crash
        viewModel.setAutoApplyDelay(5.0)
    }

    // MARK: - Window Information Tests

    func testWindowsByApplication() {
        let app1 = ApplicationIdentifier(bundleIdentifier: "com.app1", name: "App 1")
        let app2 = ApplicationIdentifier(bundleIdentifier: "com.app2", name: "App 2")

        let window1 = makeWindowInfo(title: "Window 1", application: app1)
        let window2 = makeWindowInfo(title: "Window 2", application: app1)
        let window3 = makeWindowInfo(title: "Window 3", application: app2)

        mockWindowManager.windowsToReturn = [window1, window2, window3]

        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        viewModel.loadCurrentState()

        let grouped = viewModel.windowsByApplication

        XCTAssertEqual(grouped.count, 2)
        XCTAssertEqual(grouped[app1]?.count, 2)
        XCTAssertEqual(grouped[app2]?.count, 1)
    }

    func testApplicationsList() {
        let app1 = ApplicationIdentifier(bundleIdentifier: "com.app1", name: "App 1")
        let app2 = ApplicationIdentifier(bundleIdentifier: "com.app2", name: "App 2")

        let window1 = makeWindowInfo(title: "Window 1", application: app1)
        let window2 = makeWindowInfo(title: "Window 2", application: app2)

        mockWindowManager.windowsToReturn = [window1, window2]

        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        viewModel.loadCurrentState()

        let apps = viewModel.applications

        XCTAssertEqual(apps.count, 2)
        XCTAssertTrue(apps.contains(app1))
        XCTAssertTrue(apps.contains(app2))
    }

    // MARK: - Display Info Tests

    func testDisplayInfo() {
        let display1 = makeDisplay(name: "Display 1", isMain: true)
        let display2 = makeDisplay(name: "Display 2", isMain: false)
        let config = DisplayConfiguration(displays: [display1, display2])
        mockDisplayEnumerator.configurationToReturn = config

        viewModel.loadCurrentState()

        let displayInfo = viewModel.displayInfo

        XCTAssertEqual(displayInfo.count, 2)
        XCTAssertEqual(displayInfo[0].name, "Display 1")
        XCTAssertTrue(displayInfo[0].isMain)
        XCTAssertEqual(displayInfo[1].name, "Display 2")
        XCTAssertFalse(displayInfo[1].isMain)
    }

    func testDisplayInfoEmpty() {
        viewModel.loadCurrentState()

        let displayInfo = viewModel.displayInfo

        XCTAssertTrue(displayInfo.isEmpty)
    }

    // MARK: - Preset Info Tests

    func testGetPresetInfo() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let window = makeWindowInfo(title: "Test")
        mockWindowManager.windowsToReturn = [window]

        viewModel.loadCurrentState()
        viewModel.createPreset(name: "Test Preset")

        let preset = viewModel.presets.first!
        let info = viewModel.getPresetInfo(preset)

        XCTAssertEqual(info.name, "Test Preset")
        XCTAssertEqual(info.windowCount, 1)
        XCTAssertTrue(info.isValid)
    }

    // MARK: - Error Handling Tests

    func testClearError() {
        viewModel.createPreset(name: "Test")
        XCTAssertNotNil(viewModel.error)

        viewModel.clearError()
        XCTAssertNil(viewModel.error)
    }

    func testClearLastResult() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let window = makeWindowInfo(title: "Test")
        mockWindowManager.windowsToReturn = [window]

        viewModel.loadCurrentState()
        viewModel.createPreset(name: "Test")
        viewModel.applyPreset(viewModel.presets.first!)

        XCTAssertNotNil(viewModel.lastApplyResult)

        viewModel.clearLastResult()
        XCTAssertNil(viewModel.lastApplyResult)
    }

    // MARK: - Accessibility Tests

    func testCheckAccessibilityPermissions() {
        // Default mock returns true
        XCTAssertTrue(viewModel.checkAccessibilityPermissions())
    }

    func testRequestAccessibilityPermissions() {
        // Should not crash
        viewModel.requestAccessibilityPermissions()
    }

    // MARK: - Integration Tests

    func testFullWorkflow() {
        // Setup
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let window = makeWindowInfo(title: "Test Window")
        mockWindowManager.windowsToReturn = [window]

        // Load state
        viewModel.loadCurrentState()
        XCTAssertNotNil(viewModel.currentConfiguration)
        XCTAssertEqual(viewModel.allWindows.count, 1)

        // Create preset
        viewModel.createPreset(name: "My Layout")
        XCTAssertEqual(viewModel.presets.count, 1)

        // Apply preset
        viewModel.applyPreset(viewModel.presets.first!)
        XCTAssertNotNil(viewModel.lastApplyResult)

        // Enable auto-apply
        viewModel.toggleAutoApply()
        XCTAssertTrue(viewModel.autoApplyEnabled)

        // Disable auto-apply
        viewModel.toggleAutoApply()
        XCTAssertFalse(viewModel.autoApplyEnabled)
    }

    func testMultiplePresets() {
        let display = makeDisplay()
        let config = DisplayConfiguration(displays: [display])
        mockDisplayEnumerator.configurationToReturn = config

        let window = makeWindowInfo(title: "Test")
        mockWindowManager.windowsToReturn = [window]

        viewModel.loadCurrentState()

        // Create multiple presets
        viewModel.createPreset(name: "Preset 1")
        viewModel.createPreset(name: "Preset 2")
        viewModel.createPreset(name: "Preset 3")

        XCTAssertEqual(viewModel.presets.count, 3)

        // Delete one
        viewModel.deletePreset(viewModel.presets[1])
        XCTAssertEqual(viewModel.presets.count, 2)

        // Rename one
        viewModel.renamePreset(viewModel.presets.first!, to: "Updated Name")
        XCTAssertEqual(viewModel.presets.first?.name, "Updated Name")
    }

    // MARK: - Helpers

    private func makeDisplay(
        name: String = "Test Display",
        isMain: Bool = true
    ) -> DisplayIdentity {
        return DisplayIdentity(
            displayID: 1,
            serialNumber: "TEST",
            vendorID: 0x1234,
            modelID: 0x5678,
            name: name,
            bounds: DisplayBounds(x: 0, y: 0, width: 1920, height: 1080),
            scale: 1.0,
            isMain: isMain
        )
    }

    private func makeWindowInfo(
        title: String,
        application: ApplicationIdentifier? = nil
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
            frame: WindowFrame(x: 100, y: 100, width: 800, height: 600),
            processID: 12345
        )
    }
}
