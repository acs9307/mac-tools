import XCTest
@testable import KeyManipulation

final class KeyCodeTests: XCTestCase {
    func testKeyCodeInitialization() {
        let keyCode = KeyCode(code: 0, modifiers: [.command])

        XCTAssertEqual(keyCode.code, 0)
        XCTAssertTrue(keyCode.modifiers.contains(.command))
    }

    func testKeyCodeEquality() {
        let keyCode1 = KeyCode(code: 0, modifiers: [.command])
        let keyCode2 = KeyCode(code: 0, modifiers: [.command])
        let keyCode3 = KeyCode(code: 1, modifiers: [.command])

        XCTAssertEqual(keyCode1, keyCode2)
        XCTAssertNotEqual(keyCode1, keyCode3)
    }

    func testKeyCodeHash() {
        let keyCode1 = KeyCode(code: 0, modifiers: [.command])
        let keyCode2 = KeyCode(code: 0, modifiers: [.command])

        XCTAssertEqual(keyCode1.hashValue, keyCode2.hashValue)

        var set = Set<KeyCode>()
        set.insert(keyCode1)
        set.insert(keyCode2)

        XCTAssertEqual(set.count, 1)
    }

    func testModifierFlags() {
        var modifiers: ModifierFlags = []

        XCTAssertTrue(modifiers.isEmpty)

        modifiers.insert(.command)
        XCTAssertTrue(modifiers.contains(.command))
        XCTAssertFalse(modifiers.contains(.shift))

        modifiers.insert(.shift)
        XCTAssertTrue(modifiers.contains(.command))
        XCTAssertTrue(modifiers.contains(.shift))

        modifiers.remove(.command)
        XCTAssertFalse(modifiers.contains(.command))
        XCTAssertTrue(modifiers.contains(.shift))
    }

    func testModifierFlagsCombinations() {
        let modifiers: ModifierFlags = [.command, .shift, .option]

        XCTAssertTrue(modifiers.contains(.command))
        XCTAssertTrue(modifiers.contains(.shift))
        XCTAssertTrue(modifiers.contains(.option))
        XCTAssertFalse(modifiers.contains(.control))
    }

    func testModifierFlagsCGEventConversion() {
        let modifiers: ModifierFlags = [.command, .shift]
        let cgFlags = modifiers.cgEventFlags

        XCTAssertTrue(cgFlags.contains(.maskCommand))
        XCTAssertTrue(cgFlags.contains(.maskShift))
        XCTAssertFalse(cgFlags.contains(.maskAlternate))
    }

    func testModifierFlagsFromCGEvent() {
        var cgFlags: CGEventFlags = []
        cgFlags.insert(.maskCommand)
        cgFlags.insert(.maskShift)

        let modifiers = ModifierFlags(cgEventFlags: cgFlags)

        XCTAssertTrue(modifiers.contains(.command))
        XCTAssertTrue(modifiers.contains(.shift))
        XCTAssertFalse(modifiers.contains(.option))
    }

    func testPredefinedKeys() {
        XCTAssertEqual(KeyCode.a.code, 0)
        XCTAssertEqual(KeyCode.s.code, 1)
        XCTAssertEqual(KeyCode.space.code, 49)
        XCTAssertEqual(KeyCode.escape.code, 53)
        XCTAssertEqual(KeyCode.return.code, 36)
    }

    func testKeyCodeCodable() throws {
        let keyCode = KeyCode(code: 0, modifiers: [.command, .shift])

        let encoder = JSONEncoder()
        let data = try encoder.encode(keyCode)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(KeyCode.self, from: data)

        XCTAssertEqual(keyCode, decoded)
    }

    func testModifierFlagsCodable() throws {
        let modifiers: ModifierFlags = [.command, .shift, .option]

        let encoder = JSONEncoder()
        let data = try encoder.encode(modifiers)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ModifierFlags.self, from: data)

        XCTAssertEqual(modifiers, decoded)
    }
}
