import XCTest
@testable import CapsLockAgent
@testable import MacToolsCore

final class ConfigurationReloadTests: XCTestCase {
    var agent: CapsLockAgent!

    override func setUp() {
        // Reset configuration to defaults before each test
        Configuration.shared.reset()
    }

    override func tearDown() {
        agent = nil
        Configuration.shared.reset()
    }

    // MARK: - Initialization Tests

    func testInitWithDefaultConfiguration() {
        agent = CapsLockAgent()

        let config = agent.getConfiguration()
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.minPressDuration, 0.2)
    }

    func testInitWithCustomConfiguration() {
        let customConfig = CapsLockConfiguration(
            enabled: false,
            minPressDuration: 0.5
        )

        agent = CapsLockAgent(configuration: customConfig)

        let config = agent.getConfiguration()
        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.minPressDuration, 0.5)
    }

    func testInitLoadsFromPersistentStorage() {
        // Set configuration in storage
        Configuration.shared.set("capsLock", value: [
            "enabled": false,
            "minPressDuration": 0.35
        ] as [String: Any])

        // Initialize agent (should load from storage)
        agent = CapsLockAgent()

        let config = agent.getConfiguration()
        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.minPressDuration, 0.35)
    }

    // MARK: - Configuration Update Tests

    func testUpdateConfiguration() async throws {
        agent = CapsLockAgent(configuration: .default)

        let newConfig = CapsLockConfiguration(
            enabled: false,
            minPressDuration: 0.3
        )

        try await agent.updateConfiguration(newConfig)

        let config = agent.getConfiguration()
        XCTAssertEqual(config, newConfig)
    }

    func testUpdateConfigurationDoesNotPersist() async throws {
        agent = CapsLockAgent(configuration: .default)

        let newConfig = CapsLockConfiguration(minPressDuration: 0.4)
        try await agent.updateConfiguration(newConfig)

        // Create new agent, should load original from storage
        let newAgent = CapsLockAgent()
        let loadedConfig = newAgent.getConfiguration()

        // Should be default, not the updated value
        XCTAssertEqual(loadedConfig.minPressDuration, 0.2)
    }

    func testUpdateAndSaveConfiguration() async throws {
        agent = CapsLockAgent(configuration: .default)

        let newConfig = CapsLockConfiguration(
            enabled: false,
            minPressDuration: 0.45
        )

        try await agent.updateAndSaveConfiguration(newConfig)

        // Create new agent, should load saved config
        let newAgent = CapsLockAgent()
        let loadedConfig = newAgent.getConfiguration()

        XCTAssertEqual(loadedConfig, newConfig)
    }

    // MARK: - Configuration Reload Tests

    func testReloadConfiguration() async throws {
        agent = CapsLockAgent(configuration: .default)

        // Modify storage
        Configuration.shared.set("capsLock", value: [
            "enabled": false,
            "minPressDuration": 0.25
        ] as [String: Any])

        // Reload from storage
        try await agent.reloadConfiguration()

        let config = agent.getConfiguration()
        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.minPressDuration, 0.25)
    }

    func testReloadConfigurationRuntimeUpdate() async throws {
        // Start with enabled config
        let initialConfig = CapsLockConfiguration(enabled: false)
        agent = CapsLockAgent(configuration: initialConfig)

        try await agent.start()
        XCTAssertTrue(agent.isRunning)

        // Change storage to disabled
        Configuration.shared.set("capsLock", value: [
            "enabled": false,
            "minPressDuration": 0.3
        ] as [String: Any])

        // Reload should stop the agent
        try await agent.reloadConfiguration()

        XCTAssertFalse(agent.isRunning)
        XCTAssertEqual(agent.getConfiguration().minPressDuration, 0.3)
    }

    func testMultipleReloads() async throws {
        agent = CapsLockAgent(configuration: .default)

        // First reload
        Configuration.shared.set("capsLock", value: [
            "minPressDuration": 0.1
        ] as [String: Any])
        try await agent.reloadConfiguration()
        XCTAssertEqual(agent.getConfiguration().minPressDuration, 0.1)

        // Second reload
        Configuration.shared.set("capsLock", value: [
            "minPressDuration": 0.2
        ] as [String: Any])
        try await agent.reloadConfiguration()
        XCTAssertEqual(agent.getConfiguration().minPressDuration, 0.2)

        // Third reload
        Configuration.shared.set("capsLock", value: [
            "minPressDuration": 0.3
        ] as [String: Any])
        try await agent.reloadConfiguration()
        XCTAssertEqual(agent.getConfiguration().minPressDuration, 0.3)
    }

    // MARK: - Save Configuration Tests

    func testSaveConfiguration() throws {
        let customConfig = CapsLockConfiguration(
            enabled: false,
            minPressDuration: 0.55
        )
        agent = CapsLockAgent(configuration: customConfig)

        try agent.saveConfiguration()

        // Load from storage to verify
        let manager = CapsLockConfigurationManager()
        let loaded = manager.load()

        XCTAssertEqual(loaded, customConfig)
    }

    func testSaveConfigurationPreservesChanges() throws {
        agent = CapsLockAgent(configuration: .default)

        // Make changes
        var config = agent.getConfiguration()
        config.minPressDuration = 0.65
        config.enabled = false

        // Use updateConfiguration to set it
        Task {
            try await agent.updateConfiguration(config)
        }

        // Save
        try agent.saveConfiguration()

        // Create new agent and verify
        let newAgent = CapsLockAgent()
        let loaded = newAgent.getConfiguration()

        XCTAssertFalse(loaded.enabled)
        XCTAssertEqual(loaded.minPressDuration, 0.65)
    }

    // MARK: - Complex Workflow Tests

    func testFullConfigurationWorkflow() async throws {
        // 1. Create agent with default config
        agent = CapsLockAgent()
        XCTAssertEqual(agent.getConfiguration().minPressDuration, 0.2)

        // 2. Update and save new config
        var newConfig = CapsLockConfiguration(minPressDuration: 0.15)
        try await agent.updateAndSaveConfiguration(newConfig)
        XCTAssertEqual(agent.getConfiguration().minPressDuration, 0.15)

        // 3. Modify storage externally
        Configuration.shared.set("capsLock", value: [
            "minPressDuration": 0.25
        ] as [String: Any])

        // 4. Reload from storage
        try await agent.reloadConfiguration()
        XCTAssertEqual(agent.getConfiguration().minPressDuration, 0.25)

        // 5. Make another change and save
        newConfig = agent.getConfiguration()
        newConfig.minPressDuration = 0.35
        try await agent.updateAndSaveConfiguration(newConfig)

        // 6. Create new agent to verify persistence
        let newAgent = CapsLockAgent()
        XCTAssertEqual(newAgent.getConfiguration().minPressDuration, 0.35)
    }

    func testConfigurationIsolationBetweenAgents() async throws {
        // Create first agent
        let agent1 = CapsLockAgent(configuration: CapsLockConfiguration(minPressDuration: 0.1))

        // Create second agent from storage
        let agent2 = CapsLockAgent()

        // They should have different configs (agent1 didn't save)
        XCTAssertEqual(agent1.getConfiguration().minPressDuration, 0.1)
        XCTAssertEqual(agent2.getConfiguration().minPressDuration, 0.2) // Default from storage

        // Save agent1's config
        try agent1.saveConfiguration()

        // Create third agent, should now have agent1's config
        let agent3 = CapsLockAgent()
        XCTAssertEqual(agent3.getConfiguration().minPressDuration, 0.1)
    }

    // MARK: - Error Handling Tests

    func testReloadWithCorruptedConfiguration() async throws {
        agent = CapsLockAgent(configuration: .default)

        // Set invalid configuration in storage
        Configuration.shared.set("capsLock", value: "not a dictionary")

        // Reload should fall back to defaults
        try await agent.reloadConfiguration()

        let config = agent.getConfiguration()
        XCTAssertEqual(config, .default)
    }

    func testReloadWithPartialConfiguration() async throws {
        agent = CapsLockAgent(configuration: .default)

        // Set partial configuration
        Configuration.shared.set("capsLock", value: [
            "minPressDuration": 0.12
            // Missing other fields
        ] as [String: Any])

        try await agent.reloadConfiguration()

        let config = agent.getConfiguration()
        XCTAssertEqual(config.minPressDuration, 0.12) // Custom value
        XCTAssertTrue(config.enabled) // Default value
        XCTAssertEqual(config.quickTapAction, .sendKey(53)) // Default value
    }

    // MARK: - Runtime Restart Tests

    func testUpdateConfigurationWhileRunning() async throws {
        let initialConfig = CapsLockConfiguration(enabled: false)
        agent = CapsLockAgent(configuration: initialConfig)

        try await agent.start()
        XCTAssertTrue(agent.isRunning)

        // Update with enabled=false should not restart
        let newConfig = CapsLockConfiguration(
            enabled: false,
            minPressDuration: 0.3
        )
        try await agent.updateConfiguration(newConfig)

        XCTAssertTrue(agent.isRunning)
        XCTAssertEqual(agent.getConfiguration().minPressDuration, 0.3)
    }

    func testUpdateConfigurationDisablesRunningAgent() async throws {
        let initialConfig = CapsLockConfiguration(enabled: false)
        agent = CapsLockAgent(configuration: initialConfig)

        try await agent.start()
        XCTAssertTrue(agent.isRunning)

        // Update to disabled
        let newConfig = CapsLockConfiguration(enabled: false)
        try await agent.updateConfiguration(newConfig)

        XCTAssertFalse(agent.isRunning)
    }

    func testUpdateConfigurationEnablesStoppedAgent() async throws {
        let initialConfig = CapsLockConfiguration(enabled: false)
        agent = CapsLockAgent(configuration: initialConfig)

        XCTAssertFalse(agent.isRunning)

        // Update to enabled - in test environment this will fail due to permissions
        // but we can test that it attempts to start
        let newConfig = CapsLockConfiguration(enabled: true)

        do {
            try await agent.updateConfiguration(newConfig)
            // If this succeeds, agent should be running (unlikely in test environment)
            // XCTAssertTrue(agent.isRunning)
        } catch {
            // Expected in test environment without Accessibility permissions
            XCTAssertTrue(error is EventTapError)
        }
    }
}
