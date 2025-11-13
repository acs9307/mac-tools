import XCTest
@testable import CapsLockAgent
@testable import MacToolsCore

final class CapsLockAgentTests: XCTestCase {
    func testInitialization() {
        let agent = CapsLockAgent()

        XCTAssertEqual(agent.identifier, "com.mactools.capslock")
        XCTAssertEqual(agent.name, "Caps Lock Agent")
        XCTAssertFalse(agent.isRunning)
    }

    func testInitializationWithCustomConfiguration() {
        let config = CapsLockConfiguration(
            enabled: false,
            minPressDuration: 0.5,
            quickTapAction: .disabled,
            longPressAction: .sendKey(42),
            disableCapsLock: false
        )

        let agent = CapsLockAgent(configuration: config)

        XCTAssertEqual(agent.getConfiguration(), config)
    }

    func testGetConfiguration() {
        let config = CapsLockConfiguration.default
        let agent = CapsLockAgent(configuration: config)

        let retrievedConfig = agent.getConfiguration()

        XCTAssertEqual(retrievedConfig, config)
    }

    func testUpdateConfiguration() async throws {
        let agent = CapsLockAgent()
        let originalConfig = agent.getConfiguration()

        let newConfig = CapsLockConfiguration(
            enabled: false,
            minPressDuration: 0.3,
            quickTapAction: .sendKey(42),
            longPressAction: .sendModifier(.option),
            disableCapsLock: true
        )

        try await agent.updateConfiguration(newConfig)

        let updatedConfig = agent.getConfiguration()
        XCTAssertEqual(updatedConfig, newConfig)
        XCTAssertNotEqual(updatedConfig, originalConfig)
    }

    func testConfigureViaBaseMethod() async throws {
        let agent = CapsLockAgent()

        let config: [String: Any] = [
            "enabled": false,
            "minPressDuration": 0.4
        ]

        try await agent.configure(config)

        let updatedConfig = agent.getConfiguration()
        XCTAssertFalse(updatedConfig.enabled)
        XCTAssertEqual(updatedConfig.minPressDuration, 0.4)
    }

    func testConfigureWithPartialConfig() async throws {
        let agent = CapsLockAgent()
        let originalConfig = agent.getConfiguration()

        // Only change one property
        let config: [String: Any] = [
            "minPressDuration": 0.15
        ]

        try await agent.configure(config)

        let updatedConfig = agent.getConfiguration()
        XCTAssertEqual(updatedConfig.enabled, originalConfig.enabled) // Unchanged
        XCTAssertEqual(updatedConfig.minPressDuration, 0.15) // Changed
    }

    func testStartWithDisabledConfiguration() async throws {
        let config = CapsLockConfiguration(enabled: false)
        let agent = CapsLockAgent(configuration: config)

        // Starting with disabled configuration should succeed without creating event tap
        // (which would fail in test environment due to missing permissions)
        try await agent.start()

        XCTAssertTrue(agent.isRunning)
    }

    func testStopAgent() async throws {
        let config = CapsLockConfiguration(enabled: false)
        let agent = CapsLockAgent(configuration: config)

        try await agent.start()
        XCTAssertTrue(agent.isRunning)

        try await agent.stop()
        XCTAssertFalse(agent.isRunning)
    }

    func testMultipleStopsCausesNoError() async throws {
        let config = CapsLockConfiguration(enabled: false)
        let agent = CapsLockAgent(configuration: config)

        try await agent.start()
        try await agent.stop()

        // Should not throw
        try await agent.stop()
    }

    func testUpdateConfigurationWhileRunning() async throws {
        let agent = CapsLockAgent(configuration: CapsLockConfiguration(enabled: false))
        try await agent.start()

        let newConfig = CapsLockConfiguration(
            enabled: false,
            minPressDuration: 0.5
        )

        // Should succeed
        try await agent.updateConfiguration(newConfig)

        XCTAssertEqual(agent.getConfiguration().minPressDuration, 0.5)
    }

    func testUpdateConfigurationEnableWhileNotRunning() async throws {
        let agent = CapsLockAgent(configuration: CapsLockConfiguration(enabled: false))

        let newConfig = CapsLockConfiguration(enabled: true)

        // Updating to enabled while not running should attempt to start
        // In test environment this may fail due to permissions, so we catch the error
        do {
            try await agent.updateConfiguration(newConfig)
        } catch {
            // Expected in test environment without Accessibility permissions
            XCTAssertTrue(error is EventTapError)
        }
    }

    func testUpdateConfigurationDisableWhileRunning() async throws {
        let agent = CapsLockAgent(configuration: CapsLockConfiguration(enabled: false))
        try await agent.start()

        let newConfig = CapsLockConfiguration(enabled: false)

        try await agent.updateConfiguration(newConfig)

        // Should stop the agent
        XCTAssertFalse(agent.isRunning)
    }

    func testAgentIdentifierAndName() {
        let agent = CapsLockAgent()

        XCTAssertEqual(agent.identifier, "com.mactools.capslock")
        XCTAssertEqual(agent.name, "Caps Lock Agent")
    }

    func testDefaultConfigurationIsUsed() {
        let agent = CapsLockAgent()
        let config = agent.getConfiguration()

        XCTAssertEqual(config, CapsLockConfiguration.default)
    }
}
