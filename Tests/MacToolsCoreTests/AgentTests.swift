import XCTest
@testable import MacToolsCore

final class AgentTests: XCTestCase {
    // Mock agent for testing
    class MockAgent: BaseAgent {
        var startCallCount = 0
        var stopCallCount = 0
        var shouldFailStart = false
        var shouldFailStop = false

        override func performStart() throws {
            startCallCount += 1
            if shouldFailStart {
                throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock start failure"])
            }
        }

        override func performStop() throws {
            stopCallCount += 1
            if shouldFailStop {
                throw NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock stop failure"])
            }
        }
    }

    func testAgentInitialization() {
        let agent = MockAgent(identifier: "test.agent", name: "Test Agent")

        XCTAssertEqual(agent.identifier, "test.agent")
        XCTAssertEqual(agent.name, "Test Agent")
        XCTAssertFalse(agent.isRunning)
    }

    func testAgentStart() async throws {
        let agent = MockAgent(identifier: "test.agent", name: "Test Agent")

        XCTAssertFalse(agent.isRunning)

        try await agent.start()

        XCTAssertTrue(agent.isRunning)
        XCTAssertEqual(agent.startCallCount, 1)
    }

    func testAgentStop() async throws {
        let agent = MockAgent(identifier: "test.agent", name: "Test Agent")

        try await agent.start()
        XCTAssertTrue(agent.isRunning)

        try await agent.stop()

        XCTAssertFalse(agent.isRunning)
        XCTAssertEqual(agent.stopCallCount, 1)
    }

    func testAgentStartTwiceFails() async throws {
        let agent = MockAgent(identifier: "test.agent", name: "Test Agent")

        try await agent.start()

        do {
            try await agent.start()
            XCTFail("Expected AgentError.alreadyRunning")
        } catch let error as AgentError {
            if case .alreadyRunning(let id) = error {
                XCTAssertEqual(id, "test.agent")
            } else {
                XCTFail("Expected AgentError.alreadyRunning, got \(error)")
            }
        }
    }

    func testAgentStopWithoutStartFails() async throws {
        let agent = MockAgent(identifier: "test.agent", name: "Test Agent")

        do {
            try await agent.stop()
            XCTFail("Expected AgentError.notRunning")
        } catch let error as AgentError {
            if case .notRunning(let id) = error {
                XCTAssertEqual(id, "test.agent")
            } else {
                XCTFail("Expected AgentError.notRunning, got \(error)")
            }
        }
    }

    func testAgentStartFailure() async throws {
        let agent = MockAgent(identifier: "test.agent", name: "Test Agent")
        agent.shouldFailStart = true

        do {
            try await agent.start()
            XCTFail("Expected AgentError.startupFailed")
        } catch let error as AgentError {
            if case .startupFailed(let id, _) = error {
                XCTAssertEqual(id, "test.agent")
                XCTAssertFalse(agent.isRunning)
            } else {
                XCTFail("Expected AgentError.startupFailed, got \(error)")
            }
        }
    }

    func testAgentStopFailure() async throws {
        let agent = MockAgent(identifier: "test.agent", name: "Test Agent")

        try await agent.start()
        agent.shouldFailStop = true

        do {
            try await agent.stop()
            XCTFail("Expected AgentError.shutdownFailed")
        } catch let error as AgentError {
            if case .shutdownFailed(let id, _) = error {
                XCTAssertEqual(id, "test.agent")
            } else {
                XCTFail("Expected AgentError.shutdownFailed, got \(error)")
            }
        }
    }

    func testAgentConfigure() async throws {
        let agent = MockAgent(identifier: "test.agent", name: "Test Agent")
        let config: [String: Any] = ["key": "value"]

        // Should not throw
        try await agent.configure(config)
    }
}
