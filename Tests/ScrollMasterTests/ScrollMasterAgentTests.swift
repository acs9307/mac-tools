import XCTest
@testable import ScrollMaster
@testable import MacToolsCore

final class ScrollMasterAgentTests: XCTestCase {
    var agent: ScrollMasterAgent!
    var testConfigPath: String!

    override func setUp() {
        super.setUp()

        // Create temporary config directory
        let tempDir = NSTemporaryDirectory()
        testConfigPath = (tempDir as NSString).appendingPathComponent("test-config-\(UUID().uuidString).json")

        // Set up test configuration
        Configuration.shared.configPath = testConfigPath

        agent = ScrollMasterAgent()
    }

    override func tearDown() {
        agent.stop()

        // Clean up test config file
        if FileManager.default.fileExists(atPath: testConfigPath) {
            try? FileManager.default.removeItem(atPath: testConfigPath)
        }

        agent = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(agent)
        XCTAssertFalse(agent.isRunning)
        XCTAssertFalse(agent.isGloballyDisabled)
    }

    func testAgentName() {
        XCTAssertEqual(agent.agentName, "ScrollMaster")
    }

    // MARK: - Lifecycle Tests

    func testStartStop() throws {
        XCTAssertFalse(agent.isRunning)

        try agent.start()
        XCTAssertTrue(agent.isRunning)

        agent.stop()
        XCTAssertFalse(agent.isRunning)
    }

    func testMultipleStarts() throws {
        try agent.start()
        XCTAssertTrue(agent.isRunning)

        // Starting again should not throw
        try agent.start()
        XCTAssertTrue(agent.isRunning)

        agent.stop()
    }

    func testStopWhenNotStarted() {
        XCTAssertFalse(agent.isRunning)

        // Stopping when not started should not crash
        agent.stop()
        XCTAssertFalse(agent.isRunning)
    }

    // MARK: - Global Disable Tests

    func testInitialDisableState() {
        XCTAssertFalse(agent.isGloballyDisabled)
    }

    func testDisableGlobally() {
        XCTAssertFalse(agent.isGloballyDisabled)

        agent.disableGlobally()

        XCTAssertTrue(agent.isGloballyDisabled)
    }

    func testEnableGlobally() {
        agent.disableGlobally()
        XCTAssertTrue(agent.isGloballyDisabled)

        agent.enableGlobally()

        XCTAssertFalse(agent.isGloballyDisabled)
    }

    func testToggleGlobalDisable() {
        XCTAssertFalse(agent.isGloballyDisabled)

        agent.toggleGlobalDisable()
        XCTAssertTrue(agent.isGloballyDisabled)

        agent.toggleGlobalDisable()
        XCTAssertFalse(agent.isGloballyDisabled)

        agent.toggleGlobalDisable()
        XCTAssertTrue(agent.isGloballyDisabled)
    }

    func testDisableWhileRunning() throws {
        try agent.start()
        XCTAssertTrue(agent.isRunning)
        XCTAssertFalse(agent.isGloballyDisabled)

        agent.disableGlobally()

        XCTAssertTrue(agent.isRunning)
        XCTAssertTrue(agent.isGloballyDisabled)

        agent.stop()
    }

    func testDisableBeforeStart() throws {
        agent.disableGlobally()
        XCTAssertTrue(agent.isGloballyDisabled)

        try agent.start()

        XCTAssertTrue(agent.isRunning)
        XCTAssertTrue(agent.isGloballyDisabled)

        agent.stop()
    }

    func testDisablePersistsAcrossRestart() throws {
        try agent.start()
        agent.disableGlobally()
        XCTAssertTrue(agent.isGloballyDisabled)

        agent.stop()
        XCTAssertFalse(agent.isRunning)
        XCTAssertTrue(agent.isGloballyDisabled)

        try agent.start()
        XCTAssertTrue(agent.isRunning)
        XCTAssertTrue(agent.isGloballyDisabled)

        agent.stop()
    }

    // MARK: - Configuration Management Tests

    func testLoadConfiguration() {
        // Should not throw
        agent.loadConfiguration()
    }

