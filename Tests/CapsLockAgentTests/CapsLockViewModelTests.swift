import XCTest
@testable import CapsLockAgent
@testable import MacToolsCore

@MainActor
final class CapsLockViewModelTests: XCTestCase {
    var viewModel: CapsLockViewModel!
    var testConfigPath: String!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary config directory
        let tempDir = NSTemporaryDirectory()
        testConfigPath = (tempDir as NSString).appendingPathComponent("test-config-\(UUID().uuidString).json")

        // Set up test configuration
        Configuration.shared.configPath = testConfigPath

        viewModel = CapsLockViewModel()
    }

    override func tearDown() async throws {
        // Clean up test config file
        if FileManager.default.fileExists(atPath: testConfigPath) {
            try? FileManager.default.removeItem(atPath: testConfigPath)
        }

        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        XCTAssertNotNil(viewModel)
        // Should load default configuration
        XCTAssertTrue(viewModel.enabled)
        XCTAssertEqual(viewModel.minPressDuration, 0.2, accuracy: 0.01)
        XCTAssertTrue(viewModel.disableCapsLock)
    }

    func testInitialKeyActions() {
        // Default quick tap should be Escape
        if case .sendKey(53) = viewModel.quickTapAction {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected quick tap to be Escape")
        }

        // Default long press should be Control
        if case .sendModifier(.control) = viewModel.longPressAction {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected long press to be Control")
        }
    }

    // MARK: - Configuration Management Tests

    func testLoadConfiguration() {
        viewModel.loadConfiguration()

        XCTAssertNil(viewModel.error)
        XCTAssertNotNil(viewModel)
    }

    func testSaveConfiguration() {
        viewModel.enabled = false
        viewModel.minPressDuration = 0.5

        viewModel.saveConfiguration()

        XCTAssertNil(viewModel.error)

        // Verify saved by creating new view model
        let newViewModel = CapsLockViewModel()
        XCTAssertFalse(newViewModel.enabled)
        XCTAssertEqual(newViewModel.minPressDuration, 0.5, accuracy: 0.01)
    }

    func testApplyConfiguration() async {
        viewModel.enabled = false
        viewModel.minPressDuration = 0.3

        viewModel.applyConfiguration()

        // Give async task time to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        XCTAssertNil(viewModel.error)
    }

    // MARK: - Toggle Tests

    func testToggleEnabled() {
        let initialState = viewModel.enabled

        viewModel.toggleEnabled()

        XCTAssertEqual(viewModel.enabled, !initialState)
        XCTAssertNil(viewModel.error)
    }

    func testToggleDisableCapsLock() {
        let initialState = viewModel.disableCapsLock

        viewModel.toggleDisableCapsLock()

        XCTAssertEqual(viewModel.disableCapsLock, !initialState)
        XCTAssertNil(viewModel.error)
    }

    // MARK: - Delay Adjustment Tests

    func testSetMinPressDuration() {
        viewModel.setMinPressDuration(0.5)

        XCTAssertEqual(viewModel.minPressDuration, 0.5, accuracy: 0.01)
        XCTAssertNil(viewModel.error)
    }

    func testSetMinPressDurationClampMin() {
        viewModel.setMinPressDuration(0.01) // Too small

        XCTAssertEqual(viewModel.minPressDuration, 0.05, accuracy: 0.01) // Clamped to min
    }

    func testSetMinPressDurationClampMax() {
        viewModel.setMinPressDuration(5.0) // Too large

        XCTAssertEqual(viewModel.minPressDuration, 2.0, accuracy: 0.01) // Clamped to max
    }

    func testIncrementDelay() {
        viewModel.minPressDuration = 0.2

        viewModel.incrementDelay()

        XCTAssertEqual(viewModel.minPressDuration, 0.25, accuracy: 0.01)
    }

    func testDecrementDelay() {
        viewModel.minPressDuration = 0.2

        viewModel.decrementDelay()

        XCTAssertEqual(viewModel.minPressDuration, 0.15, accuracy: 0.01)
    }

    func testIncrementDelayDoesNotExceedMax() {
        viewModel.minPressDuration = 2.0

        viewModel.incrementDelay()

        XCTAssertEqual(viewModel.minPressDuration, 2.0, accuracy: 0.01) // Should stay at max
    }

    func testDecrementDelayDoesNotGoBelowMin() {
        viewModel.minPressDuration = 0.05

        viewModel.decrementDelay()

        XCTAssertEqual(viewModel.minPressDuration, 0.05, accuracy: 0.01) // Should stay at min
    }

    // MARK: - Key Action Tests

    func testSetQuickTapAction() {
        viewModel.setQuickTapAction(.sendKey(51)) // Delete

        if case .sendKey(51) = viewModel.quickTapAction {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected quick tap to be Delete")
        }

        XCTAssertNil(viewModel.error)
    }

    func testSetLongPressAction() {
        viewModel.setLongPressAction(.sendModifier(.command))

        if case .sendModifier(.command) = viewModel.longPressAction {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected long press to be Command")
        }

        XCTAssertNil(viewModel.error)
    }

    func testSetQuickTapActionDisabled() {
        viewModel.setQuickTapAction(.disabled)

        if case .disabled = viewModel.quickTapAction {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected quick tap to be disabled")
        }
    }

    // MARK: - Agent Control Tests

    func testStartAgent() {
        // Note: This will fail in a test environment without proper setup
        // but we test that it doesn't crash
        viewModel.startAgent()

        // Should either start or set error
        XCTAssertTrue(viewModel.isAgentRunning || viewModel.error != nil)
    }

    func testStopAgent() {
        viewModel.stopAgent()

        XCTAssertFalse(viewModel.isAgentRunning)
    }

    func testRestartAgent() {
        viewModel.restartAgent()

        // Should attempt restart
        XCTAssertTrue(viewModel.isAgentRunning || viewModel.error != nil)
    }

    // MARK: - Permissions Tests

    func testCheckPermissions() {
        viewModel.checkPermissions()

        // In test environment, should have placeholder value
        XCTAssertTrue(viewModel.hasAccessibilityPermissions)
    }

    func testRequestPermissions() {
        viewModel.requestPermissions()

        // Should not crash
        XCTAssertNotNil(viewModel)
    }

    // MARK: - Error Handling Tests

    func testClearError() {
        // Set an error manually
        viewModel.error = "Test error"

        viewModel.clearError()

        XCTAssertNil(viewModel.error)
    }

    // MARK: - Status Tests

    func testStatusDescriptionWhenActive() {
        viewModel.hasAccessibilityPermissions = true
        viewModel.isAgentRunning = true
        viewModel.enabled = true

        XCTAssertEqual(viewModel.statusDescription, "Active")
    }

    func testStatusDescriptionWhenDisabled() {
        viewModel.hasAccessibilityPermissions = true
        viewModel.isAgentRunning = true
        viewModel.enabled = false

        XCTAssertEqual(viewModel.statusDescription, "Disabled")
    }

    func testStatusDescriptionWhenAgentNotRunning() {
        viewModel.hasAccessibilityPermissions = true
        viewModel.isAgentRunning = false

        XCTAssertEqual(viewModel.statusDescription, "Agent Not Running")
    }

    func testStatusDescriptionWhenPermissionsRequired() {
        viewModel.hasAccessibilityPermissions = false

        XCTAssertEqual(viewModel.statusDescription, "Permissions Required")
    }

    func testStatusColorActive() {
        viewModel.hasAccessibilityPermissions = true
        viewModel.isAgentRunning = true
        viewModel.enabled = true

        XCTAssertEqual(viewModel.statusColor, .active)
    }

    func testStatusColorInactive() {
        viewModel.hasAccessibilityPermissions = true
        viewModel.isAgentRunning = true
        viewModel.enabled = false

        XCTAssertEqual(viewModel.statusColor, .inactive)
    }

    func testStatusColorError() {
        viewModel.hasAccessibilityPermissions = true
        viewModel.isAgentRunning = false

        XCTAssertEqual(viewModel.statusColor, .error)
    }

    func testStatusColorWarning() {
        viewModel.hasAccessibilityPermissions = false

        XCTAssertEqual(viewModel.statusColor, .warning)
    }

    // MARK: - Key Action Helper Tests

    func testAvailableQuickTapActions() {
        let actions = CapsLockViewModel.availableQuickTapActions

        XCTAssertFalse(actions.isEmpty)
        XCTAssertTrue(actions.contains { $0.name == "Escape" })
        XCTAssertTrue(actions.contains { $0.name == "Delete" })
        XCTAssertTrue(actions.contains { $0.name == "Control" })
        XCTAssertTrue(actions.contains { $0.name == "Disabled" })
    }

    func testAvailableLongPressActions() {
        let actions = CapsLockViewModel.availableLongPressActions

        XCTAssertFalse(actions.isEmpty)
        XCTAssertTrue(actions.contains { $0.name == "Control" })
        XCTAssertTrue(actions.contains { $0.name == "Command" })
        XCTAssertTrue(actions.contains { $0.name == "Option" })
        XCTAssertTrue(actions.contains { $0.name == "Disabled" })
    }

    func testNameForActionEscape() {
        let name = viewModel.nameForAction(.sendKey(53))
        XCTAssertEqual(name, "Escape")
    }

    func testNameForActionDelete() {
        let name = viewModel.nameForAction(.sendKey(51))
        XCTAssertEqual(name, "Delete")
    }

    func testNameForActionControl() {
        let name = viewModel.nameForAction(.sendModifier(.control))
        XCTAssertEqual(name, "Control")
    }

    func testNameForActionCommand() {
        let name = viewModel.nameForAction(.sendModifier(.command))
        XCTAssertEqual(name, "Command")
    }

    func testNameForActionDisabled() {
        let name = viewModel.nameForAction(.disabled)
        XCTAssertEqual(name, "Disabled")
    }

    func testNameForUnknownAction() {
        let name = viewModel.nameForAction(.sendKey(999))
        XCTAssertEqual(name, "Custom")
    }

    // MARK: - Integration Tests

    func testFullWorkflow() {
        // Load configuration
        viewModel.loadConfiguration()
        XCTAssertNil(viewModel.error)

        // Modify settings
        viewModel.enabled = false
        viewModel.minPressDuration = 0.5
        viewModel.disableCapsLock = false
        viewModel.quickTapAction = .sendKey(51)
        viewModel.longPressAction = .sendModifier(.command)

        // Save
        viewModel.saveConfiguration()
        XCTAssertNil(viewModel.error)

        // Verify by creating new view model
        let newViewModel = CapsLockViewModel()
        XCTAssertFalse(newViewModel.enabled)
        XCTAssertEqual(newViewModel.minPressDuration, 0.5, accuracy: 0.01)
        XCTAssertFalse(newViewModel.disableCapsLock)
    }

    func testConfigurationPersistence() {
        // Set specific configuration
        viewModel.minPressDuration = 0.75
        viewModel.enabled = false
        viewModel.saveConfiguration()

        // Create new instance
        let newViewModel = CapsLockViewModel()

        // Should load saved configuration
        XCTAssertEqual(newViewModel.minPressDuration, 0.75, accuracy: 0.01)
        XCTAssertFalse(newViewModel.enabled)
    }

    func testMultipleDelayAdjustments() {
        viewModel.minPressDuration = 0.2

        viewModel.incrementDelay()
        XCTAssertEqual(viewModel.minPressDuration, 0.25, accuracy: 0.01)

        viewModel.incrementDelay()
        XCTAssertEqual(viewModel.minPressDuration, 0.3, accuracy: 0.01)

        viewModel.decrementDelay()
        XCTAssertEqual(viewModel.minPressDuration, 0.25, accuracy: 0.01)

        viewModel.setMinPressDuration(1.0)
        XCTAssertEqual(viewModel.minPressDuration, 1.0, accuracy: 0.01)
    }
}
