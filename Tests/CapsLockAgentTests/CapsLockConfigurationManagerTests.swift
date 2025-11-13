import XCTest
@testable import CapsLockAgent
@testable import MacToolsCore

final class CapsLockConfigurationManagerTests: XCTestCase {
    var sut: CapsLockConfigurationManager!
    var tempConfigPath: URL!

    override func setUp() {
        sut = CapsLockConfigurationManager()

        // Create temporary config path for testing
        tempConfigPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-config-\(UUID().uuidString).json")
    }

    override func tearDown() {
        sut = nil

        // Clean up temporary config file
        if let path = tempConfigPath {
            try? FileManager.default.removeItem(at: path)
            tempConfigPath = nil
        }

        // Reset Configuration singleton to defaults
        Configuration.shared.reset()
    }

    // MARK: - Loading Tests

    func testLoadDefaultConfiguration() {
        let config = sut.load()

        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.minPressDuration, 0.2)
        XCTAssertEqual(config.quickTapAction, .sendKey(53)) // Escape
        XCTAssertEqual(config.longPressAction, .sendModifier(.control))
        XCTAssertTrue(config.disableCapsLock)
    }

    func testLoadFromConfiguration() {
        // Set custom values in Configuration
        Configuration.shared.set("capsLock", value: [
            "enabled": false,
            "minPressDuration": 0.3,
            "quickTapAction": ["type": "sendKey", "value": 42],
            "longPressAction": ["type": "sendModifier", "value": "option"],
            "disableCapsLock": false
        ] as [String: Any])

        let config = sut.load()

        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.minPressDuration, 0.3)
        XCTAssertEqual(config.quickTapAction, .sendKey(42))
        XCTAssertEqual(config.longPressAction, .sendModifier(.option))
        XCTAssertFalse(config.disableCapsLock)
    }

    func testLoadWithMissingValues() {
        // Set incomplete configuration
        Configuration.shared.set("capsLock", value: [
            "enabled": false
            // Missing other values
        ] as [String: Any])

        let config = sut.load()

        // Should use defaults for missing values
        XCTAssertFalse(config.enabled) // Only this was set
        XCTAssertEqual(config.minPressDuration, 0.2) // Default
        XCTAssertEqual(config.quickTapAction, .sendKey(53)) // Default
    }

    func testLoadWithInvalidConfiguration() {
        // Set invalid configuration
        Configuration.shared.set("capsLock", value: "invalid")

        let config = sut.load()

        // Should return default configuration
        XCTAssertEqual(config, .default)
    }

    // MARK: - Saving Tests

    func testSaveConfiguration() throws {
        let config = CapsLockConfiguration(
            enabled: false,
            minPressDuration: 0.5,
            quickTapAction: .disabled,
            longPressAction: .sendKey(36), // Return key
            disableCapsLock: false
        )

        try sut.save(config)

        // Verify it was saved to Configuration
        let loaded = sut.load()
        XCTAssertEqual(loaded, config)
    }

    func testSaveAndLoadRoundTrip() throws {
        let original = CapsLockConfiguration(
            enabled: true,
            minPressDuration: 0.15,
            quickTapAction: .sendModifier(.command),
            longPressAction: .sendModifier(.shift),
            disableCapsLock: true
        )

        try sut.save(original)
        let loaded = sut.load()

        XCTAssertEqual(loaded, original)
    }

    func testSaveAllActionTypes() throws {
        // Test sendKey action
        var config = CapsLockConfiguration(
            enabled: true,
            minPressDuration: 0.2,
            quickTapAction: .sendKey(123),
            longPressAction: .sendKey(456),
            disableCapsLock: true
        )
        try sut.save(config)
        var loaded = sut.load()
        XCTAssertEqual(loaded.quickTapAction, .sendKey(123))
        XCTAssertEqual(loaded.longPressAction, .sendKey(456))

        // Test sendModifier action
        config = CapsLockConfiguration(
            enabled: true,
            minPressDuration: 0.2,
            quickTapAction: .sendModifier(.option),
            longPressAction: .sendModifier(.function),
            disableCapsLock: true
        )
        try sut.save(config)
        loaded = sut.load()
        XCTAssertEqual(loaded.quickTapAction, .sendModifier(.option))
        XCTAssertEqual(loaded.longPressAction, .sendModifier(.function))

        // Test disabled action
        config = CapsLockConfiguration(
            enabled: true,
            minPressDuration: 0.2,
            quickTapAction: .disabled,
            longPressAction: .disabled,
            disableCapsLock: true
        )
        try sut.save(config)
        loaded = sut.load()
        XCTAssertEqual(loaded.quickTapAction, .disabled)
        XCTAssertEqual(loaded.longPressAction, .disabled)
    }

    // MARK: - Specific Value Access Tests

    func testGetMinPressDuration() {
        Configuration.shared.set("capsLock", value: [
            "minPressDuration": 0.4
        ] as [String: Any])

        let duration = sut.getMinPressDuration()
        XCTAssertEqual(duration, 0.4)
    }

    func testGetMinPressDurationDefault() {
        // Don't set any value
        Configuration.shared.set("capsLock", value: [:] as [String: Any])

        let duration = sut.getMinPressDuration()
        XCTAssertEqual(duration, 0.2) // Default value
    }

    func testSetMinPressDuration() throws {
        try sut.setMinPressDuration(0.35)

        let config = sut.load()
        XCTAssertEqual(config.minPressDuration, 0.35)
    }

    func testGetEnabled() {
        Configuration.shared.set("capsLock", value: [
            "enabled": false
        ] as [String: Any])

        let enabled = sut.getEnabled()
        XCTAssertFalse(enabled)
    }

    func testGetEnabledDefault() {
        Configuration.shared.set("capsLock", value: [:] as [String: Any])

        let enabled = sut.getEnabled()
        XCTAssertTrue(enabled) // Default value
    }

    func testSetEnabled() throws {
        try sut.setEnabled(false)

        let config = sut.load()
        XCTAssertFalse(config.enabled)
    }

    // MARK: - Edge Cases

    func testSavePreservesOtherConfigurationSections() throws {
        // Set some other configuration
        Configuration.shared.set("daemon", value: ["logLevel": "debug"])

        let capsLockConfig = CapsLockConfiguration(enabled: false)
        try sut.save(capsLockConfig)

        // Verify other configuration wasn't affected
        let daemonConfig = Configuration.shared.get("daemon") as? [String: Any]
        XCTAssertEqual(daemonConfig?["logLevel"] as? String, "debug")
    }

    func testMultipleSavesCumulative() throws {
        // First save
        try sut.setEnabled(false)

        // Second save with different property
        try sut.setMinPressDuration(0.25)

        // Both should be preserved
        let config = sut.load()
        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.minPressDuration, 0.25)
    }

    func testLoadAfterReset() {
        // Save custom config
        Configuration.shared.set("capsLock", value: [
            "enabled": false,
            "minPressDuration": 0.99
        ] as [String: Any])

        // Reset configuration
        Configuration.shared.reset()

        // Load should return defaults
        let config = sut.load()
        XCTAssertTrue(config.enabled) // Back to default
        XCTAssertEqual(config.minPressDuration, 0.2) // Back to default
    }

    // MARK: - Modifier Flag Tests

    func testAllModifierFlags() throws {
        let modifiers: [ModifierFlag] = [.command, .control, .option, .shift, .function]

        for modifier in modifiers {
            let config = CapsLockConfiguration(
                enabled: true,
                minPressDuration: 0.2,
                quickTapAction: .sendModifier(modifier),
                longPressAction: .sendModifier(modifier),
                disableCapsLock: true
            )

            try sut.save(config)
            let loaded = sut.load()

            XCTAssertEqual(loaded.quickTapAction, .sendModifier(modifier))
            XCTAssertEqual(loaded.longPressAction, .sendModifier(modifier))
        }
    }

    // MARK: - Timing Tests

    func testVeryShortMinPressDuration() throws {
        let config = CapsLockConfiguration(
            enabled: true,
            minPressDuration: 0.01, // 10ms
            quickTapAction: .sendKey(53),
            longPressAction: .sendModifier(.control),
            disableCapsLock: true
        )

        try sut.save(config)
        let loaded = sut.load()

        XCTAssertEqual(loaded.minPressDuration, 0.01)
    }

    func testVeryLongMinPressDuration() throws {
        let config = CapsLockConfiguration(
            enabled: true,
            minPressDuration: 2.0, // 2 seconds
            quickTapAction: .sendKey(53),
            longPressAction: .sendModifier(.control),
            disableCapsLock: true
        )

        try sut.save(config)
        let loaded = sut.load()

        XCTAssertEqual(loaded.minPressDuration, 2.0)
    }

    func testZeroMinPressDuration() throws {
        let config = CapsLockConfiguration(
            enabled: true,
            minPressDuration: 0.0,
            quickTapAction: .sendKey(53),
            longPressAction: .sendModifier(.control),
            disableCapsLock: true
        )

        try sut.save(config)
        let loaded = sut.load()

        XCTAssertEqual(loaded.minPressDuration, 0.0)
    }
}
