import Foundation
import Combine
import MacToolsCore

/// View model for Caps Lock settings UI
@MainActor
public final class CapsLockViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var enabled: Bool = true
    @Published public var minPressDuration: Double = 0.2
    @Published public var disableCapsLock: Bool = true
    @Published public var quickTapAction: KeyAction = .sendKey(53) // Escape
    @Published public var longPressAction: KeyAction = .sendModifier(.control)
    @Published public private(set) var isAgentRunning: Bool = false
    @Published public private(set) var hasAccessibilityPermissions: Bool = false
    @Published public private(set) var error: String?

    // MARK: - Dependencies

    private let agent: CapsLockAgent

    // MARK: - Initialization

    public init(agent: CapsLockAgent = CapsLockAgent()) {
        self.agent = agent
        loadConfiguration()
        checkPermissions()
    }

    // MARK: - Configuration Management

    /// Load current configuration
    public func loadConfiguration() {
        do {
            try agent.reloadConfiguration()
            let config = agent.currentConfiguration

            enabled = config.enabled
            minPressDuration = config.minPressDuration
            disableCapsLock = config.disableCapsLock
            quickTapAction = config.quickTapAction
            longPressAction = config.longPressAction
            isAgentRunning = agent.isRunning

            error = nil
        } catch {
            self.error = "Failed to load configuration: \(error.localizedDescription)"
        }
    }

    /// Save current configuration
    public func saveConfiguration() {
        let config = CapsLockConfiguration(
            enabled: enabled,
            minPressDuration: minPressDuration,
            quickTapAction: quickTapAction,
            longPressAction: longPressAction,
            disableCapsLock: disableCapsLock
        )

        do {
            try agent.updateAndSaveConfiguration(config)
            error = nil
        } catch {
            self.error = "Failed to save configuration: \(error.localizedDescription)"
        }
    }

    /// Apply changes without saving
    public func applyConfiguration() {
        let config = CapsLockConfiguration(
            enabled: enabled,
            minPressDuration: minPressDuration,
            quickTapAction: quickTapAction,
            longPressAction: longPressAction,
            disableCapsLock: disableCapsLock
        )

        Task {
            do {
                try await agent.updateConfiguration(config)
                error = nil
            } catch {
                self.error = "Failed to apply configuration: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Toggle Actions

    /// Toggle enabled state
    public func toggleEnabled() {
        enabled.toggle()
        saveConfiguration()
    }

    /// Toggle disable Caps Lock
    public func toggleDisableCapsLock() {
        disableCapsLock.toggle()
        saveConfiguration()
    }

    // MARK: - Delay Adjustment

    /// Set minimum press duration
    public func setMinPressDuration(_ duration: Double) {
        minPressDuration = max(0.05, min(2.0, duration))
        saveConfiguration()
    }

    /// Increment delay
    public func incrementDelay() {
        setMinPressDuration(minPressDuration + 0.05)
    }

    /// Decrement delay
    public func decrementDelay() {
        setMinPressDuration(minPressDuration - 0.05)
    }

    // MARK: - Key Action Configuration

    /// Set quick tap action
    public func setQuickTapAction(_ action: KeyAction) {
        quickTapAction = action
        saveConfiguration()
    }

    /// Set long press action
    public func setLongPressAction(_ action: KeyAction) {
        longPressAction = action
        saveConfiguration()
    }

    // MARK: - Agent Control

    /// Start the agent
    public func startAgent() {
        do {
            try agent.start()
            isAgentRunning = agent.isRunning
            error = nil
        } catch {
            self.error = "Failed to start agent: \(error.localizedDescription)"
        }
    }

    /// Stop the agent
    public func stopAgent() {
        agent.stop()
        isAgentRunning = agent.isRunning
    }

    /// Restart the agent
    public func restartAgent() {
        stopAgent()
        startAgent()
    }

    // MARK: - Permissions

    /// Check accessibility permissions
    public func checkPermissions() {
        // In a real implementation, this would check AXIsProcessTrusted()
        // For now, we'll use a placeholder
        hasAccessibilityPermissions = true // Placeholder
    }

    /// Request accessibility permissions
    public func requestPermissions() {
        // In a real implementation, this would trigger the system dialog
        // For now, just check again
        checkPermissions()
    }

    // MARK: - Error Handling

    /// Clear error
    public func clearError() {
        error = nil
    }

    // MARK: - Status

    /// Get status description
    public var statusDescription: String {
        if !hasAccessibilityPermissions {
            return "Permissions Required"
        } else if !isAgentRunning {
            return "Agent Not Running"
        } else if !enabled {
            return "Disabled"
        } else {
            return "Active"
        }
    }

    /// Get status color
    public var statusColor: StatusColor {
        if !hasAccessibilityPermissions {
            return .warning
        } else if !isAgentRunning {
            return .error
        } else if !enabled {
            return .inactive
        } else {
            return .active
        }
    }

    public enum StatusColor {
        case active
        case inactive
        case warning
        case error
    }
}

// MARK: - Key Action Helpers

extension CapsLockViewModel {
    /// Available quick tap actions
    public static let availableQuickTapActions: [(name: String, action: KeyAction)] = [
        ("Escape", .sendKey(53)),
        ("Delete", .sendKey(51)),
        ("Control", .sendModifier(.control)),
        ("Command", .sendModifier(.command)),
        ("Option", .sendModifier(.option)),
        ("Disabled", .disabled)
    ]

    /// Available long press actions
    public static let availableLongPressActions: [(name: String, action: KeyAction)] = [
        ("Control", .sendModifier(.control)),
        ("Command", .sendModifier(.command)),
        ("Option", .sendModifier(.option)),
        ("Escape", .sendKey(53)),
        ("Disabled", .disabled)
    ]

    /// Get name for key action
    public func nameForAction(_ action: KeyAction) -> String {
        switch action {
        case .sendKey(53):
            return "Escape"
        case .sendKey(51):
            return "Delete"
        case .sendModifier(.control):
            return "Control"
        case .sendModifier(.command):
            return "Command"
        case .sendModifier(.option):
            return "Option"
        case .disabled:
            return "Disabled"
        default:
            return "Custom"
        }
    }
}
