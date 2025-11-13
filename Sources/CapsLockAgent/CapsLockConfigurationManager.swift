import Foundation
import MacToolsCore

/// Manages loading and saving of CapsLock configuration
public final class CapsLockConfigurationManager {
    private let configuration = Configuration.shared

    public init() {}

    // MARK: - Loading

    /// Load CapsLock configuration from persistent storage
    /// - Returns: The loaded configuration, or default if not found/invalid
    public func load() -> CapsLockConfiguration {
        guard let capsLockConfig = configuration.get("capsLock") as? [String: Any] else {
            return .default
        }

        return parseCapsLockConfiguration(from: capsLockConfig)
    }

    // MARK: - Saving

    /// Save CapsLock configuration to persistent storage
    /// - Parameter config: The configuration to save
    /// - Throws: Error if configuration cannot be saved
    public func save(_ config: CapsLockConfiguration) throws {
        let dict = serializeCapsLockConfiguration(config)
        configuration.set("capsLock", value: dict)
        try configuration.save()
    }

    // MARK: - Parsing

    private func parseCapsLockConfiguration(from dict: [String: Any]) -> CapsLockConfiguration {
        let enabled = dict["enabled"] as? Bool ?? true
        let minPressDuration = dict["minPressDuration"] as? TimeInterval ?? 0.2
        let disableCapsLock = dict["disableCapsLock"] as? Bool ?? true

        let quickTapAction = parseKeyAction(from: dict["quickTapAction"])
            ?? .sendKey(53) // Default to Escape
        let longPressAction = parseKeyAction(from: dict["longPressAction"])
            ?? .sendModifier(.control) // Default to Control

        return CapsLockConfiguration(
            enabled: enabled,
            minPressDuration: minPressDuration,
            quickTapAction: quickTapAction,
            longPressAction: longPressAction,
            disableCapsLock: disableCapsLock
        )
    }

    private func parseKeyAction(from value: Any?) -> KeyAction? {
        guard let dict = value as? [String: Any],
              let type = dict["type"] as? String else {
            return nil
        }

        switch type {
        case "sendKey":
            guard let keyCode = dict["value"] as? Int else { return nil }
            return .sendKey(keyCode)

        case "sendModifier":
            guard let modifierStr = dict["value"] as? String,
                  let modifier = ModifierFlag(rawValue: modifierStr) else {
                return nil
            }
            return .sendModifier(modifier)

        case "disabled":
            return .disabled

        default:
            return nil
        }
    }

    // MARK: - Serialization

    private func serializeCapsLockConfiguration(_ config: CapsLockConfiguration) -> [String: Any] {
        return [
            "enabled": config.enabled,
            "minPressDuration": config.minPressDuration,
            "quickTapAction": serializeKeyAction(config.quickTapAction),
            "longPressAction": serializeKeyAction(config.longPressAction),
            "disableCapsLock": config.disableCapsLock
        ]
    }

    private func serializeKeyAction(_ action: KeyAction) -> [String: Any] {
        switch action {
        case .sendKey(let keyCode):
            return ["type": "sendKey", "value": keyCode]

        case .sendModifier(let modifier):
            return ["type": "sendModifier", "value": modifier.rawValue]

        case .disabled:
            return ["type": "disabled"]
        }
    }

    // MARK: - Specific Value Access

    /// Get the minimum press duration from configuration
    public func getMinPressDuration() -> TimeInterval {
        configuration.get("capsLock.minPressDuration", default: 0.2)
    }

    /// Set the minimum press duration
    public func setMinPressDuration(_ duration: TimeInterval) throws {
        var config = load()
        config.minPressDuration = duration
        try save(config)
    }

    /// Get the enabled state from configuration
    public func getEnabled() -> Bool {
        configuration.get("capsLock.enabled", default: true)
    }

    /// Set the enabled state
    public func setEnabled(_ enabled: Bool) throws {
        var config = load()
        config.enabled = enabled
        try save(config)
    }
}
