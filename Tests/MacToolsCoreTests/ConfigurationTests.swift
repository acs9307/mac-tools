import XCTest
@testable import MacToolsCore

final class ConfigurationTests: XCTestCase {
    var config: Configuration!
    var testConfigPath: URL!

    override func setUp() {
        config = Configuration.shared
        config.reset()

        // Create a temporary config file path for testing
        testConfigPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-config-\(UUID().uuidString).json")
    }

    override func tearDown() {
        // Clean up test config file
        if FileManager.default.fileExists(atPath: testConfigPath.path) {
            try? FileManager.default.removeItem(at: testConfigPath)
        }
    }

    func testDefaultConfiguration() {
        let daemon = config.get("daemon") as? [String: Any]
        XCTAssertNotNil(daemon)

        let logLevel = daemon?["logLevel"] as? String
        XCTAssertEqual(logLevel, "info")

        let autoStart = daemon?["autoStart"] as? Bool
        XCTAssertEqual(autoStart, true)
    }

    func testGetConfiguration() {
        config.set("test.key", value: "test.value")

        let value = config.get("test.key") as? String
        XCTAssertEqual(value, "test.value")
    }

    func testGetConfigurationWithDefault() {
        let value: String = config.get("nonexistent.key", default: "default.value")
        XCTAssertEqual(value, "default.value")

        config.set("existing.key", value: "existing.value")
        let existingValue: String = config.get("existing.key", default: "default.value")
        XCTAssertEqual(existingValue, "existing.value")
    }

    func testSetConfiguration() {
        config.set("new.key", value: 42)

        let value = config.get("new.key") as? Int
        XCTAssertEqual(value, 42)
    }

    func testResetConfiguration() {
        config.set("custom.key", value: "custom.value")

        let customValue = config.get("custom.key") as? String
        XCTAssertEqual(customValue, "custom.value")

        config.reset()

        let resetValue = config.get("custom.key")
        XCTAssertNil(resetValue)

        // Default values should be restored
        let daemon = config.get("daemon") as? [String: Any]
        XCTAssertNotNil(daemon)
    }

    func testAllConfiguration() {
        let all = config.all()
        XCTAssertTrue(all.keys.contains("daemon"))
        XCTAssertTrue(all.keys.contains("keyManipulation"))
        XCTAssertTrue(all.keys.contains("windowManipulation"))
    }

    func testSaveConfiguration() throws {
        config.set("test.save.key", value: "test.save.value")

        try config.save(to: testConfigPath)

        XCTAssertTrue(FileManager.default.fileExists(atPath: testConfigPath.path))

        // Verify the file contains valid JSON
        let data = try Data(contentsOf: testConfigPath)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        let dict = json as? [String: Any]

        XCTAssertNotNil(dict)
    }

    func testLoadConfiguration() throws {
        // Create a test configuration file
        let testConfig: [String: Any] = [
            "daemon": [
                "logLevel": "debug",
                "autoStart": false
            ],
            "custom": [
                "key": "value"
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: testConfig, options: [.prettyPrinted])
        try data.write(to: testConfigPath)

        // Load the configuration
        try config.load(from: testConfigPath)

        // Verify loaded values
        let daemon = config.get("daemon") as? [String: Any]
        XCTAssertEqual(daemon?["logLevel"] as? String, "debug")
        XCTAssertEqual(daemon?["autoStart"] as? Bool, false)

        let custom = config.get("custom") as? [String: Any]
        XCTAssertEqual(custom?["key"] as? String, "value")
    }

    func testLoadNonexistentConfigurationDoesNotFail() throws {
        let nonexistentPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString).json")

        // Should not throw
        try config.load(from: nonexistentPath)

        // Should still have default configuration
        let daemon = config.get("daemon") as? [String: Any]
        XCTAssertNotNil(daemon)
    }

    func testSaveCreatesDirectoryIfNeeded() throws {
        let nestedPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-nested-\(UUID().uuidString)")
            .appendingPathComponent("subdir")
            .appendingPathComponent("config.json")

        try config.save(to: nestedPath)

        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedPath.path))

        // Clean up
        try? FileManager.default.removeItem(at: nestedPath.deletingLastPathComponent().deletingLastPathComponent())
    }
}
