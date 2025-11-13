import XCTest
@testable import CapsLockAgent
@testable import MacToolsCore

final class DaemonIntegrationTests: XCTestCase {
    var manager: DaemonManager!

    override func setUp() {
        manager = DaemonManager.shared
        // Reset configuration
        Configuration.shared.reset()
    }

    override func tearDown() async throws {
        // Stop all agents
        await manager.stopAll()
        manager = nil
        Configuration.shared.reset()
    }

    // MARK: - Registration Tests

    func testCapsLockAgentRegistration() throws {
        let agent = CapsLockAgent(configuration: CapsLockConfiguration(enabled: false))

        try manager.register(agent)

        let status = manager.status()
        XCTAssertNotNil(status["com.mactools.capslock"])
    }

    func testMultipleAgentRegistration() throws {
        let agent1 = CapsLockAgent(configuration: CapsLockConfiguration(enabled: false))

        try manager.register(agent1)

        // Try to register another with same identifier
        let agent2 = CapsLockAgent(configuration: CapsLockConfiguration(enabled: false))

        XCTAssertThrowsError(try manager.register(agent2)) { error in
            XCTAssertTrue(error is AgentError)
        }
    }

    func testAgentUnregistration() async throws {
        let agent = CapsLockAgent(configuration: CapsLockConfiguration(enabled: false))

        try manager.register(agent)
        XCTAssertNotNil(manager.status()["com.mactools.capslock"])

        try await manager.unregister("com.mactools.capslock")
        XCTAssertNil(manager.status()["com.mactools.capslock"])
    }

    // MARK: - Startup Tests

    func testCapsLockAgentStartsWithDaemon() async throws {
        let agent = CapsLockAgent(configuration: CapsLockConfiguration(enabled: false))
        try manager.register(agent)

        // Start the agent (disabled config means no event tap will be created)
        try await manager.start("com.mactools.capslock")

        let status = manager.status()
        XCTAssertEqual(status["com.mactools.capslock"], true)
    }

    func testCapsLockAgentStopsWithDaemon() async throws {
        let agent = CapsLockAgent(configuration: CapsLockConfiguration(enabled: false))
        try manager.register(agent)

        try await manager.start("com.mactools.capslock")
        XCTAssertTrue(agent.isRunning)

        try await manager.stop("com.mactools.capslock")
        XCTAssertFalse(agent.isRunning)
    }

    func testDisabledAgentStartsSuccessfully() async throws {
        // Agent with disabled config should start without errors (no event tap)
        let agent = CapsLockAgent(configuration: CapsLockConfiguration(enabled: false))
        try manager.register(agent)

        try await manager.start("com.mactools.capslock")

        XCTAssertTrue(agent.isRunning)
        let status = manager.status()
        XCTAssertEqual(status["com.mactools.capslock"], true)
    }

    // MARK: - Configuration Integration Tests