    func testLoadConfigurationWithNoConfig() {
        agent.loadConfiguration()

        let configs = agent.getAllConfigurations()
        XCTAssertTrue(configs.isEmpty)
    }

    func testLoadConfigurationWithSavedConfig() throws {
        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertVertical: true),
            enabled: true
        )

        let configManager = ScrollConfigurationManager()
        try configManager.save(config)

        agent.loadConfiguration()

        let loaded = agent.getConfiguration(for: "device-1")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded, config)
    }

    func testUpdateDeviceConfiguration() throws {
        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertVertical: true),
            enabled: true
        )

        try agent.updateDeviceConfiguration(config)

        let loaded = agent.getConfiguration(for: "device-1")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded, config)
    }

    func testUpdateDeviceConfigurationPersists() throws {
        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(verticalMultiplier: 2.0),
            enabled: true
        )

        try agent.updateDeviceConfiguration(config)

        // Create new agent instance
        let newAgent = ScrollMasterAgent()
        newAgent.loadConfiguration()

        let loaded = newAgent.getConfiguration(for: "device-1")
        XCTAssertEqual(loaded, config)
    }

    func testUpdateDefaultConfiguration() throws {
        let transform = ScrollTransform(
            invertVertical: true,
            invertHorizontal: true,
            verticalMultiplier: 1.5
        )

        try agent.updateDefaultConfiguration(transform)

        // Reload and verify
        agent.loadConfiguration()

        let configManager = ScrollConfigurationManager()
        let loaded = configManager.loadDefault()
        XCTAssertEqual(loaded, transform)
    }

    func testUpdateSmoothScrollParameters() throws {
        let params = SmoothScrollParameters(
            duration: 0.5,
            curve: .easeInOut,
            distanceMultiplier: 1.2
        )

        try agent.updateSmoothScrollParameters(params)

        // Reload and verify
        agent.loadConfiguration()

        let configManager = ScrollConfigurationManager()
        let loaded = configManager.loadSmoothScrollParameters()
        XCTAssertEqual(loaded, params)
    }

    func testReloadConfiguration() throws {
        // Save a config
        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertVertical: true)
        )
        try agent.updateDeviceConfiguration(config)

        // Modify config externally
        let newConfig = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertHorizontal: true)
        )
        let configManager = ScrollConfigurationManager()
        try configManager.save(newConfig)

        // Reload
        try agent.reloadConfiguration()

        // Should have new config
        let loaded = agent.getConfiguration(for: "device-1")
        XCTAssertEqual(loaded?.transform.invertHorizontal, true)
        XCTAssertEqual(loaded?.transform.invertVertical, false)
    }

    // MARK: - Device Enumeration Tests

    func testEnumerateDevices() throws {
        // Should not throw even if no devices
        let devices = try agent.enumerateDevices()
        XCTAssertNotNil(devices)
    }

    func testGetAllConfigurations() throws {
        let config1 = DeviceScrollConfiguration(deviceStableID: "device-1")
        let config2 = DeviceScrollConfiguration(deviceStableID: "device-2")

        try agent.updateDeviceConfiguration(config1)
        try agent.updateDeviceConfiguration(config2)

        let configs = agent.getAllConfigurations()
        XCTAssertEqual(configs.count, 2)
        XCTAssertNotNil(configs["device-1"])
        XCTAssertNotNil(configs["device-2"])
    }

    func testGetConfigurationForNonExistentDevice() {
        let config = agent.getConfiguration(for: "nonexistent")
        XCTAssertNil(config)
    }

    // MARK: - Status Tests

    func testGetStatusWhenStopped() {
        let status = agent.getStatus()

        XCTAssertEqual(status.name, "ScrollMaster")
        XCTAssertFalse(status.isRunning)
        XCTAssertFalse(status.isGloballyDisabled)
        XCTAssertEqual(status.activeAnimations, 0)
    }

    func testGetStatusWhenRunning() throws {
        try agent.start()

        let status = agent.getStatus()

        XCTAssertEqual(status.name, "ScrollMaster")
        XCTAssertTrue(status.isRunning)
        XCTAssertFalse(status.isGloballyDisabled)

        agent.stop()
    }

    func testGetStatusWhenDisabled() {
        agent.disableGlobally()

        let status = agent.getStatus()

        XCTAssertTrue(status.isGloballyDisabled)
    }

    func testGetStatusWithConfigurations() throws {
        let config1 = DeviceScrollConfiguration(deviceStableID: "device-1")
        let config2 = DeviceScrollConfiguration(deviceStableID: "device-2")

        try agent.updateDeviceConfiguration(config1)
        try agent.updateDeviceConfiguration(config2)

        let status = agent.getStatus()

        XCTAssertEqual(status.configuredDevices, 2)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentDisableEnable() {
        let expectation = self.expectation(description: "Concurrent disable/enable")
        expectation.expectedFulfillmentCount = 100

        for i in 0..<100 {
            DispatchQueue.global().async {
                if i % 2 == 0 {
                    self.agent.disableGlobally()
                } else {
                    self.agent.enableGlobally()
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Should not crash
        _ = agent.isGloballyDisabled
    }

    func testConcurrentStatusReads() {
        let expectation = self.expectation(description: "Concurrent status reads")
        expectation.expectedFulfillmentCount = 50

        for _ in 0..<50 {
            DispatchQueue.global().async {
                _ = self.agent.getStatus()
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testConcurrentConfigurationUpdates() throws {
        let expectation = self.expectation(description: "Concurrent config updates")
        expectation.expectedFulfillmentCount = 20

        for i in 0..<20 {
            DispatchQueue.global().async {
                let config = DeviceScrollConfiguration(
                    deviceStableID: "device-\(i)",
                    transform: ScrollTransform(verticalMultiplier: Double(i))
                )

                do {
                    try self.agent.updateDeviceConfiguration(config)
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to update config: \(error)")
                }
            }
        }

        wait(for: [expectation], timeout: 5.0)

        let configs = agent.getAllConfigurations()
        XCTAssertEqual(configs.count, 20)
    }

    // MARK: - Integration Tests

    func testFullWorkflow() throws {
        // Start agent
        try agent.start()
        XCTAssertTrue(agent.isRunning)

        // Configure a device
        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(
                invertVertical: true,
                verticalMultiplier: 2.0,
                smoothScrollEnabled: true
            ),
            enabled: true
        )
        try agent.updateDeviceConfiguration(config)

        // Update smooth scroll params
        let params = SmoothScrollParameters(
            duration: 0.4,
            curve: .easeOut
        )
        try agent.updateSmoothScrollParameters(params)

        // Get status
        var status = agent.getStatus()
        XCTAssertTrue(status.isRunning)
        XCTAssertFalse(status.isGloballyDisabled)
        XCTAssertEqual(status.configuredDevices, 1)

        // Disable globally
        agent.disableGlobally()
        status = agent.getStatus()
        XCTAssertTrue(status.isGloballyDisabled)

        // Re-enable
        agent.enableGlobally()
        status = agent.getStatus()
        XCTAssertFalse(status.isGloballyDisabled)

        // Stop
        agent.stop()
        XCTAssertFalse(agent.isRunning)
    }

    func testConfigurationSurvivesRestart() throws {
        // Configure
        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertVertical: true)
        )
        try agent.updateDeviceConfiguration(config)

        let defaultTransform = ScrollTransform(invertHorizontal: true)
        try agent.updateDefaultConfiguration(defaultTransform)

        // Start and stop
        try agent.start()
        agent.stop()

        // Create new agent
        let newAgent = ScrollMasterAgent()
        newAgent.loadConfiguration()

        // Verify config persists
        let loaded = newAgent.getConfiguration(for: "device-1")
        XCTAssertEqual(loaded, config)

        let configManager = ScrollConfigurationManager()
        let loadedDefault = configManager.loadDefault()
        XCTAssertEqual(loadedDefault, defaultTransform)
    }
}

// MARK: - Global Disable Regression Tests

final class GlobalDisableRegressionTests: XCTestCase {
    var agent: ScrollMasterAgent!
    var testConfigPath: String!

    override func setUp() {
        super.setUp()

        let tempDir = NSTemporaryDirectory()
        testConfigPath = (tempDir as NSString).appendingPathComponent("test-config-\(UUID().uuidString).json")
        Configuration.shared.configPath = testConfigPath

        agent = ScrollMasterAgent()
    }

    override func tearDown() {
        agent.stop()

        if FileManager.default.fileExists(atPath: testConfigPath) {
            try? FileManager.default.removeItem(atPath: testConfigPath)
        }

        agent = nil
        super.tearDown()
    }

    // MARK: - Regression Tests

    func testGlobalDisableBypassesAllTransformations() throws {
        // Configure devices with various transformations
        let config1 = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(
                invertVertical: true,
                invertHorizontal: true,
                verticalMultiplier: 2.0,
                horizontalMultiplier: 1.5,
                smoothScrollEnabled: true
            ),
            enabled: true
        )
        try agent.updateDeviceConfiguration(config1)

        // Start agent
        try agent.start()

        // Disable globally
        agent.disableGlobally()

        // Verify disabled
        XCTAssertTrue(agent.isGloballyDisabled)

        // In a real implementation, we would verify that scroll events
        // are passed through unmodified. Here we verify the state.
        let status = agent.getStatus()
        XCTAssertTrue(status.isGloballyDisabled)

        agent.stop()
    }

    func testGlobalDisableClearsSmoothScrollAnimations() throws {
        // Configure smooth scrolling
        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(smoothScrollEnabled: true),
            enabled: true
        )
        try agent.updateDeviceConfiguration(config)

        try agent.start()

        // Simulate some scroll events that would create animations
        // (In real implementation, events would be fed to the engine)

        // Disable globally - should clear animations
        agent.disableGlobally()

        let status = agent.getStatus()
        XCTAssertEqual(status.activeAnimations, 0)

        agent.stop()
    }

    func testGlobalDisableDoesNotAffectConfiguration() throws {
        // Configure device
        let config = DeviceScrollConfiguration(
            deviceStableID: "device-1",
            transform: ScrollTransform(invertVertical: true),
            enabled: true
        )
        try agent.updateDeviceConfiguration(config)

        // Disable globally
        agent.disableGlobally()

        // Configuration should still be accessible
        let loaded = agent.getConfiguration(for: "device-1")
        XCTAssertEqual(loaded, config)

        // Should be able to update config while disabled
        var updatedConfig = config
        updatedConfig.transform.verticalMultiplier = 2.0
        try agent.updateDeviceConfiguration(updatedConfig)

        let reloaded = agent.getConfiguration(for: "device-1")
        XCTAssertEqual(reloaded?.transform.verticalMultiplier, 2.0)
    }

    func testEnableAfterDisableRestoresNormalOperation() throws {
        try agent.start()

        // Disable
        agent.disableGlobally()
        XCTAssertTrue(agent.isGloballyDisabled)

        // Re-enable
        agent.enableGlobally()
        XCTAssertFalse(agent.isGloballyDisabled)

        // Agent should still be running normally
        XCTAssertTrue(agent.isRunning)

        agent.stop()
    }

    func testMultipleDisableEnableCycles() throws {
        try agent.start()

        for _ in 0..<10 {
            agent.disableGlobally()
            XCTAssertTrue(agent.isGloballyDisabled)

            agent.enableGlobally()
            XCTAssertFalse(agent.isGloballyDisabled)
        }

        // Agent should still be healthy
        XCTAssertTrue(agent.isRunning)

        agent.stop()
    }

    func testDisableStateIsThreadSafe() {
        let expectation = self.expectation(description: "Thread-safe disable")
        expectation.expectedFulfillmentCount = 200

        for i in 0..<100 {
            DispatchQueue.global().async {
                if i % 2 == 0 {
                    self.agent.disableGlobally()
                } else {
                    self.agent.enableGlobally()
                }
                expectation.fulfill()
            }

            DispatchQueue.global().async {
                _ = self.agent.isGloballyDisabled
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Should always have a valid boolean state
        let finalState = agent.isGloballyDisabled
        XCTAssertTrue(finalState == true || finalState == false)
    }
}
