import XCTest
@testable import CapsLockAgent

final class EventSynthesizerTests: XCTestCase {
    var sut: EventSynthesizer!

    override func setUp() {
        sut = EventSynthesizer()
    }

    override func tearDown() {
        sut = nil
    }

    func testInitialization() {
        XCTAssertNotNil(sut)
    }

    func testSynthesizeKeyEvent() {
        // This test verifies the synthesizer can be called without crashing
        // Actual event posting requires a macOS environment with proper permissions

        let action = KeyAction.sendKey(53) // Escape key

        // Should not crash
        sut.synthesizeEvent(for: action)
    }

    func testSynthesizeModifierEvent() {
        let action = KeyAction.sendModifier(.control)

        // Should not crash
        sut.synthesizeEvent(for: action)
    }

    func testSynthesizeDisabledAction() {
        let action = KeyAction.disabled

        // Should not crash (does nothing)
        sut.synthesizeEvent(for: action)
    }

    func testSynthesizeAllModifiers() {
        let modifiers: [ModifierFlag] = [.command, .control, .option, .shift, .function]

        for modifier in modifiers {
            // Should not crash for any modifier
            sut.synthesizeEvent(for: .sendModifier(modifier))
        }
    }

    func testSynthesizeMultipleKeys() {
        // Test synthesizing multiple different keys
        let keyCodes = [53, 36, 49, 51] // Escape, Return, Space, Delete

        for keyCode in keyCodes {
            // Should not crash
            sut.synthesizeEvent(for: .sendKey(keyCode))
        }
    }
}
