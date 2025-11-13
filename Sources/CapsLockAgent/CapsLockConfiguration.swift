import Foundation

/// Configuration for Caps Lock manipulation behavior
public struct CapsLockConfiguration: Codable, Equatable {
    /// Enable/disable Caps Lock manipulation
    public var enabled: Bool

    /// Minimum press duration in seconds to distinguish tap vs. hold
    public var minPressDuration: TimeInterval

    /// Action for quick tap (< minPressDuration)
    public var quickTapAction: KeyAction

    /// Action for long press (>= minPressDuration)
    public var longPressAction: KeyAction

    /// Whether to completely disable Caps Lock functionality
    public var disableCapsLock: Bool

    public init(
        enabled: Bool = true,
        minPressDuration: TimeInterval = 0.2,
        quickTapAction: KeyAction = .sendKey(53), // Escape key
        longPressAction: KeyAction = .sendModifier(.control),
        disableCapsLock: Bool = true
    ) {
        self.enabled = enabled
        self.minPressDuration = minPressDuration
        self.quickTapAction = quickTapAction
        self.longPressAction = longPressAction
        self.disableCapsLock = disableCapsLock
    }

    /// Default configuration
    public static var `default`: CapsLockConfiguration {
        CapsLockConfiguration()
    }
}

/// Actions that can be triggered by Caps Lock key
public enum KeyAction: Codable, Equatable {
    /// Send a specific key code
    case sendKey(Int)

    /// Act as a modifier key
    case sendModifier(ModifierFlag)

    /// Do nothing, just suppress the original Caps Lock
    case disabled
}

/// Modifier flags for key actions
public enum ModifierFlag: String, Codable, Equatable {
    case command
    case control
    case option
    case shift
    case function
}
