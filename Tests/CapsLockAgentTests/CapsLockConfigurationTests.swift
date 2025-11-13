import XCTest
@testable import CapsLockAgent

final class CapsLockConfigurationTests: XCTestCase {
    func testDefaultConfiguration() {
        let config = CapsLockConfiguration.default

        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.minPressDuration, 0.2)
        XCTAssertEqual(config.quickTapAction, .sendKey(53)) // Escape
        XCTAssertEqual(config.longPressAction, .sendModifier(.control))
        XCTAssertTrue(config.disableCapsLock)
    }

    func testCustomConfiguration() {
        let config = CapsLockConfiguration(
            enabled: false,
            minPressDuration: 0.5,
            quickTapAction: .disabled,
            longPressAction: .sendKey(42),
            disableCapsLock: false
        )

        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.minPressDuration, 0.5)
        XCTAssertEqual(config.quickTapAction, .disabled)
        XCTAssertEqual(config.longPressAction, .sendKey(42))
        XCTAssertFalse(config.disableCapsLock)
    }

    func testConfigurationCodable() throws {
        let original = CapsLockConfiguration(
            enabled: true,
            minPressDuration: 0.3,
            quickTapAction: .sendKey(53),
            longPressAction: .sendModifier(.option),
            disableCapsLock: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CapsLockConfiguration.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testKeyActionEquality() {
        XCTAssertEqual(KeyAction.sendKey(53), KeyAction.sendKey(53))
        XCTAssertNotEqual(KeyAction.sendKey(53), KeyAction.sendKey(54))

        XCTAssertEqual(KeyAction.sendModifier(.control), KeyAction.sendModifier(.control))
        XCTAssertNotEqual(KeyAction.sendModifier(.control), KeyAction.sendModifier(.command))

        XCTAssertEqual(KeyAction.disabled, KeyAction.disabled)
        XCTAssertNotEqual(KeyAction.disabled, KeyAction.sendKey(53))
    }

    func testModifierFlagCases() {
        let flags: [ModifierFlag] = [.command, .control, .option, .shift, .function]

        for flag in flags {
            // Should be able to encode and decode
            let action = KeyAction.sendModifier(flag)
            XCTAssertEqual(action, .sendModifier(flag))
        }
    }

    func testConfigurationEquality() {
        let config1 = CapsLockConfiguration.default
        let config2 = CapsLockConfiguration.default

        XCTAssertEqual(config1, config2)

        let config3 = CapsLockConfiguration(enabled: false)
        XCTAssertNotEqual(config1, config3)
    }
}
