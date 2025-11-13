import XCTest
@testable import KeyManipulation
@testable import MacToolsCore

final class KeyManipulationAgentTests: XCTestCase {
    var agent: KeyManipulationAgent!

    override func setUp() {
        agent = KeyManipulationAgent()
    }

    override func tearDown() async throws {
        if agent.isRunning {
            try await agent.stop()
        }
    }

    func testAgentInitialization() {
        XCTAssertEqual(agent.identifier, "key.manipulation")
        XCTAssertEqual(agent.name, "Key Manipulation")
        XCTAssertFalse(agent.isRunning)
    }

    func testAgentStartRequiresPermissions() async throws {
        // Note: This test will fail if accessibility permissions are not granted
        // In a CI environment, this would need to be mocked or skipped
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

    func testUnregisterHotkey() async throws {
        // This test doesn't require the agent to be running
        // Just verify the method doesn't crash
        agent.unregisterHotkey("test.hotkey")
    }

    func testSimulateKeyPressRequiresRunningAgent() async throws {
        let keyCode = KeyCode.a

        do {
            try agent.simulateKeyPress(keyCode, down: true)
            XCTFail("Expected error when agent is not running")
        } catch let error as AgentError {
            if case .notRunning = error {
                // Expected
            } else {
                XCTFail("Expected notRunning error, got \(error)")
            }
        }
    }

    func testTypeTextRequiresRunningAgent() async throws {
        do {
            try agent.typeText("test")
            XCTFail("Expected error when agent is not running")
        } catch let error as AgentError {
            if case .notRunning = error {
                // Expected
            } else {
                XCTFail("Expected notRunning error, got \(error)")
            }
        }
    }

    func testRegisterHotkeyRequiresRunningAgent() async throws {
        let keyCode = KeyCode(code: 0, modifiers: [.command])

        do {
            try agent.registerHotkey(identifier: "test", keyCode: keyCode) {
                // Handler
            }
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
            "hotkeys": [
                "test.hotkey": [
                    "keyCode": 0,
                    "modifiers": ["command", "shift"]
                ]
            ]
        ]

        // Configure should not throw even if agent is not running
        try await agent.configure(config)
    }
}
