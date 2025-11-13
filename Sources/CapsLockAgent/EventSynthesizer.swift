import Foundation
import CoreGraphics

/// Synthesizes keyboard events to replace suppressed Caps Lock events
public final class EventSynthesizer {
    // MARK: - Initialization

    public init() {}

    // MARK: - Public Interface

    /// Synthesize and post a key event based on the configured action
    /// - Parameter action: The action to perform
    public func synthesizeEvent(for action: KeyAction) {
        switch action {
        case .sendKey(let keyCode):
            sendKey(keyCode: CGKeyCode(keyCode))

        case .sendModifier(let modifier):
            sendModifier(modifier)

        case .disabled:
            // Do nothing, event was just suppressed
            break
        }
    }

    // MARK: - Private Methods

    private func sendKey(keyCode: CGKeyCode) {
        // Create key down event
        guard let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: true
        ) else { return }

        // Create key up event
        guard let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: false
        ) else { return }

        // Post events to the system
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
    }

    private func sendModifier(_ modifier: ModifierFlag) {
        // For modifiers, we need to post a flags changed event
        let flags = cgEventFlags(for: modifier)

        // Create flags changed event with modifier down
        if let flagsDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
            flagsDownEvent.flags = flags
            flagsDownEvent.type = .flagsChanged
            flagsDownEvent.post(tap: .cghidEventTap)
        }

        // Note: The modifier will remain active until the user presses another key
        // For a complete implementation, we'd need to track when to release the modifier
    }

    private func cgEventFlags(for modifier: ModifierFlag) -> CGEventFlags {
        switch modifier {
        case .command:
            return .maskCommand
        case .control:
            return .maskControl
        case .option:
            return .maskAlternate
        case .shift:
            return .maskShift
        case .function:
            return .maskSecondaryFn
        }
    }
}
