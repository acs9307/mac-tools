import XCTest
@testable import WindowManipulation
@testable import MacToolsCore

final class WindowManipulationAgentTests: XCTestCase {
    var agent: WindowManipulationAgent!

    override func setUp() {
        agent = WindowManipulationAgent()
    }

    override func tearDown() async throws {
        if agent.isRunning {
            try await agent.stop()
        }
    }

    func testAgentInitialization() {
        XCTAssertEqual(agent.identifier, "window.manipulation")
        XCTAssertEqual(agent.name, "Window Manipulation")
        XCTAssertFalse(agent.isRunning)
    }

    func testAgentStartRequiresPermissions() async throws {
        // Note: This test will fail if accessibility permissions are not granted
        do {
            try await agent.start()
            // If we get here, permissions are granted
            XCTAssertTrue(agent.isRunning)
            try await agent.stop()
        } catch let error as AgentError {
            // Expected if permissions are not granted
            if case .permissionDenied = error {
                XCTAssertFalse(agent.isRunning)
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testGetAllWindowsRequiresRunningAgent() async throws {
        do {
            _ = try agent.getAllWindows()
            XCTFail("Expected error when agent is not running")
        } catch let error as AgentError {
            if case .notRunning = error {
                // Expected
            } else {
                XCTFail("Expected notRunning error, got \(error)")
            }
        }
    }

    func testGetWindowsForApplicationRequiresRunningAgent() async throws {
        do {
            _ = try agent.getWindows(forApplication: "com.apple.Safari")
            XCTFail("Expected error when agent is not running")
        } catch let error as AgentError {
            if case .notRunning = error {
                // Expected
            } else {
                XCTFail("Expected notRunning error, got \(error)")
            }
        }
    }

    func testGetFocusedWindowRequiresRunningAgent() async throws {
        do {
            _ = try agent.getFocusedWindow()
            XCTFail("Expected error when agent is not running")
        } catch let error as AgentError {
            if case .notRunning = error {
                // Expected
            } else {
                XCTFail("Expected notRunning error, got \(error)")
            }
        }
    }

    func testAgentConfigure() async throws {
        let config: [String: Any] = [
            "animations": false,
            "animationDuration": 0.5
        ]

        // Configure should not throw even if agent is not running
        try await agent.configure(config)
    }

    func testConfigureAnimations() async throws {
        let config: [String: Any] = [
            "animations": true,
            "animationDuration": 0.3
        ]

        try await agent.configure(config)

        // Verify configuration was applied (we can't directly test private properties,
        // but we can verify the configure method doesn't throw)
    }
}
