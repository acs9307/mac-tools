import Foundation
import MacToolsCore
import ApplicationServices

/// Agent for handling key manipulation and hotkey registration
public final class KeyManipulationAgent: BaseAgent {
    private var registeredHotkeys: [String: Hotkey] = [:]

    public init() {
        super.init(identifier: "key.manipulation", name: "Key Manipulation")
    }

    override public func performStart() throws {
        logger.info("Starting key manipulation agent")

        // Verify accessibility permissions
        guard PermissionsManager.shared.checkAccessibilityPermissions() else {
            throw AgentError.permissionDenied(
                "Accessibility permissions required for key manipulation. " +
                "Please grant permissions in System Settings > Privacy & Security > Accessibility"
            )
        }

        // Load hotkey configuration
        if let hotkeyConfig = Configuration.shared.get("keyManipulation.hotkeys") as? [String: [String: Any]] {
            for (identifier, config) in hotkeyConfig {
                do {
                    try registerHotkeyFromConfig(identifier: identifier, config: config)
                } catch {
                    logger.warning("Failed to register hotkey '\(identifier)': \(error)")
                }
            }
        }

        logger.info("Key manipulation agent started successfully")
    }

    override public func performStop() throws {
        logger.info("Stopping key manipulation agent")

        // Unregister all hotkeys
        HotkeyManager.shared.unregisterAll()
        registeredHotkeys.removeAll()

        logger.info("Key manipulation agent stopped successfully")
    }

    override public func configure(_ config: [String: Any]) async throws {
        try await super.configure(config)

        if let hotkeys = config["hotkeys"] as? [String: [String: Any]] {
            // Unregister existing hotkeys
            HotkeyManager.shared.unregisterAll()
            registeredHotkeys.removeAll()

            // Register new hotkeys
            for (identifier, hotkeyConfig) in hotkeys {
                do {
                    try registerHotkeyFromConfig(identifier: identifier, config: hotkeyConfig)
                } catch {
                    logger.warning("Failed to register hotkey '\(identifier)': \(error)")
                }
            }
        }
    }

    /// Register a hotkey programmatically
    /// - Parameters:
    ///   - identifier: Unique identifier for the hotkey
    ///   - keyCode: The key combination
    ///   - handler: Closure to execute when hotkey is pressed
    public func registerHotkey(
        identifier: String,
        keyCode: KeyCode,
        handler: @escaping () -> Void
    ) throws {
        guard isRunning else {
            throw AgentError.notRunning(self.identifier)
        }

        guard let hotkey = HotkeyManager.shared.registerHotkey(
            identifier: identifier,
            keyCode: keyCode,
            handler: handler
        ) else {
            throw AgentError.configurationError("Failed to register hotkey '\(identifier)'")
        }

        registeredHotkeys[identifier] = hotkey
        logger.info("Registered hotkey '\(identifier)'")
    }

    /// Unregister a hotkey by identifier
    /// - Parameter identifier: The hotkey identifier
    public func unregisterHotkey(_ identifier: String) {
        HotkeyManager.shared.unregisterHotkey(identifier)
        registeredHotkeys.removeValue(forKey: identifier)
        logger.info("Unregistered hotkey '\(identifier)'")
    }

    /// Simulate a key press
    /// - Parameters:
    ///   - keyCode: The key to press
    ///   - down: Whether to press (true) or release (false)
    public func simulateKeyPress(_ keyCode: KeyCode, down: Bool) throws {
        guard isRunning else {
            throw AgentError.notRunning(self.identifier)
        }

        guard PermissionsManager.shared.checkAccessibilityPermissions() else {
            throw AgentError.permissionDenied("Accessibility permissions required")
        }

        guard let event = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(keyCode.code),
            keyDown: down
        ) else {
            throw AgentError.unsupported("Failed to create keyboard event")
        }

        event.flags = keyCode.modifiers.cgEventFlags
        event.post(tap: .cghidEventTap)

        logger.debug("Simulated key \(down ? "press" : "release"): \(keyCode.code)")
    }

    /// Type a string by simulating key presses
    /// - Parameter text: The text to type
    public func typeText(_ text: String) throws {
        guard isRunning else {
            throw AgentError.notRunning(self.identifier)
        }

        guard PermissionsManager.shared.checkAccessibilityPermissions() else {
            throw AgentError.permissionDenied("Accessibility permissions required")
        }

        for character in text.unicodeScalars {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
                throw AgentError.unsupported("Failed to create keyboard event")
            }

            event.keyboardSetUnicodeString(stringLength: 1, unicodeString: [character.value])
            event.post(tap: .cghidEventTap)
        }

        logger.debug("Typed text: \(text)")
    }

    private func registerHotkeyFromConfig(identifier: String, config: [String: Any]) throws {
        guard let keyCodeValue = config["keyCode"] as? Int else {
            throw AgentError.configurationError("Missing 'keyCode' in hotkey configuration")
        }

        var modifiers: ModifierFlags = []
        if let modifierArray = config["modifiers"] as? [String] {
            for modifier in modifierArray {
                switch modifier.lowercased() {
                case "command", "cmd":
                    modifiers.insert(.command)
                case "shift":
                    modifiers.insert(.shift)
                case "option", "alt":
                    modifiers.insert(.option)
                case "control", "ctrl":
                    modifiers.insert(.control)
                case "function", "fn":
                    modifiers.insert(.function)
                default:
                    logger.warning("Unknown modifier: \(modifier)")
                }
            }
        }

        let keyCode = KeyCode(code: keyCodeValue, modifiers: modifiers)

        // For configuration-based hotkeys, we'll just log when triggered
        try registerHotkey(identifier: identifier, keyCode: keyCode) {
            self.logger.info("Hotkey triggered: \(identifier)")
        }
    }
}
