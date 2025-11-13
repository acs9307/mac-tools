import XCTest
@testable import MacToolsCore

final class DaemonManagerTests: XCTestCase {
    // Mock agent for testing
    class MockAgent: BaseAgent {
        override func performStart() throws {
            // No-op for testing
        }

        override func performStop() throws {
            // No-op for testing
        }
    }

    var manager: DaemonManager!

    override func setUp() async throws {
        // Note: We can't fully reset the singleton, so we'll work with it as-is
        manager = DaemonManager.shared

        // Stop all agents before each test
        await manager.stopAll()
    }

    func testRegisterAgent() throws {
        let agent = MockAgent(identifier: "test.agent1", name: "Test Agent 1")

        try manager.register(agent)

        let status = manager.status()
        XCTAssertTrue(status.keys.contains("test.agent1"))
    }

    func testRegisterDuplicateAgentFails() throws {
        let agent1 = MockAgent(identifier: "test.agent2", name: "Test Agent 2")
        let agent2 = MockAgent(identifier: "test.agent2", name: "Test Agent 2 Duplicate")

        try manager.register(agent1)

        XCTAssertThrowsError(try manager.register(agent2)) { error in
            XCTAssertTrue(error is AgentError)
            if case .configurationError(let message) = error as? AgentError {
                XCTAssertTrue(message.contains("test.agent2"))
            }
        }
    }

    func testStartSpecificAgent() async throws {
        let agent = MockAgent(identifier: "test.agent3", name: "Test Agent 3")
        try manager.register(agent)

        try await manager.start("test.agent3")

        XCTAssertTrue(agent.isRunning)
        let status = manager.status()
        XCTAssertEqual(status["test.agent3"], true)
    }

    func testStopSpecificAgent() async throws {
        let agent = MockAgent(identifier: "test.agent4", name: "Test Agent 4")
        try manager.register(agent)

        try await manager.start("test.agent4")
        XCTAssertTrue(agent.isRunning)

        try await manager.stop("test.agent4")
        XCTAssertFalse(agent.isRunning)

        let status = manager.status()
        XCTAssertEqual(status["test.agent4"], false)
    }

    func testStartNonexistentAgentFails() async throws {
        do {
            try await manager.start("nonexistent.agent")
            XCTFail("Expected error when starting nonexistent agent")
        } catch let error as AgentError {
            if case .configurationError(let message) = error {
                XCTAssertTrue(message.contains("not found"))
            } else {
                XCTFail("Expected configurationError, got \(error)")
            }
        }
    }

    func testStopNonexistentAgentFails() async throws {
        do {
            try await manager.stop("nonexistent.agent")
            XCTFail("Expected error when stopping nonexistent agent")
        } catch let error as AgentError {
            if case .configurationError(let message) = error {
                XCTAssertTrue(message.contains("not found"))
            } else {
                XCTFail("Expected configurationError, got \(error)")
            }
        }
    }

    func testUnregisterAgent() async throws {
        let agent = MockAgent(identifier: "test.agent5", name: "Test Agent 5")
        try manager.register(agent)
        try await manager.start("test.agent5")

        XCTAssertTrue(agent.isRunning)

        try await manager.unregister("test.agent5")

        XCTAssertFalse(agent.isRunning)
        let status = manager.status()
        XCTAssertNil(status["test.agent5"])
    }

    func testStatusReturnsAllAgents() throws {
        let agent1 = MockAgent(identifier: "test.agent6", name: "Test Agent 6")
        let agent2 = MockAgent(identifier: "test.agent7", name: "Test Agent 7")

        try manager.register(agent1)
        try manager.register(agent2)

        let status = manager.status()

        XCTAssertTrue(status.keys.contains("test.agent6"))
        XCTAssertTrue(status.keys.contains("test.agent7"))
        XCTAssertEqual(status["test.agent6"], false)
        XCTAssertEqual(status["test.agent7"], false)
    }

    func testStopAllStopsRunningAgents() async throws {
        let agent1 = MockAgent(identifier: "test.agent8", name: "Test Agent 8")
        let agent2 = MockAgent(identifier: "test.agent9", name: "Test Agent 9")

        try manager.register(agent1)
        try manager.register(agent2)

        try await manager.start("test.agent8")
        try await manager.start("test.agent9")

        XCTAssertTrue(agent1.isRunning)
        XCTAssertTrue(agent2.isRunning)

        await manager.stopAll()

        XCTAssertFalse(agent1.isRunning)
        XCTAssertFalse(agent2.isRunning)
    }
}