    func testAgentLoadsConfigurationFromStorage() {
        // Set configuration in storage
        Configuration.shared.set("capsLock", value: [
            "enabled": false,
            "minPressDuration": 0.33
        ] as [String: Any])

        // Create agent (should load from storage)
        let agent = CapsLockAgent()
        let config = agent.getConfiguration()

        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.minPressDuration, 0.33)
    }

    func testAgentUsesDefaultConfigurationWhenNotSet() {
        // Don't set any configuration
        let agent = CapsLockAgent()
        let config = agent.getConfiguration()

        XCTAssertEqual(config, .default)
    }

    func testAgentConfigurationPersistsAcrossInstances() async throws {
        // Create first agent and save config
        let agent1 = CapsLockAgent(configuration: CapsLockConfiguration(minPressDuration: 0.42))
        try agent1.saveConfiguration()

        // Create second agent (should load saved config)
        let agent2 = CapsLockAgent()
        let config = agent2.getConfiguration()

        XCTAssertEqual(config.minPressDuration, 0.42)
    }

    // MARK: - Status Tests

    func testDaemonStatusReflectsAgentState() async throws {
        let agent = CapsLockAgent(configuration: CapsLockConfiguration(enabled: false))
        try manager.register(agent)

        // Initially not running
        var status = manager.status()
        XCTAssertEqual(status["com.mactools.capslock"], false)

        // Start agent
        try await manager.start("com.mactools.capslock")
        status = manager.status()
        XCTAssertEqual(status["com.mactools.capslock"], true)

        // Stop agent
        try await manager.stop("com.mactools.capslock")
        status = manager.status()
        XCTAssertEqual(status["com.mactools.capslock"], false)
    }

    func testMultipleAgentsStatus() async throws {
        let agent1 = CapsLockAgent(configuration: CapsLockConfiguration(enabled: false))
        agent1.identifier = "test.capslock.1" // Unique identifier for testing

        // Would need to mock other agents for complete test
        // For now just test single agent
        try manager.register(agent1)
        try await manager.start("test.capslock.1")

        let status = manager.status()
        XCTAssertEqual(status["test.capslock.1"], true)
    }

    // MARK: - Error Handling Tests

    func testStartingNonExistentAgentThrowsError() async throws {
        XCTAssertThrowsError(try await manager.start("com.mactools.nonexistent")) { error in
            XCTAssertTrue(error is AgentError)
        }
    }

    func testStoppingNonExistentAgentThrowsError() async throws {
        XCTAssertThrowsError(try await manager.stop("com.mactools.nonexistent")) { error in
            XCTAssertTrue(error is AgentError)
        }
    }

    func testUnregisteringRunningAgentStopsIt() async throws {
        let agent = CapsLockAgent(configuration: CapsLockConfiguration(enabled: false))
        try manager.register(agent)
        try await manager.start("com.mactools.capslock")

        XCTAssertTrue(agent.isRunning)

        // Unregister should stop it first
        try await manager.unregister("com.mactools.capslock")

        XCTAssertFalse(agent.isRunning)
    }

    // MARK: - Lifecycle Tests

    func testAgentStartStopCycle() async throws {
        let agent = CapsLockAgent(configuration: CapsLockConfiguration(enabled: false))
        try manager.register(agent)

        // Start
        try await manager.start("com.mactools.capslock")
        XCTAssertTrue(agent.isRunning)

        // Stop
        try await manager.stop("com.mactools.capslock")
        XCTAssertFalse(agent.isRunning)

        // Start again
        try await manager.start("com.mactools.capslock")
        XCTAssertTrue(agent.isRunning)

        // Stop again
        try await manager.stop("com.mactools.capslock")
        XCTAssertFalse(agent.isRunning)
    }

    func testMultipleStartsDoesNotCrash() async throws {
        let agent = CapsLockAgent(configuration: CapsLockConfiguration(enabled: false))
        try manager.register(agent)

        try await manager.start("com.mactools.capslock")

        // Try to start again (should throw)
        do {
            try await manager.start("com.mactools.capslock")
            XCTFail("Expected error when starting already running agent")
        } catch {
            // Expected
            XCTAssertTrue(error is AgentError)
        }
    }

    func testMultipleStopsDoesNotCrash() async throws {
        let agent = CapsLockAgent(configuration: CapsLockConfiguration(enabled: false))
        try manager.register(agent)

        try await manager.start("com.mactools.capslock")
        try await manager.stop("com.mactools.capslock")

        // Try to stop again (should throw)
        do {
            try await manager.stop("com.mactools.capslock")
            XCTFail("Expected error when stopping already stopped agent")
        } catch {
            // Expected
            XCTAssertTrue(error is AgentError)
        }
    }

    // MARK: - Integration Workflow Tests

    func testCompleteWorkflow() async throws {
        // 1. Create and configure agent
        var config = CapsLockConfiguration(enabled: false, minPressDuration: 0.25)
        let agent = CapsLockAgent(configuration: config)

        // 2. Register with daemon
        try manager.register(agent)

        // 3. Start agent
        try await manager.start("com.mactools.capslock")
        XCTAssertTrue(agent.isRunning)

        // 4. Update configuration
        config.minPressDuration = 0.35
        try await agent.updateAndSaveConfiguration(config)
        XCTAssertEqual(agent.getConfiguration().minPressDuration, 0.35)

        // 5. Stop agent
        try await manager.stop("com.mactools.capslock")
        XCTAssertFalse(agent.isRunning)

        // 6. Unregister
        try await manager.unregister("com.mactools.capslock")
        XCTAssertNil(manager.status()["com.mactools.capslock"])
    }

    func testConfigurationReloadDuringOperation() async throws {
        let agent = CapsLockAgent(configuration: CapsLockConfiguration(enabled: false, minPressDuration: 0.2))
        try manager.register(agent)
        try await manager.start("com.mactools.capslock")

        // Modify storage externally
        Configuration.shared.set("capsLock", value: [
            "enabled": false,
            "minPressDuration": 0.4
        ] as [String: Any])

        // Reload configuration
        try await agent.reloadConfiguration()

        XCTAssertEqual(agent.getConfiguration().minPressDuration, 0.4)
        XCTAssertTrue(agent.isRunning) // Should still be running
    }

    // MARK: - Permission Tests

    func testAgentIdentifierIsConsistent() {
        let agent1 = CapsLockAgent()
        let agent2 = CapsLockAgent()

        XCTAssertEqual(agent1.identifier, agent2.identifier)
        XCTAssertEqual(agent1.identifier, "com.mactools.capslock")
    }

    func testAgentNameIsDescriptive() {
        let agent = CapsLockAgent()
        XCTAssertEqual(agent.name, "Caps Lock Agent")
    }
}
